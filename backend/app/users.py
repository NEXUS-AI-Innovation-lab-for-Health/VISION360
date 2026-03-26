"""
Routes API pour la gestion des utilisateurs et profils.

Ce module expose les endpoints REST pour :
- Authentification (inscription, connexion)
- Gestion des profils PMR
- Gestion des allergies et conditions médicales
- Gestion des préférences (aime/n'aime pas)
- Historique des interactions
"""

from typing import List, Optional
from uuid import UUID
import hashlib

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .database import get_db
from .models import (
    User, Profile, Allergy, Condition, Preference, Interaction, Feedback,
    PreferenceCategory, Sentiment, PreferenceSource, MobilityType, VisionLevel
)
from .schemas import (
    UserCreate, UserLogin, UserResponse,
    ProfileCreate, ProfileResponse,
    AllergyCreate, AllergyResponse,
    ConditionCreate, ConditionResponse,
    PreferenceCreate, PreferenceUpdate, PreferenceResponse,
    InteractionCreate, InteractionResponse,
    FeedbackCreate, FeedbackResponse,
    FullProfileForLLM
)
from .services import ProfileService, InteractionService

router = APIRouter()


# =============================================================================
# AUTHENTIFICATION
# =============================================================================

def _hash_password(password: str) -> str:
    """Hash simple du mot de passe avec SHA256."""
    return hashlib.sha256(password.encode()).hexdigest()


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(user_data: UserCreate, db: Session = Depends(get_db)):
    """
    Inscription d'un nouvel utilisateur.

    Crée un compte utilisateur avec un profil vide associé.

    Args:
        user_data: Email et mot de passe

    Returns:
        UserResponse: Données de l'utilisateur créé

    Raises:
        HTTPException 400: Si l'email existe déjà
    """
    # Vérifier si l'email existe déjà
    existing = db.query(User).filter(User.email == user_data.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Un compte avec cet email existe déjà"
        )

    # Créer l'utilisateur
    user = User(
        email=user_data.email,
        password_hash=_hash_password(user_data.password)
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # Créer un profil vide associé
    profile = Profile(user_id=user.id)
    db.add(profile)
    db.commit()

    return user


@router.post("/login", response_model=UserResponse)
def login(credentials: UserLogin, db: Session = Depends(get_db)):
    """
    Connexion d'un utilisateur.

    Vérifie les identifiants et retourne les données utilisateur.

    Args:
        credentials: Email et mot de passe

    Returns:
        UserResponse: Données de l'utilisateur connecté

    Raises:
        HTTPException 401: Si les identifiants sont invalides
    """
    user = db.query(User).filter(User.email == credentials.email).first()

    if not user or user.password_hash != _hash_password(credentials.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou mot de passe incorrect"
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Ce compte est désactivé"
        )

    return user


# =============================================================================
# PROFILS
# =============================================================================

@router.get("/users/{user_id}/profile", response_model=ProfileResponse)
def get_profile(user_id: UUID, db: Session = Depends(get_db)):
    """
    Récupère le profil d'un utilisateur.

    Args:
        user_id: ID de l'utilisateur

    Returns:
        ProfileResponse: Profil PMR complet

    Raises:
        HTTPException 404: Si le profil n'existe pas
    """
    profile = db.query(Profile).filter(Profile.user_id == user_id).first()
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profil non trouvé"
        )
    return profile


@router.put("/users/{user_id}/profile", response_model=ProfileResponse)
def update_profile(user_id: UUID, profile_data: ProfileCreate, db: Session = Depends(get_db)):
    """
    Met à jour le profil d'un utilisateur.

    Args:
        user_id: ID de l'utilisateur
        profile_data: Nouvelles données du profil

    Returns:
        ProfileResponse: Profil mis à jour

    Raises:
        HTTPException 404: Si le profil n'existe pas
    """
    profile = db.query(Profile).filter(Profile.user_id == user_id).first()
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profil non trouvé"
        )

    # Mettre à jour les champs
    for field, value in profile_data.model_dump(exclude_unset=True).items():
        setattr(profile, field, value)

    db.commit()
    db.refresh(profile)
    return profile


@router.get("/users/{user_id}/full-profile", response_model=FullProfileForLLM)
def get_full_profile(user_id: UUID, db: Session = Depends(get_db)):
    """
    Récupère le profil complet pour le LLM.

    Inclut toutes les informations nécessaires pour personnaliser
    les recommandations : allergies, conditions, préférences.

    Args:
        user_id: ID de l'utilisateur

    Returns:
        FullProfileForLLM: Profil complet formaté pour le LLM
    """
    service = ProfileService(db)
    return service.get_full_profile(user_id)


# =============================================================================
# ALLERGIES
# =============================================================================

@router.get("/users/{user_id}/allergies", response_model=List[AllergyResponse])
def get_allergies(user_id: UUID, db: Session = Depends(get_db)):
    """Récupère toutes les allergies d'un utilisateur."""
    return db.query(Allergy).filter(Allergy.user_id == user_id).all()


@router.post("/users/{user_id}/allergies", response_model=AllergyResponse, status_code=status.HTTP_201_CREATED)
def add_allergy(user_id: UUID, allergy_data: AllergyCreate, db: Session = Depends(get_db)):
    """
    Ajoute une allergie à un utilisateur.

    Args:
        user_id: ID de l'utilisateur
        allergy_data: Données de l'allergie

    Returns:
        AllergyResponse: Allergie créée
    """
    allergy = Allergy(
        user_id=user_id,
        allergen=allergy_data.allergen,
        severity=allergy_data.severity,
        notes=allergy_data.notes
    )
    db.add(allergy)
    db.commit()
    db.refresh(allergy)
    return allergy


@router.delete("/users/{user_id}/allergies/{allergy_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_allergy(user_id: UUID, allergy_id: UUID, db: Session = Depends(get_db)):
    """Supprime une allergie."""
    allergy = db.query(Allergy).filter(
        Allergy.id == allergy_id,
        Allergy.user_id == user_id
    ).first()

    if not allergy:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Allergie non trouvée"
        )

    db.delete(allergy)
    db.commit()


# =============================================================================
# CONDITIONS MÉDICALES
# =============================================================================

@router.get("/users/{user_id}/conditions", response_model=List[ConditionResponse])
def get_conditions(user_id: UUID, db: Session = Depends(get_db)):
    """Récupère toutes les conditions médicales d'un utilisateur."""
    return db.query(Condition).filter(Condition.user_id == user_id).all()


@router.post("/users/{user_id}/conditions", response_model=ConditionResponse, status_code=status.HTTP_201_CREATED)
def add_condition(user_id: UUID, condition_data: ConditionCreate, db: Session = Depends(get_db)):
    """
    Ajoute une condition médicale à un utilisateur.

    Args:
        user_id: ID de l'utilisateur
        condition_data: Données de la condition

    Returns:
        ConditionResponse: Condition créée
    """
    condition = Condition(
        user_id=user_id,
        condition=condition_data.condition,
        severity=condition_data.severity,
        dietary_impact=condition_data.dietary_impact
    )
    db.add(condition)
    db.commit()
    db.refresh(condition)
    return condition


@router.delete("/users/{user_id}/conditions/{condition_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_condition(user_id: UUID, condition_id: UUID, db: Session = Depends(get_db)):
    """Supprime une condition médicale."""
    condition = db.query(Condition).filter(
        Condition.id == condition_id,
        Condition.user_id == user_id
    ).first()

    if not condition:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Condition non trouvée"
        )

    db.delete(condition)
    db.commit()


# =============================================================================
# PRÉFÉRENCES
# =============================================================================

@router.get("/users/{user_id}/preferences", response_model=List[PreferenceResponse])
def get_preferences(
    user_id: UUID,
    category: Optional[PreferenceCategory] = None,
    sentiment: Optional[Sentiment] = None,
    db: Session = Depends(get_db)
):
    """
    Récupère les préférences d'un utilisateur.

    Args:
        user_id: ID de l'utilisateur
        category: Filtrer par catégorie (produit, marque, etc.)
        sentiment: Filtrer par sentiment (aime, naime_pas, etc.)

    Returns:
        List[PreferenceResponse]: Liste des préférences
    """
    query = db.query(Preference).filter(Preference.user_id == user_id)

    if category:
        query = query.filter(Preference.category == category)
    if sentiment:
        query = query.filter(Preference.sentiment == sentiment)

    return query.order_by(Preference.last_mentioned.desc()).all()


@router.post("/users/{user_id}/preferences", response_model=PreferenceResponse, status_code=status.HTTP_201_CREATED)
def add_preference(user_id: UUID, pref_data: PreferenceCreate, db: Session = Depends(get_db)):
    """
    Ajoute ou met à jour une préférence.

    Si une préférence existe déjà pour le même item/catégorie,
    elle est mise à jour au lieu d'être dupliquée.

    Args:
        user_id: ID de l'utilisateur
        pref_data: Données de la préférence

    Returns:
        PreferenceResponse: Préférence créée ou mise à jour
    """
    service = ProfileService(db)
    return service.add_preference(
        user_id=user_id,
        category=pref_data.category,
        item_name=pref_data.item_name,
        sentiment=pref_data.sentiment,
        reason=pref_data.reason,
        source=pref_data.source,
        confidence=pref_data.confidence
    )


@router.put("/users/{user_id}/preferences/{preference_id}", response_model=PreferenceResponse)
def update_preference(
    user_id: UUID,
    preference_id: UUID,
    pref_data: PreferenceUpdate,
    db: Session = Depends(get_db)
):
    """
    Met à jour une préférence existante.

    Args:
        user_id: ID de l'utilisateur
        preference_id: ID de la préférence
        pref_data: Données à mettre à jour

    Returns:
        PreferenceResponse: Préférence mise à jour
    """
    pref = db.query(Preference).filter(
        Preference.id == preference_id,
        Preference.user_id == user_id
    ).first()

    if not pref:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Préférence non trouvée"
        )

    for field, value in pref_data.model_dump(exclude_unset=True).items():
        if value is not None:
            setattr(pref, field, value)

    db.commit()
    db.refresh(pref)
    return pref


@router.delete("/users/{user_id}/preferences/{preference_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_preference(user_id: UUID, preference_id: UUID, db: Session = Depends(get_db)):
    """Supprime une préférence."""
    pref = db.query(Preference).filter(
        Preference.id == preference_id,
        Preference.user_id == user_id
    ).first()

    if not pref:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Préférence non trouvée"
        )

    db.delete(pref)
    db.commit()


# =============================================================================
# INTERACTIONS
# =============================================================================

@router.get("/users/{user_id}/interactions", response_model=List[InteractionResponse])
def get_interactions(user_id: UUID, limit: int = 20, db: Session = Depends(get_db)):
    """
    Récupère l'historique des interactions d'un utilisateur.

    Args:
        user_id: ID de l'utilisateur
        limit: Nombre maximum d'interactions à retourner

    Returns:
        List[InteractionResponse]: Liste des interactions récentes
    """
    return db.query(Interaction).filter(
        Interaction.user_id == user_id
    ).order_by(
        Interaction.created_at.desc()
    ).limit(limit).all()


@router.post("/users/{user_id}/interactions", response_model=InteractionResponse, status_code=status.HTTP_201_CREATED)
def create_interaction(user_id: UUID, interaction_data: InteractionCreate, db: Session = Depends(get_db)):
    """
    Enregistre une nouvelle interaction.

    Analyse automatiquement le message utilisateur pour extraire
    les préférences (via le service d'extraction).

    Args:
        user_id: ID de l'utilisateur
        interaction_data: Données de l'interaction

    Returns:
        InteractionResponse: Interaction créée
    """
    service = InteractionService(db)
    return service.create_interaction(
        user_id=user_id,
        context=interaction_data.context.value,
        user_query=interaction_data.user_query,
        gemini_description=interaction_data.gemini_description,
        groq_response=interaction_data.groq_response
    )


# =============================================================================
# FEEDBACK
# =============================================================================

@router.post("/feedback", response_model=FeedbackResponse, status_code=status.HTTP_201_CREATED)
def create_feedback(feedback_data: FeedbackCreate, db: Session = Depends(get_db)):
    """
    Ajoute un feedback sur une interaction.

    Analyse le texte du feedback pour extraire d'éventuelles
    nouvelles préférences de l'utilisateur.

    Args:
        feedback_data: Données du feedback

    Returns:
        FeedbackResponse: Feedback créé
    """
    # Récupérer l'interaction pour obtenir le user_id
    interaction = db.query(Interaction).filter(
        Interaction.id == feedback_data.interaction_id
    ).first()

    if not interaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Interaction non trouvée"
        )

    service = InteractionService(db)
    return service.add_feedback(
        interaction_id=feedback_data.interaction_id,
        user_id=interaction.user_id,
        rating=feedback_data.rating,
        was_helpful=feedback_data.was_helpful,
        feedback_text=feedback_data.feedback_text
    )


# =============================================================================
# EXTRACTION DE PRÉFÉRENCES (endpoint utilitaire)
# =============================================================================

@router.post("/users/{user_id}/extract-preferences", response_model=List[PreferenceResponse])
def extract_preferences(user_id: UUID, text: str, db: Session = Depends(get_db)):
    """
    Extrait et enregistre les préférences d'un texte.

    Endpoint utilitaire pour forcer l'extraction de préférences
    depuis un texte arbitraire.

    Args:
        user_id: ID de l'utilisateur
        text: Texte à analyser

    Returns:
        List[PreferenceResponse]: Préférences extraites et enregistrées
    """
    service = ProfileService(db)
    return service.process_user_message(user_id, text)
