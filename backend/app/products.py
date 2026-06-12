"""
Module d'identification de produits par code-barres (Open Food Facts).

Deux modes d'identification :
- /lookup : le client fournit directement le code-barres (EAN-8/EAN-13)
- /identify : le client fournit une photo ; Gemini lit les chiffres du
  code-barres, puis Open Food Facts fournit les données certifiées.

Open Food Facts est une base ouverte et gratuite (pas de clé API) très
bien fournie sur les produits alimentaires français. Elle apporte des
données FIABLES (nom exact, marque, allergènes officiels, Nutri-Score)
là où la vision IA seule peut se tromper.

Le croisement avec les allergies du profil utilisateur permet une alerte
vocale immédiate : « Attention, contient de l'arachide, présente dans
votre profil. »
"""

import json
import os
import re

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

router = APIRouter()

# ============================================================================
# Configuration
# ============================================================================

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.0-flash-exp")
GEMINI_API_VERSION = os.getenv("GEMINI_API_VERSION", "v1beta")
GEMINI_URL = (
    f"https://generativelanguage.googleapis.com/"
    f"{GEMINI_API_VERSION}/models/{GEMINI_MODEL}:generateContent"
)

OFF_URL = "https://world.openfoodfacts.org/api/v2/product/{code}.json"
# Champs demandés à OFF (limite la taille des réponses)
OFF_FIELDS = (
    "product_name,product_name_fr,brands,quantity,nutriscore_grade,"
    "allergens_tags,ingredients_text_fr,ingredients_text,categories_tags"
)
# User-Agent requis par les conditions d'utilisation d'Open Food Facts
OFF_USER_AGENT = "Vision360-SAE/1.0 (projet universitaire d'assistance aux malvoyants)"

# Traduction française des 14 allergènes majeurs (tags Open Food Facts)
ALLERGEN_FR = {
    "en:gluten": "gluten",
    "en:crustaceans": "crustacés",
    "en:eggs": "œufs",
    "en:fish": "poisson",
    "en:peanuts": "arachide",
    "en:soybeans": "soja",
    "en:milk": "lait",
    "en:nuts": "fruits à coque",
    "en:celery": "céleri",
    "en:mustard": "moutarde",
    "en:sesame-seeds": "sésame",
    "en:sulphur-dioxide-and-sulphites": "sulfites",
    "en:lupin": "lupin",
    "en:molluscs": "mollusques",
}


# ============================================================================
# Modèles Pydantic
# ============================================================================

class LookupRequest(BaseModel):
    """Recherche directe par code-barres."""
    barcode: str = Field(..., description="Code-barres EAN-8 ou EAN-13 (chiffres)")
    allergies: list[str] = Field(
        default_factory=list,
        description="Allergies du profil utilisateur (ex: ['arachide', 'lait'])",
    )


class IdentifyRequest(BaseModel):
    """Identification par photo : Gemini lit le code-barres puis lookup OFF."""
    image_b64: str = Field(..., description="Photo du produit côté code-barres (base64)")
    allergies: list[str] = Field(default_factory=list)


# ============================================================================
# Helpers
# ============================================================================

def _clean_b64(raw: str) -> str:
    return raw.split(",", 1)[1] if "," in raw else raw


def _extract_json(text: str):
    """Extrait un objet JSON d'une réponse LLM (gère les fences markdown)."""
    text = text.strip()
    fence = re.search(r"```(?:json)?\s*(.*?)```", text, re.DOTALL)
    if fence:
        text = fence.group(1).strip()
    try:
        return json.loads(text)
    except Exception:
        pass
    start = text.find("{")
    if start == -1:
        return None
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                try:
                    return json.loads(text[start:i + 1])
                except Exception:
                    return None
    return None


async def _call_gemini(parts: list[dict], timeout: int = 30) -> str:
    """Appelle Gemini et retourne le texte de la réponse."""
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY manquante côté serveur")
    body = {"contents": [{"parts": parts}]}
    headers = {"Content-Type": "application/json", "x-goog-api-key": GEMINI_API_KEY}
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            resp = await client.post(GEMINI_URL, headers=headers, json=body)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Appel Gemini échoué: {exc}") from exc
    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)
    data = resp.json()
    p = data.get("candidates", [{}])[0].get("content", {}).get("parts", [])
    return " ".join(x.get("text", "") for x in p if isinstance(x, dict)).strip()


async def _fetch_off(barcode: str) -> dict | None:
    """
    Interroge Open Food Facts pour un code-barres.

    Returns:
        Le dict 'product' d'OFF, ou None si le produit est inconnu.
    """
    url = OFF_URL.format(code=barcode)
    headers = {"User-Agent": OFF_USER_AGENT}
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.get(url, params={"fields": OFF_FIELDS}, headers=headers)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Open Food Facts injoignable: {exc}") from exc
    if resp.status_code == 404:
        return None
    if resp.status_code != 200:
        raise HTTPException(status_code=502, detail=f"Open Food Facts: HTTP {resp.status_code}")
    data = resp.json()
    if data.get("status") != 1:
        return None
    return data.get("product")


def _normalize_product(barcode: str, product: dict, allergies: list[str]) -> dict:
    """
    Normalise la réponse OFF et croise les allergènes avec le profil.

    Construit aussi le message vocal adapté à une lecture TTS.
    """
    name = product.get("product_name_fr") or product.get("product_name") or "Produit sans nom"
    brand = (product.get("brands") or "").split(",")[0].strip()
    quantity = product.get("quantity") or ""
    nutriscore = (product.get("nutriscore_grade") or "").upper()

    # Allergènes officiels traduits en français
    allergen_tags = product.get("allergens_tags") or []
    allergens_fr = [ALLERGEN_FR.get(tag, tag.removeprefix("en:")) for tag in allergen_tags]

    # Croisement avec les allergies du profil (correspondance souple,
    # insensible à la casse, dans les deux sens : "lait" ↔ "lait de vache")
    profile_alerts = []
    for allergen in allergens_fr:
        for user_allergy in allergies:
            a, u = allergen.lower().strip(), user_allergy.lower().strip()
            if u and (u in a or a in u):
                profile_alerts.append(allergen)
                break

    # Message vocal
    parts = [name]
    if quantity:
        parts.append(quantity)
    if brand:
        parts.append(f"marque {brand}")
    voice = ", ".join(parts) + "."
    if nutriscore:
        voice += f" Nutri-score {nutriscore}."
    if profile_alerts:
        voice += (
            f" Attention, allergène de votre profil détecté : "
            f"{', '.join(sorted(set(profile_alerts)))}. Produit déconseillé."
        )
    elif allergens_fr:
        voice += f" Contient : {', '.join(allergens_fr)}."

    return {
        "found": True,
        "barcode": barcode,
        "name": name,
        "brand": brand,
        "quantity": quantity,
        "nutriscore": nutriscore,
        "allergens": allergens_fr,
        "profile_allergen_alerts": sorted(set(profile_alerts)),
        "ingredients": product.get("ingredients_text_fr") or product.get("ingredients_text") or "",
        "voice_message": voice,
    }


# ============================================================================
# Endpoints
# ============================================================================

@router.post("/lookup")
async def lookup_barcode(payload: LookupRequest) -> dict:
    """
    Recherche un produit par son code-barres dans Open Food Facts.

    Croise les allergènes officiels du produit avec les allergies du
    profil utilisateur et construit un message vocal.
    """
    barcode = re.sub(r"\D", "", payload.barcode)
    if not (8 <= len(barcode) <= 14):
        raise HTTPException(status_code=422, detail="Code-barres invalide (8 à 14 chiffres attendus)")

    product = await _fetch_off(barcode)
    if product is None:
        return {
            "found": False,
            "barcode": barcode,
            "voice_message": (
                "Produit introuvable dans la base Open Food Facts. "
                "Essayez l'analyse visuelle classique."
            ),
        }
    return _normalize_product(barcode, product, payload.allergies)


_BARCODE_PROMPT = (
    "Cette image montre un produit de consommation. Trouve le code-barres "
    "(EAN-8 ou EAN-13) et lis la séquence de chiffres imprimée sous les barres. "
    "Réponds STRICTEMENT en JSON sans texte hors JSON : "
    '{"barcode": string|null}. '
    "Mets null si aucun code-barres n'est lisible. Ne devine jamais les chiffres."
)


@router.post("/identify")
async def identify_product(payload: IdentifyRequest) -> dict:
    """
    Identifie un produit à partir d'une photo de son code-barres.

    Pipeline : Gemini lit les chiffres du code-barres sur la photo,
    puis Open Food Facts fournit les données certifiées du produit.
    Aucune dépendance de scan côté mobile n'est nécessaire.
    """
    text = await _call_gemini([
        {"text": _BARCODE_PROMPT},
        {"inline_data": {"mime_type": "image/jpeg", "data": _clean_b64(payload.image_b64)}},
    ])
    parsed = _extract_json(text) or {}
    barcode = parsed.get("barcode")
    digits = re.sub(r"\D", "", str(barcode)) if barcode else ""

    if not digits or not (8 <= len(digits) <= 14):
        return {
            "found": False,
            "barcode": None,
            "voice_message": (
                "Je n'ai pas pu lire de code-barres. Rapprochez l'appareil "
                "du code-barres et tenez-le stable."
            ),
        }

    product = await _fetch_off(digits)
    if product is None:
        return {
            "found": False,
            "barcode": digits,
            "voice_message": (
                f"Code-barres {' '.join(digits)} lu, mais produit introuvable "
                "dans la base Open Food Facts. Essayez l'analyse visuelle classique."
            ),
        }
    return _normalize_product(digits, product, payload.allergies)
