"""
Module de guidage et enrichissement des détections.

Ce module fournit des endpoints pour :
- Enrichir les détections d'objets avec des descriptions PMR
- Générer des conseils personnalisés selon le profil utilisateur
- Évaluer les risques liés aux obstacles détectés

Les détections proviennent généralement du modèle COCO-SSD côté client
et sont enrichies avec des informations contextuelles pour l'assistance PMR.
"""

from typing import Dict, List, Optional

from fastapi import APIRouter
from pydantic import BaseModel, Field


router = APIRouter()


# ============================================================================
# Modèles Pydantic pour validation des requêtes/réponses
# ============================================================================

class Detection(BaseModel):
    """
    Représente une détection d'objet dans l'image.

    Attributes:
        class_name: Nom de la classe détectée (person, stairs, etc.)
                   Utilise l'alias "class" pour compatibilité avec les modèles ML
        score: Score de confiance entre 0.0 et 1.0
        zone: Zone de profondeur estimée (near, mid, far)
        side: Position latérale (left, center, right)
        ocr: Texte extrait par OCR si disponible
        context: Contexte additionnel (retail, restaurant, etc.)
    """
    class_name: str = Field(..., alias="class")
    score: float = Field(..., ge=0.0, le=1.0)
    zone: Optional[str] = Field(None, description="near|mid|far")
    side: Optional[str] = Field(None, description="left|center|right")
    ocr: Optional[str] = None
    context: Optional[str] = None


class EnrichRequest(BaseModel):
    """Requête pour enrichir une seule détection."""
    detection: Detection
    profile_hint: Optional[str] = None


class EnrichBatchRequest(BaseModel):
    """Requête pour enrichir plusieurs détections en lot."""
    detections: List[Detection]
    profile_hint: Optional[str] = None


class EnrichResponse(BaseModel):
    """
    Réponse d'enrichissement d'une détection.

    Attributes:
        summary: Description en français de l'objet détecté
        attributes: Attributs clés (zone, side, score, ocr, context)
        risks: Liste des risques potentiels pour un PMR
        class_name: Classe d'origine pour référence
        zone: Zone de profondeur pour référence
        side: Position latérale pour référence
    """
    summary: str
    attributes: Dict[str, str] = {}
    risks: List[str] = []
    class_name: Optional[str] = None
    zone: Optional[str] = None
    side: Optional[str] = None


class AdviceRequest(BaseModel):
    """
    Requête pour générer des conseils personnalisés.

    Attributes:
        profile: Type de profil PMR (wheelchair, cane, visual, etc.)
        context: Contexte d'utilisation (supermarket, restaurant, street)
        detections: Liste des objets détectés
        enrichments: Enrichissements préalablement calculés
    """
    profile: str
    context: str
    detections: List[Detection]
    enrichments: List[EnrichResponse] = []


class AdviceResponse(BaseModel):
    """
    Réponse contenant les conseils générés.

    Attributes:
        priority: Niveau de priorité (info, high)
        channel: Canaux de notification (voice, haptic)
        messages: Liste des messages à communiquer
    """
    priority: str
    channel: List[str]
    messages: List[str]


# ============================================================================
# Dictionnaires de descriptions par catégorie
# ============================================================================

# Obstacles urbains et environnementaux
OBSTACLE_DESCRIPTIONS = {
    "person": "Personne à proximité",
    "crowd": "Groupe dense",
    "stairs": "Escalier",
    "curb": "Dénivelé",
    "door": "Porte",
    "cone": "Cône de chantier",
    "barrier": "Barrière / obstacle fixe",
    "puddle": "Zone glissante"
}

# Objets de contexte retail (supermarché)
RETAIL_DESCRIPTIONS = {
    "product": "Article en rayon",
    "price_tag": "Etiquette de prix",
    "barcode": "Code-barres visible",
    "bottle": "Bouteille / boisson",
    "can": "Boîte ou canette",
    "produce": "Fruit ou légume",
    "package": "Produit emballé"
}

# Objets de contexte restaurant/cantine
RESTAURANT_DESCRIPTIONS = {
    "table": "Table",
    "chair": "Chaise",
    "tray": "Plateau",
    "cutlery": "Couverts",
    "terminal": "Terminal de paiement",
    "dish": "Plat servi"
}


# ============================================================================
# Fonctions de traitement
# ============================================================================

def describe_detection(det: Detection) -> EnrichResponse:
    """
    Enrichit une détection avec une description et des risques PMR.

    La fonction :
    1. Traduit la classe ML en description française
    2. Évalue les risques selon le type d'objet et sa position
    3. Compile les attributs pertinents

    Args:
        det: Détection à enrichir

    Returns:
        EnrichResponse avec description, attributs et risques
    """
    cls = det.class_name.lower()

    # Recherche de la description dans les dictionnaires par priorité
    if cls in OBSTACLE_DESCRIPTIONS:
        summary = OBSTACLE_DESCRIPTIONS[cls]
    elif cls in RETAIL_DESCRIPTIONS:
        summary = RETAIL_DESCRIPTIONS[cls]
    elif cls in RESTAURANT_DESCRIPTIONS:
        summary = RESTAURANT_DESCRIPTIONS[cls]
    else:
        summary = f"Objet {det.class_name}"  # Fallback générique

    # Évaluation des risques pour les objets potentiellement dangereux
    risks: List[str] = []
    if cls in {"person", "crowd", "stairs", "curb", "cone", "barrier", "puddle"}:
        # Risque accru si l'obstacle est proche
        if det.zone == "near":
            risks.append("Obstacle proche")
        # Risques spécifiques par type d'obstacle
        if cls == "puddle":
            risks.append("Risque de glissade")
        if cls == "stairs":
            risks.append("Prévoir montée/descente")

    # Compilation des attributs
    attrs: Dict[str, str] = {
        "zone": det.zone or "unknown",
        "side": det.side or "unknown",
        "score": f"{det.score:.2f}"
    }
    if det.ocr:
        attrs["ocr"] = det.ocr
    if det.context:
        attrs["context"] = det.context

    return EnrichResponse(
        summary=summary,
        attributes=attrs,
        risks=risks,
        class_name=det.class_name,
        zone=det.zone,
        side=det.side
    )


# ============================================================================
# Endpoints API
# ============================================================================

@router.post("/enrich", response_model=EnrichResponse)
def enrich_detection(payload: EnrichRequest) -> EnrichResponse:
    """
    Enrichit une détection unique avec description et risques.

    Args:
        payload: Requête contenant la détection à enrichir

    Returns:
        EnrichResponse avec les informations enrichies
    """
    return describe_detection(payload.detection)


@router.post("/enrich/batch", response_model=List[EnrichResponse])
def enrich_batch(payload: EnrichBatchRequest) -> List[EnrichResponse]:
    """
    Enrichit un lot de détections en une seule requête.

    Utile pour traiter toutes les détections d'une frame en une fois.

    Args:
        payload: Requête contenant la liste des détections

    Returns:
        Liste d'EnrichResponse pour chaque détection
    """
    return [describe_detection(det) for det in payload.detections]


@router.post("/advise", response_model=AdviceResponse)
def advise(payload: AdviceRequest) -> AdviceResponse:
    """
    Génère des conseils personnalisés selon le profil et les détections.

    La fonction analyse les détections et enrichissements pour générer
    des messages adaptés au profil PMR, avec une priorité et des canaux
    de notification appropriés.

    Logique de priorité :
    - "high" si un obstacle est détecté dans la zone "near"
    - "info" sinon

    Canaux de notification :
    - "voice" : toujours présent pour la lecture vocale
    - "haptic" : ajouté si priorité haute pour retour vibratoire

    Args:
        payload: Requête avec profil, contexte, détections et enrichissements

    Returns:
        AdviceResponse avec priorité, canaux et messages
    """
    messages: List[str] = []
    priority = "info"

    # Analyse des détections pour obstacles proches
    for det in payload.detections:
        if det.zone == "near":
            priority = "high"
            side = det.side or "devant"
            messages.append(f"Obstacle {det.class_name} {side}, ralentir")

    # Compilation des risques depuis les enrichissements
    for enr in payload.enrichments:
        for risk in enr.risks:
            messages.append(f"{enr.summary}: {risk}")

    # Message par défaut si aucun obstacle critique
    if not messages:
        messages.append("Aucun obstacle critique détecté")

    # Définition des canaux selon la priorité
    channels = ["voice"]
    if priority == "high":
        channels.append("haptic")  # Vibration pour alertes importantes

    return AdviceResponse(priority=priority, channel=channels, messages=messages)
