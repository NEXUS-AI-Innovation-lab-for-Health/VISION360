"""
Services métier pour Vision360.

Ce module contient la logique métier pour :
- Extraction automatique des préférences depuis les conversations LLM
- Construction du profil complet pour le LLM
- Mise à jour des préférences utilisateur
"""

import re
import json
from typing import List, Optional
from datetime import datetime
from uuid import UUID

from sqlalchemy.orm import Session

from .models import (
    User, Profile, Allergy, Condition, Preference, Interaction, Feedback,
    PreferenceCategory, Sentiment, PreferenceSource
)
from .schemas import PreferenceExtracted, FullProfileForLLM


# =============================================================================
# EXTRACTION DE PRÉFÉRENCES
# =============================================================================

class PreferenceExtractor:
    """
    Service d'extraction automatique des préférences depuis le texte.

    Analyse les messages de l'utilisateur et les réponses du LLM
    pour détecter les préférences (aime/n'aime pas).
    """

    # Patterns pour détecter les sentiments négatifs
    NEGATIVE_PATTERNS = [
        r"(?:je |j')?(?:n')?aime pas (?:le |la |les |l')?(.+)",
        r"(?:je |j')?déteste (?:le |la |les |l')?(.+)",
        r"(?:je |j')?(?:ne )?supporte pas (?:le |la |les |l')?(.+)",
        r"(?:je suis |j'ai une )?allergi(?:que|e) (?:au |à la |aux |à l')?(.+)",
        r"(?:je |j')?évite (?:le |la |les |l')?(.+)",
        r"(.+) (?:me dégoûte|me rend malade)",
        r"pas de (.+)(?: pour moi| s'il vous plaît)?",
        r"sans (.+)(?: pour moi| s'il vous plaît)?",
    ]

    # Patterns pour détecter les sentiments positifs
    POSITIVE_PATTERNS = [
        r"(?:je |j')?aime (?:bien |beaucoup )?(?:le |la |les |l')?(.+)",
        r"(?:je |j')?adore (?:le |la |les |l')?(.+)",
        r"(?:je |j')?préfère (?:le |la |les |l')?(.+)",
        r"(.+) est (?:mon |ma )?préféré(?:e)?",
        r"(?:je |j')?(?:ai une préférence|opte) pour (?:le |la |les |l')?(.+)",
    ]

    # Patterns pour les raisons
    REASON_PATTERNS = [
        r"(?:c'est |car c'est )?trop (.+)",
        r"(?:c'est |car c'est )?pas assez (.+)",
        r"(?:à cause de |car )(.+)",
        r"(?:ça me |cela me )(.+)",
    ]

    # Catégories connues
    CATEGORY_KEYWORDS = {
        PreferenceCategory.PRODUIT: [
            "nutella", "coca", "chips", "yaourt", "lait", "pain", "beurre",
            "fromage", "jambon", "poulet", "riz", "pâtes", "pizza",
        ],
        PreferenceCategory.MARQUE: [
            "danone", "nestlé", "carrefour", "auchan", "lidl", "leclerc",
        ],
        PreferenceCategory.INGREDIENT: [
            "sucre", "sel", "huile", "gluten", "lactose", "arachide",
            "noix", "soja", "oeuf", "poisson", "crustacé",
        ],
        PreferenceCategory.CUISINE: [
            "italien", "chinois", "japonais", "indien", "mexicain",
            "français", "marocain", "libanais", "thaï",
        ],
        PreferenceCategory.TEXTURE: [
            "croquant", "mou", "crémeux", "liquide", "sec", "gras",
        ],
    }

    def extract_from_text(self, text: str) -> List[PreferenceExtracted]:
        """
        Extrait les préférences d'un texte utilisateur.

        Args:
            text: Texte à analyser (message utilisateur ou feedback)

        Returns:
            Liste des préférences extraites
        """
        text = text.lower().strip()
        preferences = []

        # Chercher les sentiments négatifs
        for pattern in self.NEGATIVE_PATTERNS:
            matches = re.findall(pattern, text, re.IGNORECASE)
            for match in matches:
                item = self._clean_item(match)
                if item:
                    category = self._guess_category(item)
                    reason = self._extract_reason(text)
                    preferences.append(PreferenceExtracted(
                        category=category,
                        item_name=item,
                        sentiment=Sentiment.NAIME_PAS,
                        reason=reason,
                        confidence=0.8
                    ))

        # Chercher les sentiments positifs
        for pattern in self.POSITIVE_PATTERNS:
            matches = re.findall(pattern, text, re.IGNORECASE)
            for match in matches:
                item = self._clean_item(match)
                if item:
                    category = self._guess_category(item)
                    preferences.append(PreferenceExtracted(
                        category=category,
                        item_name=item,
                        sentiment=Sentiment.AIME,
                        reason=None,
                        confidence=0.8
                    ))

        return preferences

    def _clean_item(self, item: str) -> Optional[str]:
        """Nettoie le nom de l'item extrait."""
        # Enlever la ponctuation et les mots vides
        item = re.sub(r'[,\.!?;:]', '', item)
        item = item.strip()

        # Ignorer si trop court ou trop long
        if len(item) < 2 or len(item) > 50:
            return None

        # Ignorer certains mots vides
        stop_words = ["ça", "cela", "tout", "rien", "quelque chose"]
        if item in stop_words:
            return None

        return item.title()  # Capitalize

    def _guess_category(self, item: str) -> PreferenceCategory:
        """Devine la catégorie d'un item."""
        item_lower = item.lower()

        for category, keywords in self.CATEGORY_KEYWORDS.items():
            for keyword in keywords:
                if keyword in item_lower:
                    return category

        # Par défaut, c'est un produit
        return PreferenceCategory.PRODUIT

    def _extract_reason(self, text: str) -> Optional[str]:
        """Extrait la raison du sentiment."""
        for pattern in self.REASON_PATTERNS:
            match = re.search(pattern, text, re.IGNORECASE)
            if match:
                return match.group(1).strip()
        return None


# =============================================================================
# SERVICE DE PROFIL
# =============================================================================

class ProfileService:
    """
    Service de gestion des profils utilisateur.
    """

    def __init__(self, db: Session):
        self.db = db
        self.extractor = PreferenceExtractor()

    def get_full_profile(self, user_id: UUID) -> FullProfileForLLM:
        """
        Construit le profil complet d'un utilisateur pour le LLM.

        Args:
            user_id: ID de l'utilisateur

        Returns:
            Profil complet avec allergies, conditions, préférences
        """
        # Récupérer le profil de base
        profile = self.db.query(Profile).filter(Profile.user_id == user_id).first()

        # Récupérer les allergies
        allergies = self.db.query(Allergy).filter(Allergy.user_id == user_id).all()
        allergy_names = [a.allergen for a in allergies]

        # Récupérer les conditions
        conditions = self.db.query(Condition).filter(Condition.user_id == user_id).all()
        condition_names = [c.condition for c in conditions]

        # Récupérer les préférences
        preferences = self.db.query(Preference).filter(Preference.user_id == user_id).all()

        likes = []
        dislikes = []
        forbidden = []

        for pref in preferences:
            if pref.sentiment in [Sentiment.AIME, Sentiment.ADORE]:
                likes.append(pref.item_name)
            elif pref.sentiment in [Sentiment.NAIME_PAS, Sentiment.DETESTE]:
                dislikes.append(pref.item_name)
            elif pref.sentiment == Sentiment.INTERDIT:
                forbidden.append(pref.item_name)

        return FullProfileForLLM(
            name=profile.name if profile else None,
            mobility=profile.mobility.value if profile else "marche",
            vision_level=profile.vision_level.value if profile else "normal",
            allergies=allergy_names,
            conditions=condition_names,
            likes=likes,
            dislikes=dislikes,
            forbidden=forbidden
        )

    def add_preference(
        self,
        user_id: UUID,
        category: PreferenceCategory,
        item_name: str,
        sentiment: Sentiment,
        reason: Optional[str] = None,
        source: PreferenceSource = PreferenceSource.USER_EXPLICIT,
        confidence: float = 1.0
    ) -> Preference:
        """
        Ajoute ou met à jour une préférence utilisateur.

        Si la préférence existe déjà, elle est mise à jour avec:
        - Le nouveau sentiment (si différent)
        - Incrémentation du compteur times_mentioned
        - Mise à jour de last_mentioned
        """
        # Chercher une préférence existante
        existing = self.db.query(Preference).filter(
            Preference.user_id == user_id,
            Preference.category == category,
            Preference.item_name == item_name
        ).first()

        if existing:
            # Mettre à jour
            existing.sentiment = sentiment
            if reason:
                existing.reason = reason
            existing.times_mentioned += 1
            existing.last_mentioned = datetime.utcnow()
            existing.confidence = max(existing.confidence, confidence)
            self.db.commit()
            return existing
        else:
            # Créer
            pref = Preference(
                user_id=user_id,
                category=category,
                item_name=item_name,
                sentiment=sentiment,
                reason=reason,
                source=source,
                confidence=confidence
            )
            self.db.add(pref)
            self.db.commit()
            self.db.refresh(pref)
            return pref

    def process_user_message(self, user_id: UUID, message: str) -> List[Preference]:
        """
        Analyse un message utilisateur et extrait les préférences.

        Args:
            user_id: ID de l'utilisateur
            message: Message à analyser

        Returns:
            Liste des préférences ajoutées/mises à jour
        """
        extracted = self.extractor.extract_from_text(message)
        preferences = []

        for pref in extracted:
            saved = self.add_preference(
                user_id=user_id,
                category=pref.category,
                item_name=pref.item_name,
                sentiment=pref.sentiment,
                reason=pref.reason,
                source=PreferenceSource.LLM_INFERRED,
                confidence=pref.confidence
            )
            preferences.append(saved)

        return preferences

    def get_preferences_by_sentiment(
        self,
        user_id: UUID,
        sentiments: List[Sentiment]
    ) -> List[Preference]:
        """Récupère les préférences d'un utilisateur par sentiment."""
        return self.db.query(Preference).filter(
            Preference.user_id == user_id,
            Preference.sentiment.in_(sentiments)
        ).all()


# =============================================================================
# SERVICE D'INTERACTION
# =============================================================================

class InteractionService:
    """
    Service de gestion des interactions avec l'IA.
    """

    def __init__(self, db: Session):
        self.db = db
        self.profile_service = ProfileService(db)

    def create_interaction(
        self,
        user_id: UUID,
        context: str,
        user_query: Optional[str],
        gemini_description: Optional[str],
        groq_response: Optional[dict]
    ) -> Interaction:
        """
        Enregistre une nouvelle interaction.

        Analyse automatiquement le message utilisateur pour extraire
        les préférences.
        """
        interaction = Interaction(
            user_id=user_id,
            context=context,
            user_query=user_query,
            gemini_description=gemini_description,
            groq_response=groq_response
        )

        # Extraire les préférences du message utilisateur
        extracted_prefs = []
        if user_query:
            prefs = self.profile_service.process_user_message(user_id, user_query)
            extracted_prefs = [
                {"item": p.item_name, "sentiment": p.sentiment.value}
                for p in prefs
            ]

        interaction.extracted_preferences = extracted_prefs

        self.db.add(interaction)
        self.db.commit()
        self.db.refresh(interaction)
        return interaction

    def add_feedback(
        self,
        interaction_id: UUID,
        user_id: UUID,
        rating: Optional[int],
        was_helpful: Optional[bool],
        feedback_text: Optional[str]
    ) -> Feedback:
        """
        Ajoute un feedback sur une interaction.

        Analyse le texte du feedback pour extraire d'éventuelles préférences.
        """
        feedback = Feedback(
            interaction_id=interaction_id,
            user_id=user_id,
            rating=rating,
            was_helpful=was_helpful,
            feedback_text=feedback_text
        )

        # Extraire les préférences du feedback
        if feedback_text:
            prefs = self.profile_service.process_user_message(user_id, feedback_text)
            feedback.preference_extracted = [
                {"item": p.item_name, "sentiment": p.sentiment.value}
                for p in prefs
            ]

        self.db.add(feedback)
        self.db.commit()
        self.db.refresh(feedback)
        return feedback
