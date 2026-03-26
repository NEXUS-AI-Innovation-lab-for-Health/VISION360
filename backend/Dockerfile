# =============================================================================
# Dockerfile Backend Vision360
# =============================================================================
# Image de production pour l'API FastAPI
# Build : docker build -t vision360-backend -f backend/Dockerfile .
# Run   : docker run -p 8000:8000 --env-file .env vision360-backend
# =============================================================================

# -----------------------------------------------------------------------------
# Image de base : Python 3.12 slim (Debian)
# Slim réduit la taille de l'image tout en gardant les outils essentiels
# -----------------------------------------------------------------------------
FROM python:3.12-slim

# -----------------------------------------------------------------------------
# Configuration du répertoire de travail
# -----------------------------------------------------------------------------
WORKDIR /app

# -----------------------------------------------------------------------------
# Variables d'environnement Python
# -----------------------------------------------------------------------------
# PYTHONDONTWRITEBYTECODE : Évite la création de fichiers .pyc
# PYTHONUNBUFFERED : Force la sortie stdout/stderr en temps réel (logs Docker)
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# -----------------------------------------------------------------------------
# Installation des dépendances Python
# Copie requirements.txt d'abord pour profiter du cache Docker
# -----------------------------------------------------------------------------
COPY backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# -----------------------------------------------------------------------------
# Copie du code source
# -----------------------------------------------------------------------------
# Application principale
COPY backend/app ./app
# Tests (optionnel, utile pour CI/CD)
COPY backend/tests ./tests

# -----------------------------------------------------------------------------
# Configuration réseau
# Port 8000 exposé pour l'API
# -----------------------------------------------------------------------------
EXPOSE 8000

# -----------------------------------------------------------------------------
# Commande de démarrage
# - Utilise la variable PORT si définie (Cloud Run), sinon 8000
# - Host 0.0.0.0 pour accepter les connexions externes
# -----------------------------------------------------------------------------
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
