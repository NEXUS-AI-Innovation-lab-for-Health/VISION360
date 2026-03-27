"""
Module de configuration de la base de données.

Ce module configure la connexion à PostgreSQL avec SQLAlchemy,
et définit la session de base de données.
"""

import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# URL de connexion à la base de données
# Format : postgresql://user:password@host:port/database
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:postgres@localhost:5432/vision360"
)

# Pour SQLite en développement (plus simple, pas besoin de PostgreSQL)
# DATABASE_URL = "sqlite:///./vision360.db"

# Création du moteur SQLAlchemy
engine = create_engine(
    DATABASE_URL,
    # echo=True  # Décommenter pour voir les requêtes SQL (debug)
)

# Session locale pour les requêtes
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Classe de base pour les modèles
Base = declarative_base()


def get_db():
    """
    Générateur de session de base de données.

    Utilisé comme dépendance FastAPI pour injecter
    la session dans les endpoints.

    Yields:
        Session: Session SQLAlchemy
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """
    Initialise la base de données.

    Crée toutes les tables définies dans les modèles.
    À appeler au démarrage de l'application.
    """
    Base.metadata.create_all(bind=engine)
