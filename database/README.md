# Base de données Vision360 — Exports DUMP et scripts de création

Ce dossier contient **tout ce qui est nécessaire pour recréer la base de données
du projet Vision360 à partir de zéro**, sans dépendre d'aucun service en ligne.

---

## Contenu du dossier

| Fichier | Rôle |
|---|---|
| [`01_schema.sql`](01_schema.sql) | **Script de création** : types énumérés, 7 tables, contraintes, index. Commenté ligne à ligne. |
| [`vision360_dump.sql`](vision360_dump.sql) | **Export DUMP** au format `pg_dump` plain : structure + données. |
| [`02_seed_demo.sql`](02_seed_demo.sql) | Jeu d'essai facultatif : 1 utilisateur complet pour démontrer le modèle. |
| [`99_reset.sql`](99_reset.sql) | Suppression de toutes les tables et de tous les types (remise à zéro). |
| [`dump.sh`](dump.sh) | Régénère un export depuis le conteneur PostgreSQL en cours. |
| [`restore.sh`](restore.sh) | Restaure un export dans le conteneur PostgreSQL. |

---

## Pourquoi le dump est-il vide ?

**C'est normal, et c'est l'état réel de l'application.**

Vision360 ne crée **aucun compte par défaut** : ni administrateur, ni utilisateur
de test, ni donnée de référence. La totalité du contenu de la base naît de
l'inscription d'un utilisateur réel via `POST /api/users/register`, puis, en
cascade, de ses actions dans l'application :

```
inscription  ──▶  users
   │
   ├─ configuration du profil  ──▶  profiles
   ├─ déclaration allergies    ──▶  allergies
   ├─ déclaration pathologies  ──▶  conditions
   ├─ « je n'aime pas X »      ──▶  preferences
   ├─ analyse d'une photo      ──▶  interactions
   └─ notation d'un conseil    ──▶  feedback
```

Aucun compte n'ayant été créé sur l'environnement exporté, les sept tables
comptent **0 ligne**. Le dump reflète donc fidèlement la réalité :
**la structure est complète, les données sont vides**.

Ce choix est aussi un choix de conformité : les tables `allergies` et
`conditions` contiennent des **données de santé**, catégorie particulière au
sens du RGPD. Livrer un dump peuplé de vraies données de santé serait une
mauvaise pratique. Le jeu d'essai [`02_seed_demo.sql`](02_seed_demo.sql) est
fourni pour cette raison : il contient des données **entièrement fictives**.

> **Pour voir la base peuplée**, exécuter `02_seed_demo.sql` (voir plus bas) ou
> simplement créer un compte depuis l'interface web.

---

## Le schéma en un coup d'œil

```
                          ┌──────────────┐
                          │    users     │  ← racine du modèle
                          │──────────────│
                          │ id (PK)      │
                          │ email (UQ)   │
                          │ password_hash│
                          └──────┬───────┘
                                 │ 1
          ┌───────────┬──────────┼──────────┬─────────────┐
          │ 1         │ N        │ N        │ N           │ N
   ┌──────▼──────┐ ┌──▼───────┐ ┌▼─────────┐ ┌───────────▼──┐ ┌──────────────┐
   │  profiles   │ │allergies │ │conditions│ │ preferences  │ │ interactions │
   │─────────────│ │──────────│ │──────────│ │──────────────│ │──────────────│
   │ mobility    │ │ allergen │ │condition │ │ category     │ │ context      │
   │ vision_level│ │ severity │ │ severity │ │ item_name    │ │ image_hash   │
   │ tts_*       │ │ source   │ │dietary_  │ │ sentiment    │ │ groq_response│
   │ high_contra.│ │ notes    │ │  impact  │ │ confidence   │ │ recommend... │
   └─────────────┘ └──────────┘ └──────────┘ └──────────────┘ └──────┬───────┘
                                                                     │ 1
                                                              ┌──────▼───────┐
                                                              │   feedback   │
                                                              │──────────────│
                                                              │ rating       │
                                                              │ was_helpful  │
                                                              └──────────────┘
```

| Table | Cardinalité | Rôle |
|---|---|---|
| `users` | — | Comptes (email + empreinte SHA-256 du mot de passe) |
| `profiles` | 1–1 | Profil PMR : mobilité, vision, synthèse vocale, contraste |
| `allergies` | 1–N | Allergènes ; déclenchent les alertes de sécurité au scan |
| `conditions` | 1–N | Pathologies à impact alimentaire (diabète, hypertension…) |
| `preferences` | 1–N | Ce que l'utilisateur aime / refuse, avec un indice de confiance |
| `interactions` | 1–N | Historique image → Gemini → Groq, réponses brutes en JSON |
| `feedback` | 1–1 avec `interactions` | Notation d'une recommandation, boucle d'apprentissage |

La description détaillée colonne par colonne se trouve dans
[`../docs/DATABASE.md`](../docs/DATABASE.md).

---

## Point technique important : les libellés ENUM sont en MAJUSCULES

SQLAlchemy, lorsqu'on lui passe une énumération Python, persiste le **nom** du
membre et non sa valeur :

```python
class MobilityType(str, enum.Enum):
    FAUTEUIL = "fauteuil"   # ← "fauteuil" côté Python
```

```sql
INSERT INTO profiles (mobility) VALUES ('FAUTEUIL');  -- ← 'FAUTEUIL' côté base
```

Les scripts de ce dossier respectent cette convention. **Ne pas la modifier** :
mettre les libellés en minuscules casserait la lecture des lignes par l'ORM.

---

## Recréer la base

### Méthode 1 — Automatique via Docker (recommandée)

Rien à faire. Le fichier `01_schema.sql` est monté dans
`/docker-entrypoint-initdb.d/` par [`../docker-compose.yml`](../docker-compose.yml)
et **PostgreSQL l'exécute tout seul au premier démarrage** du conteneur :

```bash
docker compose up -d
```

Vérification :

```bash
docker compose exec postgres psql -U postgres -d vision360 -c "\dt"
```

> Le script d'init n'est joué **qu'une seule fois**, quand le volume de données
> est vide. Pour le rejouer : `docker compose down -v && docker compose up -d`.

En complément, le backend appelle `Base.metadata.create_all()` au démarrage :
si une table venait à manquer, elle serait créée automatiquement. Les deux
mécanismes sont compatibles (`create_all` ignore les tables déjà présentes).

### Méthode 2 — Restaurer le dump manuellement

```bash
docker compose up -d postgres
./database/restore.sh
```

Ou sans le script :

```bash
docker compose exec -T postgres psql -U postgres -d vision360 < database/vision360_dump.sql
```

### Méthode 3 — PostgreSQL installé en local (sans Docker)

```bash
createdb -U postgres vision360
psql -U postgres -d vision360 -f database/01_schema.sql
```

---

## Charger le jeu d'essai de démonstration

```bash
./database/restore.sh --with-demo
```

Ou directement :

```bash
docker compose exec -T postgres psql -U postgres -d vision360 < database/02_seed_demo.sql
```

Compte créé :

| Champ | Valeur |
|---|---|
| Email | `demo@vision360.fr` |
| Mot de passe | `Vision360!` |

Le jeu d'essai contient 1 utilisateur, 1 profil (fauteuil + malvoyant),
2 allergies (dont une mortelle), 1 condition médicale, 4 préférences,
1 interaction IA complète et 1 feedback — de quoi exercer chaque table et
chaque type énuméré du modèle.

---

## Régénérer un export

Après toute modification de `backend/app/models.py`, régénérer le dump livré :

```bash
./database/dump.sh                 # structure + données -> vision360_dump.sql
./database/dump.sh --schema-only   # structure seule    -> vision360_schema.sql
./database/dump.sh --data-only     # données seules     -> vision360_data.sql
./database/dump.sh --custom        # binaire compressé  -> vision360.dump
```

Équivalent manuel :

```bash
docker compose exec postgres pg_dump -U postgres -d vision360 --no-owner --no-privileges > database/vision360_dump.sql
```

Le format `--custom` se restaure avec `pg_restore` et non `psql` :

```bash
docker compose exec -T postgres pg_restore -U postgres -d vision360 --clean < database/vision360.dump
```

---

## Remettre la base à zéro

```bash
# Option A : vider la base sans détruire le conteneur
docker compose exec -T postgres psql -U postgres -d vision360 < database/99_reset.sql
docker compose exec -T postgres psql -U postgres -d vision360 < database/01_schema.sql

# Option B : repartir d'un volume totalement neuf (le schéma est rejoué seul)
docker compose down -v
docker compose up -d
```

---

## Vérifications utiles

```bash
# Ouvrir une session psql interactive
docker compose exec postgres psql -U postgres -d vision360
```

```sql
\dt                              -- 7 tables attendues
\dT                              -- 7 types énumérés attendus
\d preferences                   -- structure détaillée d'une table
\di                              -- liste des index

-- Nombre de lignes par table
SELECT 'users' AS "table", COUNT(*) FROM users
UNION ALL SELECT 'profiles',     COUNT(*) FROM profiles
UNION ALL SELECT 'allergies',    COUNT(*) FROM allergies
UNION ALL SELECT 'conditions',   COUNT(*) FROM conditions
UNION ALL SELECT 'preferences',  COUNT(*) FROM preferences
UNION ALL SELECT 'interactions', COUNT(*) FROM interactions
UNION ALL SELECT 'feedback',     COUNT(*) FROM feedback;
```

---

## Dépannage

| Symptôme | Cause | Solution |
|---|---|---|
| `type "mobilitytype" already exists` | Schéma déjà en place | Jouer `99_reset.sql` avant, ou `docker compose down -v` |
| `relation "users" already exists` | Idem | Idem |
| Le script d'init n'est pas joué | Le volume contient déjà des données | `docker compose down -v && docker compose up -d` |
| `invalid input value for enum` | Libellé en minuscules | Utiliser les MAJUSCULES (voir section ENUM ci-dessus) |
| `could not connect to server` | PostgreSQL pas encore prêt | Attendre le healthcheck : `docker compose ps` |
| `permission denied` sur `.sh` | Bit exécutable absent | `chmod +x database/*.sh` |

---

## Voir aussi

- [`../docs/INSTALLATION_LINUX.md`](../docs/INSTALLATION_LINUX.md) — installation et déploiement complets sous Linux
- [`../docs/DATABASE.md`](../docs/DATABASE.md) — dictionnaire de données détaillé
- [`../backend/app/models.py`](../backend/app/models.py) — modèles SQLAlchemy, source de vérité du schéma
