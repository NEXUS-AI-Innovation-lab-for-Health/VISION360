# 🚀 Backend Vision360

API REST FastAPI pour l'écosystème Vision360 d'assistance aux personnes à mobilité réduite.

## Description

Ce backend sert de passerelle entre les applications clientes (mobile Flutter, web Next.js) et les services d'IA externes (Google Gemini, Groq). Il fournit des endpoints pour :

- **Analyse d'images** via Google Gemini Vision
- **Génération de recommandations** personnalisées via Groq LLM
- **Enrichissement des détections** d'obstacles avec contexte PMR
- **Gestion des réservations** de transport PMR (stub)

## Structure des fichiers

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py           # Point d'entrée, configuration CORS
│   ├── describe.py       # Endpoints Gemini et Groq
│   ├── guidance.py       # Enrichissement détections, conseils
│   ├── reservations.py   # Gestion réservations PMR
│   └── user_profiles.json # Catalogue de profils utilisateur
├── tests/
│   └── test_api.py       # Tests unitaires
├── requirements.txt      # Dépendances Python
├── Dockerfile           # Image Docker production
└── README.md            # Ce fichier
```

## Endpoints API

### Health Check
| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/health` | Vérification état du service |

### Description (Gemini/Groq)
| Méthode | Endpoint | Description |
|---------|----------|-------------|
| POST | `/api/describe/gemini` | Analyse image avec Gemini Vision |
| POST | `/api/describe/groq` | Génération recommandations LLM |

### Guidance
| Méthode | Endpoint | Description |
|---------|----------|-------------|
| POST | `/api/guidance/enrich` | Enrichir une détection |
| POST | `/api/guidance/enrich/batch` | Enrichir plusieurs détections |
| POST | `/api/guidance/advise` | Générer conseils personnalisés |

### Réservations
| Méthode | Endpoint | Description |
|---------|----------|-------------|
| POST | `/api/reservations` | Créer réservation |
| GET | `/api/reservations` | Lister réservations |
| GET | `/api/reservations/{id}` | Détail réservation |

## Variables d'environnement

| Variable | Obligatoire | Description | Défaut |
|----------|-------------|-------------|--------|
| `GEMINI_API_KEY` | Oui | Clé API Google Gemini | - |
| `GROQ_API_KEY` | Oui | Clé API Groq | - |
| `GEMINI_MODEL` | Non | Modèle Gemini à utiliser | `gemini-2.0-flash-exp` |
| `GROQ_MODEL` | Non | Modèle Groq à utiliser | `llama-3.1-8b-instant` |
| `PORT` | Non | Port d'écoute (Cloud Run) | `8000` |

## Installation

### Avec Docker (Recommandé)

```bash
# Depuis la racine du projet
docker build -t vision360-backend -f backend/Dockerfile .
docker run -p 8000:8000 --env-file .env vision360-backend
```

### Manuelle

```bash
cd backend

# Créer environnement virtuel
python -m venv venv
source venv/bin/activate  # Linux/macOS
# ou .\venv\Scripts\activate  # Windows

# Installer dépendances
pip install -r requirements.txt

# Configurer variables d'environnement
export GEMINI_API_KEY="votre_clé"
export GROQ_API_KEY="votre_clé"

# Lancer le serveur
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Commandes de développement

```bash
# Lancer en mode développement (hot reload)
uvicorn app.main:app --reload

# Lancer les tests
pytest tests/ -v

# Lancer avec couverture de code
pytest tests/ --cov=app --cov-report=html

# Formater le code
black app/
isort app/

# Vérifier le typage
mypy app/
```

## Documentation API

Une fois le serveur lancé, accéder à :
- **Swagger UI** : http://localhost:8000/docs
- **ReDoc** : http://localhost:8000/redoc
- **OpenAPI JSON** : http://localhost:8000/openapi.json

## Tests

```bash
# Tous les tests
pytest tests/ -v

# Test spécifique
pytest tests/test_api.py::test_health -v

# Avec sortie détaillée
pytest tests/ -v -s
```

## Déploiement

### Google Cloud Run

```bash
# Build et push
gcloud builds submit --tag gcr.io/PROJECT_ID/vision360-backend

# Déployer
gcloud run deploy vision360-backend \
  --image gcr.io/PROJECT_ID/vision360-backend \
  --platform managed \
  --region europe-west1 \
  --allow-unauthenticated \
  --set-secrets "GEMINI_API_KEY=GEMINI_API_KEY:latest,GROQ_API_KEY=GROQ_API_KEY:latest"
```

Voir [docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md) pour plus de détails.

## Dépendances

| Package | Version | Usage |
|---------|---------|-------|
| FastAPI | 0.115.0 | Framework API REST |
| Uvicorn | 0.30.6 | Serveur ASGI |
| httpx | 0.27.2 | Client HTTP async |
| pytest | 8.3.2 | Tests unitaires |
