-- =============================================================================
-- Vision360 - Jeu d'essai de démonstration (OPTIONNEL)
-- =============================================================================
-- Ce script est FACULTATIF. Il n'est PAS joué automatiquement au démarrage.
--
-- POURQUOI CE FICHIER EXISTE
--   L'export vision360_dump.sql contient une base VIDE : c'est l'état réel de
--   l'application, qui ne crée aucun compte par défaut. Toutes les données
--   naissent de l'inscription d'un utilisateur (POST /api/users/register).
--   Ce script permet donc de démontrer le modèle relationnel complet sans
--   avoir à cliquer dans l'interface.
--
-- CONTENU
--   1 utilisateur de démonstration, son profil PMR, 2 allergies,
--   1 condition médicale, 4 préférences, 1 interaction IA et 1 feedback.
--   Les UUID sont fixes (et non aléatoires) pour rendre les exemples
--   reproductibles et faciles à citer dans le rapport.
--
-- EXÉCUTION
--   psql -U postgres -d vision360 -f 02_seed_demo.sql
--   docker compose exec -T postgres psql -U postgres -d vision360 < 02_seed_demo.sql
--
-- COMPTE CRÉÉ
--   Email        : demo@vision360.fr
--   Mot de passe : Vision360!
--   (l'empreinte SHA-256 ci-dessous correspond bien à ce mot de passe :
--    le backend hashe avec hashlib.sha256, cf. backend/app/users.py)
--
-- NETTOYAGE
--   Pour repartir d'une base vide : psql -f 99_reset.sql puis 01_schema.sql
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Utilisateur
-- -----------------------------------------------------------------------------
INSERT INTO users (id, email, password_hash, is_active, created_at, last_login)
VALUES (
    '11111111-1111-4111-8111-111111111111',
    'demo@vision360.fr',
    'c2cf8cdc53d2333a2f9a44b5302d2b73946202c8be2a7e805a353c79d3818c7a',  -- SHA-256("Vision360!")
    TRUE,
    '2026-02-10 09:00:00',
    '2026-02-14 18:32:10'
);

-- -----------------------------------------------------------------------------
-- 2. Profil PMR
-- -----------------------------------------------------------------------------
-- Utilisatrice en fauteuil roulant et malvoyante : la synthèse vocale est
-- activée et ralentie, le contraste renforcé et le texte agrandi.
INSERT INTO profiles (
    id, user_id, name, mobility, vision_level,
    tts_enabled, tts_speed, tts_voice,
    high_contrast, large_text, language, updated_at
)
VALUES (
    '22222222-2222-4222-8222-222222222222',
    '11111111-1111-4111-8111-111111111111',
    'Camille Dupont',
    'FAUTEUIL',
    'MALVOYANT',
    TRUE, 0.9, 'fr-FR',
    TRUE, TRUE, 'fr-FR',
    '2026-02-14 18:35:00'
);

-- -----------------------------------------------------------------------------
-- 3. Allergies
-- -----------------------------------------------------------------------------
-- L'arachide est en sévérité MORTEL : le scan d'un produit contenant cet
-- allergène déclenche une alerte vocale bloquante.
INSERT INTO allergies (id, user_id, allergen, severity, confirmed, source, notes, created_at)
VALUES
    (
        '33333333-3333-4333-8333-333333333301',
        '11111111-1111-4111-8111-111111111111',
        'arachide', 'MORTEL', TRUE, 'MEDICAL',
        'Choc anaphylactique en 2019 - porte un stylo auto-injecteur',
        '2026-02-10 09:05:00'
    ),
    (
        '33333333-3333-4333-8333-333333333302',
        '11111111-1111-4111-8111-111111111111',
        'gluten', 'MODERE', TRUE, 'USER_EXPLICIT',
        'Intolérance, pas de maladie coeliaque diagnostiquée',
        '2026-02-10 09:06:00'
    );

-- -----------------------------------------------------------------------------
-- 4. Condition médicale
-- -----------------------------------------------------------------------------
INSERT INTO conditions (id, user_id, condition, severity, dietary_impact, medications, created_at)
VALUES (
    '44444444-4444-4444-8444-444444444401',
    '11111111-1111-4111-8111-111111111111',
    'diabete', 'MODERE',
    'Limiter les sucres rapides ; privilégier un index glycémique bas',
    'Metformine 500 mg, 2 fois par jour',
    '2026-02-10 09:08:00'
);

-- -----------------------------------------------------------------------------
-- 5. Préférences évolutives
-- -----------------------------------------------------------------------------
-- Deux origines illustrées :
--   - USER_EXPLICIT : dit directement par l'utilisatrice, confiance = 1.0
--   - LLM_INFERRED  : déduit par Groq d'une phrase, confiance < 1.0
INSERT INTO preferences (
    id, user_id, category, item_name, normalized_name,
    sentiment, reason, source, confidence, times_mentioned,
    created_at, last_mentioned
)
VALUES
    (
        '55555555-5555-4555-8555-555555555501',
        '11111111-1111-4111-8111-111111111111',
        'PRODUIT', 'Nutella', 'nutella',
        'NAIME_PAS', 'Trop sucré et contient des fruits à coque',
        'USER_EXPLICIT', 1.0, 3,
        '2026-02-10 09:12:00', '2026-02-14 18:30:00'
    ),
    (
        '55555555-5555-4555-8555-555555555502',
        '11111111-1111-4111-8111-111111111111',
        'CUISINE', 'italienne', 'italienne',
        'ADORE', 'Mentionné spontanément à plusieurs reprises',
        'LLM_INFERRED', 0.8, 5,
        '2026-02-11 12:40:00', '2026-02-14 12:05:00'
    ),
    (
        '55555555-5555-4555-8555-555555555503',
        '11111111-1111-4111-8111-111111111111',
        'INGREDIENT', 'sucre ajouté', 'sucre ajoute',
        'INTERDIT', 'Contre-indication liée au diabète',
        'MEDICAL', 1.0, 1,
        '2026-02-10 09:14:00', '2026-02-10 09:14:00'
    ),
    (
        '55555555-5555-4555-8555-555555555504',
        '11111111-1111-4111-8111-111111111111',
        'MARQUE', 'Bjorg', 'bjorg',
        'AIME', 'Gamme sans gluten bien identifiée en rayon',
        'BEHAVIOR', 0.65, 2,
        '2026-02-12 17:20:00', '2026-02-14 18:31:00'
    );

-- -----------------------------------------------------------------------------
-- 6. Interaction avec l'IA
-- -----------------------------------------------------------------------------
-- Cycle complet : photo d'un rayon -> description Gemini -> recommandations
-- Groq filtrées par le profil (allergies + diabète + préférences).
INSERT INTO interactions (
    id, user_id, session_id, context, location,
    image_hash, image_url, user_query,
    gemini_description, groq_response, recommendations, extracted_preferences,
    created_at
)
VALUES (
    '66666666-6666-4666-8666-666666666601',
    '11111111-1111-4111-8111-111111111111',
    '77777777-7777-4777-8777-777777777701',
    'SUPERMARCHE',
    'Carrefour Market - Rayon petit-déjeuner',
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    NULL,
    'Qu''est-ce que je peux prendre pour le petit-déjeuner ?',
    'Rayon petit-déjeuner. Trois étagères visibles : pâtes à tartiner (Nutella, purée de noisettes), confitures allégées, miel. Étagère du bas : biscuits sans gluten. Les prix sont affichés sur des étiquettes jaunes.',
    '{"summary": "Rayon petit-déjeuner, 3 étagères", "risks": ["Nutella : contient des fruits à coque - allergie arachide déclarée", "Pâtes à tartiner : sucre ajouté, déconseillé avec le diabète"], "actions": ["Privilégier la confiture allégée en sucre, 2e étagère à hauteur de main", "Les biscuits sans gluten sont sur l''étagère du bas, à gauche"]}',
    '["Confiture allégée en sucre - 2e étagère", "Biscuits sans gluten - étagère du bas à gauche"]',
    '[{"item_name": "Nutella", "sentiment": "NAIME_PAS", "confidence": 1.0}]',
    '2026-02-14 18:30:00'
);

-- -----------------------------------------------------------------------------
-- 7. Retour utilisateur
-- -----------------------------------------------------------------------------
INSERT INTO feedback (
    id, interaction_id, user_id,
    rating, was_helpful, was_accurate,
    feedback_text, preference_extracted, created_at
)
VALUES (
    '88888888-8888-4888-8888-888888888801',
    '66666666-6666-4666-8666-666666666601',
    '11111111-1111-4111-8111-111111111111',
    5, TRUE, TRUE,
    'L''indication de l''étagère était précise, j''ai trouvé du premier coup.',
    '{"localisation_utile": true}',
    '2026-02-14 18:33:00'
);

COMMIT;

-- =============================================================================
-- VÉRIFICATION
-- =============================================================================
-- Compte le contenu de chaque table après insertion :
--
--   SELECT 'users' AS table_name, COUNT(*) FROM users
--   UNION ALL SELECT 'profiles',     COUNT(*) FROM profiles
--   UNION ALL SELECT 'allergies',    COUNT(*) FROM allergies
--   UNION ALL SELECT 'conditions',   COUNT(*) FROM conditions
--   UNION ALL SELECT 'preferences',  COUNT(*) FROM preferences
--   UNION ALL SELECT 'interactions', COUNT(*) FROM interactions
--   UNION ALL SELECT 'feedback',     COUNT(*) FROM feedback;
--
-- Résultat attendu : 1, 1, 2, 1, 4, 1, 1
-- =============================================================================
