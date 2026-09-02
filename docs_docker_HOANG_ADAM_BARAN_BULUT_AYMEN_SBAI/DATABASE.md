# Base de Données Vision360

## Objectifs

- Stocker les utilisateurs et leurs profils PMR
- Enregistrer les préférences évolutives (produits aimés/détestés, recettes, etc.)
- Historiser les interactions avec le LLM
- Permettre au système d'apprendre des retours utilisateur

---

## Schéma de la base de données

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           BASE DE DONNÉES VISION360                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────┐       ┌──────────────────┐       ┌──────────────────┐
│    users     │       │     profiles     │       │   preferences    │
├──────────────┤       ├──────────────────┤       ├──────────────────┤
│ id (PK)      │──────▶│ id (PK)          │       │ id (PK)          │
│ email        │       │ user_id (FK)     │◀──────│ user_id (FK)     │
│ password_hash│       │ name             │       │ category         │
│ created_at   │       │ mobility         │       │ item_name        │
│ last_login   │       │ tts_enabled      │       │ sentiment        │
└──────────────┘       │ updated_at       │       │ reason           │
                       └──────────────────┘       │ source           │
                                                  │ created_at       │
                                                  └──────────────────┘

┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐
│    allergies     │       │   conditions     │       │  interactions    │
├──────────────────┤       ├──────────────────┤       ├──────────────────┤
│ id (PK)          │       │ id (PK)          │       │ id (PK)          │
│ user_id (FK)     │       │ user_id (FK)     │       │ user_id (FK)     │
│ allergen         │       │ condition        │       │ context          │
│ severity         │       │ severity         │       │ image_hash       │
│ created_at       │       │ created_at       │       │ gemini_response  │
└──────────────────┘       └──────────────────┘       │ groq_response    │
                                                      │ user_feedback    │
                                                      │ created_at       │
                                                      └──────────────────┘
```

---

## Détail des tables

### 1. `users` - Utilisateurs

| Colonne | Type | Description |
|---------|------|-------------|
| `id` | UUID (PK) | Identifiant unique |
| `email` | VARCHAR(255) | Email unique |
| `password_hash` | VARCHAR(255) | Mot de passe hashé (bcrypt) |
| `created_at` | TIMESTAMP | Date d'inscription |
| `last_login` | TIMESTAMP | Dernière connexion |
| `is_active` | BOOLEAN | Compte actif |

### 2. `profiles` - Profils PMR

| Colonne | Type | Description |
|---------|------|-------------|
| `id` | UUID (PK) | Identifiant unique |
| `user_id` | UUID (FK) | Référence vers users |
| `name` | VARCHAR(100) | Nom/Prénom |
| `mobility` | ENUM | 'fauteuil', 'canne', 'deambulateur', 'marche' |
| `vision_level` | ENUM | 'normal', 'faible', 'malvoyant', 'non_voyant' |
| `tts_enabled` | BOOLEAN | Synthèse vocale activée |
| `tts_speed` | FLOAT | Vitesse de lecture (0.5 - 2.0) |
| `language` | VARCHAR(10) | Langue préférée (fr-FR) |
| `updated_at` | TIMESTAMP | Dernière mise à jour |

### 3. `allergies` - Allergies utilisateur

| Colonne | Type | Description |
|---------|------|-------------|
| `id` | UUID (PK) | Identifiant unique |
| `user_id` | UUID (FK) | Référence vers users |
| `allergen` | VARCHAR(100) | Nom de l'allergène (arachide, gluten, lactose...) |
| `severity` | ENUM | 'faible', 'modere', 'severe', 'mortel' |
| `confirmed` | BOOLEAN | Confirmé par l'utilisateur |
| `source` | ENUM | 'user_input', 'llm_detected', 'medical' |
| `created_at` | TIMESTAMP | Date d'ajout |

### 4. `conditions` - Conditions médicales

| Colonne | Type | Description |
|---------|------|-------------|
| `id` | UUID (PK) | Identifiant unique |
| `user_id` | UUID (FK) | Référence vers users |
| `condition` | VARCHAR(100) | Nom de la condition (diabete, hypertension...) |
| `severity` | ENUM | 'leger', 'modere', 'severe' |
| `dietary_impact` | TEXT | Impact sur l'alimentation |
| `created_at` | TIMESTAMP | Date d'ajout |

### 5. `preferences` - Préférences évolutives ⭐

C'est la table clé pour stocker ce que l'utilisateur aime ou n'aime pas.

| Colonne | Type | Description |
|---------|------|-------------|
| `id` | UUID (PK) | Identifiant unique |
| `user_id` | UUID (FK) | Référence vers users |
| `category` | ENUM | 'produit', 'marque', 'recette', 'ingredient', 'lieu', 'texture' |
| `item_name` | VARCHAR(255) | Nom de l'élément (ex: "Nutella", "poulet rôti") |
| `sentiment` | ENUM | 'aime', 'adore', 'neutre', 'naime_pas', 'deteste', 'interdit' |
| `reason` | TEXT | Raison (ex: "trop sucré", "mauvaise expérience") |
| `source` | ENUM | 'user_explicit', 'llm_inferred', 'behavior' |
| `confidence` | FLOAT | Niveau de confiance (0.0 - 1.0) |
| `times_mentioned` | INT | Nombre de fois mentionné |
| `last_mentioned` | TIMESTAMP | Dernière mention |
| `created_at` | TIMESTAMP | Première détection |

### 6. `interactions` - Historique des échanges

| Colonne | Type | Description |
|---------|------|-------------|
| `id` | UUID (PK) | Identifiant unique |
| `user_id` | UUID (FK) | Référence vers users |
| `session_id` | UUID | Session de conversation |
| `context` | ENUM | 'supermarche', 'restaurant', 'navigation', 'maison' |
| `image_hash` | VARCHAR(64) | Hash de l'image (pour éviter doublons) |
| `image_description` | TEXT | Description Gemini |
| `user_query` | TEXT | Question/commande de l'utilisateur |
| `groq_response` | JSONB | Réponse complète de Groq |
| `recommendations` | JSONB | Recommandations extraites |
| `created_at` | TIMESTAMP | Date de l'interaction |

### 7. `feedback` - Retours utilisateur

| Colonne | Type | Description |
|---------|------|-------------|
| `id` | UUID (PK) | Identifiant unique |
| `interaction_id` | UUID (FK) | Référence vers interactions |
| `user_id` | UUID (FK) | Référence vers users |
| `rating` | INT | Note (1-5) |
| `was_helpful` | BOOLEAN | La recommandation était-elle utile ? |
| `feedback_text` | TEXT | Commentaire libre |
| `preference_extracted` | JSONB | Préférences extraites du feedback |
| `created_at` | TIMESTAMP | Date du feedback |

---

## Exemples de données

### Exemple : Préférences

```json
// L'utilisateur dit : "Je n'aime pas le Nutella, c'est trop sucré"

{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "123e4567-e89b-12d3-a456-426614174000",
  "category": "produit",
  "item_name": "Nutella",
  "sentiment": "naime_pas",
  "reason": "trop sucré",
  "source": "user_explicit",
  "confidence": 1.0,
  "times_mentioned": 1,
  "created_at": "2024-01-15T10:30:00Z"
}
```

### Exemple : Interaction

```json
{
  "id": "...",
  "user_id": "...",
  "context": "supermarche",
  "image_description": "Rayon petit-déjeuner avec Nutella, confiture, miel...",
  "user_query": "Qu'est-ce que je peux prendre pour le petit-déjeuner ?",
  "groq_response": {
    "summary": "Rayon petit-déjeuner",
    "risks": ["Nutella détecté - vous n'aimez pas (trop sucré)"],
    "actions": ["Privilégier le miel ou la confiture allégée"]
  }
}
```

---

## Requêtes SQL utiles

### Récupérer le profil complet d'un utilisateur

```sql
SELECT
    u.email,
    p.name,
    p.mobility,
    p.vision_level,
    ARRAY_AGG(DISTINCT a.allergen) as allergies,
    ARRAY_AGG(DISTINCT c.condition) as conditions,
    ARRAY_AGG(DISTINCT
        CASE WHEN pr.sentiment IN ('naime_pas', 'deteste')
        THEN pr.item_name END
    ) as dislikes,
    ARRAY_AGG(DISTINCT
        CASE WHEN pr.sentiment IN ('aime', 'adore')
        THEN pr.item_name END
    ) as likes
FROM users u
JOIN profiles p ON u.id = p.user_id
LEFT JOIN allergies a ON u.id = a.user_id
LEFT JOIN conditions c ON u.id = c.user_id
LEFT JOIN preferences pr ON u.id = pr.user_id
WHERE u.id = $1
GROUP BY u.id, p.id;
```

### Trouver les préférences négatives pour le contexte supermarché

```sql
SELECT item_name, reason, times_mentioned
FROM preferences
WHERE user_id = $1
  AND category IN ('produit', 'marque', 'ingredient')
  AND sentiment IN ('naime_pas', 'deteste', 'interdit')
ORDER BY times_mentioned DESC;
```

### Ajouter ou mettre à jour une préférence

```sql
INSERT INTO preferences (id, user_id, category, item_name, sentiment, reason, source, confidence)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
ON CONFLICT (user_id, category, item_name)
DO UPDATE SET
    sentiment = EXCLUDED.sentiment,
    reason = COALESCE(EXCLUDED.reason, preferences.reason),
    times_mentioned = preferences.times_mentioned + 1,
    last_mentioned = NOW(),
    confidence = GREATEST(preferences.confidence, EXCLUDED.confidence);
```

---

## Endpoints API

### Authentification

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `POST` | `/api/users/register` | Inscription d'un utilisateur |
| `POST` | `/api/users/login` | Connexion |

### Profils

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/api/users/{user_id}/profile` | Récupérer le profil |
| `PUT` | `/api/users/{user_id}/profile` | Mettre à jour le profil |
| `GET` | `/api/users/{user_id}/full-profile` | Profil complet pour LLM |

### Allergies

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/api/users/{user_id}/allergies` | Liste des allergies |
| `POST` | `/api/users/{user_id}/allergies` | Ajouter une allergie |
| `DELETE` | `/api/users/{user_id}/allergies/{id}` | Supprimer une allergie |

### Conditions médicales

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/api/users/{user_id}/conditions` | Liste des conditions |
| `POST` | `/api/users/{user_id}/conditions` | Ajouter une condition |
| `DELETE` | `/api/users/{user_id}/conditions/{id}` | Supprimer une condition |

### Préférences

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/api/users/{user_id}/preferences` | Liste des préférences |
| `POST` | `/api/users/{user_id}/preferences` | Ajouter une préférence |
| `PUT` | `/api/users/{user_id}/preferences/{id}` | Modifier une préférence |
| `DELETE` | `/api/users/{user_id}/preferences/{id}` | Supprimer une préférence |
| `POST` | `/api/users/{user_id}/extract-preferences` | Extraction automatique depuis texte |

### Interactions & Feedback

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/api/users/{user_id}/interactions` | Historique des interactions |
| `POST` | `/api/users/{user_id}/interactions` | Enregistrer une interaction |
| `POST` | `/api/feedback` | Ajouter un feedback |

---

## Extraction automatique des préférences

Le système extrait automatiquement les préférences depuis les messages utilisateur grâce à des patterns regex :

### Sentiments négatifs détectés

```
"je n'aime pas le Nutella"     → Nutella, naime_pas
"je déteste les épinards"      → Épinards, deteste
"je suis allergique aux noix"  → Noix, allergie détectée
"sans gluten s'il vous plaît"  → Gluten, naime_pas
"évitez le lactose"            → Lactose, naime_pas
```

### Sentiments positifs détectés

```
"j'adore le chocolat"          → Chocolat, adore
"je préfère la cuisine italienne" → Italienne, aime
"le poulet est mon préféré"    → Poulet, aime
```

### Catégories auto-détectées

- **Produit** : nutella, chips, yaourt, pizza...
- **Marque** : danone, nestlé, carrefour...
- **Ingrédient** : sucre, sel, gluten, lactose...
- **Cuisine** : italien, chinois, japonais...
- **Texture** : croquant, crémeux, mou...

