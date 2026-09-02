-- =============================================================================
-- Vision360 - Réinitialisation complète de la base
-- =============================================================================
-- ATTENTION : ce script SUPPRIME toutes les tables, tous les types et toutes
-- les données de la base vision360. Il est irréversible.
--
-- Usage typique : repartir d'une base propre sans détruire le conteneur Docker.
--
--   psql -U postgres -d vision360 -f 99_reset.sql
--   psql -U postgres -d vision360 -f 01_schema.sql
--
-- Ou dans Docker :
--   docker compose exec -T postgres psql -U postgres -d vision360 < 99_reset.sql
--   docker compose exec -T postgres psql -U postgres -d vision360 < 01_schema.sql
--
-- Alternative plus radicale (détruit aussi le volume Docker) :
--   docker compose down -v
-- =============================================================================

BEGIN;

-- L'ordre importe peu grâce à CASCADE, mais on respecte quand même
-- l'inverse de l'ordre de création pour rester lisible.
DROP TABLE IF EXISTS feedback     CASCADE;
DROP TABLE IF EXISTS interactions CASCADE;
DROP TABLE IF EXISTS preferences  CASCADE;
DROP TABLE IF EXISTS conditions   CASCADE;
DROP TABLE IF EXISTS allergies    CASCADE;
DROP TABLE IF EXISTS profiles     CASCADE;
DROP TABLE IF EXISTS users        CASCADE;

-- Les types énumérés ne sont pas supprimés par le DROP TABLE :
-- sans cette étape, un nouveau 01_schema.sql échouerait sur
-- "type mobilitytype already exists".
DROP TYPE IF EXISTS contexttype        CASCADE;
DROP TYPE IF EXISTS preferencesource   CASCADE;
DROP TYPE IF EXISTS sentiment          CASCADE;
DROP TYPE IF EXISTS preferencecategory CASCADE;
DROP TYPE IF EXISTS severity           CASCADE;
DROP TYPE IF EXISTS visionlevel        CASCADE;
DROP TYPE IF EXISTS mobilitytype       CASCADE;

COMMIT;

-- Vérification : les deux requêtes doivent renvoyer 0 ligne.
--   \dt
--   \dT
