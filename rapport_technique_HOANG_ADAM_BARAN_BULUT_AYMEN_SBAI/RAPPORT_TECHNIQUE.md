# Rapport technique de réalisation — Vision360

**Projet** : SAE Vision360 — Écosystème d'assistance IA pour personnes à mobilité réduite et malvoyantes
**Formation** : BUT Informatique 3ᵉ année — SAE S5 et S6, Parcours A et C
**Équipe** : HOANG · ADAM · BARAN · BULUT · AYMEN · SBAI
**Licence** : MIT

---

## Table des matières

1. [Contexte et objectifs](#1-contexte-et-objectifs)
2. [Analyse du besoin](#2-analyse-du-besoin)
3. [Choix technologiques](#3-choix-technologiques)
4. [Architecture générale](#4-architecture-générale)
5. [Réalisation du backend](#5-réalisation-du-backend)
6. [Chaîne de traitement IA](#6-chaîne-de-traitement-ia)
7. [Réalisation de l'application mobile](#7-réalisation-de-lapplication-mobile)
8. [Réalisation de l'interface web](#8-réalisation-de-linterface-web)
9. [POC de détection temps réel](#9-poc-de-détection-temps-réel)
10. [Modèle de données](#10-modèle-de-données)
11. [Sécurité et protection des données](#11-sécurité-et-protection-des-données)
12. [Tests et qualité](#12-tests-et-qualité)
13. [Industrialisation et déploiement](#13-industrialisation-et-déploiement)
14. [Difficultés rencontrées](#14-difficultés-rencontrées)
15. [Limites connues et dette technique](#15-limites-connues-et-dette-technique)
16. [Perspectives](#16-perspectives)
17. [Bilan](#17-bilan)
18. [Annexes](#18-annexes)

---

## 1. Contexte et objectifs

### 1.1 Le problème

En France, environ **1,7 million de personnes** sont atteintes d'un trouble de la
vision, dont plus de 200 000 sont aveugles ou malvoyantes profondes. À cela
s'ajoutent les personnes à mobilité réduite (PMR) au sens large : utilisateurs de
fauteuil roulant, de canne, de déambulateur.

Ces publics rencontrent des difficultés concrètes et quotidiennes que la
technologie grand public n'adresse que partiellement :

| Situation | Difficulté rencontrée |
|---|---|
| Courses en supermarché | Identifier un produit, lire un prix, détecter un allergène |
| Passage en caisse | Vérifier que tous les articles ont été transférés, contrôler le ticket |
| Restaurant | Localiser une table libre, comprendre le menu, trouver le terminal de paiement |
| Navigation urbaine | Anticiper un obstacle, un escalier, une bordure de trottoir |
| Vie domestique | Savoir ce qui reste dans les placards |

### 1.2 L'objectif du projet

Vision360 vise à construire un **écosystème d'agents IA multimodaux** capables
d'assister ces personnes dans ces cinq situations, en combinant :

- **la vision par ordinateur**, pour comprendre l'environnement à partir d'une photo ;
- **le langage naturel**, pour transformer cette compréhension en conseils utiles ;
- **la synthèse et la reconnaissance vocales**, pour que l'interaction ne dépende
  jamais de la lecture d'un écran ;
- **un profil personnel évolutif**, pour que les conseils tiennent compte des
  allergies, des pathologies et des goûts de chacun.

### 1.3 Le parti pris qui structure tout le projet

> **Une information générique n'aide pas.** Dire « il y a du Nutella dans le
> rayon » n'a aucune valeur. Dire « le Nutella contient des fruits à coque, or
> vous êtes allergique à l'arachide ; la confiture allégée est sur la deuxième
> étagère » en a une.

Ce principe explique l'essentiel des choix de conception : la présence d'une base
de données de profils, le chaînage de deux modèles d'IA plutôt qu'un seul, le
recours à une base produits certifiée plutôt qu'à la seule vision, et la place
centrale de la sortie vocale.

---

## 2. Analyse du besoin

### 2.1 Exigences fonctionnelles

| Réf. | Exigence | Statut |
|---|---|:-:|
| EF-01 | Décrire une scène à partir d'une photo | ✅ |
| EF-02 | Produire des recommandations tenant compte du profil | ✅ |
| EF-03 | Lire les résultats à voix haute | ✅ |
| EF-04 | Accepter des commandes vocales | ✅ |
| EF-05 | Gérer un profil santé (allergies, pathologies) | ✅ |
| EF-06 | Apprendre les goûts au fil des échanges | ✅ |
| EF-07 | Identifier un produit par code-barres avec données certifiées | ✅ |
| EF-08 | Assister le passage en caisse de bout en bout | ✅ |
| EF-09 | Guider un déplacement piéton par la voix | ✅ |
| EF-10 | Détecter des obstacles en temps réel | ⚠️ POC |
| EF-11 | Historiser les interactions et permettre l'export | ✅ |
| EF-12 | Gérer un inventaire domestique et une liste de courses | ✅ |
| EF-13 | Réserver un transport adapté | ⚠️ Stub |

### 2.2 Exigences non fonctionnelles

| Réf. | Exigence | Cible | Atteint |
|---|---|---|:-:|
| ENF-01 | Latence de la chaîne complète | < 10 s | ✅ ~4-8 s |
| ENF-02 | Fonctionnement sans lecture d'écran | Total | ✅ |
| ENF-03 | Déploiement reproductible | Une commande | ✅ Docker Compose |
| ENF-04 | Aucune donnée de santé exposée en clair | — | ✅ |
| ENF-05 | Coût d'exploitation | Nul en niveau gratuit | ✅ |
| ENF-06 | Compatibilité Android | ≥ 7.0 | ✅ `minSdk 24` |

### 2.3 Personas retenus

Trois profils ont guidé les arbitrages de conception.

**Camille, 34 ans, malvoyante et en fauteuil, diabétique et allergique à
l'arachide.** Ne peut pas lire une étiquette. A besoin d'une alerte *avant*
d'acheter, pas après. C'est le persona principal ; le jeu d'essai de la base
(`02_seed_demo.sql`) reprend exactement son profil.

**Marc, 68 ans, marche avec une canne, vision faible.** Se déplace seul mais
craint les obstacles au sol. Utilise surtout le guidage GPS et la description de
scène.

**Sofia, 22 ans, non-voyante, autonome.** Utilisatrice experte. Ne veut pas d'une
application qui parle trop : elle attend des messages courts et une réactivité
maximale. C'est pour elle que les messages vocaux du module caisse ont été
retravaillés jusqu'à tenir en une phrase.

---

## 3. Choix technologiques

### 3.1 Vue d'ensemble

| Couche | Technologie | Version |
|---|---|---|
| API | FastAPI (Python) | 0.115.0 |
| Serveur ASGI | Uvicorn | 0.30.6 |
| ORM | SQLAlchemy | 2.0.35 |
| Base de données | PostgreSQL | 16 |
| Application mobile | Flutter / Dart | 3.6+ |
| Interface web | Next.js / React | 16.1 / 19.2 |
| Détection embarquée | TensorFlow.js + COCO-SSD | — |
| Vision IA | Google Gemini | `gemini-2.0-flash-exp` |
| Langage IA | Groq | `llama-3.1-8b-instant` |
| Données produits | Open Food Facts | API v2 |
| Cartographie | OpenStreetMap, Valhalla, OSRM | — |
| Conteneurisation | Docker + Docker Compose | 20.10+ / v2 |

### 3.2 Justification des choix structurants

#### FastAPI plutôt que Django ou Flask

Trois raisons ont tranché :

1. **L'asynchrone natif.** Chaque requête d'analyse enchaîne deux appels HTTP
   externes de plusieurs secondes. Avec un serveur synchrone, chaque requête
   monopoliserait un worker pendant toute cette durée. `async/await` permet de
   servir des dizaines de requêtes simultanées avec un seul processus.
2. **La validation par Pydantic.** Les schémas (`schemas.py`, 269 lignes)
   décrivent les contrats d'entrée et de sortie. Une requête malformée est
   rejetée avant d'atteindre la logique métier, avec un message d'erreur précis.
3. **La documentation générée.** Swagger UI est disponible sur `/docs` sans une
   ligne de code supplémentaire, ce qui a servi de contrat entre les personnes
   travaillant sur le backend et celles travaillant sur les clients.

Django aurait apporté un ORM et une administration, au prix d'un poids inutile :
Vision360 n'a pas d'interface d'administration.

#### Flutter plutôt que du natif ou du React Native

Le projet devait livrer une application mobile fonctionnelle sans disposer de six
mois de développement Android **et** iOS. Flutter offre une base de code unique,
un rendu identique sur les deux plateformes, et surtout un **écosystème de
plugins mature pour l'accessibilité** — `flutter_tts` et `speech_to_text` sont
directement adossés aux moteurs vocaux du système, donc aux voix que
l'utilisateur a déjà configurées et dont il a l'habitude.

Le rechargement à chaud a également compté : ajuster une taille de police ou un
contraste et voir le résultat en une seconde a permis d'itérer vite sur
l'accessibilité.

#### Le chaînage Gemini → Groq plutôt qu'un modèle unique

C'est la décision d'architecture la plus structurante du projet.

| | Modèle multimodal unique | Chaînage Gemini → Groq |
|---|---|---|
| Appels réseau | 1 | 2 |
| Latence | ~3 s | ~5 s |
| Qualité de la description | Bonne | Bonne |
| Qualité du raisonnement personnalisé | Moyenne | **Élevée** |
| Coût | Élevé (tokens image) | **Faible** |
| Traçabilité | Boîte noire | **Deux étapes auditables** |

Le chaînage a été retenu parce qu'il **sépare deux problèmes de nature
différente** : *voir* et *conseiller*.

- **Gemini** est excellent pour transcrire une image en texte. On ne lui demande
  rien d'autre, et surtout **jamais le profil médical de l'utilisateur** — ce qui
  évite d'envoyer des données de santé à un service de vision.
- **Groq** raisonne sur du texte, très vite (architecture LPU, quelques centaines
  de tokens par seconde), et reçoit le profil pour croiser description et
  contraintes personnelles.

Bénéfice inattendu : la description intermédiaire étant du texte, elle est
**stockable, relisible et rejouable**. La colonne `interactions.gemini_description`
permet de comprendre a posteriori pourquoi une recommandation a été produite.

#### PostgreSQL plutôt que SQLite ou MongoDB

Les données du projet sont fortement relationnelles : un utilisateur possède un
profil, N allergies, N préférences, N interactions, chacune ayant 0 ou 1 feedback.
Les types `ENUM` natifs de PostgreSQL garantissent qu'aucune valeur aberrante
n'entre en base — un `sentiment` ne peut valoir que l'une des six valeurs prévues.
Le type `JSON` permet en parallèle de conserver les réponses brutes des modèles
sans figer leur structure.

Le module `database.py` conserve toutefois une compatibilité SQLite (détection du
préfixe `sqlite` et ajout de `check_same_thread=False`), utile pour un
développement local sans conteneur.

#### Open Food Facts en complément de la vision

Constat de terrain : la vision par IA **se trompe sur les allergènes**. Elle
identifie correctement « un pot de pâte à tartiner », mais ne peut pas garantir
la liste exacte des ingrédients — or sur ce sujet, une erreur peut envoyer
quelqu'un à l'hôpital.

D'où le choix d'un mode d'identification par code-barres : Gemini ne sert plus
qu'à **lire les chiffres** sous le code-barres (une tâche d'OCR, où il est
fiable), puis Open Food Facts fournit les données **officielles** : nom exact,
marque, allergènes réglementaires, Nutri-Score. La base est ouverte, gratuite et
sans clé d'API.

Le croisement avec le profil est délibérément **souple et bidirectionnel** : une
allergie déclarée « lait » déclenche l'alerte sur un allergène « lait de vache »,
et réciproquement (`products.py`, fonction `_normalize_product`).

---

## 4. Architecture générale

### 4.1 Vue d'ensemble

```
┌──────────────────────── APPLICATIONS CLIENTES ────────────────────────┐
│                                                                       │
│   📱 Mobile Flutter        🌐 Web Next.js        🧪 POC TensorFlow.js  │
│   5 283 lignes Dart        785 lignes TSX        439 lignes HTML/JS   │
│   5 onglets                Webcam + profil       COCO-SSD navigateur  │
│   Android · iOS · Web      React 19              Détection temps réel │
│                                                                       │
└──────────────┬────────────────────┬───────────────────┬───────────────┘
               │  HTTP/JSON         │                   │
               ▼                    ▼                   ▼
┌───────────────────────────── BACKEND API ─────────────────────────────┐
│                    FastAPI · 3 455 lignes Python                      │
│                                                                       │
│   /api/describe/*   → analyse d'image, recommandations                │
│   /api/guidance/*   → enrichissement des détections                   │
│   /api/users/*      → comptes, profils, préférences, historique       │
│   /api/products/*   → identification par code-barres                  │
│   /api/checkout/*   → assistance au passage en caisse                 │
│   /health           → sonde de disponibilité                          │
│                                                                       │
└──────┬──────────────────────────────────────────────┬─────────────────┘
       │                                              │
       ▼                                              ▼
┌──────────────────┐              ┌──────────────────────────────────────┐
│  PostgreSQL 16   │              │        SERVICES EXTERNES             │
│                  │              │                                      │
│  7 tables        │              │  Gemini Vision   → description       │
│  7 types ENUM    │              │  Groq LLM        → recommandations   │
│  Volume Docker   │              │  Open Food Facts → données produits  │
│  persistant      │              │  Valhalla / OSRM → itinéraires       │
└──────────────────┘              │  Nominatim       → recherche de lieux│
                                  └──────────────────────────────────────┘
```

### 4.2 Principes d'architecture retenus

**Le backend est le seul détenteur des secrets.** Aucune clé d'API n'existe dans
le code des clients. Un APK décompilé ne révèle aucun secret : il ne contient
qu'une URL.

**Les clients sont interchangeables.** Mobile, web et POC consomment strictement
la même API REST. Ajouter un quatrième client (montre connectée, assistant vocal)
ne demanderait aucune modification du backend.

**Le backend démarre même sans base de données.** L'événement de démarrage
capture l'exception d'initialisation et poursuit :

```python
try:
    init_db()
except Exception as exc:
    print(f"[WARN] Base de données indisponible, démarrage sans DB: {exc}")
```

Ce choix permet de servir les routes d'IA — qui ne dépendent pas de la base —
même dans un environnement où `DATABASE_URL` n'est pas configurée. Il a été
déterminant pour le déploiement serverless, où la base n'était pas provisionnée.

**La dégradation est toujours gracieuse.** Aucune panne d'un service externe ne
fait tomber l'application : GPS sans réseau → mode carte seule ; Groq
indisponible → la description Gemini reste affichée et lue ; Open Food Facts
muet → repli sur l'identification visuelle.

---

## 5. Réalisation du backend

### 5.1 Organisation des modules

| Module | Lignes | Responsabilité |
|---|--:|---|
| `main.py` | 171 | Application FastAPI, CORS, chargement `.env`, montage des routeurs |
| `describe.py` | 324 | Endpoints Gemini et Groq |
| `guidance.py` | 292 | Enrichissement des détections, conseils PMR |
| `users.py` | 524 | CRUD comptes, profils, allergies, conditions, préférences |
| `checkout.py` | 651 | Assistance au passage en caisse (5 fonctionnalités) |
| `products.py` | 296 | Identification par code-barres, croisement allergènes |
| `services.py` | 406 | Logique métier : extraction de préférences, profil pour LLM |
| `models.py` | 309 | 7 modèles SQLAlchemy, 7 énumérations |
| `schemas.py` | 269 | Schémas Pydantic d'entrée et de sortie |
| `reservations.py` | 137 | Réservations PMR (stub en mémoire) |
| `database.py` | 63 | Moteur SQLAlchemy, session, initialisation |

**Total : 3 455 lignes**, réparties selon un découpage par domaine fonctionnel
plutôt que par couche technique — chaque fichier reste lisible d'une traite.

### 5.2 Chargement de la configuration

Le module `main.py` implémente un chargeur `.env` maison plutôt que d'ajouter
`python-dotenv`, avec un ordre de recherche à quatre niveaux :

```
1. .env à la racine du dépôt
2. .env dans backend/
3. .env.example à la racine        (repli)
4. .env.example dans backend/      (repli)
```

Le point subtil est **l'ordre d'exécution** : les routeurs lisent leurs clés
d'API au niveau module, à l'import. Le chargement doit donc être fait **avant**
les imports, ce qui explique la position inhabituelle des `import` en milieu de
fichier — situation documentée par un commentaire dans le code.

### 5.3 Gestion du CORS

Le projet expose l'API à trois clients d'origines différentes, dont un fichier
HTML ouvert en local. La configuration combine **deux mécanismes** :

1. Le `CORSMiddleware` standard, en `allow_origins=["*"]` ;
2. Un middleware HTTP personnalisé qui intercepte les requêtes `OPTIONS` et
   repose les en-têtes CORS en `setdefault` sur toutes les réponses.

Cette redondance a été ajoutée après avoir constaté que certaines réponses
d'erreur générées avant le middleware standard partaient sans en-têtes CORS, ce
qui transformait une erreur 500 lisible en une erreur CORS opaque côté navigateur
— un piège classique, coûteux en temps de diagnostic.

C'est un réglage **de développement** : la section 13.6 du guide Linux détaille
la restriction à appliquer en production.

### 5.4 Le module d'assistance au passage en caisse

C'est le module le plus abouti fonctionnellement (651 lignes, 22 tests). Il
décompose un scénario réel en cinq étapes :

| # | Endpoint | Rôle |
|:-:|---|---|
| 1 | `POST /api/checkout/belt/scan` | Photographier le tapis, identifier chaque article, établir la liste de référence |
| 2 | `POST /api/checkout/belt/transfer` | Comparer deux captures pour suivre le transfert tapis → caddie |
| 3 | `POST /api/checkout/forgotten` | Différence entre liste initiale et caddie : qu'a-t-on oublié ? |
| 4 | `POST /api/checkout/ticket/scan` | Lire le ticket de caisse par OCR (articles, prix, total) |
| 5 | `POST /api/checkout/reconcile` | Rapprocher sémantiquement ticket et caddie via Groq |

Trois partis pris techniques méritent d'être signalés.

**L'état de session est conservé en mémoire serveur**, indexé par `session_id`
(UUID généré par `POST /checkout/start`). Le scénario dure quelques minutes et
n'a aucune valeur au-delà : le persister en base aurait ajouté de la complexité
et un risque RGPD pour aucun bénéfice. La contrepartie est assumée : un
redémarrage du conteneur perd les sessions en cours, et l'API n'est pas
répartissable sur plusieurs instances en l'état.

**Chaque réponse porte un champ `voice_message`.** C'est une phrase française
naturelle et courte, prête à être lue telle quelle par la synthèse vocale du
client. Le formatage — accord du pluriel, énumération avec « et » avant le
dernier élément, mention des articles incertains — est fait côté serveur par les
fonctions `_spoken_list` et `_items_to_text`. Les clients n'ont ainsi aucune
logique de langue à dupliquer, et un changement de formulation profite
immédiatement au mobile comme au web.

**Le degré de certitude est explicite.** Gemini renvoie pour chaque article un
niveau de confiance ; les articles marqués `low` sont isolés dans
`session["uncertain_items"]` et annoncés séparément (« je ne suis pas sûr
de… »). Le système préfère avouer son incertitude plutôt que d'affirmer à tort —
principe non négociable quand l'utilisateur ne peut pas vérifier visuellement.

### 5.5 Robustesse du parsing des réponses LLM

Un modèle de langage à qui l'on demande du JSON produit régulièrement du JSON
**entouré de texte** ou encapsulé dans des balises Markdown. Une fonction
`_extract_json` a donc été écrite, avec trois stratégies successives :

1. Retrait d'une éventuelle clôture ```` ```json ```` ;
2. Tentative de `json.loads` direct ;
3. À défaut, **parcours caractère par caractère avec comptage de profondeur des
   accolades** pour isoler le premier objet JSON complet.

Cette fonction est testée pour elle-même (`test_extract_json_variants`). Sans
elle, environ une réponse sur dix échouait en production.

---

## 6. Chaîne de traitement IA

### 6.1 Le pipeline complet

```
   📷 Photo (base64)
        │
        ▼
┌────────────────────────────────────────────┐
│ POST /api/describe/gemini                  │
│                                            │
│ Envoi : { prompt, inline_data: image }     │
│ Modèle : gemini-2.0-flash-exp              │
│ Timeout : 60 s                             │
└────────────────┬───────────────────────────┘
                 │
                 ▼
     "Rayon petit-déjeuner. Trois étagères :
      pâtes à tartiner (Nutella, purée de
      noisettes), confitures allégées, miel.
      Étagère du bas : biscuits sans gluten."
                 │
                 │  ← texte, donc stockable et auditable
                 ▼
┌────────────────────────────────────────────┐
│ POST /api/describe/groq                    │
│                                            │
│ system : « assistant de sécurité PMR,      │
│           réponds STRICTEMENT en JSON »    │
│ user   : profil + description + consigne   │
│ Modèle : llama-3.1-8b-instant              │
│ temperature : 0.2                          │
└────────────────┬───────────────────────────┘
                 │
                 ▼
   {
     "summary": "Rayon petit-déjeuner, 3 étagères",
     "risks":   ["Nutella : fruits à coque — allergie arachide déclarée",
                 "Pâtes à tartiner : sucre ajouté, déconseillé (diabète)"],
     "actions": ["Confiture allégée, 2e étagère à hauteur de main",
                 "Biscuits sans gluten, étagère du bas à gauche"]
   }
                 │
                 ▼
        🔊 Synthèse vocale
```

### 6.2 Détails d'implémentation notables

**`temperature = 0.2`.** Une valeur basse pour une raison de sécurité : sur des
recommandations touchant à la santé, la créativité est un défaut. On veut une
sortie stable et reproductible pour une entrée donnée.

**Le prompt système impose le format.** La consigne « Réponds STRICTEMENT en JSON
sans texte hors JSON » est doublée d'une consigne de sortie paramétrable
(`instruction`), ce qui permet à un client de demander une structure différente
sans modifier le backend.

**Le profil est surchargeable.** Le champ `profile_override` prend le pas sur le
catalogue de profils prédéfinis. Concrètement, l'application mobile envoie le
profil réel de l'utilisateur à chaque requête, ce qui permet de fonctionner
**sans compte serveur** : le profil peut rester purement local sur le téléphone.

**Le parsing est non bloquant.** Si le JSON de Groq est invalide, `structured`
vaut `null` mais `raw_text` est renvoyé. Le client affiche alors le texte brut
plutôt que de planter — dégradation gracieuse plutôt qu'échec sec.

### 6.3 Le mode « double face » pour les produits

L'endpoint `POST /api/describe/gemini/product` accepte **deux images** — face
avant et face arrière d'un produit. La face avant identifie la marque et le
produit, la face arrière porte la liste d'ingrédients et le tableau nutritionnel.
Cette astuce reproduit le geste naturel d'une personne voyante qui retourne un
paquet pour lire l'étiquette.

### 6.4 L'enrichissement local, sans IA

Le module `guidance.py` couvre un besoin différent : le POC de détection produit
des dizaines de détections par seconde. Y appliquer un LLM serait absurde en
latence comme en coût.

L'enrichissement est donc **purement déterministe** : trois dictionnaires
(`OBSTACLE_DESCRIPTIONS`, `RETAIL_DESCRIPTIONS`, `RESTAURANT_DESCRIPTIONS`)
traduisent les classes COCO-SSD en français, et une logique à base de règles
évalue le risque en croisant la classe et la zone de profondeur :

```python
if cls in {"person", "crowd", "stairs", "curb", "cone", "barrier", "puddle"}:
    if det.zone == "near":
        risks.append("Obstacle proche")
    if cls == "puddle":
        risks.append("Risque de glissade")
    if cls == "stairs":
        risks.append("Prévoir montée/descente")
```

Réponse en quelques millisecondes, coût nul, comportement parfaitement
prévisible. Un endpoint `/enrich/batch` traite un lot de détections en une seule
requête pour limiter les allers-retours réseau.

**Enseignement du projet : tout ne doit pas passer par un LLM.** Le bon outil
dépend de la nature du problème — traduire un vocabulaire fermé est un problème
de dictionnaire, pas d'intelligence artificielle.

---

## 7. Réalisation de l'application mobile

### 7.1 Structure

L'application représente **5 283 lignes de Dart**, réparties en deux fichiers :
`main.dart` (4 618 lignes) et `checkout_screen.dart` (665 lignes).

L'architecture est délibérément simple : un `StatefulWidget` principal
(`_HomeScreenState`) porte l'état applicatif, sans gestionnaire d'état externe
(Provider, Riverpod, Bloc). Ce choix se discute — voir
[§15](#15-limites-connues-et-dette-technique) — mais il a évité d'imposer
l'apprentissage d'un framework supplémentaire à toute l'équipe dans le temps
imparti.

### 7.2 Les cinq onglets

| Onglet | Fonctions principales |
|---|---|
| **Profil** | Authentification locale, profil santé, réglages d'accessibilité, thème clair/sombre, inventaire domestique |
| **Guidance** | Aperçu caméra, capture, chaîne Gemini → Groq, lecture vocale des conseils, saisie manuelle de repli |
| **GPS** | Carte OpenStreetMap, recherche de lieux, calcul d'itinéraire piéton, guidage vocal pas à pas |
| **Historique** | Journal horodaté des analyses, export fichier, copie presse-papiers |
| **Caddie** | Liste de courses, scan de code-barres, passage en caisse assisté, vérification du ticket |

### 7.3 L'accessibilité, contrainte de conception et non option

Toutes les fonctions doivent rester utilisables **sans regarder l'écran**.

| Dispositif | Mise en œuvre |
|---|---|
| Synthèse vocale | `flutter_tts` en `fr-FR`, vitesse réglable de 0.5× à 2× |
| Reconnaissance vocale | `speech_to_text`, déclenchée par un bouton unique en pleine largeur |
| Contraste renforcé | Bascule dans le profil, appliquée à tout le thème |
| Texte agrandi | Bascule dédiée, indépendante des réglages système |
| Zones tactiles | Boutons principaux surdimensionnés, atteignables au pouce |
| Retour d'état | Bandeaux d'état et point pulsant (`_PulsingDot`) doublant l'annonce vocale |

Le réglage de vitesse est né d'un retour d'usage : les utilisateurs habitués aux
lecteurs d'écran écoutent **beaucoup plus vite** que la vitesse par défaut, qu'ils
trouvent pénible. Inversement, un utilisateur novice a besoin d'un débit ralenti.

### 7.4 Le guidage GPS

C'est la fonction techniquement la plus délicate. Elle repose entièrement sur des
services **libres et sans clé d'API** :

| Service | Rôle |
|---|---|
| OpenStreetMap | Fond de carte (`flutter_map`) |
| Nominatim | Recherche de lieux par nom |
| Overpass | Lieux accessibles à proximité |
| **Valhalla** | Calcul d'itinéraire piéton — **instructions en français natif** |
| **OSRM** | Repli si Valhalla est indisponible |

La stratégie à deux moteurs (`_fetchRoute`) est née d'un besoin concret :
**Valhalla renvoie les instructions directement en français**, ce qui évite une
traduction approximative des indications de navigation. Mais sa disponibilité
publique est irrégulière ; OSRM, plus stable mais anglophone, prend le relais.

Le suivi de progression (`_checkStepAdvance`) compare en continu la position GPS
au point de l'étape courante et déclenche l'annonce vocale de l'étape suivante
lorsque le seuil de proximité est franchi. L'utilisateur n'a rien à toucher
pendant tout le trajet.

### 7.5 Persistance locale

`shared_preferences` conserve sur l'appareil : comptes locaux, session courante,
URL de l'API, profil santé, historique, inventaire domestique, liste de courses,
réglages d'accessibilité et thème.

**Conséquence majeure : l'application fonctionne sans compte serveur.** Le profil
peut vivre entièrement sur le téléphone et être transmis à chaque requête via
`profile_override`. La base PostgreSQL devient alors optionnelle — utile pour la
synchronisation multi-appareils et l'apprentissage à long terme, mais pas
nécessaire à l'usage quotidien.

C'est aussi un choix favorable à la vie privée : par défaut, **les données de
santé ne quittent pas l'appareil**.

---

## 8. Réalisation de l'interface web

L'application Next.js (`web_next/`, 785 lignes de TSX) répond à un besoin
distinct du mobile : **configurer confortablement son profil au clavier**, et
démontrer le projet sans installer d'APK.

| Aspect | Choix |
|---|---|
| Framework | Next.js 16, App Router |
| Rendu | `"use client"` — application entièrement côté client |
| Caméra | `getUserMedia`, capture sur `<canvas>` |
| Vocal | Web Speech API du navigateur (TTS et STT) |
| Style | CSS Modules, sans framework externe |

Deux points techniques à retenir.

**La capture webcam exige un contexte sécurisé.** Les navigateurs n'autorisent
`getUserMedia()` que sur `https://` ou `http://localhost`. Cette contrainte
détermine à elle seule la configuration de déploiement en production : sans
HTTPS, la fonction centrale est inutilisable. C'est la raison de la section
reverse proxy + Certbot du guide d'installation.

**`NEXT_PUBLIC_API_BASE` est figée au moment du build.** Next.js remplace les
références à `process.env.NEXT_PUBLIC_*` par leur valeur littérale à la
compilation. Passer la variable au conteneur à l'exécution est sans effet côté
navigateur. Le `docker-compose.yml` la transmet donc en `build arg`, et le
`Dockerfile` la reçoit via `ARG` — correction apportée après le démantèlement de
l'infrastructure cloud, sans laquelle l'interface continuait d'appeler une URL
morte.

---

## 9. POC de détection temps réel

Le dossier `poc-web/` contient un prototype autonome (439 lignes) qui répond à une
question précise : **peut-on détecter des obstacles en temps réel sans serveur
d'inférence ?**

**Réponse : oui.** TensorFlow.js exécute le modèle COCO-SSD directement dans le
navigateur, sur le GPU via WebGL, avec un flux webcam.

| Avantage | Détail |
|---|---|
| Latence | Aucun aller-retour réseau |
| Coût | Aucune infrastructure d'inférence |
| Vie privée | **Les images ne quittent jamais l'appareil** |
| Hors ligne | Fonctionne sans connexion une fois le modèle chargé |

Le fichier `ontology.json` définit trois profils de détection — obstacles
urbains, retail, restaurant — chacun listant les classes pertinentes et leurs
synonymes français et anglais. Cette ontologie externalisée permet d'ajuster le
comportement **sans recompiler** : filtrer les classes selon le contexte, et
faire correspondre les libellés du modèle avec un vocabulaire francophone.

Limite assumée : COCO-SSD ne connaît que ses 80 classes génériques. Il ne détecte
ni « escalier », ni « bordure de trottoir », ni « code-barres » — précisément les
objets les plus utiles ici. Le dossier `datasets/` prépare la suite (entraînement
d'un modèle YOLO spécialisé, scripts de préparation) mais l'entraînement n'a pas
été mené dans le temps du projet.

---

## 10. Modèle de données

### 10.1 Schéma

Sept tables, articulées autour de `users` :

```
                      users (racine)
                        │
     ┌──────┬───────────┼───────────┬──────────────┐
     │ 1-1  │ 1-N       │ 1-N       │ 1-N          │ 1-N
  profiles allergies conditions preferences   interactions
                                                    │ 1-1
                                                 feedback
```

| Table | Rôle |
|---|---|
| `users` | Comptes : email, empreinte du mot de passe, état |
| `profiles` | Mobilité, vision, TTS, contraste, langue |
| `allergies` | Allergènes et sévérité — source des alertes de sécurité |
| `conditions` | Pathologies à impact alimentaire |
| `preferences` | Goûts évolutifs avec indice de confiance |
| `interactions` | Historique image → Gemini → Groq, réponses brutes en JSON |
| `feedback` | Notation d'une recommandation |

Le détail colonne par colonne figure dans `docs_docker_.../DATABASE.md` et le
script de création commenté dans `database_.../01_schema.sql`.

### 10.2 La table `preferences`, cœur de l'apprentissage

C'est la table la plus spécifique au projet. Elle ne stocke pas seulement *quoi*,
mais *avec quelle fiabilité* :

| Colonne | Apport |
|---|---|
| `sentiment` | 6 niveaux, de `ADORE` à `INTERDIT` |
| `source` | Déclaré par l'utilisateur, déduit par le LLM, ou observé |
| `confidence` | 0.0 à 1.0 |
| `times_mentioned` | Compteur de répétitions |
| `last_mentioned` | Fraîcheur de l'information |

Cette granularité permet de **pondérer**. Une préférence dite explicitement
(`USER_EXPLICIT`, confiance 1.0) l'emporte sur une déduction du LLM
(`LLM_INFERRED`, confiance 0.8). Une préférence mentionnée dix fois pèse plus
qu'une mention isolée. Et `INTERDIT` — contre-indication médicale ou religieuse —
est traité comme bloquant, jamais comme un simple goût.

### 10.3 Extraction automatique des préférences

Le service `PreferenceExtractor` (`services.py`) détecte les préférences dans les
phrases de l'utilisateur au moyen d'expressions régulières :

```python
NEGATIVE_PATTERNS = [
    r"(?:je |j')?(?:n')?aime pas (?:le |la |les |l')?(.+)",
    r"(?:je |j')?déteste (?:le |la |les |l')?(.+)",
    r"(?:je suis |j'ai une )?allergi(?:que|e) (?:au |à la |aux |à l')?(.+)",
    ...
]
```

Le choix des expressions régulières plutôt que d'un appel LLM supplémentaire est
délibéré : c'est **instantané, gratuit et déterministe**. Le compromis est
assumé — la couverture linguistique reste limitée (voir
[§15](#15-limites-connues-et-dette-technique)).

### 10.4 Le piège des types ENUM

Point technique qui a coûté du temps et mérite d'être documenté.

SQLAlchemy, lorsqu'on lui passe une énumération Python, persiste le **nom** du
membre et non sa valeur :

```python
class MobilityType(str, enum.Enum):
    FAUTEUIL = "fauteuil"     # "fauteuil" côté Python
```
```sql
INSERT INTO profiles (mobility) VALUES ('FAUTEUIL');   -- 'FAUTEUIL' côté base
```

Conséquence visible dans toute la chaîne : l'API accepte `"severe"` en
minuscules (Pydantic travaille sur les valeurs), tandis que la base contient
`'SEVERE'`. Les scripts SQL livrés respectent scrupuleusement cette convention ;
les écrire en minuscules rendrait la base illisible par l'ORM.

### 10.5 État des données livrées

Le dump livré contient **la structure complète et zéro ligne**. Ce n'est pas un
export raté : l'application ne crée aucun compte par défaut, et aucun compte
n'avait été créé sur l'environnement exporté.

S'y ajoute une raison de conformité : les tables `allergies` et `conditions`
contiennent des données de santé, catégorie particulière au sens du RGPD. Livrer
un dump peuplé de vraies données de santé aurait été une mauvaise pratique. Un
jeu d'essai **entièrement fictif** (`02_seed_demo.sql`) est fourni pour la
démonstration.

---

## 11. Sécurité et protection des données

### 11.1 Ce qui a été fait

| Mesure | Mise en œuvre |
|---|---|
| Clés d'API côté serveur uniquement | Aucun secret dans les binaires clients |
| Secrets hors du dépôt | `.env` ignoré par Git, `.env.example` documenté |
| Mots de passe non stockés en clair | Empreinte uniquement |
| Validation des entrées | Pydantic sur tous les endpoints |
| Requêtes paramétrées | SQLAlchemy — pas de concaténation SQL |
| Minimisation des données envoyées | Le profil médical n'est **jamais** transmis à Gemini |
| Données de santé locales par défaut | Profil stocké sur l'appareil |
| Base non exposée | Recommandation de ne pas publier le port 5432 |
| Vérification des secrets en CI | Workflow `secrets-sanity.yml` |

### 11.2 Ce qui reste insuffisant, et pourquoi

Ces points sont **connus et documentés**, pas découverts après coup.

| Faiblesse | Risque | Ce qu'il faudrait |
|---|---|---|
| Hachage SHA-256 sans sel | Vulnérable aux tables arc-en-ciel | **bcrypt ou Argon2** |
| Pas de jeton de session | Aucune authentification réelle des requêtes | JWT ou session serveur |
| `user_id` en clair dans l'URL | N'importe qui peut lire le profil d'autrui | Contrôle d'accès par jeton |
| CORS totalement ouvert | Toute origine peut appeler l'API | Liste blanche de domaines |
| Identifiants PostgreSQL par défaut | `postgres/postgres` | Mot de passe généré |
| Pas de limitation de débit | Épuisement des quotas d'API | Rate limiting |

> **Le point le plus grave est le hachage SHA-256 sans sel.** SHA-256 est une
> fonction de hachage *rapide* — c'est exactement ce qu'il ne faut pas pour un
> mot de passe, car cette rapidité profite à l'attaquant. `bcrypt` et `Argon2`
> sont lents **par conception**. La correction est faible en volume de code
> (`passlib` + une migration des empreintes existantes) mais n'a pas été
> priorisée face aux fonctionnalités d'accessibilité, qui constituaient le cœur
> du sujet.

Le contexte atténue le risque sans l'annuler : l'application fonctionne
principalement avec un profil local, et la base livrée est vide. Il n'en reste
pas moins que **le backend n'est pas exposable sur Internet en l'état**.

### 11.3 Positionnement RGPD

Le projet manipule des **données de santé**, catégorie particulière relevant de
l'article 9 du RGPD. Trois principes ont guidé la conception :

1. **Minimisation.** Gemini reçoit une image, jamais le profil médical. Seul
   Groq, qui raisonne sur du texte, reçoit les contraintes de santé.
2. **Localité par défaut.** Le profil vit sur l'appareil ; l'envoi au serveur
   est un choix de l'utilisateur, pas un prérequis.
3. **Aucune donnée réelle livrée.** Le dump est vide, le jeu d'essai fictif.

---

## 12. Tests et qualité

### 12.1 Couverture

**34 tests unitaires** répartis sur trois fichiers (535 lignes) :

| Fichier | Tests | Portée |
|---|--:|---|
| `test_checkout.py` | 22 | Les 5 étapes du passage en caisse, cas limites, fonctions utilitaires |
| `test_products.py` | 11 | Code-barres, croisement d'allergènes, erreurs Open Food Facts |
| `test_health.py` | 1 | Sonde de disponibilité |

```bash
docker compose exec backend pytest tests/ -v
```

### 12.2 Stratégie : simuler les appels externes

Tous les tests utilisent `monkeypatch` pour remplacer les appels à Gemini, Groq
et Open Food Facts par des réponses figées. Trois bénéfices :

- Les tests s'exécutent **hors ligne**, en quelques secondes ;
- Ils ne consomment **aucun quota d'API** ;
- Ils sont **déterministes** — un LLM ne l'est pas, un test doit l'être.

L'effort a porté sur les **cas limites**, plus révélateurs que les cas nominaux :

| Test | Situation couverte |
|---|---|
| `test_belt_scan_empty` | Tapis vide |
| `test_belt_scan_handles_markdown_fences` | Réponse LLM encapsulée en Markdown |
| `test_belt_scan_tolerates_malformed_quantities` | Quantité renvoyée en texte au lieu d'un nombre |
| `test_transfer_uncertain_alert` | Article identifié avec une confiance faible |
| `test_ticket_scan_tolerates_null_currency_and_total` | Champs manquants dans le ticket |
| `test_lookup_invalid_barcode` | Code-barres syntaxiquement invalide |
| `test_extract_json_variants` | Les trois stratégies d'extraction JSON |

Cette orientation reflète une réalité du projet : **les intégrations LLM échouent
rarement franchement — elles renvoient du presque-correct.** Un `"deux"` au lieu
d'un `2`, un JSON entouré de prose. Ce sont ces cas-là qui cassent une
application en production.

### 12.3 Intégration continue

Le workflow `.github/workflows/ci-tests-and-backup.yml` s'exécute à chaque
`push` et `pull request` sur `main` :

1. Installation de Python 3.11 avec mise en cache des dépendances ;
2. Exécution de `pytest --maxfail=1` ;
3. Sur `push` uniquement : archivage du dépôt vers Google Drive via `rclone`.

Deux workflows complémentaires (`secrets-sanity.yml`, `drive-diagnose.yml`)
vérifient à la demande la présence et la validité des secrets de sauvegarde.

### 12.4 Ce qui n'est pas testé

Par honnêteté, l'inventaire des manques :

- **Aucun test des routes `/api/users/*`** — c'est le module non couvert le plus
  important (524 lignes) ; il exigerait une base de test avec fixtures.
- **Aucun test Flutter** au-delà du squelette généré (`widget_test.dart`).
- **Aucun test frontend Next.js** ; l'étape correspondante de la CI pointe vers
  un dossier `frontend/` qui n'existe pas dans ce dépôt (le frontend est
  `web_next/`) — cette étape ne teste donc rien.
- **Aucun test d'intégration de bout en bout** avec des services réels.

---

## 13. Industrialisation et déploiement

### 13.1 Les deux temps du projet

**Phase 1 — Cloud.** Le backend a été déployé sur **Google Cloud Run**
(région `europe-west1`), avec un pipeline `cloudbuild.yaml` produisant l'image
et la poussant vers Artifact Registry. Le frontend Next.js était hébergé
séparément. Cette phase a validé le déploiement serverless : montée en charge
automatique, HTTPS fourni, aucune administration de serveur.

**Phase 2 — Auto-hébergement.** Les crédits gratuits arrivant à échéance et
Cloud Run exigeant un compte de facturation actif, **les comptes cloud ont été
supprimés pour éviter tout prélèvement**. Le projet a donc basculé sur un
déploiement **entièrement conteneurisé et auto-hébergé**.

Le basculement a été peu coûteux, et c'est la meilleure validation du travail
d'industrialisation : **l'image Docker déployée sur Cloud Run était déjà celle
que produit `docker compose`**. Cloud Run ne faisait que l'héberger.

### 13.2 La stack Docker Compose

Trois services orchestrés par un fichier unique :

| Service | Image | Port | Points notables |
|---|---|:-:|---|
| `postgres` | `postgres:16-alpine` | 5432 | Volume persistant, healthcheck `pg_isready`, schéma joué automatiquement à l'init |
| `backend` | `backend/Dockerfile` | 8000 | Python 3.12 slim, healthcheck sur `/health` |
| `web_next` | `web_next/Dockerfile` | 3000 | Build multi-étapes Node 20 |

Trois mécanismes méritent d'être signalés.

**Le démarrage ordonné.** `depends_on` avec `condition: service_healthy` garantit
que le backend n'est lancé qu'une fois PostgreSQL prêt à accepter des connexions.
Sans cela, le backend échouait aléatoirement au premier démarrage — le conteneur
de base est « démarré » bien avant d'être « prêt ».

**L'initialisation automatique du schéma.** Le fichier `database/01_schema.sql`
est monté en lecture seule dans `/docker-entrypoint-initdb.d/`. PostgreSQL
l'exécute au premier démarrage, quand le volume est vide. Le backend appelle par
ailleurs `create_all()` : les deux mécanismes sont compatibles, `create_all`
ignorant les tables existantes.

**Le build multi-étapes du frontend.** Trois étapes (`deps`, `builder`, `runner`)
produisent une image finale sensiblement plus légère que si les outils de build y
figuraient.

### 13.3 Livrables d'industrialisation

| Livrable | Contenu |
|---|---|
| `docs_docker_.../INSTALLATION_LINUX.md` | Installation et déploiement Linux détaillés : Docker par distribution, pare-feu, Nginx, HTTPS, systemd, sauvegardes |
| `database_.../` | Script de création commenté, export DUMP, jeu d'essai, réinitialisation, scripts `dump.sh` et `restore.sh` |
| `guide_apk_.../` | Génération de l'APK et des autres formats de packaging, script `build_apk.sh` |

---

## 14. Difficultés rencontrées

### 14.1 Les LLM ne respectent pas les formats

**Problème.** Malgré une consigne explicite « réponds STRICTEMENT en JSON », le
modèle produisait régulièrement du JSON entouré de texte ou encapsulé en
Markdown. Environ **une réponse sur dix** échouait au parsing.

**Solution.** La fonction `_extract_json` à trois stratégies décrite en
[§5.5](#55-robustesse-du-parsing-des-réponses-llm), avec un test dédié.

**Enseignement.** Une sortie de LLM doit être traitée comme une **entrée non
fiable**, au même titre qu'une saisie utilisateur.

### 14.2 La vision se trompe sur les allergènes

**Problème.** Gemini identifie correctement « un paquet de biscuits », mais ne
peut pas garantir la liste exacte des allergènes. Sur ce sujet, une erreur peut
avoir des conséquences graves.

**Solution.** Changement de rôle du modèle : Gemini ne fait plus que **lire les
chiffres du code-barres** — une tâche d'OCR où il est fiable — et Open Food Facts
fournit les données réglementaires.

**Enseignement.** Sur les sujets à enjeu vital, une source de vérité certifiée
doit prévaloir sur une inférence probabiliste.

### 14.3 Le démarrage désordonné des conteneurs

**Problème.** Le backend plantait au premier `docker compose up` avec une erreur
`connection refused`, tout en fonctionnant après un redémarrage.

**Cause.** Docker considère un conteneur « démarré » dès que le processus tourne.
PostgreSQL met plusieurs secondes de plus à accepter des connexions.

**Solution.** Healthcheck `pg_isready` sur `postgres`, et
`condition: service_healthy` sur `backend`. Doublé d'un `try/except` autour de
`init_db()` pour ne jamais faire tomber l'API sur une indisponibilité de base.

### 14.4 Les erreurs CORS masquant les vraies erreurs

**Problème.** Une erreur 500 côté serveur apparaissait dans le navigateur comme
une erreur CORS, rendant le diagnostic impossible.

**Cause.** Les réponses d'erreur générées avant le `CORSMiddleware` partaient
sans en-têtes CORS.

**Solution.** Un middleware HTTP personnalisé qui repose les en-têtes en
`setdefault` sur **toutes** les réponses, y compris les erreurs.

### 14.5 Les variables d'environnement de Next.js

**Problème.** Après suppression de l'infrastructure cloud, l'interface web
continuait d'appeler l'ancienne URL Cloud Run **malgré** la variable
`NEXT_PUBLIC_API_BASE` correctement définie dans `docker-compose.yml`.

**Cause.** Next.js remplace `process.env.NEXT_PUBLIC_*` par sa valeur littérale
**au moment du build**. Une variable d'exécution arrive trop tard.

**Solution.** Passage de la variable en `build arg` dans `docker-compose.yml` et
réception par `ARG` dans le `Dockerfile`.

**Enseignement.** Distinguer variables de build et variables d'exécution est
essentiel — le symptôme est déroutant car la configuration semble correcte.

### 14.6 L'irrégularité des services de routage libres

**Problème.** Le calcul d'itinéraire échouait par intermittence.

**Cause.** Les instances publiques de Valhalla n'offrent aucune garantie de
disponibilité.

**Solution.** Stratégie à deux moteurs : Valhalla d'abord (instructions en
français), OSRM en repli (plus stable, anglophone).

### 14.7 Le compromis financier final

**Problème.** Maintenir Cloud Run au-delà des crédits gratuits impliquait une
facturation, incompatible avec un projet étudiant.

**Décision.** Suppression des comptes cloud et bascule sur Docker en
auto-hébergement.

**Conséquence.** L'URL de production ne répond plus. Trois points ont dû être
traités pour que le projet reste démontrable par un tiers : la correction du
build arg Next.js, la documentation de la reconfiguration de l'URL côté clients,
et la rédaction du guide d'installation Linux complet.

---

## 15. Limites connues et dette technique

### 15.1 Sécurité

Détaillée en [§11.2](#112-ce-qui-reste-insuffisant-et-pourquoi). En résumé :
**hachage SHA-256 sans sel, absence de jetons de session, CORS ouvert.** Le
backend n'est pas exposable sur Internet en l'état.

### 15.2 Architecture de l'application mobile

`main.dart` compte **4 618 lignes**. C'est trop pour un seul fichier : la
navigation y est pénible et le travail à plusieurs sur le même fichier génère des
conflits. Un découpage en widgets par onglet, avec un gestionnaire d'état
(Riverpod ou Bloc), serait la première refonte à mener.

### 15.3 Extraction de préférences par expressions régulières

La couverture linguistique est limitée. « Je n'aime pas le Nutella » est détecté ;
« le Nutella, très peu pour moi » ne l'est pas. Un appel LLM dédié, ou un modèle
de classification léger, améliorerait le rappel — au prix de la latence et du
déterminisme.

### 15.4 État de session en mémoire

Les sessions de passage en caisse vivent dans un dictionnaire Python. Un
redémarrage du conteneur les perd, et l'API ne peut pas être répartie sur
plusieurs instances. Redis serait la réponse naturelle si le besoin de montée en
charge apparaissait.

### 15.5 Couverture de tests partielle

Le module `users.py` (524 lignes) n'est couvert par aucun test. L'étape
« frontend » de la CI pointe vers un dossier inexistant et ne teste rien.

### 15.6 Fonctionnalités incomplètes

| Élément | État |
|---|---|
| `reservations.py` | Stub en mémoire, non relié à un système réel, non monté dans `main.py` |
| Modèle YOLO spécialisé | Scripts de préparation présents, entraînement non réalisé |
| Détection d'escaliers et bordures | Hors des 80 classes de COCO-SSD |
| `README.md` racine | Encodé en UTF-16 avec des caractères corrompus |

### 15.7 Identifiant d'application Android

L'`applicationId` reste `com.example.mobile_flutter`. Suffisant pour une
distribution directe d'APK, **refusé par Google Play**. La procédure de
changement est documentée dans le guide de génération de l'APK.

---

## 16. Perspectives

### 16.1 Court terme — corriger la dette

| Priorité | Action | Charge estimée |
|:-:|---|---|
| 🔴 | Remplacer SHA-256 par bcrypt ou Argon2 | 0,5 j |
| 🔴 | Authentification par jeton JWT | 2 j |
| 🔴 | Restreindre le CORS aux domaines de production | 0,5 j |
| 🟠 | Tests du module `users.py` | 2 j |
| 🟠 | Découpage de `main.dart` | 3 j |
| 🟡 | Corriger l'étape frontend de la CI | 0,5 j |

### 16.2 Moyen terme — fonctionnalités

- **Modèle YOLO spécialisé** entraîné sur des escaliers, bordures, portes et
  code-barres — les objets que COCO-SSD ignore, et les plus utiles ici.
- **Mode hors ligne** avec un modèle de vision embarqué pour les scénarios sans
  réseau.
- **Synchronisation multi-appareils** du profil et de l'historique.
- **Boucle de feedback effective** : la table `feedback` existe et est alimentée,
  mais son contenu n'influence pas encore les recommandations futures.
- **Réservations PMR réelles**, connectées à un système de transport.

### 16.3 Long terme

- Détection d'obstacles en temps réel embarquée sur mobile (TensorFlow Lite).
- Intégration avec les assistants vocaux du système (Google Assistant, Siri).
- Retour haptique en complément du vocal, pour les environnements bruyants.
- Validation auprès d'associations d'usagers — **la seule évaluation qui compte
  vraiment** pour un projet d'accessibilité.

---

## 17. Bilan

### 17.1 Ce qui a été livré

| Composant | Volume | État |
|---|--:|---|
| Backend FastAPI | 3 455 lignes | ✅ Fonctionnel |
| Application mobile Flutter | 5 283 lignes | ✅ Fonctionnelle, 5 onglets |
| Interface web Next.js | 785 lignes | ✅ Fonctionnelle |
| POC TensorFlow.js | 439 lignes | ✅ Démonstrateur |
| Base de données | 7 tables, 7 ENUM | ✅ Scriptée et documentée |
| Tests | 34 tests, 535 lignes | ⚠️ Couverture partielle |
| Scripts utilitaires | 204 lignes | ✅ |
| SQL livré | 1 170 lignes | ✅ |
| Documentation | 9 documents | ✅ |
| Conteneurisation | 3 services | ✅ Une commande |

**Environ 10 600 lignes de code**, hors documentation et fichiers générés.

### 17.2 Ce que le projet a apporté

**Sur le plan technique.** L'intégration de modèles d'IA dans une application
réelle est un exercice différent de leur usage en démonstration. La leçon
centrale du projet est que **les sorties de LLM sont des entrées non fiables**
et doivent être traitées comme telles : parsing défensif, tests des cas limites,
dégradation gracieuse.

**Sur le plan de la conception.** Le chaînage Gemini → Groq illustre qu'assembler
deux outils spécialisés donne souvent un meilleur résultat qu'un outil unique
polyvalent — tout en améliorant coût, traçabilité et protection des données.

**Sur le plan de l'accessibilité.** Concevoir pour des utilisateurs qui ne voient
pas l'écran change la nature du travail. Une interface visuellement réussie mais
inutilisable au clavier ou à la voix est un échec. Cette contrainte a rendu
l'application meilleure pour tout le monde.

**Sur le plan de l'industrialisation.** Le passage forcé du cloud à
l'auto-hébergement a été peu coûteux précisément parce que le projet était
conteneurisé dès le départ. C'est la validation la plus concrète de ce choix
initial.

### 17.3 Ce que nous ferions différemment

1. **Traiter la sécurité comme une fonctionnalité**, pas comme une finition. Le
   hachage SHA-256 a été écrit « en attendant » et n'a jamais été repris.
2. **Découper l'application mobile dès le départ.** `main.dart` a dépassé les
   1 500 lignes sans que la question soit posée, et il était alors trop tard pour
   refactoriser sans risque.
3. **Écrire les tests en même temps que le code.** Le module `checkout.py`, testé
   au fil de l'eau, est le plus fiable du projet. `users.py`, écrit sans tests,
   ne l'est pas.
4. **Anticiper la fin des crédits cloud.** La bascule a été gérée, mais dans
   l'urgence.

---

## 18. Annexes

### A. Volumétrie du projet

| Élément | Volume |
|---|--:|
| Backend Python (`backend/app/`) | 3 455 lignes · 12 fichiers |
| Tests Python (`backend/tests/`) | 535 lignes · 34 tests |
| Application Flutter (`mobile_flutter/lib/`) | 5 283 lignes · 2 fichiers |
| Interface Next.js (`web_next/src/`) | 785 lignes |
| POC TensorFlow.js (`poc-web/`) | 439 lignes |
| Scripts utilitaires (`scripts/`) | 204 lignes |
| SQL (`database/`) | 1 170 lignes |
| **Total code** | **≈ 10 600 lignes** |

### B. Inventaire des endpoints

| Méthode | Chemin | Rôle |
|---|---|---|
| `GET` | `/health` | Sonde de disponibilité |
| `POST` | `/api/describe/gemini` | Description d'une image |
| `POST` | `/api/describe/gemini/product` | Analyse produit deux faces |
| `POST` | `/api/describe/groq` | Recommandations personnalisées |
| `POST` | `/api/guidance/enrich` | Enrichissement d'une détection |
| `POST` | `/api/guidance/enrich/batch` | Enrichissement par lot |
| `POST` | `/api/guidance/advise` | Conseil personnalisé |
| `POST` | `/api/users/register` | Inscription |
| `POST` | `/api/users/login` | Connexion |
| `GET`/`PUT` | `/api/users/users/{id}/profile` | Profil PMR |
| `GET` | `/api/users/users/{id}/full-profile` | Profil agrégé pour le LLM |
| `GET`/`POST`/`DELETE` | `/api/users/users/{id}/allergies` | Allergies |
| `GET`/`POST`/`DELETE` | `/api/users/users/{id}/conditions` | Conditions médicales |
| `GET`/`POST`/`PUT`/`DELETE` | `/api/users/users/{id}/preferences` | Préférences |
| `POST` | `/api/users/users/{id}/extract-preferences` | Extraction automatique |
| `GET`/`POST` | `/api/users/users/{id}/interactions` | Historique |
| `POST` | `/api/users/feedback` | Retour utilisateur |
| `POST` | `/api/products/lookup` | Produit par code-barres |
| `POST` | `/api/products/identify` | Produit par photo du code-barres |
| `POST` | `/api/checkout/start` | Ouverture de session caisse |
| `GET`/`DELETE` | `/api/checkout/session/{id}` | État / fermeture de session |
| `POST` | `/api/checkout/belt/scan` | Scan du tapis |
| `POST` | `/api/checkout/belt/transfer` | Suivi du transfert |
| `POST` | `/api/checkout/forgotten` | Articles oubliés |
| `POST` | `/api/checkout/ticket/scan` | Lecture du ticket |
| `POST` | `/api/checkout/reconcile` | Rapprochement ticket / caddie |

> Le segment `users` apparaît doublé (`/api/users/users/...`) : le routeur est
> monté avec le préfixe `/api/users` et ses routes internes commencent
> elles-mêmes par `/users/{user_id}/`. La liste exacte reste consultable sur
> `/docs`.

### C. Services externes

| Service | Clé requise | Coût | Rôle |
|---|:-:|---|---|
| Google Gemini | ✅ | Gratuit (niveau AI Studio) | Vision, OCR |
| Groq | ✅ | Gratuit (quotas/minute) | Recommandations |
| Open Food Facts | ❌ | Libre | Données produits certifiées |
| OpenStreetMap | ❌ | Libre | Fond de carte |
| Nominatim / Overpass | ❌ | Libre | Recherche de lieux |
| Valhalla / OSRM | ❌ | Libre | Itinéraires piétons |
| Google Cloud Run | — | **Compte supprimé** | Remplacé par Docker |

### D. Documents du projet

| Document | Contenu |
|---|---|
| `docs_docker_.../INSTALLATION_LINUX.md` | Installation et déploiement Linux détaillés |
| `docs_docker_.../INSTALLATION.md` | Installation multiplateforme |
| `docs_docker_.../DEPLOYMENT.md` | Déploiement cloud (référence historique) |
| `docs_docker_.../ARCHITECTURE.md` | Architecture technique |
| `docs_docker_.../API.md` | Référence des endpoints |
| `docs_docker_.../DATABASE.md` | Dictionnaire de données |
| `docs_docker_.../GLOSSARY.md` | Glossaire |
| `database_.../README.md` | Dumps et scripts de création |
| `guide_apk_.../GUIDE_GENERATION_APK.md` | Génération de l'application mobile |
| `rapport_technique_.../RAPPORT_TECHNIQUE.md` | Ce document |

### E. Comment reproduire le projet

```bash
# 1. Backend + base + interface web
cp .env.example .env          # y renseigner GEMINI_API_KEY et GROQ_API_KEY
docker compose up -d --build
curl http://localhost:8000/health

# 2. Jeu d'essai de démonstration (facultatif)
docker compose exec -T postgres psql -U postgres -d vision360 \
  < database/02_seed_demo.sql

# 3. Application mobile
cd mobile_flutter
flutter pub get
flutter build apk --release

# 4. Tests
docker compose exec backend pytest tests/ -v
```

Procédures détaillées : `docs_docker_.../INSTALLATION_LINUX.md` et
`guide_apk_.../GUIDE_GENERATION_APK.md`.
