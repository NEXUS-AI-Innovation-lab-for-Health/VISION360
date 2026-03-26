# 🚀 Guide de Déploiement - Vision360

Ce guide couvre le déploiement de Vision360 en environnement de production.

## Options de déploiement

| Composant | Service recommandé | Alternative |
|-----------|-------------------|-------------|
| Backend API | Google Cloud Run | AWS Lambda, Heroku |
| Web Next.js | Vercel | Netlify, Cloud Run |
| Mobile | Play Store / App Store | Distribution interne |

## Déploiement Docker Local (Staging)

### Prérequis

- Docker Desktop ou Docker Engine
- Docker Compose v2+
- Fichier `.env` configuré

### Commandes

```bash
# Build et démarrage
docker compose up -d --build

# Vérification des services
docker compose ps

# Logs en temps réel
docker compose logs -f

# Arrêt
docker compose down

# Nettoyage complet (images, volumes)
docker compose down --rmi all --volumes
```

### Configuration production

Modifier `docker-compose.yml` pour la production :

```yaml
services:
  backend:
    build:
      context: .
      dockerfile: backend/Dockerfile
    ports:
      - "8000:8000"
    env_file:
      - .env
    environment:
      - PYTHONUNBUFFERED=1
    restart: always
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  web_next:
    build:
      context: ./web_next
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      - NEXT_PUBLIC_API_BASE=https://votre-domaine.com/api
    depends_on:
      backend:
        condition: service_healthy
    restart: always
```

## Déploiement Google Cloud Run

Cloud Run permet un déploiement serverless avec scaling automatique.

### Prérequis

1. Compte Google Cloud avec facturation activée
2. [gcloud CLI](https://cloud.google.com/sdk/docs/install) installé
3. Docker configuré avec Google Container Registry

### Configuration initiale

```bash
# Connexion à Google Cloud
gcloud auth login

# Sélectionner le projet
gcloud config set project VOTRE_PROJECT_ID

# Activer les APIs nécessaires
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com

# Configurer Docker pour GCR
gcloud auth configure-docker
```

### Déploiement du Backend

#### 1. Build et push de l'image

```bash
# Variables
PROJECT_ID=$(gcloud config get-value project)
IMAGE_NAME=vision360-backend
REGION=europe-west1

# Build
docker build -t gcr.io/$PROJECT_ID/$IMAGE_NAME:latest -f backend/Dockerfile .

# Push vers Google Container Registry
docker push gcr.io/$PROJECT_ID/$IMAGE_NAME:latest
```

#### 2. Déploiement sur Cloud Run

```bash
gcloud run deploy vision360-backend \
  --image gcr.io/$PROJECT_ID/$IMAGE_NAME:latest \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --port 8000 \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 10 \
  --set-env-vars "GEMINI_API_KEY=votre_clé,GROQ_API_KEY=votre_clé"
```

#### 3. Utiliser Secret Manager (recommandé)

```bash
# Créer les secrets
echo -n "votre_clé_gemini" | gcloud secrets create GEMINI_API_KEY --data-file=-
echo -n "votre_clé_groq" | gcloud secrets create GROQ_API_KEY --data-file=-

# Autoriser Cloud Run à accéder aux secrets
gcloud secrets add-iam-policy-binding GEMINI_API_KEY \
  --member=serviceAccount:PROJECT_NUMBER-compute@developer.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor

# Déployer avec secrets
gcloud run deploy vision360-backend \
  --image gcr.io/$PROJECT_ID/$IMAGE_NAME:latest \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --set-secrets "GEMINI_API_KEY=GEMINI_API_KEY:latest,GROQ_API_KEY=GROQ_API_KEY:latest"
```

### Déploiement du Web Next.js

#### Option 1 : Vercel (Recommandé)

```bash
# Installer Vercel CLI
npm i -g vercel

# Déployer
cd web_next
vercel

# Configurer la variable d'environnement
vercel env add NEXT_PUBLIC_API_BASE
# Entrer: https://vision360-backend-xxxx.run.app/api
```

#### Option 2 : Cloud Run

```bash
# Build et push
docker build -t gcr.io/$PROJECT_ID/vision360-web:latest ./web_next
docker push gcr.io/$PROJECT_ID/vision360-web:latest

# Déployer
gcloud run deploy vision360-web \
  --image gcr.io/$PROJECT_ID/vision360-web:latest \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --port 3000 \
  --set-env-vars "NEXT_PUBLIC_API_BASE=https://vision360-backend-xxxx.run.app/api"
```

## Déploiement Mobile

### Android (Play Store)

#### 1. Générer le bundle de release

```bash
cd mobile_flutter

# Créer la keystore (une seule fois)
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload

# Configurer key.properties
cat > android/key.properties << EOF
storePassword=votre_password
keyPassword=votre_password
keyAlias=upload
storeFile=/chemin/vers/upload-keystore.jks
EOF

# Build le bundle
flutter build appbundle --release
```

#### 2. Soumettre sur Play Console

1. Aller sur [Google Play Console](https://play.google.com/console)
2. Créer une application
3. Uploader `build/app/outputs/bundle/release/app-release.aab`
4. Remplir la fiche de store
5. Soumettre pour review

### iOS (App Store)

#### 1. Configurer Xcode

```bash
cd mobile_flutter/ios
pod install
open Runner.xcworkspace
```

Dans Xcode :
- Configurer le Bundle Identifier
- Configurer les signing certificates
- Configurer les capabilities (Camera, Microphone)

#### 2. Archive et distribution

```bash
flutter build ios --release
```

Puis dans Xcode : Product > Archive > Distribute App

## Configuration Production

### Variables d'environnement

| Variable | Production | Description |
|----------|------------|-------------|
| `GEMINI_API_KEY` | Secret Manager | Clé API Gemini |
| `GROQ_API_KEY` | Secret Manager | Clé API Groq |
| `GEMINI_MODEL` | `gemini-2.0-flash-exp` | Modèle Gemini |
| `GROQ_MODEL` | `llama-3.1-8b-instant` | Modèle Groq |

### CORS en production

Modifier `backend/app/main.py` pour restreindre les origines :

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://votre-domaine.com",
        "https://vision360-web-xxxx.vercel.app",
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
)
```

### Monitoring

#### Google Cloud Monitoring

```bash
# Activer Cloud Monitoring
gcloud services enable monitoring.googleapis.com

# Créer une alerte sur les erreurs
gcloud alpha monitoring policies create \
  --display-name="Vision360 Errors" \
  --condition="..."
```

#### Logs

```bash
# Voir les logs Cloud Run
gcloud run services logs read vision360-backend --region=$REGION

# Filtrer les erreurs
gcloud run services logs read vision360-backend \
  --region=$REGION \
  --filter="severity>=ERROR"
```

## Checklist pré-production

- [ ] Clés API stockées dans Secret Manager
- [ ] CORS configuré avec domaines spécifiques
- [ ] HTTPS activé (automatique sur Cloud Run)
- [ ] Monitoring et alertes configurés
- [ ] Backup des données (si applicable)
- [ ] Tests de charge effectués
- [ ] Documentation utilisateur à jour

## Coûts estimés

| Service | Usage gratuit | Coût au-delà |
|---------|--------------|--------------|
| Cloud Run | 2M requêtes/mois | $0.40/million |
| Gemini API | Gratuit (limité) | Variable selon usage |
| Groq API | Gratuit (limité) | Variable selon usage |
| Vercel | Gratuit (hobby) | $20/mois (Pro) |
