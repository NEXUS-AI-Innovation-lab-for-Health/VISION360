# 📦 Guide d'Installation - Vision360

Ce guide détaille l'installation complète du projet Vision360, que ce soit via Docker (recommandé) ou manuellement.

> ### 📌 À lire en premier
>
> **L'infrastructure Google Cloud Run du projet a été supprimée** (comptes fermés
> pour éviter toute facturation). L'URL `https://vision360-backend-...run.app`
> ne répond donc plus.
>
> Le projet fonctionne à l'identique en local : il suffit de **recréer les
> conteneurs Docker**, de **créer ses propres clés d'API gratuites** (Gemini et
> Groq) et de **relier le client au backend local**. Aucune modification de code
> n'est nécessaire.
>
> 👉 **Procédure pas à pas sous Linux : [INSTALLATION_LINUX.md](INSTALLATION_LINUX.md)**
> 👉 **Base de données (dump + scripts de création) : [../database/README.md](../database/README.md)**

## Prérequis

### Obligatoires

| Outil | Version | Usage |
|-------|---------|-------|
| Git | 2.x+ | Clonage du repository |
| Docker | 20.x+ | Conteneurisation (méthode recommandée) |
| Docker Compose | 2.x+ | Orchestration des services |

### Pour installation manuelle

| Outil | Version | Usage |
|-------|---------|-------|
| Python | 3.12+ | Backend API |
| Node.js | 20+ | Application web Next.js |
| Flutter | 3.6+ | Application mobile |

### Clés API requises

| Service | Variable | Obtention |
|---------|----------|-----------|
| Google Gemini | `GEMINI_API_KEY` | [Google AI Studio](https://aistudio.google.com/apikey) |
| Groq | `GROQ_API_KEY` | [Groq Console](https://console.groq.com/keys) |

## Installation avec Docker (Recommandé)

### Étape 1 : Cloner le repository

```bash
git clone https://github.com/votre-repo/SAE-VISION360.git
cd SAE-VISION360
```

### Étape 2 : Configurer les variables d'environnement

```bash
# Copier le fichier exemple
cp .env.example .env

# Éditer avec vos clés API
nano .env  # ou code .env, vim .env, etc.
```

Contenu minimal du `.env` :
```env
GEMINI_API_KEY=votre_clé_gemini
GROQ_API_KEY=votre_clé_groq
```

### Étape 3 : Lancer les services

```bash
# Construction et démarrage
docker compose up --build

# Ou en arrière-plan
docker compose up -d --build
```

### Étape 4 : Vérifier l'installation

| Service | URL | Vérification |
|---------|-----|--------------|
| Backend API | http://localhost:8000/health | `{"status": "ok"}` |
| Documentation API | http://localhost:8000/docs | Swagger UI |
| Web Next.js | http://localhost:3000 | Interface web |

### Commandes utiles

```bash
# Voir les logs
docker compose logs -f

# Arrêter les services
docker compose down

# Reconstruire un service spécifique
docker compose build backend
docker compose up -d backend
```

## Installation manuelle

### Backend Python

#### 1. Environnement virtuel

```bash
cd backend

# Créer l'environnement virtuel
python -m venv venv

# Activer (Linux/macOS)
source venv/bin/activate

# Activer (Windows)
.\venv\Scripts\activate
```

#### 2. Dépendances

```bash
pip install -r requirements.txt
```

#### 3. Variables d'environnement

```bash
# Linux/macOS
export GEMINI_API_KEY="votre_clé"
export GROQ_API_KEY="votre_clé"

# Windows PowerShell
$env:GEMINI_API_KEY="votre_clé"
$env:GROQ_API_KEY="votre_clé"
```

Ou créer un fichier `.env` à la racine du projet.

#### 4. Lancer le serveur

```bash
# Développement (hot reload)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Production
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Application Web Next.js

#### 1. Installation des dépendances

```bash
cd web_next
npm install
```

#### 2. Configuration

```bash
# Créer le fichier d'environnement local
echo "NEXT_PUBLIC_API_BASE=http://localhost:8000/api" > .env.local
```

#### 3. Lancer le serveur

```bash
# Développement
npm run dev

# Production
npm run build
npm run start
```

Accéder à http://localhost:3000

### Application Mobile Flutter

#### 1. Prérequis Flutter

```bash
# Vérifier l'installation
flutter doctor

# Installer les dépendances si nécessaire
# Android : Android Studio + SDK
# iOS : Xcode (macOS uniquement)
```

#### 2. Installation des packages

```bash
cd mobile_flutter
flutter pub get
```

#### 3. Configuration API

Dans `lib/main.dart`, modifier l'URL de base si nécessaire :
```dart
final TextEditingController _apiBaseController = TextEditingController(
  text: 'http://10.0.2.2:8000/api',  // Android émulateur
  // text: 'http://localhost:8000/api',  // iOS simulateur
);
```

#### 4. Lancer l'application

```bash
# Lister les devices disponibles
flutter devices

# Lancer sur un device
flutter run

# Lancer en mode release
flutter run --release
```

### POC Web TensorFlow.js

Aucune installation requise, uniquement un serveur HTTP statique.

```bash
cd poc-web

# Option 1 : Python
python -m http.server 8080

# Option 2 : Node.js
npx serve .

# Option 3 : PHP
php -S localhost:8080
```

Accéder à http://localhost:8080

## Vérification de l'installation

### Test du backend

```bash
# Health check
curl http://localhost:8000/health

# Test Gemini (nécessite une image base64)
curl -X POST http://localhost:8000/api/describe/gemini \
  -H "Content-Type: application/json" \
  -d '{"image_b64": "...", "prompt": "Décris cette image"}'
```

### Tests unitaires

```bash
cd backend
pytest tests/ -v
```

## Dépannage

### Erreur : "GEMINI_API_KEY manquante"

**Cause** : Variable d'environnement non définie.

**Solution** :
1. Vérifier le fichier `.env`
2. Redémarrer les conteneurs Docker
3. Vérifier avec `docker compose config`

### Erreur CORS dans le navigateur

**Cause** : Le backend n'accepte pas l'origine de la requête.

**Solution** :
Le middleware CORS est configuré pour accepter toutes les origines en développement.
Vérifier que le backend est bien démarré sur le bon port.

### Flutter : "Camera not available"

**Cause** : Permissions non accordées ou émulateur sans caméra.

**Solutions** :
- Sur device physique : Autoriser la caméra dans les paramètres
- Sur émulateur Android : Utiliser un émulateur avec caméra virtuelle
- Sur iOS : Ajouter les clés `NSCameraUsageDescription` dans `Info.plist`

### Docker : "Port already in use"

**Cause** : Un autre service utilise le port 8000 ou 3000.

**Solution** :
```bash
# Trouver le processus
lsof -i :8000

# Modifier les ports dans docker-compose.yml
ports:
  - "8001:8000"  # Utiliser le port 8001
```

## Configuration avancée

### Variables d'environnement complètes

Voir [.env.example](../.env.example) pour la liste complète des variables configurables.

### Déploiement production

Voir [docs/DEPLOYMENT.md](DEPLOYMENT.md) pour les instructions de déploiement sur Google Cloud Run.
