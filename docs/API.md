# 📡 Documentation API - Vision360

## Base URL

| Environnement | URL |
|---------------|-----|
| Local | `http://localhost:8000/api` |
| Production | `https://vision360-backend-276274707876.europe-west1.run.app/api` |

## Authentification

Actuellement, l'API est ouverte (pas d'authentification requise). Les clés API (Gemini, Groq) sont gérées côté serveur.

## Endpoints

### Health Check

#### `GET /health`

Vérifie l'état du service.

**Réponse** :
```json
{
  "status": "ok"
}
```

---

### Description d'image avec Gemini

#### `POST /api/describe/gemini`

Analyse une image avec Google Gemini Vision pour obtenir une description textuelle.

**Headers** :
```
Content-Type: application/json
```

**Body** :
```json
{
  "image_b64": "string (obligatoire)",
  "prompt": "string (optionnel)"
}
```

| Paramètre | Type | Description |
|-----------|------|-------------|
| `image_b64` | string | Image encodée en base64 (avec ou sans préfixe `data:image/jpeg;base64,`) |
| `prompt` | string | Instruction pour l'analyse. Par défaut : "Décris précisément les produits/objets visibles, marques ou catégories, positions relatives." |

**Exemple de requête** :
```bash
curl -X POST http://localhost:8000/api/describe/gemini \
  -H "Content-Type: application/json" \
  -d '{
    "image_b64": "/9j/4AAQSkZJRgABAQAAAQABAAD...",
    "prompt": "Décris les obstacles visibles pour une personne en fauteuil roulant"
  }'
```

**Réponse (200 OK)** :
```json
{
  "structured": {
    "text": "L'image montre un couloir de supermarché avec des étagères de chaque côté. Au sol, on aperçoit un carton et un panneau indiquant 'sol glissant'. Le passage semble étroit.",
    "raw_parts": [...],
    "prompt": "Décris les obstacles visibles...",
    "model": "gemini-2.0-flash-exp"
  },
  "raw": {
    "candidates": [...]
  }
}
```

**Erreurs** :

| Code | Description |
|------|-------------|
| 500 | `GEMINI_API_KEY manquante côté serveur` |
| 500 | `Appel Gemini échoué: <détails>` |
| 4xx | Erreur renvoyée par l'API Gemini |

---

### Génération de recommandations avec Groq

#### `POST /api/describe/groq`

Génère des recommandations personnalisées à partir d'une description textuelle et du profil utilisateur.

**Body** :
```json
{
  "description": "string (obligatoire)",
  "profile": "string (optionnel, défaut: 'default')",
  "instruction": "string (optionnel)",
  "profile_override": "object (optionnel)"
}
```

| Paramètre | Type | Description |
|-----------|------|-------------|
| `description` | string | Texte descriptif (généralement la sortie de Gemini) |
| `profile` | string | Identifiant du profil utilisateur dans le catalogue |
| `instruction` | string | Instruction de formatage pour la sortie |
| `profile_override` | object | Profil inline pour écraser le catalogue |

**Structure du `profile_override`** :
```json
{
  "name": "Jean Dupont",
  "allergies": ["arachide", "gluten"],
  "conditions": ["diabete", "hypertension"],
  "preferences": ["sans sucre", "bio"],
  "mobility": "fauteuil"
}
```

**Exemple de requête** :
```bash
curl -X POST http://localhost:8000/api/describe/groq \
  -H "Content-Type: application/json" \
  -d '{
    "description": "Rayon snacks avec chips, cacahuètes, barres chocolatées",
    "profile_override": {
      "name": "Marie",
      "allergies": ["arachide"],
      "mobility": "canne"
    }
  }'
```

**Réponse (200 OK)** :
```json
{
  "structured": {
    "summary": "Rayon snacks détecté. Attention aux produits contenant des arachides.",
    "risks": [
      "Cacahuètes détectées - allergène présent",
      "Certaines barres chocolatées peuvent contenir des traces d'arachide"
    ],
    "actions": [
      "Éviter le paquet de cacahuètes",
      "Vérifier les étiquettes des barres chocolatées",
      "Privilégier les chips nature"
    ]
  },
  "raw_text": "{\"summary\": ...",
  "raw": {
    "choices": [...]
  }
}
```

---

### Enrichissement de détection

#### `POST /api/guidance/enrich`

Enrichit une détection d'objet avec une description et des risques PMR.

**Body** :
```json
{
  "detection": {
    "class": "string (obligatoire)",
    "score": "float 0-1 (obligatoire)",
    "zone": "string (optionnel: near|mid|far)",
    "side": "string (optionnel: left|center|right)",
    "ocr": "string (optionnel)",
    "context": "string (optionnel)"
  },
  "profile_hint": "string (optionnel)"
}
```

**Exemple** :
```bash
curl -X POST http://localhost:8000/api/guidance/enrich \
  -H "Content-Type: application/json" \
  -d '{
    "detection": {
      "class": "stairs",
      "score": 0.92,
      "zone": "near",
      "side": "center"
    }
  }'
```

**Réponse** :
```json
{
  "summary": "Escalier",
  "attributes": {
    "zone": "near",
    "side": "center",
    "score": "0.92"
  },
  "risks": [
    "Obstacle proche",
    "Prévoir montée/descente"
  ],
  "class_name": "stairs",
  "zone": "near",
  "side": "center"
}
```

---

### Enrichissement par lot

#### `POST /api/guidance/enrich/batch`

Enrichit plusieurs détections en une seule requête.

**Body** :
```json
{
  "detections": [
    {"class": "person", "score": 0.85, "zone": "mid", "side": "left"},
    {"class": "stairs", "score": 0.90, "zone": "near", "side": "center"}
  ],
  "profile_hint": "wheelchair"
}
```

**Réponse** :
```json
[
  {
    "summary": "Personne à proximité",
    "attributes": {"zone": "mid", "side": "left", "score": "0.85"},
    "risks": [],
    "class_name": "person",
    "zone": "mid",
    "side": "left"
  },
  {
    "summary": "Escalier",
    "attributes": {"zone": "near", "side": "center", "score": "0.90"},
    "risks": ["Obstacle proche", "Prévoir montée/descente"],
    "class_name": "stairs",
    "zone": "near",
    "side": "center"
  }
]
```

---

### Conseil personnalisé

#### `POST /api/guidance/advise`

Génère des consignes vocales/haptiques personnalisées selon le profil et les détections.

**Body** :
```json
{
  "profile": "string (obligatoire)",
  "context": "string (obligatoire)",
  "detections": [
    {"class": "string", "score": "float", "zone": "string", "side": "string"}
  ],
  "enrichments": [
    {"summary": "string", "risks": ["string"]}
  ]
}
```

**Exemple** :
```bash
curl -X POST http://localhost:8000/api/guidance/advise \
  -H "Content-Type: application/json" \
  -d '{
    "profile": "wheelchair",
    "context": "supermarket",
    "detections": [
      {"class": "person", "score": 0.9, "zone": "near", "side": "left"}
    ],
    "enrichments": []
  }'
```

**Réponse** :
```json
{
  "priority": "high",
  "channel": ["voice", "haptic"],
  "messages": [
    "Obstacle person left, ralentir"
  ]
}
```

**Valeurs de priorité** :
- `info` : Aucun obstacle critique
- `high` : Obstacle proche détecté

**Canaux de sortie** :
- `voice` : Message vocal (toujours présent)
- `haptic` : Vibration (ajouté si priorité high)

---

### Gestion des réservations PMR

#### `POST /api/reservations`

Crée une nouvelle réservation de transport PMR.

**Body** :
```json
{
  "origin": "Gare de Lyon, Paris",
  "destination": "Aéroport CDG Terminal 2",
  "datetime_utc": "2024-12-15T14:30:00Z",
  "passenger": {
    "name": "Jean Dupont",
    "pmr_profile": "fauteuil électrique"
  }
}
```

**Réponse (200 OK)** :
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "origin": "Gare de Lyon, Paris",
  "destination": "Aéroport CDG Terminal 2",
  "datetime_utc": "2024-12-15T14:30:00Z",
  "passenger": {
    "name": "Jean Dupont",
    "pmr_profile": "fauteuil électrique"
  },
  "status": "pending"
}
```

#### `GET /api/reservations`

Liste toutes les réservations.

**Réponse** :
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "origin": "Gare de Lyon",
    "destination": "CDG",
    "datetime_utc": "2024-12-15T14:30:00Z",
    "passenger": {...},
    "status": "pending"
  }
]
```

#### `GET /api/reservations/{reservation_id}`

Récupère une réservation spécifique.

**Erreur 404** :
```json
{
  "detail": "Reservation not found"
}
```

---

## Codes d'erreur

| Code HTTP | Signification |
|-----------|---------------|
| 200 | Succès |
| 400 | Requête malformée |
| 404 | Ressource non trouvée |
| 422 | Erreur de validation Pydantic |
| 500 | Erreur serveur (clé API manquante, service externe down) |

## Documentation interactive

L'API expose une documentation Swagger interactive à :
- **Swagger UI** : `http://localhost:8000/docs`
- **ReDoc** : `http://localhost:8000/redoc`
- **OpenAPI JSON** : `http://localhost:8000/openapi.json`
