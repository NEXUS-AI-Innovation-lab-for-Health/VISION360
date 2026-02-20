"""
Module principal de l'API Vision360.

Ce module configure et initialise l'application FastAPI, incluant :
- Le chargement des variables d'environnement
- La configuration du middleware CORS
- L'enregistrement des routes (guidance, describe)

L'API sert de passerelle entre les applications clientes (mobile, web)
et les services d'IA externes (Gemini, Groq).
"""

import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse


def _load_env_file():
    """
    Charge les variables d'environnement depuis un fichier .env.

    Recherche les fichiers dans l'ordre de priorité suivant :
    1. .env à la racine du repository
    2. .env dans le dossier backend
    3. .env.example à la racine (fallback)
    4. .env.example dans le dossier backend (fallback)

    Les variables sont chargées dans os.environ pour être accessibles
    par les autres modules (describe.py, guidance.py).
    """
    here = Path(__file__).resolve()
    candidates = [
        here.parent.parent.parent / ".env",          # racine du repo
        here.parent.parent / ".env",                 # dossier backend
        here.parent.parent.parent / ".env.example",  # fallback exemple racine
        here.parent.parent / ".env.example",         # fallback exemple backend
    ]
    env_path = next((p for p in candidates if p.exists()), None)
    if not env_path:
        return
    for line in env_path.read_text(encoding="utf-8").splitlines():
        # Ignorer les lignes vides et les commentaires
        if not line or line.strip().startswith("#") or "=" not in line:
            continue
        key, val = line.split("=", 1)
        os.environ[key.strip()] = val.strip()


# Charger l'environnement AVANT d'importer les routes
# car elles utilisent os.getenv() au niveau module
_load_env_file()

# Import des routers après le chargement des variables d'environnement
from .guidance import router as guidance_router
from .describe import router as describe_router
from .users import router as users_router
from .database import init_db

# Création de l'application FastAPI avec métadonnées
app = FastAPI(
    title="Vision360 API",
    description="API d'assistance IA pour personnes à mobilité réduite",
    version="1.0.0",
)


@app.on_event("startup")
def startup_event():
    """
    Événement de démarrage de l'application.

    Initialise la base de données en créant toutes les tables
    si elles n'existent pas encore.
    """
    init_db()

# Configuration CORS permissive pour le développement
# Permet à toutes les origines d'accéder à l'API
# Note: À restreindre en production avec les domaines autorisés
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],              # Toutes origines autorisées
    allow_origin_regex=".*",          # Pattern regex de fallback
    allow_credentials=False,          # Doit rester False avec allow_origins="*"
    allow_methods=["*"],              # Toutes méthodes HTTP autorisées
    allow_headers=["*"],              # Tous headers autorisés
    expose_headers=["*"],             # Tous headers exposés au client
    max_age=86400,                    # Cache preflight 24h
)


@app.middleware("http")
async def add_cors_headers(request, call_next):
    """
    Middleware HTTP ajoutant les headers CORS à toutes les réponses.

    Gère spécifiquement les requêtes OPTIONS (preflight) en retournant
    une réponse vide avec les headers CORS appropriés.

    Ce middleware agit en complément du CORSMiddleware standard pour
    garantir que les headers sont présents dans tous les cas.

    Args:
        request: Requête HTTP entrante
        call_next: Fonction pour passer au middleware suivant

    Returns:
        JSONResponse pour OPTIONS, ou réponse enrichie de headers CORS
    """
    # Gestion des requêtes preflight (OPTIONS)
    if request.method == "OPTIONS":
        return JSONResponse(
            status_code=200,
            content={"status": "ok"},
            headers={
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
                "Access-Control-Allow-Headers": "*",
                "Access-Control-Expose-Headers": "*",
                "Access-Control-Max-Age": "86400",
            },
        )

    # Exécuter la requête normale
    response = await call_next(request)

    # Ajouter les headers CORS si non présents
    response.headers.setdefault("Access-Control-Allow-Origin", "*")
    response.headers.setdefault("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
    response.headers.setdefault("Access-Control-Allow-Headers", "*")
    response.headers.setdefault("Access-Control-Expose-Headers", "*")
    response.headers.setdefault("Access-Control-Max-Age", "86400")
    return response


@app.get("/health")
def health():
    """
    Endpoint de vérification de l'état du service.

    Utilisé par les systèmes de monitoring et les health checks
    Docker/Kubernetes pour vérifier que l'API est opérationnelle.

    Returns:
        dict: {"status": "ok"} si le service fonctionne
    """
    return {"status": "ok"}


# Enregistrement des routes avec leurs préfixes
# - /api/guidance/* : Enrichissement des détections et conseils
# - /api/* : Endpoints Gemini et Groq pour description d'images
# - /api/users/* : Gestion utilisateurs, profils, préférences
app.include_router(guidance_router, prefix="/api/guidance", tags=["guidance"])
app.include_router(describe_router, prefix="/api", tags=["describe"])
app.include_router(users_router, prefix="/api/users", tags=["users"])
