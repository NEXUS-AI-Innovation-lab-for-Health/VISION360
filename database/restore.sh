#!/usr/bin/env bash
# =============================================================================
# Vision360 - Restauration de la base PostgreSQL depuis un dump
# =============================================================================
# Recrée la structure (et les données si le dump en contient) dans le
# conteneur PostgreSQL de la stack docker-compose.
#
# Usage :
#   ./database/restore.sh                          # restaure vision360_dump.sql
#   ./database/restore.sh mon_export.sql           # restaure un autre fichier
#   ./database/restore.sh --with-demo              # dump + jeu d'essai de démo
#
# Prérequis : la stack doit tourner (docker compose up -d postgres)
#
# ATTENTION : si les tables existent déjà, psql renverra des erreurs
# "already exists". Réinitialiser d'abord avec 99_reset.sql, ou repartir
# d'un volume neuf avec : docker compose down -v && docker compose up -d
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONTAINER="${PG_CONTAINER:-vision360_db}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_NAME="${POSTGRES_DB:-vision360}"

WITH_DEMO=0
DUMP_FILE="$SCRIPT_DIR/vision360_dump.sql"

if [[ "${1:-}" == "--with-demo" ]]; then
    WITH_DEMO=1
elif [[ -n "${1:-}" ]]; then
    DUMP_FILE="$1"
fi

if [[ ! -f "$DUMP_FILE" ]]; then
    echo "ERREUR : fichier introuvable : $DUMP_FILE" >&2
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    echo "ERREUR : le conteneur '$CONTAINER' n'est pas démarré." >&2
    echo "Lancer d'abord : docker compose up -d postgres" >&2
    exit 1
fi

echo "Restauration de $(basename "$DUMP_FILE") dans la base '$DB_NAME'..."
docker exec -i "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 < "$DUMP_FILE"

if [[ "$WITH_DEMO" -eq 1 ]]; then
    echo "Chargement du jeu d'essai de démonstration..."
    docker exec -i "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 \
        < "$SCRIPT_DIR/02_seed_demo.sql"
    echo "Compte de démonstration : demo@vision360.fr / Vision360!"
fi

echo
echo "Contenu de la base après restauration :"
docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT 'users' AS \"table\", COUNT(*) AS lignes FROM users
UNION ALL SELECT 'profiles',     COUNT(*) FROM profiles
UNION ALL SELECT 'allergies',    COUNT(*) FROM allergies
UNION ALL SELECT 'conditions',   COUNT(*) FROM conditions
UNION ALL SELECT 'preferences',  COUNT(*) FROM preferences
UNION ALL SELECT 'interactions', COUNT(*) FROM interactions
UNION ALL SELECT 'feedback',     COUNT(*) FROM feedback;
"
