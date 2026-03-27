"""
Module de description d'images via IA.

Ce module fournit deux endpoints principaux :
- /describe/gemini : Analyse d'image avec Google Gemini Vision
- /describe/groq : Génération de recommandations avec Groq LLM

Pipeline typique :
1. L'utilisateur envoie une image en base64.
2. Gemini analyse l'image et retourne une description textuelle.
3. La description est envoyée à Groq avec le profil utilisateur.
4. Groq génère des recommandations personnalisées (risques, actions).
"""

import os
import json
from pathlib import Path

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field


router = APIRouter()

# ============================================================================
# Configuration des APIs externes
# ============================================================================

# Configuration Google Gemini Vision API
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.0-flash-exp")  # Modèle vision rapide
GEMINI_API_VERSION = os.getenv("GEMINI_API_VERSION", "v1beta")
GEMINI_URL = (
    f"https://generativelanguage.googleapis.com/"
    f"{GEMINI_API_VERSION}/models/{GEMINI_MODEL}:generateContent"
)

# Debug: Afficher les premières lettres de la clé pour vérifier le chargement
if GEMINI_API_KEY:
    print(f"[DEBUG] GEMINI_API_KEY loaded (prefix): {GEMINI_API_KEY[:6]}...", flush=True)
else:
    print("[DEBUG] GEMINI_API_KEY is missing", flush=True)

# Configuration Groq API (LLM Llama)
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
GROQ_MODEL = os.getenv("GROQ_MODEL", "llama-3.1-8b-instant")  # Modèle rapide et économique
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"

# Chargement des profils utilisateur depuis le fichier JSON
PROFILE_PATH = Path(__file__).parent / "user_profiles.json"
try:
    _PROFILES = json.loads(PROFILE_PATH.read_text(encoding="utf-8"))
except FileNotFoundError:
    _PROFILES = {}  # Aucun profil pré-défini


# ============================================================================
# Modèles Pydantic pour validation des requêtes
# ============================================================================

class DescribeRequest(BaseModel):
    """
    Requête pour l'analyse d'image via Gemini.

    Attributes:
        image_b64: Image encodée en base64. Peut inclure le préfixe
                   "data:image/jpeg;base64," ou être l'image brute.
        prompt: Instructions pour l'analyse d'image. Par défaut, demande
                une description des objets, marques et positions.
    """
    image_b64: str = Field(
        ...,
        description="Image encodée en base64 (avec ou sans préfixe data:)"
    )
    prompt: str = Field(
        default="Décris précisément les produits/objets visibles, marques ou catégories, positions relatives.",
        description="Prompt texte pour la description"
    )


class ProductDescribeRequest(BaseModel):
    """Requête pour analyser les deux faces d'un produit en un seul appel Gemini."""
    front_b64: str = Field(..., description="Face avant (base64)")
    back_b64: str | None = Field(default=None, description="Face arrière (base64, optionnel)")


class GroqRequest(BaseModel):
    """
    Requête pour la génération de recommandations via Groq.

    Attributes:
        description: Texte descriptif de la scène (généralement sortie de Gemini)
        profile: Identifiant du profil dans le catalogue (ex: "wheelchair_diabetic")
        instruction: Format de sortie attendu (JSON avec summary, risks, actions)
        profile_override: Profil personnalisé envoyé par le client, prioritaire
                         sur le catalogue
    """
    description: str = Field(
        ...,
        description="Texte descriptif (ex: sortie Gemini)"
    )
    profile: str = Field(
        default="default",
        description="Profil utilisateur (pour les consignes)"
    )
    instruction: str = Field(
        default='Génère un JSON minimal : {"summary": string, "risks": [string], "actions": [string]}',
        description="Instruction envoyée au LLM Groq"
    )
    profile_override: dict | None = Field(
        default=None,
        description="Profil inline pour écraser le catalogue"
    )


# ============================================================================
# Endpoints API
# ============================================================================

@router.post("/describe/gemini")
async def describe_gemini(payload: DescribeRequest) -> dict:
    """
    Analyse une image avec Google Gemini Vision API.

    Envoie l'image et le prompt à Gemini qui retourne une description
    textuelle détaillée de la scène. Cette description peut ensuite
    être utilisée par Groq pour générer des recommandations.

    Args:
        payload: Requête contenant l'image base64 et le prompt

    Returns:
        dict contenant:
        - structured: Données structurées (text, model, prompt)
        - raw: Réponse brute de l'API Gemini

    Raises:
        HTTPException 500: Si GEMINI_API_KEY manquante ou appel échoué
    """
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY manquante côté serveur")

    # Extraire le base64 pur si préfixe data: présent
    b64 = payload.image_b64
    if "," in b64:  # Format: data:image/jpeg;base64,/9j/4AAQ...
        b64 = b64.split(",", 1)[1]

    # Construction du body pour l'API Gemini (format multimodal)
    body = {
        "contents": [
            {
                "parts": [
                    {"text": payload.prompt},
                    {
                        "inline_data": {
                            "mime_type": "image/jpeg",
                            "data": b64,
                        }
                    },
                ]
            }
        ]
    }

    headers = {
        "Content-Type": "application/json",
        "x-goog-api-key": GEMINI_API_KEY,
    }

    # Appel asynchrone à l'API Gemini
    try:
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post(GEMINI_URL, headers=headers, json=body)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Appel Gemini échoué: {exc}") from exc

    if resp.status_code != 200:
        # Renvoyer l'erreur complète pour diagnostic
        raise HTTPException(status_code=resp.status_code, detail=resp.text)

    data = resp.json()

    # Extraction du texte depuis la structure de réponse Gemini
    parts = data.get("candidates", [{}])[0].get("content", {}).get("parts", [])
    text = " ".join([p.get("text", "") for p in parts if isinstance(p, dict)]).strip()

    # Payload structuré prêt à être transmis à Groq
    structured = {
        "text": text,
        "raw_parts": parts,
        "prompt": payload.prompt,
        "model": GEMINI_MODEL,
    }
    return {"structured": structured, "raw": data}


@router.post("/describe/gemini/product")
async def describe_gemini_product(payload: ProductDescribeRequest) -> dict:
    """
    Analyse les deux faces d'un produit en un seul appel Gemini.
    Envoie les deux images dans la même requête pour économiser les tokens
    et obtenir une description cohérente face avant + face arrière.
    """
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY manquante côté serveur")

    def clean_b64(raw: str) -> str:
        return raw.split(",", 1)[1] if "," in raw else raw

    parts: list[dict] = [
        {"text": (
            "Voici les faces d'un produit de consommation. "
            "Analyse-les ensemble et fournis une description complète et précise : "
            "nom du produit, marque, catégorie (face avant) ; "
            "ingrédients, allergènes, valeurs nutritionnelles, informations importantes (face arrière si fournie). "
            "Sois exhaustif et factuel."
        )},
        {"text": "— Face avant du produit :"},
        {"inline_data": {"mime_type": "image/jpeg", "data": clean_b64(payload.front_b64)}},
    ]

    if payload.back_b64:
        parts.append({"text": "— Face arrière du produit :"})
        parts.append({"inline_data": {"mime_type": "image/jpeg", "data": clean_b64(payload.back_b64)}})

    body = {"contents": [{"parts": parts}]}
    headers = {"Content-Type": "application/json", "x-goog-api-key": GEMINI_API_KEY}

    try:
        async with httpx.AsyncClient(timeout=90) as client:
            resp = await client.post(GEMINI_URL, headers=headers, json=body)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Appel Gemini échoué: {exc}") from exc

    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)

    data = resp.json()
    p = data.get("candidates", [{}])[0].get("content", {}).get("parts", [])
    text = " ".join([x.get("text", "") for x in p if isinstance(x, dict)]).strip()

    return {"structured": {"text": text, "model": GEMINI_MODEL}, "raw": data}


@router.post("/describe/groq")
async def describe_groq(payload: GroqRequest) -> dict:
    """
    Génère des recommandations personnalisées via Groq LLM.

    Prend une description textuelle (généralement de Gemini) et le profil
    utilisateur pour générer des recommandations adaptées : résumé de la
    situation, risques potentiels, et actions recommandées.

    Args:
        payload: Requête contenant la description et le profil utilisateur

    Returns:
        dict contenant:
        - structured: JSON parsé avec summary, risks, actions (si valide)
        - raw_text: Texte brut retourné par Groq
        - raw: Réponse complète de l'API Groq

    Raises:
        HTTPException 500: Si GROQ_API_KEY manquante ou appel échoué
    """
    if not GROQ_API_KEY:
        raise HTTPException(status_code=500, detail="GROQ_API_KEY manquante côté serveur")

    # Priorité au profil envoyé par le client, sinon utiliser le catalogue
    profile_data = payload.profile_override or _PROFILES.get(payload.profile) or _PROFILES.get("default", {})

    # Prompt système définissant le comportement de l'assistant
    system_prompt = (
        "Tu es un assistant de sécurité pour la mobilité PMR. "
        "Réponds STRICTEMENT en JSON sans texte hors JSON. "
        "Inclue des risques potentiels et des actions/recommandations courtes."
    )

    # Prompt utilisateur avec contexte complet
    user_prompt = (
        f"Profil: {payload.profile}\n"
        f"Données profil: {json.dumps(profile_data, ensure_ascii=False)}\n"
        f"Description:\n{payload.description}\n"
        f"Consigne de sortie: {payload.instruction}"
    )

    # Construction du body pour l'API Groq (format OpenAI-compatible)
    body = {
        "model": GROQ_MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": 0.2,  # Basse température pour réponses cohérentes
    }
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {GROQ_API_KEY}",
    }

    # Appel asynchrone à l'API Groq
    try:
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post(GROQ_URL, headers=headers, json=body)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Appel Groq échoué: {exc}") from exc

    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)

    data = resp.json()

    # Extraction du contenu de la réponse
    content = data.get("choices", [{}])[0].get("message", {}).get("content", "")

    # Tentative de parsing JSON du contenu
    parsed = None
    try:
        parsed = json.loads(content)
    except Exception:
        parsed = None  # Le contenu n'est pas du JSON valide

    return {"structured": parsed, "raw_text": content, "raw": data}
