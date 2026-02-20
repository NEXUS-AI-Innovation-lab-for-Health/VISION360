"""
Schémas Pydantic pour l'API Vision360.

Ces schémas définissent la structure des données pour :
- Les requêtes (entrées)
- Les réponses (sorties)
- La validation des données
"""

from datetime import datetime
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field

from .models import (
    MobilityType, VisionLevel, Severity,
    PreferenceCategory, Sentiment, PreferenceSource, ContextType
)


# =============================================================================
# UTILISATEURS
# =============================================================================

class UserCreate(BaseModel):
    """Données pour créer un utilisateur."""
    email: EmailStr
    password: str = Field(..., min_length=6)


class UserLogin(BaseModel):
    """Données de connexion."""
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    """Réponse utilisateur (sans mot de passe)."""
    id: UUID
    email: str
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


# =============================================================================
# PROFILS
# =============================================================================

class ProfileCreate(BaseModel):
    """Données pour créer/modifier un profil."""
    name: Optional[str] = None
    mobility: MobilityType = MobilityType.MARCHE
    vision_level: VisionLevel = VisionLevel.NORMAL
    tts_enabled: bool = True
    tts_speed: float = Field(default=1.0, ge=0.5, le=2.0)
    language: str = "fr-FR"


class ProfileResponse(BaseModel):
    """Réponse profil."""
    id: UUID
    name: Optional[str]
    mobility: MobilityType
    vision_level: VisionLevel
    tts_enabled: bool
    tts_speed: float
    language: str

    class Config:
        from_attributes = True


# =============================================================================
# ALLERGIES
# =============================================================================

class AllergyCreate(BaseModel):
    """Données pour ajouter une allergie."""
    allergen: str
    severity: Severity = Severity.MODERE
    notes: Optional[str] = None


class AllergyResponse(BaseModel):
    """Réponse allergie."""
    id: UUID
    allergen: str
    severity: Severity
    confirmed: bool
    notes: Optional[str]

    class Config:
        from_attributes = True


# =============================================================================
# CONDITIONS MÉDICALES
# =============================================================================

class ConditionCreate(BaseModel):
    """Données pour ajouter une condition."""
    condition: str
    severity: Severity = Severity.MODERE
    dietary_impact: Optional[str] = None


class ConditionResponse(BaseModel):
    """Réponse condition."""
    id: UUID
    condition: str
    severity: Severity
    dietary_impact: Optional[str]

    class Config:
        from_attributes = True


# =============================================================================
# PRÉFÉRENCES
# =============================================================================

class PreferenceCreate(BaseModel):
    """Données pour ajouter une préférence."""
    category: PreferenceCategory
    item_name: str
    sentiment: Sentiment
    reason: Optional[str] = None
    source: PreferenceSource = PreferenceSource.USER_EXPLICIT
    confidence: float = Field(default=1.0, ge=0.0, le=1.0)


class PreferenceUpdate(BaseModel):
    """Données pour modifier une préférence."""
    sentiment: Optional[Sentiment] = None
    reason: Optional[str] = None
    confidence: Optional[float] = None


class PreferenceResponse(BaseModel):
    """Réponse préférence."""
    id: UUID
    category: PreferenceCategory
    item_name: str
    sentiment: Sentiment
    reason: Optional[str]
    source: PreferenceSource
    confidence: float
    times_mentioned: int
    created_at: datetime
    last_mentioned: datetime

    class Config:
        from_attributes = True


class PreferenceExtracted(BaseModel):
    """
    Préférence extraite d'une conversation avec le LLM.

    Utilisé par le service d'extraction automatique.
    """
    category: PreferenceCategory
    item_name: str
    sentiment: Sentiment
    reason: Optional[str] = None
    confidence: float = 0.8


# =============================================================================
# INTERACTIONS
# =============================================================================

class InteractionCreate(BaseModel):
    """Données pour enregistrer une interaction."""
    context: ContextType = ContextType.SUPERMARCHE
    user_query: Optional[str] = None
    image_hash: Optional[str] = None
    gemini_description: Optional[str] = None
    groq_response: Optional[dict] = None


class InteractionResponse(BaseModel):
    """Réponse interaction."""
    id: UUID
    context: ContextType
    user_query: Optional[str]
    gemini_description: Optional[str]
    groq_response: Optional[dict]
    created_at: datetime

    class Config:
        from_attributes = True


# =============================================================================
# FEEDBACK
# =============================================================================

class FeedbackCreate(BaseModel):
    """Données pour donner un feedback."""
    interaction_id: UUID
    rating: Optional[int] = Field(None, ge=1, le=5)
    was_helpful: Optional[bool] = None
    was_accurate: Optional[bool] = None
    feedback_text: Optional[str] = None


class FeedbackResponse(BaseModel):
    """Réponse feedback."""
    id: UUID
    rating: Optional[int]
    was_helpful: Optional[bool]
    feedback_text: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


# =============================================================================
# PROFIL COMPLET (pour envoi au LLM)
# =============================================================================

class FullProfileForLLM(BaseModel):
    """
    Profil complet de l'utilisateur pour envoi au LLM.

    Contient toutes les informations nécessaires pour personnaliser
    les recommandations.
    """
    name: Optional[str] = None
    mobility: str
    vision_level: str
    allergies: List[str] = []
    conditions: List[str] = []
    likes: List[str] = []      # Produits aimés
    dislikes: List[str] = []   # Produits détestés
    forbidden: List[str] = []  # Produits interdits

    def to_prompt_string(self) -> str:
        """Convertit le profil en texte pour le prompt LLM."""
        parts = []

        if self.name:
            parts.append(f"Nom: {self.name}")

        parts.append(f"Mobilité: {self.mobility}")
        parts.append(f"Vision: {self.vision_level}")

        if self.allergies:
            parts.append(f"ALLERGIES (DANGER): {', '.join(self.allergies)}")

        if self.conditions:
            parts.append(f"Conditions médicales: {', '.join(self.conditions)}")

        if self.forbidden:
            parts.append(f"INTERDIT: {', '.join(self.forbidden)}")

        if self.dislikes:
            parts.append(f"N'aime pas: {', '.join(self.dislikes)}")

        if self.likes:
            parts.append(f"Aime: {', '.join(self.likes)}")

        return "\n".join(parts)
