-- =============================================================================
-- Vision360 - Script de création de la base de données
-- =============================================================================
-- SGBD cible  : PostgreSQL 16
-- Base        : vision360
-- Encodage    : UTF8
-- Projet      : SAE Vision360 - BUT INFO 3e année (S5/S6, Parcours A & C)
--
-- CE FICHIER EST LE SCRIPT DE CRÉATION DE RÉFÉRENCE.
-- Il reproduit exactement le schéma généré par SQLAlchemy
-- (backend/app/models.py -> Base.metadata.create_all()).
--
-- Exécution manuelle :
--   psql -U postgres -d vision360 -f 01_schema.sql
--
-- Exécution automatique (Docker) :
--   Ce fichier est monté dans /docker-entrypoint-initdb.d/ par docker-compose.yml
--   et joué automatiquement au tout premier démarrage du conteneur PostgreSQL.
--
-- IMPORTANT - Libellés des types ENUM :
--   SQLAlchemy persiste le NOM des membres d'énumération Python, pas leur valeur.
--   Exemple : MobilityType.FAUTEUIL = "fauteuil" en Python  ->  'FAUTEUIL' en base.
--   Les libellés ci-dessous sont donc en MAJUSCULES : c'est volontaire et
--   indispensable pour que l'ORM et la base restent compatibles.
-- =============================================================================


-- =============================================================================
-- 0. EXTENSIONS
-- =============================================================================
-- Génération d'UUID côté serveur.
-- Le backend génère déjà les UUID côté Python (uuid.uuid4) ; l'extension est
-- fournie pour permettre des INSERT SQL manuels avec gen_random_uuid().
CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- =============================================================================
-- 1. TYPES ÉNUMÉRÉS
-- =============================================================================

-- Mode de déplacement de la personne à mobilité réduite.
-- Utilisé par : profiles.mobility
CREATE TYPE mobilitytype AS ENUM (
    'FAUTEUIL',      -- Fauteuil roulant
    'CANNE',         -- Canne / canne blanche
    'DEAMBULATEUR',  -- Déambulateur
    'MARCHE'         -- Marche autonome (valeur par défaut)
);

-- Niveau d'acuité visuelle : pilote l'agressivité des alertes vocales.
-- Utilisé par : profiles.vision_level
CREATE TYPE visionlevel AS ENUM (
    'NORMAL',
    'FAIBLE',
    'MALVOYANT',
    'NON_VOYANT'
);

-- Gravité d'une allergie ou d'une condition médicale.
-- 'MORTEL' n'est utilisé que pour les allergies (choc anaphylactique).
-- Utilisé par : allergies.severity, conditions.severity
CREATE TYPE severity AS ENUM (
    'FAIBLE',
    'MODERE',
    'SEVERE',
    'MORTEL'
);

-- Nature de l'élément sur lequel porte une préférence.
-- Utilisé par : preferences.category
CREATE TYPE preferencecategory AS ENUM (
    'PRODUIT',      -- Ex : "Nutella"
    'MARQUE',       -- Ex : "Danone"
    'RECETTE',      -- Ex : "poulet rôti"
    'INGREDIENT',   -- Ex : "gluten"
    'LIEU',         -- Ex : "Carrefour Market"
    'TEXTURE',      -- Ex : "croquant"
    'CUISINE'       -- Ex : "italienne"
);

-- Position de l'utilisateur vis-à-vis d'un élément.
-- 'INTERDIT' = contre-indication médicale ou religieuse (bloquant).
-- Utilisé par : preferences.sentiment
CREATE TYPE sentiment AS ENUM (
    'ADORE',
    'AIME',
    'NEUTRE',
    'NAIME_PAS',
    'DETESTE',
    'INTERDIT'
);

-- Origine de l'information : saisie utilisateur, déduction du LLM, etc.
-- Sert à pondérer la confiance accordée à la donnée.
-- Utilisé par : allergies.source, preferences.source
CREATE TYPE preferencesource AS ENUM (
    'USER_EXPLICIT',  -- L'utilisateur l'a dit explicitement
    'LLM_INFERRED',   -- Déduit par Groq depuis une conversation
    'BEHAVIOR',       -- Déduit du comportement (feedbacks répétés)
    'MEDICAL'         -- Information médicale déclarée
);

-- Environnement dans lequel se déroule une interaction.
-- Utilisé par : interactions.context
CREATE TYPE contexttype AS ENUM (
    'SUPERMARCHE',
    'RESTAURANT',
    'NAVIGATION',
    'MAISON',
    'TRANSPORT'
);


-- =============================================================================
-- 2. TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 2.1 users - Comptes utilisateurs
-- -----------------------------------------------------------------------------
-- Table racine de tout le modèle : chaque donnée personnelle (profil, allergie,
-- préférence, interaction) est rattachée à un utilisateur.
-- Le mot de passe n'est JAMAIS stocké en clair, seule son empreinte l'est.
-- -----------------------------------------------------------------------------
CREATE TABLE users (
    id             UUID         NOT NULL,
    email          VARCHAR(255) NOT NULL,
    password_hash  VARCHAR(255) NOT NULL,
    is_active      BOOLEAN,
    created_at     TIMESTAMP WITHOUT TIME ZONE,
    last_login     TIMESTAMP WITHOUT TIME ZONE,

    CONSTRAINT users_pkey PRIMARY KEY (id)
);

-- Index unique : garantit l'unicité de l'email et accélère /api/users/login,
-- qui fait un SELECT ... WHERE email = ? à chaque connexion.
CREATE UNIQUE INDEX ix_users_email ON users (email);

COMMENT ON TABLE  users               IS 'Comptes utilisateurs de l''application Vision360';
COMMENT ON COLUMN users.password_hash IS 'Empreinte du mot de passe - jamais le mot de passe en clair';
COMMENT ON COLUMN users.is_active     IS 'Compte actif ; FALSE = désactivé sans suppression des données';


-- -----------------------------------------------------------------------------
-- 2.2 profiles - Profils PMR
-- -----------------------------------------------------------------------------
-- Relation 1-1 avec users. Contient tout ce qui personnalise l'assistance :
-- mobilité, vision, et réglages d'accessibilité (synthèse vocale, contraste).
-- -----------------------------------------------------------------------------
CREATE TABLE profiles (
    id            UUID         NOT NULL,
    user_id       UUID         NOT NULL,

    name          VARCHAR(100),
    mobility      mobilitytype,
    vision_level  visionlevel,

    -- Synthèse vocale (Text-To-Speech)
    tts_enabled   BOOLEAN,
    tts_speed     DOUBLE PRECISION,   -- 0.5 (lent) à 2.0 (rapide)
    tts_voice     VARCHAR(50),        -- Identifiant de voix, ex : 'fr-FR'

    -- Confort visuel
    high_contrast BOOLEAN,
    large_text    BOOLEAN,

    language      VARCHAR(10),        -- Locale de l'interface, ex : 'fr-FR'
    updated_at    TIMESTAMP WITHOUT TIME ZONE,

    CONSTRAINT profiles_pkey         PRIMARY KEY (id),
    CONSTRAINT profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id)
);

COMMENT ON TABLE  profiles           IS 'Profil PMR : mobilité, vision et réglages d''accessibilité';
COMMENT ON COLUMN profiles.tts_speed IS 'Vitesse de lecture de la synthèse vocale (0.5 à 2.0)';


-- -----------------------------------------------------------------------------
-- 2.3 allergies - Allergènes déclarés
-- -----------------------------------------------------------------------------
-- Table critique pour la sécurité : c'est elle qui déclenche les alertes
-- vocales lors du scan d'un code-barres (croisement avec Open Food Facts).
-- -----------------------------------------------------------------------------
CREATE TABLE allergies (
    id          UUID         NOT NULL,
    user_id     UUID         NOT NULL,

    allergen    VARCHAR(100) NOT NULL,  -- Ex : 'arachide', 'gluten', 'lactose'
    severity    severity,               -- Défaut applicatif : MODERE
    confirmed   BOOLEAN,                -- Validé par l'utilisateur
    source      preferencesource,       -- Défaut applicatif : USER_EXPLICIT
    notes       TEXT,                   -- Précisions libres

    created_at  TIMESTAMP WITHOUT TIME ZONE,

    CONSTRAINT allergies_pkey         PRIMARY KEY (id),
    CONSTRAINT allergies_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id)
);

COMMENT ON TABLE  allergies          IS 'Allergènes de l''utilisateur - source des alertes de sécurité';
COMMENT ON COLUMN allergies.severity IS 'MORTEL = risque de choc anaphylactique, alerte bloquante';


-- -----------------------------------------------------------------------------
-- 2.4 conditions - Conditions médicales
-- -----------------------------------------------------------------------------
-- Pathologies ayant un impact alimentaire (diabète, hypertension...).
-- Injectées dans le prompt Groq pour adapter les recommandations.
-- -----------------------------------------------------------------------------
CREATE TABLE conditions (
    id              UUID         NOT NULL,
    user_id         UUID         NOT NULL,

    condition       VARCHAR(100) NOT NULL,  -- Ex : 'diabete', 'hypertension'
    severity        severity,
    dietary_impact  TEXT,                   -- Ex : 'éviter les sucres rapides'
    medications     TEXT,                   -- Traitements en cours

    created_at      TIMESTAMP WITHOUT TIME ZONE,

    CONSTRAINT conditions_pkey         PRIMARY KEY (id),
    CONSTRAINT conditions_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id)
);

COMMENT ON TABLE conditions IS 'Conditions médicales impactant les recommandations alimentaires';


-- -----------------------------------------------------------------------------
-- 2.5 preferences - Préférences évolutives
-- -----------------------------------------------------------------------------
-- Coeur de l'apprentissage du système. Alimentée soit explicitement par
-- l'utilisateur, soit automatiquement par extraction depuis ses phrases
-- (POST /api/users/{id}/extract-preferences).
--
-- times_mentioned et confidence permettent de pondérer : une préférence
-- répétée dix fois pèse plus lourd qu'une déduction isolée du LLM.
-- -----------------------------------------------------------------------------
CREATE TABLE preferences (
    id               UUID               NOT NULL,
    user_id          UUID               NOT NULL,

    -- Sur quoi porte la préférence
    category         preferencecategory NOT NULL,
    item_name        VARCHAR(255)       NOT NULL,  -- Ex : 'Nutella'
    normalized_name  VARCHAR(255),                 -- Ex : 'nutella' (matching)

    -- Position de l'utilisateur
    sentiment        sentiment          NOT NULL,
    reason           TEXT,                         -- Ex : 'trop sucré'

    -- Métadonnées de fiabilité
    source           preferencesource,
    confidence       DOUBLE PRECISION,             -- 0.0 à 1.0
    times_mentioned  INTEGER,                      -- Compteur de mentions

    created_at       TIMESTAMP WITHOUT TIME ZONE,
    last_mentioned   TIMESTAMP WITHOUT TIME ZONE,

    CONSTRAINT preferences_pkey         PRIMARY KEY (id),
    CONSTRAINT preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id)
);

COMMENT ON TABLE  preferences                 IS 'Préférences évolutives : ce que l''utilisateur aime ou refuse';
COMMENT ON COLUMN preferences.normalized_name IS 'Nom normalisé (minuscules, sans accents) pour le rapprochement';
COMMENT ON COLUMN preferences.confidence      IS 'Confiance 0.0-1.0 : 1.0 si déclaré, < 1.0 si déduit par le LLM';


-- -----------------------------------------------------------------------------
-- 2.6 interactions - Historique des échanges avec l'IA
-- -----------------------------------------------------------------------------
-- Une ligne = une analyse complète : photo -> description Gemini ->
-- recommandations Groq. Les colonnes JSON stockent les réponses brutes,
-- ce qui permet de rejouer ou d'auditer une recommandation a posteriori.
-- -----------------------------------------------------------------------------
CREATE TABLE interactions (
    id                     UUID        NOT NULL,
    user_id                UUID        NOT NULL,
    session_id             UUID,                   -- Regroupe une conversation

    -- Contexte d'usage
    context                contexttype,            -- Défaut applicatif : SUPERMARCHE
    location               VARCHAR(255),

    -- Image analysée
    image_hash             VARCHAR(64),            -- SHA-256, évite les doublons
    image_url              VARCHAR(500),

    -- Entrée utilisateur
    user_query             TEXT,                   -- Commande vocale ou texte

    -- Sorties des modèles
    gemini_description     TEXT,                   -- Description de la scène
    groq_response          JSON,                   -- Réponse LLM complète
    recommendations        JSON,                   -- Conseils extraits
    extracted_preferences  JSON,                   -- Préférences détectées

    created_at             TIMESTAMP WITHOUT TIME ZONE,

    CONSTRAINT interactions_pkey         PRIMARY KEY (id),
    CONSTRAINT interactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id)
);

COMMENT ON TABLE  interactions            IS 'Historique des analyses image + recommandations IA';
COMMENT ON COLUMN interactions.image_hash IS 'SHA-256 de l''image : évite de ré-analyser une photo identique';


-- -----------------------------------------------------------------------------
-- 2.7 feedback - Retours utilisateur
-- -----------------------------------------------------------------------------
-- Relation 1-1 avec interactions. Boucle d'amélioration : un feedback négatif
-- peut générer une nouvelle ligne dans preferences via preference_extracted.
-- -----------------------------------------------------------------------------
CREATE TABLE feedback (
    id                    UUID    NOT NULL,
    interaction_id        UUID    NOT NULL,
    user_id               UUID    NOT NULL,

    -- Évaluation
    rating                INTEGER,   -- 1 à 5 étoiles
    was_helpful           BOOLEAN,
    was_accurate          BOOLEAN,

    feedback_text         TEXT,      -- Commentaire libre
    preference_extracted  JSON,      -- Préférences déduites du commentaire

    created_at            TIMESTAMP WITHOUT TIME ZONE,

    CONSTRAINT feedback_pkey                PRIMARY KEY (id),
    CONSTRAINT feedback_interaction_id_fkey FOREIGN KEY (interaction_id) REFERENCES interactions (id),
    CONSTRAINT feedback_user_id_fkey        FOREIGN KEY (user_id)        REFERENCES users (id)
);

COMMENT ON TABLE feedback IS 'Retours utilisateur sur les recommandations - boucle d''apprentissage';


-- =============================================================================
-- 3. INDEX DE PERFORMANCE
-- =============================================================================
-- Toutes les requêtes de l'API filtrent sur user_id. Sans ces index,
-- PostgreSQL fait un parcours séquentiel complet de la table.
-- Ils ne sont pas créés par SQLAlchemy : c'est un ajout d'optimisation,
-- sans aucun impact sur le fonctionnement de l'ORM.
-- =============================================================================

CREATE INDEX ix_profiles_user_id     ON profiles     (user_id);
CREATE INDEX ix_allergies_user_id    ON allergies    (user_id);
CREATE INDEX ix_conditions_user_id   ON conditions   (user_id);
CREATE INDEX ix_preferences_user_id  ON preferences  (user_id);
CREATE INDEX ix_interactions_user_id ON interactions (user_id);
CREATE INDEX ix_feedback_user_id     ON feedback     (user_id);

-- L'historique est toujours affiché du plus récent au plus ancien
-- (GET /api/users/{id}/interactions -> ORDER BY created_at DESC LIMIT 20)
CREATE INDEX ix_interactions_user_created ON interactions (user_id, created_at DESC);

-- Le moteur de recommandation filtre les préférences par catégorie
CREATE INDEX ix_preferences_user_category ON preferences (user_id, category);


-- =============================================================================
-- FIN DU SCRIPT
-- =============================================================================
-- Vérification rapide après exécution :
--   \dt                          -- doit lister 7 tables
--   \dT                          -- doit lister 7 types énumérés
--   SELECT COUNT(*) FROM users;  -- 0 : la base est vide, voir README.md
-- =============================================================================
