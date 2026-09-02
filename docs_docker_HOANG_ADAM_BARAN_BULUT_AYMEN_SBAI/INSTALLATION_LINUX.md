# Guide d'installation et de déploiement — Vision360 sous Linux (Docker Compose)

**Projet** : SAE Vision360 — Assistance IA pour personnes à mobilité réduite
**Formation** : BUT Informatique 3ᵉ année — SAE S5 et S6, Parcours A et C
**Cible de ce document** : machine ou serveur **Linux** (Debian, Ubuntu, Fedora, Rocky, Arch)
**Méthode** : conteneurisation intégrale via **Docker Compose**

---

## Table des matières

1. [À lire avant tout — l'infrastructure cloud a été démantelée](#1-à-lire-avant-tout--linfrastructure-cloud-a-été-démantelée)
2. [Ce que vous allez déployer](#2-ce-que-vous-allez-déployer)
3. [Prérequis](#3-prérequis)
4. [Installation de Docker sous Linux](#4-installation-de-docker-sous-linux)
5. [Récupération du projet](#5-récupération-du-projet)
6. [Obtenir vos propres clés d'API](#6-obtenir-vos-propres-clés-dapi)
7. [Configuration du fichier `.env`](#7-configuration-du-fichier-env)
8. [Lancement de la stack](#8-lancement-de-la-stack)
9. [Vérification du déploiement](#9-vérification-du-déploiement)
10. [Relier les clients au backend](#10-relier-les-clients-au-backend)
11. [Base de données](#11-base-de-données)
12. [Exploitation au quotidien](#12-exploitation-au-quotidien)
13. [Déploiement sur un serveur Linux distant](#13-déploiement-sur-un-serveur-linux-distant)
14. [Sauvegarde et restauration](#14-sauvegarde-et-restauration)
15. [Dépannage](#15-dépannage)
16. [Annexes](#16-annexes)

---

## 1. À lire avant tout — l'infrastructure cloud a été démantelée

> ### ⚠️ Point essentiel pour la personne qui évalue ou reprend ce projet
>
> Pendant le développement, le backend Vision360 tournait sur **Google Cloud
> Run**, et les modèles d'IA étaient appelés avec **nos clés personnelles**
> Gemini et Groq. Ces ressources étaient adossées à des comptes qui, une fois
> la période de crédits gratuits terminée, deviennent **facturables**.
>
> **Nous avons donc supprimé ces comptes cloud pour ne pas être prélevés.**
> C'est une décision volontaire, prise pour des raisons financières, et non un
> oubli de notre part.
>
> **Conséquence pratique : l'URL de production
> `https://vision360-backend-...run.app` ne répond plus.**

### Ce que cela change pour vous : presque rien

Le projet a été conçu dès le départ pour être **entièrement auto-hébergé avec
Docker**. Il n'y a **aucune ligne de code à modifier**, aucune dépendance à
recompiler, aucune bibliothèque propriétaire à racheter. Vous devez seulement :

| # | À faire | Durée | Détail |
|:-:|---|---|---|
| 1 | **Recréer les conteneurs Docker chez vous** | ~5 min | `docker compose up -d --build` — [section 8](#8-lancement-de-la-stack) |
| 2 | **Créer vos propres clés d'API** (gratuites) | ~3 min | Gemini + Groq — [section 6](#6-obtenir-vos-propres-clés-dapi) |
| 3 | **Relier le client au backend local** | ~30 s | Renseigner `http://localhost:8000/api` — [section 10](#10-relier-les-clients-au-backend) |

**Et c'est tout.** Aucune autre modification n'est nécessaire.

### Pourquoi le projet fonctionne quand même à l'identique

- La totalité du code applicatif (API FastAPI, base PostgreSQL, interface
  Next.js) tourne **en local dans Docker**, exactement comme en production :
  ce sont les **mêmes images**, construites à partir des **mêmes Dockerfile**.
  Cloud Run ne faisait qu'héberger cette même image.
- Les seules dépendances externes restantes sont les **API d'IA** (Gemini pour
  la vision, Groq pour le langage) et **Open Food Facts** (base produits
  ouverte, sans clé). Gemini et Groq proposent tous deux un **niveau gratuit
  suffisant** pour démontrer le projet.
- L'URL du backend est **paramétrable à l'exécution** dans l'interface web
  comme dans l'application mobile : un champ de saisie est prévu à cet effet.
  Rien n'est verrouillé.

### Un point corrigé pour vous faciliter la tâche

L'interface web avait notre ancienne URL Cloud Run comme valeur par défaut.
Nous avons donc modifié la construction de l'image Next.js pour qu'elle pointe
automatiquement vers `http://localhost:8000/api` lors d'un build Docker local
(voir [`../web_next/Dockerfile`](../web_next/Dockerfile) et le bloc `args` de
[`../docker-compose.yml`](../docker-compose.yml)).

Après `docker compose up --build`, **l'interface se connecte donc toute seule
au backend local** : vous n'avez normalement rien à saisir. La procédure
manuelle de la [section 10](#10-relier-les-clients-au-backend) reste documentée
en cas de besoin (application mobile, image reconstruite autrement, etc.).

---

## 2. Ce que vous allez déployer

Trois conteneurs orchestrés par un seul fichier `docker-compose.yml` :

```
                    Machine Linux hôte
  ┌──────────────────────────────────────────────────────────────┐
  │                                                              │
  │   :3000                :8000                :5432            │
  │  ┌────────────┐      ┌────────────┐      ┌────────────────┐  │
  │  │  web_next  │─────▶│  backend   │─────▶│    postgres    │  │
  │  │  Next.js   │      │  FastAPI   │      │ PostgreSQL 16  │  │
  │  │  React 19  │◀─────│  Python    │◀─────│   (volume      │  │
  │  │  Node 20   │      │   3.12     │      │  persistant)   │  │
  │  └────────────┘      └─────┬──────┘      └────────────────┘  │
  │                            │                                 │
  └────────────────────────────┼─────────────────────────────────┘
                               │  HTTPS sortant
                 ┌─────────────┼──────────────┐
                 ▼             ▼              ▼
          Gemini Vision    Groq LLM    Open Food Facts
          (clé requise)  (clé requise)   (sans clé)
```

| Service | Image | Port hôte | Rôle |
|---|---|:-:|---|
| `postgres` | `postgres:16-alpine` | 5432 | Profils PMR, allergies, préférences, historique |
| `backend` | construite depuis `backend/Dockerfile` | 8000 | API REST, orchestration Gemini + Groq |
| `web_next` | construite depuis `web_next/Dockerfile` | 3000 | Interface web (webcam, profil, recommandations) |

Les trois conteneurs communiquent sur un **réseau Docker privé** créé
automatiquement. Le backend joint la base par le nom d'hôte `postgres`, et non
par `localhost` : c'est la résolution DNS interne de Docker qui s'en charge.

L'application mobile Flutter et le POC TensorFlow.js ne sont pas conteneurisés
(ils s'exécutent sur le terminal de l'utilisateur) mais consomment la même API.

---

## 3. Prérequis

### Matériel et système

| Élément | Minimum | Recommandé |
|---|---|---|
| Distribution | Toute distribution avec noyau ≥ 3.10 | Ubuntu 22.04+ / Debian 12+ |
| Architecture | x86_64 ou ARM64 | x86_64 |
| RAM | 2 Go | 4 Go (le build Next.js est gourmand) |
| Disque libre | 5 Go | 10 Go |
| Réseau | Accès HTTPS sortant | — |

### Logiciels

| Outil | Version | Vérification |
|---|---|---|
| Docker Engine | ≥ 20.10 | `docker --version` |
| Docker Compose | ≥ 2.0 (plugin `docker compose`) | `docker compose version` |
| Git | ≥ 2.25 | `git --version` |

> **Note sur la syntaxe** : ce guide utilise `docker compose` (avec une espace,
> plugin V2). L'ancienne commande `docker-compose` (avec un tiret) fonctionne
> aussi mais n'est plus maintenue.

### Ports à libérer

`3000`, `8000` et `5432` doivent être disponibles. Pour le vérifier :

```bash
ss -tulpn | grep -E ':(3000|8000|5432)'
```

Si la commande ne renvoie rien, tout est libre. Sinon, voir la
[section 15](#15-dépannage) pour changer les ports.

---

## 4. Installation de Docker sous Linux

> Si `docker compose version` répond déjà correctement, passez à la
> [section 5](#5-récupération-du-projet).

### Debian et Ubuntu

Le paquet `docker.io` des dépôts officiels de la distribution est souvent trop
ancien et **n'inclut pas le plugin Compose V2**. On installe donc depuis le
dépôt officiel Docker.

```bash
# 1. Retirer les éventuelles versions anciennes ou partielles
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# 2. Installer les outils nécessaires à l'ajout d'un dépôt HTTPS
sudo apt update
sudo apt install -y ca-certificates curl gnupg

# 3. Enregistrer la clé GPG officielle de Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 4. Ajouter le dépôt Docker correspondant à votre version
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. Installer le moteur et ses plugins
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
                    docker-buildx-plugin docker-compose-plugin
```

### Fedora, Rocky Linux, AlmaLinux

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io \
                    docker-buildx-plugin docker-compose-plugin
```

> Sur Rocky/Alma, remplacer `fedora` par `centos` dans l'URL du dépôt.

### Arch Linux et dérivés

```bash
sudo pacman -S --needed docker docker-compose docker-buildx
```

### Étapes communes à toutes les distributions

```bash
# Démarrer Docker et l'activer au démarrage de la machine
sudo systemctl enable --now docker

# Autoriser votre utilisateur à piloter Docker sans sudo
sudo usermod -aG docker "$USER"
```

> ⚠️ **L'ajout au groupe `docker` ne prend effet qu'à la prochaine session.**
> Fermez et rouvrez votre session (ou lancez `newgrp docker` pour le terminal
> courant), sinon toutes les commandes échoueront avec
> `permission denied while trying to connect to the Docker daemon socket`.

### Vérifier l'installation

```bash
docker --version           # Docker version 27.x.x
docker compose version     # Docker Compose version v2.x.x
docker run --rm hello-world
```

La dernière commande doit afficher `Hello from Docker!`. Si c'est le cas,
l'installation est fonctionnelle.

---

## 5. Récupération du projet

### Depuis une archive fournie

```bash
unzip VISION360-main.zip
cd VISION360-main
```

### Depuis Git

```bash
git clone <URL_DU_DEPOT> vision360
cd vision360
```

### Vérifier que vous êtes au bon endroit

```bash
ls docker-compose.yml backend/ web_next/ database/
```

Les quatre entrées doivent exister. **Toutes les commandes de ce guide se
lancent depuis cette racine.**

---

## 6. Obtenir vos propres clés d'API

Comme expliqué en [section 1](#1-à-lire-avant-tout--linfrastructure-cloud-a-été-démantelée),
nos clés ont été révoquées avec nos comptes. Il vous en faut donc deux, **toutes
deux gratuites et créées en quelques clics**.

### Clé Google Gemini — analyse d'images

1. Ouvrir **<https://aistudio.google.com/apikey>**
2. Se connecter avec un compte Google
3. Cliquer sur **« Create API key »**
4. Copier la clé (format `AIza...`)

> Le niveau gratuit de Google AI Studio suffit largement pour une démonstration.
> **Aucune carte bancaire n'est demandée** tant que vous restez sur ce niveau —
> c'est différent de Google Cloud Run, qui exige un compte de facturation, et
> c'est précisément ce qui nous a poussés à fermer nos comptes cloud.

### Clé Groq — génération des recommandations

1. Ouvrir **<https://console.groq.com/keys>**
2. Créer un compte (email ou Google/GitHub)
3. Cliquer sur **« Create API Key »**
4. Copier la clé (format `gsk_...`) — **elle n'est affichée qu'une seule fois**

> Groq est gratuit avec des quotas par minute. Aucun moyen de paiement requis.

### Et Open Food Facts ?

Rien à faire : c'est une base ouverte et collaborative, interrogée **sans clé
d'API**. Elle fournit les données produits certifiées (nom, marque, allergènes
officiels, Nutri-Score) croisées avec le profil de l'utilisateur.

---

## 7. Configuration du fichier `.env`

### Créer le fichier

```bash
cp .env.example .env
```

### Le remplir

```bash
nano .env      # ou vim .env, ou votre éditeur habituel
```

Contenu minimal à renseigner :

```env
# ---- Clés d'API (obligatoires) ----
GEMINI_API_KEY=AIza_votre_cle_gemini_ici
GROQ_API_KEY=gsk_votre_cle_groq_ici

# ---- Modèles (valeurs par défaut recommandées) ----
GEMINI_MODEL=gemini-2.0-flash-exp
GEMINI_API_VERSION=v1beta
GROQ_MODEL=llama-3.1-8b-instant

# ---- Base de données ----
# NE PAS MODIFIER pour un déploiement Docker : "postgres" est le nom du
# conteneur sur le réseau interne. Mettre "localhost" ici ferait échouer
# la connexion, car le backend chercherait la base dans son propre conteneur.
DATABASE_URL=postgresql://postgres:postgres@postgres:5432/vision360

# ---- Serveur ----
PORT=8000
```

### Détail des variables

| Variable | Obligatoire | Valeur par défaut | Rôle |
|---|:-:|---|---|
| `GEMINI_API_KEY` | ✅ | — | Analyse d'images (description de scène, lecture de code-barres) |
| `GROQ_API_KEY` | ✅ | — | Recommandations personnalisées selon le profil |
| `GEMINI_MODEL` | ❌ | `gemini-2.0-flash-exp` | Modèle de vision |
| `GEMINI_API_VERSION` | ❌ | `v1beta` | Version de l'API Gemini |
| `GROQ_MODEL` | ❌ | `llama-3.1-8b-instant` | Modèle de langage |
| `DATABASE_URL` | ❌ | surchargée par Compose | Chaîne de connexion PostgreSQL |
| `PORT` | ❌ | `8000` | Port d'écoute interne du backend |
| `NEXT_PUBLIC_API_BASE` | ❌ | `http://localhost:8000/api` | URL de l'API vue par le navigateur |

### Sécuriser le fichier

```bash
chmod 600 .env
```

> ⚠️ **Ne jamais committer `.env`.** Il est déjà listé dans `.gitignore`. Le
> fichier contient des secrets ; s'ils fuitent sur un dépôt public, ils sont
> automatiquement scannés et exploités en quelques minutes.

---

## 8. Lancement de la stack

### Démarrage

```bash
docker compose up -d --build
```

Décomposition de la commande :

| Fragment | Effet |
|---|---|
| `up` | Crée le réseau, les volumes et les conteneurs, puis les démarre |
| `-d` | Mode détaché : rend la main au terminal |
| `--build` | Force la (re)construction des images depuis les Dockerfile |

### Ce qui se passe, dans l'ordre

1. **Téléchargement des images de base** — `postgres:16-alpine`,
   `python:3.12-slim`, `node:20-alpine`. Uniquement au premier lancement.
2. **Construction du backend** — installation des dépendances de
   `backend/requirements.txt` (FastAPI, SQLAlchemy, psycopg2, httpx…).
3. **Construction du frontend** — `npm ci` puis `npm run build` en trois étapes
   (*multi-stage*), pour une image finale allégée. **C'est l'étape la plus
   longue : 2 à 4 minutes.**
4. **Démarrage de PostgreSQL** — au tout premier lancement, le script
   [`database/01_schema.sql`](../database/01_schema.sql) est exécuté
   automatiquement : les 7 types énumérés, les 7 tables, les contraintes et les
   index sont créés.
5. **Attente du healthcheck de la base** — le backend ne démarre qu'une fois
   `pg_isready` satisfait (`condition: service_healthy`), ce qui évite l'erreur
   classique « connection refused » au premier boot.
6. **Démarrage du backend** — Uvicorn sur le port 8000. Au démarrage,
   `init_db()` vérifie la présence des tables (elles existent déjà : rien à
   faire).
7. **Démarrage du frontend** — Next.js sur le port 3000, après le healthcheck
   du backend.

> **Le premier lancement prend 3 à 6 minutes** selon votre connexion et votre
> machine. Les suivants démarrent en quelques secondes grâce au cache Docker.

### Suivre le déroulement

```bash
docker compose logs -f
```

Quitter l'affichage avec `Ctrl+C` — cela **n'arrête pas** les conteneurs.

Logs attendus :

```
vision360_db   | database system is ready to accept connections
backend-1      | Uvicorn running on http://0.0.0.0:8000
web_next-1     | ✓ Ready in 1.2s
```

---

## 9. Vérification du déploiement

### 9.1 État des conteneurs

```bash
docker compose ps
```

Les trois services doivent afficher `Up`, et `postgres` comme `backend` doivent
être `(healthy)` :

```
NAME              STATUS                    PORTS
vision360_db      Up 2 minutes (healthy)    0.0.0.0:5432->5432/tcp
...-backend-1     Up 2 minutes (healthy)    0.0.0.0:8000->8000/tcp
...-web_next-1    Up 1 minute               0.0.0.0:3000->3000/tcp
```

### 9.2 Backend

```bash
curl http://localhost:8000/health
```

Réponse attendue :

```json
{"status": "ok"}
```

### 9.3 Documentation interactive de l'API

Ouvrir **<http://localhost:8000/docs>** dans un navigateur : Swagger UI liste
l'ensemble des endpoints et permet de les tester directement.

C'est le moyen le plus rapide de démontrer le fonctionnement de l'API sans
passer par l'interface graphique.

### 9.4 Base de données

```bash
docker compose exec postgres psql -U postgres -d vision360 -c "\dt"
```

Les **7 tables** doivent apparaître : `allergies`, `conditions`, `feedback`,
`interactions`, `preferences`, `profiles`, `users`.

```bash
docker compose exec postgres psql -U postgres -d vision360 -c "\dT"
```

Les **7 types énumérés** doivent apparaître.

### 9.5 Interface web

Ouvrir **<http://localhost:3000>**.

> **La webcam nécessite un contexte sécurisé.** Les navigateurs n'autorisent
> `getUserMedia()` que sur `https://` ou sur `http://localhost`. En accédant au
> site par l'adresse IP d'un serveur distant en HTTP simple, la caméra sera
> bloquée — voir la [section 13](#13-déploiement-sur-un-serveur-linux-distant)
> pour la mise en place de HTTPS.

### 9.6 Test complet de bout en bout

Ce test crée un utilisateur, lui ajoute une allergie et relit son profil. Il
valide toute la chaîne API ↔ base de données.

```bash
# 1. Inscription
curl -s -X POST http://localhost:8000/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@vision360.fr","password":"MotDePasse123"}'
```

Réponse : un objet JSON contenant un champ `id` (UUID). Copiez-le.

```bash
# 2. Ajout d'une allergie (remplacer <UUID> par l'id reçu)
curl -s -X POST http://localhost:8000/api/users/users/<UUID>/allergies \
  -H "Content-Type: application/json" \
  -d '{"allergen":"arachide","severity":"severe"}'

# 3. Relecture du profil complet destiné au LLM
curl -s http://localhost:8000/api/users/users/<UUID>/full-profile
```

```bash
# 4. Vérification côté base
docker compose exec postgres psql -U postgres -d vision360 \
  -c "SELECT email, is_active, created_at FROM users;"
```

Si la ligne apparaît, **le déploiement est complet et fonctionnel**.

> **Deux détails qui surprennent souvent :**
>
> 1. **Le segment `users` est bien doublé** dans l'URL de l'étape 2. Le routeur
>    est monté avec le préfixe `/api/users`, et ses routes internes commencent
>    elles-mêmes par `/users/{user_id}/...`. Le chemin complet est donc
>    `/api/users/users/{user_id}/allergies`. La liste exacte des chemins est
>    consultable sur <http://localhost:8000/docs>.
> 2. **La casse diffère entre l'API et la base.** On envoie `"severe"` en
>    minuscules à l'API (Pydantic travaille sur les *valeurs* de l'énumération),
>    mais la colonne contient `'SEVERE'` en majuscules (SQLAlchemy persiste les
>    *noms* des membres). Les deux sont corrects ; l'explication figure dans
>    [`../database/README.md`](../database/README.md).

---

## 10. Relier les clients au backend

C'est l'unique étape de « rebranchement » évoquée en
[section 1](#1-à-lire-avant-tout--linfrastructure-cloud-a-été-démantelée).

### Interface web — normalement automatique

Depuis la modification du build (voir section 1), l'image construite par
`docker compose` pointe déjà sur `http://localhost:8000/api`. **Vous ne devriez
avoir rien à faire.**

Si toutefois l'ancienne URL Cloud Run s'affiche encore (image construite avant
la correction, ou cache du navigateur) :

1. Ouvrir <http://localhost:3000>
2. Repérer le champ **« API Base »** en haut de la page
3. Le remplacer par : `http://localhost:8000/api`
4. Le champ est pris en compte immédiatement, sans rechargement

Pour forcer une reconstruction propre :

```bash
docker compose build --no-cache web_next
docker compose up -d web_next
```

### Application mobile Flutter

L'URL par défaut est définie dans
[`mobile_flutter/lib/main.dart`](../mobile_flutter/lib/main.dart) mais reste
**modifiable directement dans l'application**, onglet *Profil*, champ
**« API Base »** :

| Contexte d'exécution | URL à saisir |
|---|---|
| Émulateur Android | `http://10.0.2.2:8000/api` |
| Simulateur iOS | `http://localhost:8000/api` |
| Téléphone réel, même Wi-Fi | `http://<IP_DE_VOTRE_PC>:8000/api` |

Pour connaître l'IP de la machine hôte :

```bash
ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1
```

> `10.0.2.2` est l'alias par lequel l'émulateur Android joint le `localhost` de
> la machine hôte. `localhost` depuis l'émulateur désignerait l'émulateur
> lui-même.

Pour changer la valeur par défaut de façon permanente :

```bash
sed -i "s|https://vision360-backend-[^']*|http://10.0.2.2:8000/api|" \
    mobile_flutter/lib/main.dart
```

### POC TensorFlow.js

Aucune configuration : il s'exécute entièrement dans le navigateur.

```bash
cd poc-web && python3 -m http.server 8080
```

Puis <http://localhost:8080>.

---

## 11. Base de données

La création de la base est **entièrement automatisée** : au premier démarrage du
conteneur `postgres`, le script
[`database/01_schema.sql`](../database/01_schema.sql) est joué par le mécanisme
`/docker-entrypoint-initdb.d/` de l'image officielle PostgreSQL.

### Pourquoi la base est vide

Vision360 **ne crée aucun compte par défaut**. Toutes les tables sont alimentées
uniquement par l'inscription d'un utilisateur réel, puis par ses actions. Sur
l'environnement exporté, aucun compte n'ayant été créé, les 7 tables comptent
0 ligne : **le dump livré est donc vide côté données, et complet côté
structure**. C'est l'état réel de l'application, pas un export raté.

S'ajoute une raison de conformité : les tables `allergies` et `conditions`
contiennent des **données de santé**, catégorie particulière au sens du RGPD.
Livrer un dump peuplé de vraies données de santé serait une mauvaise pratique.

### Charger un jeu d'essai pour la démonstration

Un jeu de données **entièrement fictives** est fourni :

```bash
docker compose exec -T postgres psql -U postgres -d vision360 \
  < database/02_seed_demo.sql
```

Il crée 1 utilisateur (`demo@vision360.fr` / `Vision360!`), son profil PMR,
2 allergies, 1 condition médicale, 4 préférences, 1 interaction IA complète et
1 feedback — de quoi exercer chaque table et chaque type énuméré.

### Documentation complète

| Sujet | Document |
|---|---|
| Exports, restauration, remise à zéro | [`../database/README.md`](../database/README.md) |
| Dictionnaire de données colonne par colonne | [`DATABASE.md`](DATABASE.md) |
| Source de vérité du schéma | [`../backend/app/models.py`](../backend/app/models.py) |

---

## 12. Exploitation au quotidien

### Cycle de vie de la stack

```bash
docker compose up -d              # Démarrer
docker compose stop               # Arrêter sans supprimer les conteneurs
docker compose start              # Redémarrer après un stop
docker compose restart backend    # Redémarrer un seul service
docker compose down               # Arrêter et supprimer (les données restent)
docker compose down -v            # Idem + suppression du volume : ⚠️ DONNÉES PERDUES
```

> **`down` conserve la base, `down -v` la détruit.** Le `-v` supprime le volume
> `postgres_data`. Utile pour repartir d'un schéma vierge, destructeur sinon.

### Journaux

```bash
docker compose logs -f                  # Tous les services, en continu
docker compose logs -f backend          # Un seul service
docker compose logs --tail=100 backend  # Les 100 dernières lignes
docker compose logs --since 10m         # Les 10 dernières minutes
```

### Appliquer une modification de code

| Vous avez modifié… | Commande |
|---|---|
| `backend/app/*.py` | `docker compose up -d --build backend` |
| `backend/requirements.txt` | `docker compose build --no-cache backend && docker compose up -d backend` |
| `web_next/src/**` | `docker compose up -d --build web_next` |
| `.env` | `docker compose up -d` (recrée les conteneurs concernés) |
| `database/01_schema.sql` | `docker compose down -v && docker compose up -d` ⚠️ efface les données |

### Ouvrir un shell dans un conteneur

```bash
docker compose exec backend bash                       # Backend (Debian slim)
docker compose exec web_next sh                        # Frontend (Alpine, pas de bash)
docker compose exec postgres psql -U postgres -d vision360   # Session SQL
```

### Consommation de ressources

```bash
docker stats --no-stream
```

### Exécuter les tests unitaires

```bash
docker compose exec backend pytest tests/ -v
```

### Nettoyage

```bash
docker compose down --rmi local        # Supprime les images du projet
docker system prune -a                 # ⚠️ Nettoie TOUT Docker sur la machine
```

---

## 13. Déploiement sur un serveur Linux distant

Cette section couvre la mise en ligne sur un VPS ou un serveur d'établissement.
Elle n'est **pas nécessaire** pour une simple évaluation en local.

### 13.1 Préparation du serveur

```bash
ssh utilisateur@votre-serveur

sudo apt update && sudo apt upgrade -y
# Puis installer Docker : voir section 4
```

### 13.2 Pare-feu

N'exposez **que** ce qui doit l'être. En particulier, **PostgreSQL ne doit
jamais être joignable depuis Internet**.

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status verbose
```

Puis fermer le port de la base dans `docker-compose.yml` en le liant à la
boucle locale :

```yaml
  postgres:
    ports:
      - "127.0.0.1:5432:5432"   # accessible seulement depuis le serveur
```

Ou, mieux encore, **supprimer entièrement le bloc `ports`** du service
`postgres` : le backend l'atteint par le réseau interne de Docker, sans qu'aucun
port n'ait besoin d'être publié sur l'hôte.

### 13.3 Renforcer les identifiants de la base

Les identifiants `postgres/postgres` du fichier livré sont des valeurs de
développement. En production :

```yaml
  postgres:
    environment:
      POSTGRES_USER: vision360
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}   # défini dans .env
      POSTGRES_DB: vision360
```

```yaml
  backend:
    environment:
      - DATABASE_URL=postgresql://vision360:${POSTGRES_PASSWORD}@postgres:5432/vision360
```

Générer un mot de passe solide :

```bash
echo "POSTGRES_PASSWORD=$(openssl rand -base64 32)" >> .env
```

### 13.4 Reverse proxy et HTTPS

Le HTTPS n'est pas un luxe ici : **sans lui, la webcam est bloquée par le
navigateur**, et la fonctionnalité centrale du projet devient inutilisable.

Installer Nginx et Certbot :

```bash
sudo apt install -y nginx certbot python3-certbot-nginx
```

Créer `/etc/nginx/sites-available/vision360` :

```nginx
server {
    listen 80;
    server_name vision360.exemple.fr;

    # Interface web Next.js
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # API FastAPI
    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Les images encodées en base64 sont volumineuses
        client_max_body_size 20M;

        # L'analyse Gemini + Groq peut dépasser la minute
        proxy_read_timeout 120s;
        proxy_send_timeout 120s;
    }

    # Health check
    location /health {
        proxy_pass http://127.0.0.1:8000/health;
    }
}
```

Activer et obtenir le certificat :

```bash
sudo ln -s /etc/nginx/sites-available/vision360 /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

sudo certbot --nginx -d vision360.exemple.fr
```

Certbot configure la redirection HTTP → HTTPS et installe un renouvellement
automatique. Vérifier :

```bash
sudo certbot renew --dry-run
```

### 13.5 Reconstruire le frontend avec l'URL publique

L'URL de l'API étant figée à la construction (voir section 1), il faut
reconstruire l'image avec la bonne valeur :

```bash
echo 'NEXT_PUBLIC_API_BASE=https://vision360.exemple.fr/api' >> .env
docker compose build --no-cache web_next
docker compose up -d web_next
```

### 13.6 Restreindre le CORS

Le backend accepte actuellement **toutes** les origines
(`allow_origins=["*"]`), ce qui est adapté au développement mais trop permissif
en production. Dans [`../backend/app/main.py`](../backend/app/main.py) :

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://vision360.exemple.fr"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Content-Type", "Authorization"],
)
```

Le middleware `add_cors_headers` situé plus bas dans le même fichier réécrit ces
en-têtes en `*` : il doit être retiré ou adapté en même temps, sans quoi la
restriction resterait sans effet.

### 13.7 Démarrage automatique au boot

Les services déclarent `restart: unless-stopped` : Docker les relance seul après
un redémarrage du serveur, à condition que le démon soit activé :

```bash
sudo systemctl is-enabled docker || sudo systemctl enable docker
```

Pour un contrôle plus fin, créer `/etc/systemd/system/vision360.service` :

```ini
[Unit]
Description=Vision360 - stack Docker Compose
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/vision360
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now vision360
```

### 13.8 Checklist de mise en production

- [ ] Clés d'API renseignées dans `.env`, fichier en `chmod 600`
- [ ] Mot de passe PostgreSQL modifié et généré aléatoirement
- [ ] Port 5432 non publié sur Internet
- [ ] Pare-feu actif, seuls 22/80/443 ouverts
- [ ] HTTPS actif et renouvellement automatique testé
- [ ] `NEXT_PUBLIC_API_BASE` reconstruite avec l'URL publique
- [ ] CORS restreint au domaine de production
- [ ] Sauvegarde de la base planifiée ([section 14](#14-sauvegarde-et-restauration))
- [ ] Démarrage automatique vérifié par un `sudo reboot`

---

## 14. Sauvegarde et restauration

### Sauvegarde manuelle

```bash
./database/dump.sh
```

Ou directement :

```bash
docker compose exec postgres pg_dump -U postgres -d vision360 \
  --no-owner --no-privileges > sauvegarde_$(date +%F).sql
```

### Sauvegarde automatique quotidienne

Créer `/opt/vision360/backup.sh` :

```bash
#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR=/var/backups/vision360
mkdir -p "$BACKUP_DIR"

# Dump compressé horodaté
docker exec vision360_db pg_dump -U postgres -d vision360 \
    --no-owner --no-privileges \
  | gzip > "$BACKUP_DIR/vision360_$(date +%F_%H%M).sql.gz"

# Rotation : ne conserver que les 30 derniers jours
find "$BACKUP_DIR" -name 'vision360_*.sql.gz' -mtime +30 -delete
```

```bash
sudo chmod +x /opt/vision360/backup.sh
sudo crontab -e
```

Ajouter :

```cron
0 3 * * * /opt/vision360/backup.sh >> /var/log/vision360-backup.log 2>&1
```

> Une sauvegarde jamais restaurée n'est pas une sauvegarde. Testez la
> restauration au moins une fois sur un environnement séparé.

### Restauration

```bash
# Depuis un dump non compressé
./database/restore.sh sauvegarde_2026-08-26.sql

# Depuis une archive compressée
gunzip -c /var/backups/vision360/vision360_2026-08-26_0300.sql.gz \
  | docker compose exec -T postgres psql -U postgres -d vision360
```

Si les tables existent déjà, remettre la base à zéro au préalable :

```bash
docker compose exec -T postgres psql -U postgres -d vision360 < database/99_reset.sql
```

### Sauvegarder le volume Docker entier

```bash
docker run --rm \
  -v vision360main_postgres_data:/data:ro \
  -v "$(pwd)":/backup \
  alpine tar czf /backup/volume_postgres_$(date +%F).tar.gz -C /data .
```

> Le nom exact du volume est donné par `docker volume ls`. Docker le préfixe du
> nom du dossier de projet.

---

## 15. Dépannage

### Tableau de résolution rapide

| Symptôme | Cause probable | Solution |
|---|---|---|
| `permission denied ... docker.sock` | Utilisateur hors du groupe `docker` | `sudo usermod -aG docker $USER` puis **rouvrir la session** |
| `bind: address already in use` | Port 3000/8000/5432 occupé | Voir « Conflit de ports » ci-dessous |
| `GEMINI_API_KEY manquante` | `.env` absent ou mal rempli | Vérifier avec `docker compose exec backend env \| grep GEMINI` |
| `connection refused` vers postgres | Base pas encore prête | Le healthcheck gère l'attente ; sinon `docker compose restart backend` |
| Frontend appelle l'ancienne URL `run.app` | Image construite sans le build arg | `docker compose build --no-cache web_next` |
| Caméra inaccessible | Contexte non sécurisé | Utiliser `localhost` ou activer HTTPS (section 13.4) |
| `no space left on device` | Disque saturé par les images | `docker system prune -a` |
| Build `web_next` tué (exit 137) | Mémoire insuffisante | Ajouter du swap (voir ci-dessous) |
| Erreur CORS dans la console | Backend inaccessible depuis le navigateur | Vérifier `curl http://localhost:8000/health` |
| `type "..." already exists` | Schéma déjà créé | `docker compose down -v` puis `up -d` |

### Conflit de ports

Identifier le coupable :

```bash
sudo ss -tulpn | grep :8000
```

Puis remapper dans `docker-compose.yml` (seul le port hôte, à gauche, change) :

```yaml
  backend:
    ports:
      - "8001:8000"
```

Penser à ajuster `NEXT_PUBLIC_API_BASE` en conséquence et à reconstruire le
frontend.

### Le build du frontend est tué (OOM)

Next.js consomme facilement plus de 1,5 Go à la compilation. Sur une petite
machine, ajouter du swap :

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Vérifier ce que voit réellement le conteneur

```bash
docker compose exec backend env | grep -E 'GEMINI|GROQ|DATABASE'
docker compose config          # Configuration finale, variables résolues
```

> `docker compose config` affiche les secrets en clair : ne pas coller sa sortie
> dans un rapport ou un ticket.

### Repartir de zéro

```bash
docker compose down -v --rmi local
docker compose up -d --build
```

⚠️ Cette séquence détruit la base de données.

### Rassembler des informations pour demander de l'aide

```bash
docker compose ps
docker compose logs --tail=50 backend
docker compose logs --tail=50 web_next
docker version
uname -a
```

---

## 16. Annexes

### A. Ports utilisés

| Port | Service | Exposition recommandée en production |
|:-:|---|---|
| 3000 | Interface web Next.js | Derrière un reverse proxy uniquement |
| 8000 | API FastAPI | Derrière un reverse proxy uniquement |
| 5432 | PostgreSQL | **Jamais exposé** |
| 8080 | POC TensorFlow.js (facultatif) | Local uniquement |

### B. Aide-mémoire des commandes

```bash
# Installation initiale
cp .env.example .env && nano .env
docker compose up -d --build

# Vérification
docker compose ps
curl http://localhost:8000/health
docker compose exec postgres psql -U postgres -d vision360 -c "\dt"

# Exploitation
docker compose logs -f
docker compose restart backend
docker compose down

# Base de données
docker compose exec -T postgres psql -U postgres -d vision360 < database/02_seed_demo.sql
./database/dump.sh
./database/restore.sh

# Remise à zéro totale
docker compose down -v && docker compose up -d --build
```

### C. Arborescence des fichiers de déploiement

```
VISION360-main/
├── docker-compose.yml          # Orchestration des 3 services
├── .env                        # Vos secrets (à créer, jamais committé)
├── .env.example                # Modèle documenté
├── backend/
│   ├── Dockerfile              # Image Python 3.12 + FastAPI
│   ├── requirements.txt        # Dépendances Python épinglées
│   └── app/                    # Code de l'API
├── web_next/
│   ├── Dockerfile              # Image Node 20 multi-stage
│   └── src/app/page.tsx        # Interface principale
├── database/
│   ├── 01_schema.sql           # Script de création (joué automatiquement)
│   ├── 02_seed_demo.sql        # Jeu d'essai facultatif
│   ├── 99_reset.sql            # Remise à zéro
│   ├── vision360_dump.sql      # Export DUMP complet
│   ├── dump.sh / restore.sh    # Utilitaires
│   └── README.md               # Documentation de la base
└── docs/
    ├── INSTALLATION_LINUX.md   # Ce document
    ├── DATABASE.md             # Dictionnaire de données
    ├── API.md                  # Référence des endpoints
    └── ARCHITECTURE.md         # Vue d'ensemble technique
```

### D. Services externes et coûts

| Service | Clé requise | Niveau gratuit | Remarque |
|---|:-:|---|---|
| Google Gemini (AI Studio) | ✅ | Oui, sans carte bancaire | Analyse d'images |
| Groq | ✅ | Oui, quotas par minute | Génération de recommandations |
| Open Food Facts | ❌ | Base ouverte | Données produits certifiées |
| Google Cloud Run | — | **Compte supprimé** | Remplacé par Docker local |

> Le tableau ci-dessus résume la situation décrite en
> [section 1](#1-à-lire-avant-tout--linfrastructure-cloud-a-été-démantelée) :
> la seule brique payante potentielle (Cloud Run) a été retirée, et son rôle est
> assuré par Docker en local, sans coût ni compte à créer.

### E. Documents liés

| Document | Contenu |
|---|---|
| [`../database/README.md`](../database/README.md) | Exports DUMP, scripts de création, restauration |
| [`DATABASE.md`](DATABASE.md) | Dictionnaire de données détaillé |
| [`API.md`](API.md) | Référence complète des endpoints REST |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Architecture technique du système |
| [`INSTALLATION.md`](INSTALLATION.md) | Installation multi-plateforme (Windows, macOS, Linux) |
| [`DEPLOYMENT.md`](DEPLOYMENT.md) | Déploiement cloud historique (conservé pour référence) |
| [`GLOSSARY.md`](GLOSSARY.md) | Glossaire des termes du projet |
