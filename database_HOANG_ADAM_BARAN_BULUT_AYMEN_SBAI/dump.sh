#!/usr/bin/env bash
# =============================================================================
# Vision360 - Génération d'un export DUMP de la base PostgreSQL
# =============================================================================
# Régénère database/vision360_dump.sql depuis le conteneur PostgreSQL en cours
# d'exécution. À relancer après toute modification du schéma
# (backend/app/models.py) pour que le dump livré reste à jour.
#
# Usage :
#   ./database/dump.sh                    # dump structure + données
#   ./database/dump.sh --schema-only      # structure seule
#   ./database/dump.sh --data-only        # données seules
#   ./database/dump.sh --custom           # format binaire .dump (pg_restore)
#
# Prérequis : la stack doit tourner (docker compose up -d)
# =============================================================================

set -euo pipefail

# Répertoire de ce script, quel que soit l'endroit d'où il est appelé
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Paramètres de connexion : surchargeables par variables d'environnement
CONTAINER="${PG_CONTAINER:-vision360_db}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_NAME="${POSTGRES_DB:-vision360}"

# Options communes :
#   --no-owner       : le dump est restaurable par n'importe quel rôle
#   --no-privileges  : pas de GRANT/REVOKE liés à notre environnement
PG_OPTS=(--no-owner --no-privileges)
OUTPUT="$SCRIPT_DIR/vision360_dump.sql"
MODE="complet (structure + données)"

case "${1:-}" in
    --schema-only)
        PG_OPTS+=(--schema-only)
        OUTPUT="$SCRIPT_DIR/vision360_schema.sql"
        MODE="structure seule"
        ;;
    --data-only)
        # --column-inserts : génère des INSERT lisibles au lieu de COPY,
        # plus faciles à relire dans un rapport
        PG_OPTS+=(--data-only --column-inserts)
        OUTPUT="$SCRIPT_DIR/vision360_data.sql"
        MODE="données seules"
        ;;
    --custom)
        # Format binaire compressé, restauré avec pg_restore
        PG_OPTS+=(--format=custom)
        OUTPUT="$SCRIPT_DIR/vision360.dump"
        MODE="binaire (pg_restore)"
        ;;
    "")
        ;;
    *)
        echo "Option inconnue : $1" >&2
        echo "Options valides : --schema-only | --data-only | --custom" >&2
        exit 1
        ;;
esac

# Le conteneur doit être démarré, sinon pg_dump n'a rien à interroger
if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    echo "ERREUR : le conteneur '$CONTAINER' n'est pas démarré." >&2
    echo "Lancer d'abord : docker compose up -d postgres" >&2
    exit 1
fi

echo "Export $MODE de la base '$DB_NAME'..."
docker exec "$CONTAINER" pg_dump -U "$DB_USER" -d "$DB_NAME" "${PG_OPTS[@]}" > "$OUTPUT"

echo "Terminé : $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"

# Un dump de base vide est un cas normal pour ce projet : aucun compte n'est
# créé par défaut. On le signale pour éviter de croire à un export raté.
# Le format custom est binaire : on ne peut pas l'inspecter ainsi.
if [[ "${1:-}" != "--custom" ]]; then
    # Compte les lignes de données : soit des INSERT, soit le contenu d'un
    # bloc COPY (entre "FROM stdin;" et le "\." de fin).
    rows=$(awk '
        /FROM stdin;$/ { in_copy = 1; next }
        in_copy && /^\\\.$/ { in_copy = 0; next }
        in_copy { n++ }
        /^INSERT INTO / { n++ }
        END { print n + 0 }
    ' "$OUTPUT")

    if [[ "$rows" -eq 0 ]]; then
        echo "Note : 0 ligne de données exportée."
        echo "       C'est le comportement attendu tant qu'aucun utilisateur n'est inscrit."
        echo "       Jeu d'essai disponible : database/02_seed_demo.sql"
    else
        echo "$rows ligne(s) de données exportée(s)."
    fi
fi
