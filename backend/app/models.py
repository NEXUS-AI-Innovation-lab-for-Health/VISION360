"""
Modèles SQLAlchemy pour la base de données Vision360.

Ce module définit toutes les tables de la base de données :
- users : Comptes utilisateurs
- profiles : Profils PMR
- allergies : Allergènes de l'utilisateur
- conditions : Conditions médicales
- preferences : Préférences évolutives (produits aimés/détestés)
- interactions : Historique des échanges avec l'IA
- feedback : Retours utilisateur sur les recommandations
"""

import uuid
from datetime import datetime
from typing import Optional, List

from sqlalchemy import (
    Column, String, Boolean, Float, Integer, Text,
    ForeignKey, DateTime, Enum, JSON
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from .database import Base


# =============================================================================
# ÉNUMÉRATIONS
# =============================================================================

import enum

class MobilityType(str, enum.Enum):
    """Types de mobilité."""
    FAUTEUIL = "fauteuil"
    CANNE = "canne"
    DEAMBULATEUR = "deambulateur"
    MARCHE = "marche"


class VisionLevel(str, enum.Enum):
    """Niveaux de vision."""
    NORMAL = "normal"
    FAIBLE = "faible"
    MALVOYANT = "malvoyant"
    NON_VOYANT = "non_voyant"


class Severity(str, enum.Enum):
    """Niveaux de sévérité."""
    FAIBLE = "faible"
    MODERE = "modere"
    SEVERE = "severe"
    MORTEL = "mortel"  # Pour allergies uniquement


class PreferenceCategory(str, enum.Enum):
    """Catégories de préférences."""
    PRODUIT = "produit"
    MARQUE = "marque"
    RECETTE = "recette"
    INGREDIENT = "ingredient"
    LIEU = "lieu"
    TEXTURE = "texture"
    CUISINE = "cuisine"  # Type de cuisine (italienne, asiatique...)


class Sentiment(str, enum.Enum):
    """Sentiments envers un élément."""
    ADORE = "adore"       # ❤️ Aime beaucoup
    AIME = "aime"         # 👍 Aime
    NEUTRE = "neutre"     # 😐 Indifférent
    NAIME_PAS = "naime_pas"  # 👎 N'aime pas
    DETESTE = "deteste"   # 💔 Déteste
    INTERDIT = "interdit"  # 🚫 Interdit (médical/religieux)


class PreferenceSource(str, enum.Enum):
    """Source de la préférence."""
    USER_EXPLICIT = "user_explicit"    # Dit explicitement par l'utilisateur
    LLM_INFERRED = "llm_inferred"      # Déduit par le LLM
    BEHAVIOR = "behavior"               # Déduit du comportement
    MEDICAL = "medical"                 # Information médicale


class ContextType(str, enum.Enum):
    """Types de contexte d'utilisation."""
    SUPERMARCHE = "supermarche"
    RESTAURANT = "restaurant"
    NAVIGATION = "navigation"
    MAISON = "maison"
    TRANSPORT = "transport"


# =============================================================================
# MODÈLES
# =============================================================================

class User(Base):
    """
    Table des utilisateurs.

    Stocke les informations de connexion et l'état du compte.
    """
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_login = Column(DateTime, nullable=True)

    # Relations
    profile = relationship("Profile", back_populates="user", uselist=False)
    allergies = relationship("Allergy", back_populates="user")
    conditions = relationship("Condition", back_populates="user")
    preferences = relationship("Preference", back_populates="user")
    interactions = relationship("Interaction", back_populates="user")


class Profile(Base):
    """
    Table des profils PMR.

    Stocke les informations de mobilité, vision et préférences d'accessibilité.
    """
    __tablename__ = "profiles"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    name = Column(String(100), nullable=True)
    mobility = Column(Enum(MobilityType), default=MobilityType.MARCHE)
    vision_level = Column(Enum(VisionLevel), default=VisionLevel.NORMAL)

    # Préférences TTS
    tts_enabled = Column(Boolean, default=True)
    tts_speed = Column(Float, default=1.0)  # 0.5 à 2.0
    tts_voice = Column(String(50), default="fr-FR")

    # Préférences d'affichage
    high_contrast = Column(Boolean, default=False)
    large_text = Column(Boolean, default=False)

    language = Column(String(10), default="fr-FR")
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relations
    user = relationship("User", back_populates="profile")


class Allergy(Base):
    """
    Table des allergies.

    Stocke les allergènes de l'utilisateur avec leur sévérité.
    """
    __tablename__ = "allergies"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    allergen = Column(String(100), nullable=False)  # Ex: "arachide", "gluten"
    severity = Column(Enum(Severity), default=Severity.MODERE)
    confirmed = Column(Boolean, default=True)  # Confirmé par l'utilisateur
    source = Column(Enum(PreferenceSource), default=PreferenceSource.USER_EXPLICIT)
    notes = Column(Text, nullable=True)  # Notes additionnelles

    created_at = Column(DateTime, default=datetime.utcnow)

    # Relations
    user = relationship("User", back_populates="allergies")


class Condition(Base):
    """
    Table des conditions médicales.

    Stocke les conditions de santé ayant un impact sur l'alimentation.
    """
    __tablename__ = "conditions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    condition = Column(String(100), nullable=False)  # Ex: "diabete", "hypertension"
    severity = Column(Enum(Severity), default=Severity.MODERE)
    dietary_impact = Column(Text, nullable=True)  # Ex: "éviter le sucre"
    medications = Column(Text, nullable=True)  # Médicaments liés

    created_at = Column(DateTime, default=datetime.utcnow)

    # Relations
    user = relationship("User", back_populates="conditions")


class Preference(Base):
    """
    Table des préférences évolutives.

    C'est la table principale pour stocker ce que l'utilisateur
    aime ou n'aime pas, détecté via les interactions avec le LLM.

    Exemples :
    - "J'aime pas le Nutella" → category=produit, item=Nutella, sentiment=naime_pas
    - "Je préfère la cuisine italienne" → category=cuisine, item=italienne, sentiment=aime
    """
    __tablename__ = "preferences"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    # Quoi ?
    category = Column(Enum(PreferenceCategory), nullable=False)
    item_name = Column(String(255), nullable=False)  # Nom du produit/marque/etc.
    normalized_name = Column(String(255), nullable=True)  # Version normalisée pour matching

    # Sentiment
    sentiment = Column(Enum(Sentiment), nullable=False)
    reason = Column(Text, nullable=True)  # Pourquoi ? "trop sucré", "mauvaise expérience"

    # Métadonnées
    source = Column(Enum(PreferenceSource), default=PreferenceSource.USER_EXPLICIT)
    confidence = Column(Float, default=1.0)  # 0.0 à 1.0
    times_mentioned = Column(Integer, default=1)  # Combien de fois mentionné

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    last_mentioned = Column(DateTime, default=datetime.utcnow)

    # Relations
    user = relationship("User", back_populates="preferences")

    # Index unique pour éviter les doublons
    __table_args__ = (
        # Un utilisateur ne peut avoir qu'une préférence par item/catégorie
        # Index("ix_user_category_item", user_id, category, item_name, unique=True),
    )


class Interaction(Base):
    """
    Table des interactions avec l'IA.

    Historise chaque échange : image analysée, description Gemini,
    recommandations Groq, et contexte.
    """
    __tablename__ = "interactions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    session_id = Column(UUID(as_uuid=True), default=uuid.uuid4)  # Groupe de conversation

    # Contexte
    context = Column(Enum(ContextType), default=ContextType.SUPERMARCHE)
    location = Column(String(255), nullable=True)  # Lieu si connu

    # Image
    image_hash = Column(String(64), nullable=True)  # SHA256 pour éviter doublons
    image_url = Column(String(500), nullable=True)  # URL si stockée

    # Requête utilisateur
    user_query = Column(Text, nullable=True)  # Commande vocale/texte

    # Réponses IA
    gemini_description = Column(Text, nullable=True)  # Description de l'image
    groq_response = Column(JSON, nullable=True)  # Réponse complète JSON
    recommendations = Column(JSON, nullable=True)  # Recommandations extraites

    # Préférences extraites de cette interaction
    extracted_preferences = Column(JSON, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)

    # Relations
    user = relationship("User", back_populates="interactions")
    feedback = relationship("Feedback", back_populates="interaction", uselist=False)


class Feedback(Base):
    """
    Table des retours utilisateur.

    Stocke les évaluations des recommandations pour améliorer le système.
    """
    __tablename__ = "feedback"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    interaction_id = Column(UUID(as_uuid=True), ForeignKey("interactions.id"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    # Évaluation
    rating = Column(Integer, nullable=True)  # 1 à 5 étoiles
    was_helpful = Column(Boolean, nullable=True)  # Utile oui/non
    was_accurate = Column(Boolean, nullable=True)  # Précis oui/non

    # Commentaire libre
    feedback_text = Column(Text, nullable=True)

    # Préférences extraites du feedback
    # Ex: "Cette recommandation était mauvaise car je n'aime pas X"
    preference_extracted = Column(JSON, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)

    # Relations
    interaction = relationship("Interaction", back_populates="feedback")
