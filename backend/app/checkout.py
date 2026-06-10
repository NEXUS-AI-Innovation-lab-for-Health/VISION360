"""
Module d'assistance au passage en caisse pour personnes malvoyantes.

Implémente le scénario complet en 5 fonctionnalités :
1. Scan du tapis de caisse : identification des articles (Gemini Vision)
2. Suivi du transfert tapis -> caddie : comparaison entre deux captures
3. Détection des articles oubliés : diff liste initiale vs caddie
4. Lecture du ticket de caisse : OCR via Gemini (articles, prix, total)
5. Rapprochement ticket/caddie : correspondance sémantique via Groq

L'état de la session (articles du tapis, inventaire du caddie, ticket)
est conservé en mémoire serveur, indexé par session_id.

Chaque réponse contient un champ `voice_message` : une phrase naturelle,
concise, prête à être lue par la synthèse vocale du client.
"""

import json
import os
import re
import uuid
from datetime import datetime, timezone

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

router = APIRouter()

# ============================================================================
# Configuration des APIs externes (mêmes variables que describe.py)
# ============================================================================

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.0-flash-exp")
GEMINI_API_VERSION = os.getenv("GEMINI_API_VERSION", "v1beta")
GEMINI_URL = (
    f"https://generativelanguage.googleapis.com/"
    f"{GEMINI_API_VERSION}/models/{GEMINI_MODEL}:generateContent"
)

GROQ_API_KEY = os.getenv("GROQ_API_KEY")
GROQ_MODEL = os.getenv("GROQ_MODEL", "llama-3.1-8b-instant")
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"

# ============================================================================
# Stockage en mémoire des sessions de caisse
# ============================================================================

# Structure d'une session :
# {
#   "created_at": str ISO,
#   "belt_initial": [ {name, quantity, confidence} ],  # premier scan du tapis
#   "belt_current": [...],                              # dernier état connu du tapis
#   "cart_items": [...],                                # articles transférés dans le caddie
#   "ticket": {"items": [...], "total": float} | None,
#   "uncertain_items": [str],                           # articles au statut douteux
# }
_SESSIONS: dict[str, dict] = {}

# Limite de sessions simultanées pour éviter une croissance mémoire illimitée
_MAX_SESSIONS = 200


def _get_session(session_id: str) -> dict:
    session = _SESSIONS.get(session_id)
    if session is None:
        raise HTTPException(status_code=404, detail="Session de caisse inconnue ou expirée")
    return session


# ============================================================================
# Helpers appels LLM
# ============================================================================

def _clean_b64(raw: str) -> str:
    """Retire le préfixe data:image/...;base64, s'il est présent."""
    return raw.split(",", 1)[1] if "," in raw else raw


def _extract_json(text: str):
    """
    Extrait un objet JSON d'une réponse LLM.

    Gère les blocs markdown ```json ... ``` et le texte parasite
    avant/après l'objet JSON.
    """
    text = text.strip()
    # Retirer les fences markdown
    fence = re.search(r"```(?:json)?\s*(.*?)```", text, re.DOTALL)
    if fence:
        text = fence.group(1).strip()
    # Tenter le parse direct
    try:
        return json.loads(text)
    except Exception:
        pass
    # Chercher le premier objet { ... } équilibré
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


async def _call_gemini(parts: list[dict], timeout: int = 60) -> str:
    """Appelle Gemini avec une liste de parts (texte + images) et retourne le texte."""
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


async def _call_groq(system_prompt: str, user_prompt: str, timeout: int = 60) -> str:
    """Appelle Groq (format OpenAI) et retourne le contenu de la réponse."""
    if not GROQ_API_KEY:
        raise HTTPException(status_code=500, detail="GROQ_API_KEY manquante côté serveur")
    body = {
        "model": GROQ_MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": 0.2,
    }
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {GROQ_API_KEY}"}
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            resp = await client.post(GROQ_URL, headers=headers, json=body)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Appel Groq échoué: {exc}") from exc
    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)
    data = resp.json()
    return data.get("choices", [{}])[0].get("message", {}).get("content", "")


def _qty(value, default: int = 1) -> int:
    """
    Convertit une quantité renvoyée par le LLM en entier sûr.

    Les LLM renvoient parfois "2", 2.0, null ou du texte : on ne doit
    jamais planter sur une quantité mal formée.
    """
    try:
        return max(1, int(float(value)))
    except (TypeError, ValueError):
        return default


def _items_to_text(items: list[dict]) -> str:
    """Formate une liste d'articles en texte lisible pour un prompt LLM."""
    if not items:
        return "(aucun article)"
    lines = []
    for it in items:
        qty = _qty(it.get("quantity"))
        name = it.get("name", "article inconnu")
        lines.append(f"- {qty} x {name}")
    return "\n".join(lines)


def _spoken_list(items: list[dict]) -> str:
    """Formate une liste d'articles en phrase naturelle pour la lecture vocale."""
    parts = []
    for it in items:
        qty = _qty(it.get("quantity"))
        name = str(it.get("name", "article inconnu"))
        parts.append(f"{qty} {name}" if qty > 1 else name)
    if not parts:
        return ""
    if len(parts) == 1:
        return parts[0]
    return ", ".join(parts[:-1]) + " et " + parts[-1]


# ============================================================================
# Modèles Pydantic
# ============================================================================

class StartResponse(BaseModel):
    session_id: str
    voice_message: str


class ImageRequest(BaseModel):
    """Requête générique : session + image base64."""
    session_id: str = Field(..., description="Identifiant de session de caisse")
    image_b64: str = Field(..., description="Image encodée en base64 (avec ou sans préfixe data:)")


class ForgottenRequest(BaseModel):
    """Requête de détection des oublis. L'image du caddie est optionnelle."""
    session_id: str
    cart_image_b64: str | None = Field(
        default=None,
        description="Photo du caddie pour confirmation visuelle (optionnel)",
    )


class SessionRequest(BaseModel):
    session_id: str


# ============================================================================
# Fonctionnalité 0 : gestion de session
# ============================================================================

@router.post("/start", response_model=StartResponse)
def start_session() -> StartResponse:
    """
    Démarre une nouvelle session d'assistance au passage en caisse.

    À appeler quand l'utilisateur arrive au niveau de la caisse.
    Retourne un session_id à transmettre à tous les appels suivants.
    """
    # Purge simple si trop de sessions accumulées (les plus anciennes d'abord)
    if len(_SESSIONS) >= _MAX_SESSIONS:
        oldest = sorted(_SESSIONS, key=lambda k: _SESSIONS[k]["created_at"])[: _MAX_SESSIONS // 2]
        for k in oldest:
            _SESSIONS.pop(k, None)

    session_id = uuid.uuid4().hex
    _SESSIONS[session_id] = {
        "created_at": datetime.now(timezone.utc).isoformat(),
        "belt_initial": [],
        "belt_current": [],
        "cart_items": [],
        "ticket": None,
        "uncertain_items": [],
    }
    return StartResponse(
        session_id=session_id,
        voice_message=(
            "Assistance caisse activée. Placez votre téléphone face au tapis "
            "et lancez le scan des articles."
        ),
    )


@router.get("/session/{session_id}")
def get_session_state(session_id: str) -> dict:
    """Retourne l'état complet d'une session (debug / reprise côté client)."""
    return {"session_id": session_id, **_get_session(session_id)}


@router.delete("/session/{session_id}")
def end_session(session_id: str) -> dict:
    """Termine et supprime une session de caisse."""
    _SESSIONS.pop(session_id, None)
    return {"status": "ended", "voice_message": "Session de caisse terminée."}


# ============================================================================
# Fonctionnalité 1 : détection des articles sur le tapis
# ============================================================================

_BELT_SCAN_PROMPT = (
    "Tu es un assistant pour personnes malvoyantes dans un supermarché. "
    "Analyse cette image du tapis de caisse et identifie chaque article visible, "
    "y compris les articles partiellement visibles ou superposés. "
    "Réponds STRICTEMENT en JSON, sans aucun texte hors JSON, au format : "
    '{"empty": boolean, "items": [{"name": string, "quantity": number, '
    '"confidence": "high"|"low"}]}. '
    'Utilise "confidence": "low" pour tout article dont tu n\'es pas certain '
    "(flou, reflet, partiellement caché). "
    'Si le tapis est vide, réponds {"empty": true, "items": []}.'
)


@router.post("/belt/scan")
async def belt_scan(payload: ImageRequest) -> dict:
    """
    Fonctionnalité 1 : scan du tapis de caisse.

    Capture le contenu du tapis, identifie chaque article via Gemini Vision
    et initialise la liste de référence de la session (belt_initial).

    Cas limites gérés :
    - Tapis vide -> "Le tapis semble vide"
    - Article incertain -> signalé dans le message vocal
    """
    session = _get_session(payload.session_id)

    text = await _call_gemini([
        {"text": _BELT_SCAN_PROMPT},
        {"inline_data": {"mime_type": "image/jpeg", "data": _clean_b64(payload.image_b64)}},
    ])
    parsed = _extract_json(text)
    if parsed is None:
        raise HTTPException(status_code=502, detail=f"Réponse Gemini non exploitable: {text[:200]}")

    items = [it for it in parsed.get("items", []) if isinstance(it, dict) and it.get("name")]
    is_empty = bool(parsed.get("empty")) or not items

    if is_empty:
        session["belt_current"] = []
        if not session["belt_initial"]:
            return {
                "empty": True,
                "items": [],
                "voice_message": "Le tapis semble vide.",
            }
        return {
            "empty": True,
            "items": [],
            "voice_message": "Le tapis semble vide. Tous les articles ont été retirés.",
        }

    # Premier scan -> liste de référence ; sinon simple rafraîchissement
    if not session["belt_initial"]:
        session["belt_initial"] = items
    session["belt_current"] = items

    sure = [it for it in items if it.get("confidence") != "low"]
    unsure = [it for it in items if it.get("confidence") == "low"]
    session["uncertain_items"] = [it["name"] for it in unsure]

    total_count = sum(_qty(it.get("quantity")) for it in items)
    if sure:
        msg = f"J'ai détecté {total_count} article(s) sur le tapis : {_spoken_list(sure)}."
    else:
        msg = f"J'ai détecté {total_count} article(s) sur le tapis."
    if unsure:
        msg += (
            f" Attention, un ou plusieurs articles ne sont pas identifiés avec certitude : "
            f"{_spoken_list(unsure)}. Vérifiez leur position."
        )

    return {"empty": False, "items": items, "uncertain": session["uncertain_items"], "voice_message": msg}


# ============================================================================
# Fonctionnalité 2 : détection du transfert tapis -> caddie
# ============================================================================

_TRANSFER_MATCH_SYSTEM = (
    "Tu es un assistant logique pour personnes malvoyantes en caisse de supermarché. "
    "On te donne l'état précédent du tapis de caisse et son état actuel. "
    "Détermine quels articles ont disparu du tapis (supposés transférés dans le caddie). "
    "Gère la correspondance sémantique entre noms proches (marque vs générique). "
    "Réponds STRICTEMENT en JSON sans texte hors JSON : "
    '{"transferred": [{"name": string, "quantity": number}], '
    '"still_on_belt": [{"name": string, "quantity": number}], '
    '"uncertain": [string]}'
)


@router.post("/belt/transfer")
async def belt_transfer(payload: ImageRequest) -> dict:
    """
    Fonctionnalité 2 : suivi du transfert tapis -> caddie.

    Compare l'état actuel du tapis (nouvelle capture analysée par Gemini)
    avec l'état précédent. Les articles disparus sont supposés transférés
    dans le caddie : l'inventaire interne est mis à jour.

    Cas limite : article disparu mais incertain -> alerte
    "Un article a peut-être quitté le tapis mais n'est pas visible dans le caddie".
    """
    session = _get_session(payload.session_id)
    if not session["belt_initial"]:
        raise HTTPException(status_code=409, detail="Faites d'abord un scan initial du tapis (/belt/scan)")

    previous = session["belt_current"]

    # Nouvelle analyse du tapis par Gemini
    text = await _call_gemini([
        {"text": _BELT_SCAN_PROMPT},
        {"inline_data": {"mime_type": "image/jpeg", "data": _clean_b64(payload.image_b64)}},
    ])
    parsed = _extract_json(text)
    if parsed is None:
        raise HTTPException(status_code=502, detail=f"Réponse Gemini non exploitable: {text[:200]}")
    current = [it for it in parsed.get("items", []) if isinstance(it, dict) and it.get("name")]

    # Comparaison sémantique des deux états via Groq
    groq_text = await _call_groq(
        _TRANSFER_MATCH_SYSTEM,
        f"État précédent du tapis :\n{_items_to_text(previous)}\n\n"
        f"État actuel du tapis :\n{_items_to_text(current)}",
    )
    diff = _extract_json(groq_text) or {"transferred": [], "still_on_belt": current, "uncertain": []}

    transferred = [it for it in diff.get("transferred", []) if isinstance(it, dict) and it.get("name")]
    uncertain = [str(u) for u in diff.get("uncertain", [])]

    # Mise à jour de l'inventaire interne du caddie
    session["cart_items"].extend(transferred)
    session["belt_current"] = current

    if transferred:
        msg = f"Transféré dans le caddie : {_spoken_list(transferred)}."
    else:
        msg = "Aucun nouvel article transféré depuis la dernière vérification."
    if uncertain:
        msg += (
            " Attention : un article a peut-être quitté le tapis mais n'est pas "
            f"visible dans le caddie : {', '.join(uncertain)}."
        )
    if not current:
        msg += " Le tapis est maintenant vide."

    return {
        "transferred": transferred,
        "still_on_belt": current,
        "uncertain": uncertain,
        "cart_items": session["cart_items"],
        "belt_empty": not current,
        "voice_message": msg,
    }


# ============================================================================
# Fonctionnalité 3 : détection des articles oubliés
# ============================================================================

_FORGOTTEN_SYSTEM = (
    "Tu es un assistant pour personnes malvoyantes en caisse de supermarché. "
    "Compare la liste initiale des articles posés sur le tapis avec la liste des "
    "articles confirmés dans le caddie. Gère la correspondance sémantique entre "
    "noms proches (marque vs générique, singulier/pluriel). "
    "Si une photo du caddie est décrite, utilise-la comme confirmation supplémentaire. "
    "Ne JAMAIS affirmer un oubli si tu as un doute : signale le doute. "
    "Réponds STRICTEMENT en JSON sans texte hors JSON : "
    '{"forgotten": [{"name": string, "quantity": number}], '
    '"doubtful": [string], "all_transferred": boolean, '
    '"voice_message": string}. '
    'Le "voice_message" est une phrase naturelle en français adaptée à une lecture vocale, '
    'par exemple : "Attention, il semble que les deux yaourts n\'aient pas été '
    'transférés dans votre caddie."'
)


@router.post("/forgotten")
async def detect_forgotten(payload: ForgottenRequest) -> dict:
    """
    Fonctionnalité 3 : détection des articles oubliés.

    À la fin du passage (tapis vide ou déclenchement manuel), compare la liste
    initiale du tapis avec l'inventaire du caddie. Une photo du caddie peut être
    fournie pour confirmation visuelle.

    Cas limite : incertitude sur un article -> le doute est signalé sans
    affirmer l'oubli.
    """
    session = _get_session(payload.session_id)
    if not session["belt_initial"]:
        raise HTTPException(status_code=409, detail="Aucun scan initial du tapis pour cette session")

    cart_visual = ""
    if payload.cart_image_b64:
        # Scan visuel optionnel du caddie pour confirmation
        cart_visual = await _call_gemini([
            {"text": (
                "Liste les articles visibles dans ce caddie de supermarché. "
                "Réponds en texte simple, un article par ligne."
            )},
            {"inline_data": {"mime_type": "image/jpeg", "data": _clean_b64(payload.cart_image_b64)}},
        ])

    user_prompt = (
        f"Articles initialement sur le tapis :\n{_items_to_text(session['belt_initial'])}\n\n"
        f"Articles confirmés transférés dans le caddie :\n{_items_to_text(session['cart_items'])}"
    )
    if cart_visual:
        user_prompt += f"\n\nContenu visible sur la photo du caddie :\n{cart_visual}"
    if session["uncertain_items"]:
        user_prompt += (
            f"\n\nArticles dont l'identification initiale était incertaine : "
            f"{', '.join(session['uncertain_items'])}"
        )

    groq_text = await _call_groq(_FORGOTTEN_SYSTEM, user_prompt)
    result = _extract_json(groq_text)
    if result is None:
        raise HTTPException(status_code=502, detail=f"Réponse Groq non exploitable: {groq_text[:200]}")

    forgotten = result.get("forgotten", [])
    doubtful = result.get("doubtful", [])
    all_ok = bool(result.get("all_transferred")) and not forgotten

    voice = result.get("voice_message") or (
        "Tous les articles semblent avoir été transférés dans votre caddie."
        if all_ok
        else f"Attention, articles possiblement oubliés : {_spoken_list(forgotten)}."
    )

    return {
        "forgotten": forgotten,
        "doubtful": doubtful,
        "all_transferred": all_ok,
        "cart_scan_used": bool(payload.cart_image_b64),
        "voice_message": voice,
    }


# ============================================================================
# Fonctionnalité 4 : scan et lecture du ticket de caisse
# ============================================================================

_TICKET_PROMPT = (
    "Tu es un assistant pour personnes malvoyantes. Cette image montre un ticket "
    "de caisse de supermarché (imprimé ou affiché sur un écran de borne). "
    "Il peut être froissé, mal imprimé, en petits caractères ou multi-colonnes. "
    "Extrais la liste des articles facturés en ignorant les lignes de promotion, "
    "remises et sous-totaux intermédiaires (mais applique les remises au total). "
    "Réponds STRICTEMENT en JSON sans texte hors JSON : "
    '{"readable": boolean, "items": [{"name": string, "quantity": number, '
    '"unit_price": number, "line_total": number}], "total": number, '
    '"currency": string}. '
    'Si le ticket est illisible, réponds {"readable": false, "items": [], "total": 0, "currency": "EUR"}.'
)


@router.post("/ticket/scan")
async def ticket_scan(payload: ImageRequest) -> dict:
    """
    Fonctionnalité 4 : scan et lecture du ticket de caisse.

    Après le paiement, capture le ticket et en extrait via Gemini :
    désignation, quantité, prix unitaire et total de chaque article.

    Cas limites gérés : ticket froissé, manque d'encre, petits caractères,
    tickets multi-colonnes, lignes de promotion.
    """
    session = _get_session(payload.session_id)

    text = await _call_gemini([
        {"text": _TICKET_PROMPT},
        {"inline_data": {"mime_type": "image/jpeg", "data": _clean_b64(payload.image_b64)}},
    ], timeout=90)
    parsed = _extract_json(text)
    if parsed is None:
        raise HTTPException(status_code=502, detail=f"Réponse Gemini non exploitable: {text[:200]}")

    if not parsed.get("readable", True) or not parsed.get("items"):
        return {
            "readable": False,
            "items": [],
            "total": 0,
            "voice_message": (
                "Le ticket n'a pas pu être lu correctement. "
                "Essayez de le déplier, de l'aplatir et de le recadrer dans l'image."
            ),
        }

    items = [it for it in parsed.get("items", []) if isinstance(it, dict) and it.get("name")]
    total = parsed.get("total") or 0
    currency = str(parsed.get("currency") or "EUR")
    nb = sum(_qty(it.get("quantity")) for it in items)

    session["ticket"] = {"items": items, "total": total, "currency": currency}

    unit = "euros" if currency.upper() in ("EUR", "€") else currency
    return {
        "readable": True,
        "items": items,
        "total": total,
        "currency": currency,
        "voice_message": f"Votre ticket contient {nb} article(s) pour un total de {total} {unit}.",
    }


# ============================================================================
# Fonctionnalité 5 : rapprochement ticket / caddie
# ============================================================================

_RECONCILE_SYSTEM = (
    "Tu es un assistant pour personnes malvoyantes en caisse de supermarché. "
    "Compare la liste des articles facturés sur le ticket avec le contenu du caddie. "
    "Les noms peuvent différer entre le ticket et l'image (abréviations, marque vs "
    "générique) : gère la correspondance sémantique. "
    "Réponds STRICTEMENT en JSON sans texte hors JSON : "
    '{"match": boolean, '
    '"billed_not_in_cart": [{"name": string, "quantity": number}], '
    '"in_cart_not_billed": [{"name": string, "quantity": number}], '
    '"voice_message": string}. '
    'Exemples de voice_message : '
    '"Tout correspond, les 8 articles facturés sont bien dans votre caddie." ; '
    '"Un article facturé ne semble pas être dans votre caddie : 1 brique de lait." ; '
    '"Un article présent dans votre caddie ne figure pas sur le ticket. '
    'Vérifiez si tout a bien été scanné."'
)


@router.post("/reconcile")
async def reconcile(payload: SessionRequest) -> dict:
    """
    Fonctionnalité 5 : vérification de cohérence ticket / caddie.

    S'exécute après la lecture du ticket (fonctionnalité 4). Compare via Groq
    les articles facturés et l'inventaire du caddie, avec correspondance
    sémantique des désignations.
    """
    session = _get_session(payload.session_id)
    ticket = session.get("ticket")
    if not ticket:
        raise HTTPException(status_code=409, detail="Scannez d'abord le ticket (/ticket/scan)")

    # Le contenu du caddie : inventaire suivi, sinon liste initiale du tapis
    cart = session["cart_items"] or session["belt_initial"]
    if not cart:
        raise HTTPException(status_code=409, detail="Aucun contenu de caddie connu pour cette session")

    groq_text = await _call_groq(
        _RECONCILE_SYSTEM,
        f"Articles facturés sur le ticket :\n{_items_to_text(ticket['items'])}\n"
        f"Total ticket : {ticket['total']} {ticket.get('currency', 'EUR')}\n\n"
        f"Contenu du caddie :\n{_items_to_text(cart)}",
    )
    result = _extract_json(groq_text)
    if result is None:
        raise HTTPException(status_code=502, detail=f"Réponse Groq non exploitable: {groq_text[:200]}")

    match = bool(result.get("match"))
    billed_missing = result.get("billed_not_in_cart", [])
    unbilled = result.get("in_cart_not_billed", [])

    voice = result.get("voice_message") or (
        "Tout correspond entre le ticket et votre caddie."
        if match
        else "Des écarts ont été détectés entre le ticket et votre caddie."
    )

    return {
        "match": match,
        "billed_not_in_cart": billed_missing,
        "in_cart_not_billed": unbilled,
        "voice_message": voice,
    }
