# 📖 Glossaire - Vision360

Ce glossaire définit les termes techniques et les acronymes utilisés dans le projet Vision360.

## Terminologie PMR

### Mobilité

| Terme | Définition |
|-------|------------|
| **PMR** | Personne à Mobilité Réduite - Individu ayant des difficultés à se déplacer de manière autonome (handicap moteur, visuel, auditif, cognitif) |
| **UFR** | Utilisateur de Fauteuil Roulant |
| **Fauteuil manuel** | Fauteuil roulant propulsé par l'utilisateur |
| **Fauteuil électrique** | Fauteuil roulant motorisé avec joystick |
| **Déambulateur** | Cadre de marche avec ou sans roues |
| **Canne blanche** | Canne utilisée par les personnes malvoyantes pour détecter les obstacles |

### Accessibilité

| Terme | Définition |
|-------|------------|
| **Accessibilité** | Conception permettant à tous d'accéder à un lieu, service ou produit |
| **Bande podotactile** | Surface texturée au sol guidant les malvoyants |
| **Rampe PMR** | Plan incliné permettant l'accès aux fauteuils roulants |
| **Ascenseur PMR** | Ascenseur adapté (boutons en braille, annonces vocales) |
| **Sanitaires PMR** | Toilettes adaptées (espace, barres d'appui) |
| **UFR compatible** | Installation accessible aux fauteuils roulants |

### Déficiences visuelles

| Terme | Définition |
|-------|------------|
| **Malvoyant** | Personne ayant une acuité visuelle réduite mais non nulle |
| **Non-voyant** | Personne ayant une cécité totale |
| **Basse vision** | Vision très diminuée non corrigible par lunettes |
| **DMLA** | Dégénérescence Maculaire Liée à l'Âge |
| **Braille** | Système d'écriture tactile pour aveugles |

## Terminologie technique

### Intelligence Artificielle

| Terme | Définition |
|-------|------------|
| **IA** | Intelligence Artificielle - Simulation de l'intelligence humaine par des machines |
| **ML** | Machine Learning - Apprentissage automatique à partir de données |
| **DL** | Deep Learning - Apprentissage profond utilisant des réseaux de neurones |
| **LLM** | Large Language Model - Grand modèle de langage (GPT, Llama, etc.) |
| **Vision par ordinateur** | Analyse et compréhension d'images par l'IA |
| **Multimodal** | Modèle capable de traiter plusieurs types de données (texte, image, audio) |

### Modèles et APIs

| Terme | Définition |
|-------|------------|
| **Gemini** | Modèle IA multimodal de Google (texte, image, audio) |
| **Groq** | Plateforme d'inférence LLM ultra-rapide |
| **Llama** | Modèle de langage open source de Meta |
| **COCO-SSD** | Modèle de détection d'objets pré-entraîné sur COCO |
| **TensorFlow.js** | Bibliothèque ML pour le navigateur |
| **YOLO** | You Only Look Once - Architecture de détection d'objets en temps réel |

### Détection d'objets

| Terme | Définition |
|-------|------------|
| **Bounding box** | Rectangle délimitant un objet détecté |
| **Confiance (score)** | Probabilité que la détection soit correcte (0-1) |
| **Classe** | Catégorie de l'objet détecté (personne, chaise, etc.) |
| **IoU** | Intersection over Union - Mesure de chevauchement de boîtes |
| **NMS** | Non-Maximum Suppression - Filtrage des détections redondantes |
| **Inférence** | Exécution du modèle sur de nouvelles données |

### Zones et positions

| Terme | Définition |
|-------|------------|
| **Zone near** | Obstacle proche (> 8% de l'image) |
| **Zone mid** | Obstacle à distance moyenne (3-8% de l'image) |
| **Zone far** | Obstacle éloigné (< 3% de l'image) |
| **Side left** | Position à gauche (< 33% de la largeur) |
| **Side center** | Position centrale (33-66% de la largeur) |
| **Side right** | Position à droite (> 66% de la largeur) |

### Synthèse vocale

| Terme | Définition |
|-------|------------|
| **TTS** | Text-to-Speech - Synthèse vocale, conversion texte en parole |
| **STT** | Speech-to-Text - Reconnaissance vocale, conversion parole en texte |
| **ASR** | Automatic Speech Recognition - Reconnaissance automatique de la parole |
| **Prosodie** | Intonation et rythme de la parole synthétisée |

## Acronymes du projet

| Acronyme | Signification |
|----------|---------------|
| **SAE** | Situation d'Apprentissage et d'Évaluation (projet universitaire) |
| **Vision360** | Nom du projet (vision à 360° pour l'assistance) |
| **POC** | Proof of Concept - Prototype de démonstration |
| **API** | Application Programming Interface |
| **REST** | Representational State Transfer (architecture API) |
| **CORS** | Cross-Origin Resource Sharing |
| **JWT** | JSON Web Token (authentification) |
| **UUID** | Universally Unique Identifier |

## Technologies utilisées

| Technologie | Description |
|-------------|-------------|
| **FastAPI** | Framework Python pour APIs REST modernes |
| **Pydantic** | Validation de données Python |
| **HTTPX** | Client HTTP asynchrone Python |
| **Flutter** | Framework UI cross-platform de Google |
| **Dart** | Langage de programmation pour Flutter |
| **Next.js** | Framework React pour applications web |
| **React** | Bibliothèque JavaScript pour interfaces utilisateur |
| **Docker** | Conteneurisation d'applications |
| **Cloud Run** | Service serverless de Google Cloud |

## Contextes d'utilisation

### Retail (Supermarché)

| Terme | Définition |
|-------|------------|
| **Rayon** | Étagère de produits dans un magasin |
| **Étiquette prix** | Affichage du prix d'un produit |
| **Code-barres** | Identifiant unique d'un produit |
| **Caddie** | Chariot de courses |
| **Allergène** | Substance pouvant provoquer une réaction allergique |
| **Nutri-Score** | Indicateur nutritionnel (A à E) |

### Restaurant

| Terme | Définition |
|-------|------------|
| **TPE** | Terminal de Paiement Électronique |
| **Plateau** | Support pour transporter repas |
| **Couverts** | Ustensiles de table (fourchette, couteau, cuillère) |
| **Menu** | Carte des plats disponibles |

### Navigation urbaine

| Terme | Définition |
|-------|------------|
| **Trottoir** | Partie surélevée de la voie publique pour piétons |
| **Passage piéton** | Zone de traversée sécurisée |
| **Dénivelé** | Différence de hauteur (marche, bordure) |
| **Cône de chantier** | Obstacle temporaire signalant des travaux |
| **Barrière** | Obstacle fixe limitant l'accès |
