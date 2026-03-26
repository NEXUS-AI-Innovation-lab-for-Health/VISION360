"""
Module de gestion des réservations PMR.

Ce module fournit une API CRUD pour gérer les réservations de transport
adaptées aux personnes à mobilité réduite. Il s'agit actuellement d'un
stub avec stockage en mémoire, prévu pour être connecté à un système
de réservation réel.

Fonctionnalités :
- Création de réservation avec profil PMR
- Consultation d'une réservation par ID
- Liste de toutes les réservations
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import List, Optional
from uuid import uuid4
from datetime import datetime


router = APIRouter()


# ============================================================================
# Modèles Pydantic pour validation des données
# ============================================================================

class Passenger(BaseModel):
    """
    Représente un passager avec son profil PMR.

    Attributes:
        name: Nom complet du passager
        pmr_profile: Type de handicap/équipement (fauteuil, canne,
                    déficience visuelle, etc.)
    """
    name: str
    pmr_profile: Optional[str] = Field(
        default=None,
        description="Profile PMR (fauteuil, canne, déficience visuelle, etc.)"
    )


class ReservationCreate(BaseModel):
    """
    Données requises pour créer une nouvelle réservation.

    Attributes:
        origin: Point de départ (adresse ou nom de gare/aéroport)
        destination: Point d'arrivée
        datetime_utc: Date et heure du voyage en UTC
        passenger: Informations sur le passager
    """
    origin: str
    destination: str
    datetime_utc: datetime
    passenger: Passenger


class Reservation(ReservationCreate):
    """
    Réservation complète avec ID et statut.

    Hérite de ReservationCreate et ajoute :
    - id: Identifiant unique UUID
    - status: État de la réservation (pending, confirmed, cancelled)
    """
    id: str
    status: str = Field(
        default="pending",
        description="pending|confirmed|cancelled"
    )


# ============================================================================
# Stockage en mémoire (stub)
# ============================================================================

# Base de données temporaire en mémoire
# Note: Les données sont perdues au redémarrage du serveur
DB: dict[str, Reservation] = {}


# ============================================================================
# Endpoints API
# ============================================================================

@router.post("/reservations", response_model=Reservation)
def create_reservation(payload: ReservationCreate) -> Reservation:
    """
    Crée une nouvelle réservation de transport PMR.

    Génère un UUID unique pour la réservation et l'initialise
    avec le statut "pending".

    Args:
        payload: Données de la réservation à créer

    Returns:
        Reservation: La réservation créée avec son ID et statut
    """
    rid = str(uuid4())
    res = Reservation(id=rid, **payload.model_dump())
    DB[rid] = res
    return res


@router.get("/reservations/{reservation_id}", response_model=Reservation)
def get_reservation(reservation_id: str) -> Reservation:
    """
    Récupère une réservation par son identifiant.

    Args:
        reservation_id: UUID de la réservation

    Returns:
        Reservation: Les détails de la réservation

    Raises:
        HTTPException 404: Si la réservation n'existe pas
    """
    res = DB.get(reservation_id)
    if not res:
        raise HTTPException(status_code=404, detail="Reservation not found")
    return res


@router.get("/reservations", response_model=List[Reservation])
def list_reservations() -> List[Reservation]:
    """
    Liste toutes les réservations enregistrées.

    Returns:
        List[Reservation]: Liste de toutes les réservations
    """
    return list(DB.values())
