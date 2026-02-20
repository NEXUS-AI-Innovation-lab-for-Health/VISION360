# Architecture Technique - Vision360

## Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              VISION360                                       │
│                    Écosystème d'assistance IA pour PMR                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                     │
│   │   Mobile    │    │     Web     │    │     POC     │                     │
│   │   Flutter   │    │   Next.js   │    │  TF.js      │                     │
│   │ Android/iOS │    │   React 19  │    │  COCO-SSD   │                     │
│   └──────┬──────┘    └──────┬──────┘    └──────┬──────┘                     │
│          │                  │                  │                             │
│          └──────────────────┼──────────────────┘                             │
│                             │                                                │
│                             ▼                                                │
│                   ┌─────────────────┐                                        │
│                   │  Backend API    │                                        │
│                   │    FastAPI      │                                        │
│                   │  Python 3.12   │                                        │
│                   └────────┬────────┘                                        │
│                            │                                                 │
│              ┌─────────────┴─────────────┐                                   │
│              ▼                           ▼                                   │
│    ┌─────────────────┐         ┌─────────────────┐                          │
│    │  Gemini Vision  │         │   Groq Cloud    │                          │
│    │  Google Cloud   │         │   Llama 3.1     │                          │
│    │  Analyse image  │         │ Recommandations │                          │
│    └─────────────────┘         └─────────────────┘                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Architecture par couches

```
┌───────────────────────────────────────────────────────────────┐
│                    COUCHE PRÉSENTATION                        │
├───────────────────┬───────────────────┬───────────────────────┤
│    Mobile App     │      Web App      │     POC Détection     │
│    Flutter 3.6    │    Next.js 16     │    TensorFlow.js      │
│   Dart + Camera   │  React 19 + TSX   │    COCO-SSD Model     │
│   flutter_tts     │  Web Speech API   │    Canvas + WebGL     │
└─────────┬─────────┴─────────┬─────────┴───────────┬───────────┘
          │                   │                     │
          │              HTTPS/REST                 │
          │                   │                     │
┌─────────▼───────────────────▼─────────────────────▼───────────┐
│                    COUCHE API GATEWAY                         │
├───────────────────────────────────────────────────────────────┤
│                      FastAPI Backend                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐   │
│  │    CORS     │  │  Routing    │  │   Validation        │   │
│  │ Middleware  │  │  /api/*     │  │   Pydantic          │   │
│  └─────────────┘  └─────────────┘  └─────────────────────┘   │
└───────────────────────────┬───────────────────────────────────┘
                            │
┌───────────────────────────▼───────────────────────────────────┐
│                    COUCHE MÉTIER                              │
├───────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌───────────────┐ │
│  │   describe.py   │  │   guidance.py   │  │reservations.py│ │
│  │                 │  │                 │  │               │ │
│  │ • Gemini API    │  │ • Enrichissement│  │ • CRUD        │ │
│  │ • Groq API      │  │ • Calcul risques│  │ • Réservations│ │
│  │ • Profils       │  │ • Conseils      │  │               │ │
│  └─────────────────┘  └─────────────────┘  └───────────────┘ │
└───────────────────────────┬───────────────────────────────────┘
                            │
┌───────────────────────────▼───────────────────────────────────┐
│                 COUCHE SERVICES EXTERNES                      │
├─────────────────────────────┬─────────────────────────────────┤
│      Google Gemini API      │         Groq Cloud API          │
│   gemini-2.0-flash-exp      │      llama-3.1-8b-instant       │
│   Vision multimodale        │      Génération texte           │
└─────────────────────────────┴─────────────────────────────────┘
```

---

## 2. Flux de données principal

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│          │     │          │     │          │     │          │     │          │
│ CAPTURE  │────▶│ ANALYSE  │────▶│ ENRICHI- │────▶│ SYNTHÈSE │────▶│ SORTIE   │
│          │     │          │     │ SSEMENT  │     │          │     │          │
└──────────┘     └──────────┘     └──────────┘     └──────────┘     └──────────┘
     │                │                │                │                │
     ▼                ▼                ▼                ▼                ▼
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│ Caméra   │     │ Gemini   │     │ Profil   │     │ Groq     │     │ TTS      │
│ Mobile   │     │ Vision   │     │ PMR      │     │ LLM      │     │ Vocale   │
│ Webcam   │     │ API      │     │ Allergies│     │ JSON     │     │ Texte    │
└──────────┘     └──────────┘     └──────────┘     └──────────┘     └──────────┘
```

### Détail du flux

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           FLUX COMPLET                                       │
└─────────────────────────────────────────────────────────────────────────────┘

1. CAPTURE
   ┌─────────────────┐
   │  📸 Image       │
   │  Base64 JPEG    │
   │  ~100-500 KB    │
   └────────┬────────┘
            │
            ▼
2. REQUÊTE GEMINI
   ┌─────────────────────────────────────────────────────────────┐
   │  POST /api/describe/gemini                                  │
   │  {                                                          │
   │    "image_b64": "/9j/4AAQ...",                              │
   │    "prompt": "Décris les objets visibles..."                │
   │  }                                                          │
   └─────────────────────────────────────────────────────────────┘
            │
            ▼
3. RÉPONSE GEMINI
   ┌─────────────────────────────────────────────────────────────┐
   │  {                                                          │
   │    "structured": {                                          │
   │      "text": "L'image montre un rayon de supermarché        │
   │               avec des chips, des cacahuètes et des         │
   │               barres chocolatées. Un panneau indique        │
   │               'Promotion -20%'."                            │
   │    }                                                        │
   │  }                                                          │
   └─────────────────────────────────────────────────────────────┘
            │
            ▼
4. REQUÊTE GROQ + PROFIL
   ┌─────────────────────────────────────────────────────────────┐
   │  POST /api/describe/groq                                    │
   │  {                                                          │
   │    "description": "L'image montre un rayon...",             │
   │    "profile_override": {                                    │
   │      "name": "Marie",                                       │
   │      "allergies": ["arachide", "gluten"],                   │
   │      "conditions": ["diabete"],                             │
   │      "mobility": "fauteuil"                                 │
   │    }                                                        │
   │  }                                                          │
   └─────────────────────────────────────────────────────────────┘
            │
            ▼
5. RÉPONSE GROQ (JSON)
   ┌─────────────────────────────────────────────────────────────┐
   │  {                                                          │
   │    "summary": "Rayon snacks avec produits à risque",        │
   │    "risks": [                                               │
   │      "Cacahuètes détectées - ALLERGIE ARACHIDE",            │
   │      "Barres chocolatées peuvent contenir gluten"           │
   │    ],                                                       │
   │    "actions": [                                             │
   │      "Éviter les cacahuètes",                               │
   │      "Vérifier étiquettes des barres",                      │
   │      "Les chips nature sont compatibles"                    │
   │    ]                                                        │
   │  }                                                          │
   └─────────────────────────────────────────────────────────────┘
            │
            ▼
6. SORTIE VOCALE (TTS)
   ┌─────────────────────────────────────────────────────────────┐
   │  🔊 "Synthèse. Rayon snacks avec produits à risque.         │
   │      Risques. Cacahuètes détectées, allergie arachide.      │
   │      Actions. Éviter les cacahuètes. Les chips nature       │
   │      sont compatibles."                                     │
   └─────────────────────────────────────────────────────────────┘
```

---

## 3. Architecture des composants

### 3.1 Backend FastAPI

```
backend/
│
├── app/
│   │
│   ├── main.py                 # Point d'entrée
│   │   │
│   │   ├── _load_env_file()    # Charge .env
│   │   ├── FastAPI()           # Instance app
│   │   ├── CORSMiddleware      # Autorise origines
│   │   ├── add_cors_headers()  # Middleware custom
│   │   └── /health             # Health check
│   │
│   ├── describe.py             # Module IA
│   │   │
│   │   ├── /api/describe/gemini
│   │   │   ├── Reçoit image base64
│   │   │   ├── Appelle Gemini API
│   │   │   └── Retourne description
│   │   │
│   │   └── /api/describe/groq
│   │       ├── Reçoit description + profil
│   │       ├── Appelle Groq API
│   │       └── Retourne JSON structuré
│   │
│   ├── guidance.py             # Module enrichissement
│   │   │
│   │   ├── /api/guidance/enrich
│   │   │   ├── Enrichit une détection
│   │   │   └── Ajoute description + risques
│   │   │
│   │   ├── /api/guidance/enrich/batch
│   │   │   └── Enrichit plusieurs détections
│   │   │
│   │   └── /api/guidance/advise
│   │       ├── Analyse détections
│   │       ├── Calcule priorité
│   │       └── Génère messages + canaux
│   │
│   └── reservations.py         # Module réservations
│       │
│       ├── POST /reservations  # Créer
│       ├── GET /reservations   # Lister
│       └── GET /reservations/{id}  # Détail
│
├── requirements.txt
└── Dockerfile
```

### 3.2 Application Mobile Flutter

```
mobile_flutter/lib/main.dart
│
├── Vision360App (StatelessWidget)
│   └── MaterialApp + ThemeData
│
└── HomeScreen (StatefulWidget)
    │
    ├── État
    │   ├── _tabIndex           # Navigation
    │   ├── _isAuthenticated    # Session
    │   ├── _cameraController   # Caméra
    │   ├── _tts                # Synthèse vocale
    │   ├── _history            # Historique
    │   └── _cooldownUntilMs    # Anti-spam
    │
    ├── Authentification
    │   ├── _loadUsers()        # Charge users
    │   ├── _handleAuth()       # Login/Register
    │   ├── _saveSession()      # Persiste session
    │   └── _logout()           # Déconnexion
    │
    ├── Caméra
    │   ├── _startCamera()      # Initialise
    │   ├── _stopCamera()       # Libère
    │   └── _captureImage()     # Capture base64
    │
    ├── API
    │   ├── _callChain()        # Gemini → Groq
    │   ├── _callGroqWithDescription()
    │   └── _callGroqManual()   # Avec texte
    │
    ├── TTS
    │   ├── _initTts()          # Configure fr-FR
    │   └── _speakGroq()        # Lit résultat
    │
    └── UI (3 onglets)
        ├── _buildProfileTab()  # Config
        ├── _buildGuidanceTab() # Caméra + API
        └── _buildHistoryTab()  # Historique
```

### 3.3 Application Web Next.js

```
web_next/src/app/
│
├── layout.tsx                  # Layout racine
│   ├── Metadata (SEO)
│   ├── Fonts (Geist)
│   └── <html><body>{children}
│
└── page.tsx                    # Page principale
    │
    ├── Types
    │   ├── Profile             # Profil utilisateur
    │   └── HistoryItem         # Élément historique
    │
    ├── État (useState)
    │   ├── apiBase             # URL API
    │   ├── profile             # Profil santé
    │   ├── imageB64            # Image capturée
    │   ├── geminiText          # Résultat Gemini
    │   ├── groqJson            # Résultat Groq
    │   ├── cameraOn            # État caméra
    │   ├── listening           # État micro
    │   └── history             # Historique
    │
    ├── Refs (useRef)
    │   ├── videoRef            # Element <video>
    │   └── canvasRef           # Element <canvas>
    │
    ├── Fonctions
    │   ├── startCamera()       # MediaDevices API
    │   ├── stopCamera()        # Arrête stream
    │   ├── captureFrame()      # Canvas → base64
    │   ├── callGemini()        # POST /describe/gemini
    │   ├── callGroq()          # POST /describe/groq
    │   ├── callChain()         # Gemini → Groq
    │   └── startListening()    # Web Speech API
    │
    └── Rendu JSX
        ├── Header (API config)
        ├── Card Profil
        ├── Card Gemini (caméra)
        ├── Card Groq (vocal)
        └── Section Historique
```

### 3.4 POC TensorFlow.js

```
poc-web/index.html
│
├── Interface HTML
│   ├── #toolbar                # Contrôles
│   ├── #stage                  # Video + Canvas
│   ├── #labels                 # Détections
│   └── #guidance               # Résultats API
│
├── Configuration
│   ├── confThr = 0.5           # Seuil confiance
│   ├── minArea = 0.02          # Aire minimale
│   ├── stride = 1              # Inférence 1/N
│   └── allowedClasses          # Filtre classes
│
├── Ontologie (ontology.json)
│   ├── obstacles               # person, stairs...
│   ├── retail                  # product, shelf...
│   ├── restaurant              # table, chair...
│   └── general                 # COCO 80 classes
│
├── Pipeline détection
│   │
│   ├── setupCamera()
│   │   └── getUserMedia({ video: { facingMode: 'environment' } })
│   │
│   ├── loadModel()
│   │   └── cocoSsd.load({ base: 'lite_mobilenet_v2' })
│   │
│   └── loop()
│       ├── drawImage(video → canvas)
│       ├── model.detect(canvas, 20)
│       ├── filter(score, area, class)
│       ├── sideAndZone(bbox)
│       │   ├── side: left|center|right
│       │   └── zone: near|mid|far
│       ├── drawRect + labels
│       └── requestAnimationFrame(loop)
│
└── Intégration API
    ├── geminiBtn → POST /describe/gemini
    └── groqBtn → POST /describe/groq
```

---

## 4. Modèle de données

### 4.1 Profil utilisateur

```
┌─────────────────────────────────────────┐
│              PROFILE                    │
├─────────────────────────────────────────┤
│  name: string                           │
│  allergies: string[]                    │
│  conditions: string[]                   │
│  preferences: string[]                  │
│  mobility: "fauteuil"|"canne"|"marche"  │
│  tts_enabled: boolean                   │
└─────────────────────────────────────────┘

Exemple :
{
  "name": "Marie Dupont",
  "allergies": ["arachide", "gluten"],
  "conditions": ["diabete", "hypertension"],
  "preferences": ["sans sucre", "bio"],
  "mobility": "fauteuil",
  "tts_enabled": true
}
```

### 4.2 Détection

```
┌─────────────────────────────────────────┐
│             DETECTION                   │
├─────────────────────────────────────────┤
│  class: string          # "person"      │
│  score: float           # 0.0 - 1.0     │
│  zone: "near"|"mid"|"far"               │
│  side: "left"|"center"|"right"          │
│  ocr?: string           # Texte lu      │
│  context?: string       # "retail"      │
└─────────────────────────────────────────┘
```

### 4.3 Enrichissement

```
┌─────────────────────────────────────────┐
│          ENRICH_RESPONSE                │
├─────────────────────────────────────────┤
│  summary: string        # "Escalier"    │
│  attributes: {                          │
│    zone: string                         │
│    side: string                         │
│    score: string                        │
│  }                                      │
│  risks: string[]        # Alertes       │
│  class_name: string                     │
│  zone: string                           │
│  side: string                           │
└─────────────────────────────────────────┘
```

### 4.4 Recommandation Groq

```
┌─────────────────────────────────────────┐
│         GROQ_RESPONSE                   │
├─────────────────────────────────────────┤
│  summary: string                        │
│  risks: string[]                        │
│  actions: string[]                      │
└─────────────────────────────────────────┘

Exemple :
{
  "summary": "Rayon snacks avec allergènes",
  "risks": [
    "Cacahuètes - ALLERGIE",
    "Traces de gluten possibles"
  ],
  "actions": [
    "Éviter cacahuètes",
    "Chips nature OK",
    "Vérifier étiquettes"
  ]
}
```

---

## 5. Sécurité et configuration

### 5.1 Variables d'environnement

```
┌─────────────────────────────────────────────────────────────┐
│                    .env (Backend)                           │
├─────────────────────────────────────────────────────────────┤
│  GEMINI_API_KEY=AIza...                 # Clé Google        │
│  GEMINI_MODEL=gemini-2.0-flash-exp      # Modèle vision     │
│  GEMINI_API_VERSION=v1beta                                  │
│                                                             │
│  GROQ_API_KEY=gsk_...                   # Clé Groq          │
│  GROQ_MODEL=llama-3.1-8b-instant        # Modèle LLM        │
│                                                             │
│  PORT=8000                              # Port serveur      │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Flux d'authentification (Mobile)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Login     │────▶│ SharedPrefs │────▶│  Session    │
│   Screen    │     │  (local)    │     │  Active     │
└─────────────┘     └─────────────┘     └─────────────┘
                          │
                          ▼
                    ┌─────────────┐
                    │  Profil     │
                    │  Historique │
                    │  (par user) │
                    └─────────────┘

Clés de stockage :
- vision360_users      → {email: password}
- vision360_session    → email connecté
- vision360_profile_X  → profil de X
- vision360_history_X  → historique de X
```

---

## 6. Déploiement

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          INFRASTRUCTURE                                      │
└─────────────────────────────────────────────────────────────────────────────┘

                        ┌─────────────────┐
                        │   Utilisateur   │
                        └────────┬────────┘
                                 │
                 ┌───────────────┼───────────────┐
                 │               │               │
                 ▼               ▼               ▼
        ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
        │   Mobile    │ │    Web      │ │    POC      │
        │  App Store  │ │   Vercel    │ │  Static     │
        │ Play Store  │ │             │ │  Hosting    │
        └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
               │               │               │
               └───────────────┼───────────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Google Cloud Run  │
                    │   Backend FastAPI   │
                    │   (Serverless)      │
                    └──────────┬──────────┘
                               │
                 ┌─────────────┴─────────────┐
                 │                           │
                 ▼                           ▼
        ┌─────────────────┐         ┌─────────────────┐
        │  Google Cloud   │         │   Groq Cloud    │
        │  Gemini API     │         │   Llama API     │
        └─────────────────┘         └─────────────────┘
```

### Docker Compose (développement)

```yaml
services:
  backend:
    build: ./backend
    ports: ["8000:8000"]
    env_file: .env

  web_next:
    build: ./web_next
    ports: ["3000:3000"]
    environment:
      NEXT_PUBLIC_API_BASE: "http://localhost:8000/api"
    depends_on: [backend]
```

---

## 7. Performances et optimisations

### 7.1 Latences typiques

| Opération | Latence | Optimisation |
|-----------|---------|--------------|
| Capture image | ~100ms | Résolution medium |
| Appel Gemini | 2-4s | Modèle flash |
| Appel Groq | 1-2s | Modèle 8b-instant |
| TTS | ~500ms | Pré-chargé |
| **Total** | **4-7s** | |

### 7.2 Optimisations implémentées

```
┌─────────────────────────────────────────────────────────────┐
│                     OPTIMISATIONS                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ⏱️  Cooldown 60s          Évite surcharge API             │
│                                                             │
│  📦  Compression JPEG 0.8   Réduit taille upload           │
│                                                             │
│  ⚡  httpx async            Appels non-bloquants           │
│                                                             │
│  🔄  Stride (POC)           Inférence 1 frame sur N        │
│                                                             │
│  💾  SharedPreferences      Persistance locale rapide      │
│                                                             │
│  🎯  Modèles légers         gemini-flash, llama-8b         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 8. Évolutions prévues

```
┌─────────────────────────────────────────────────────────────┐
│                    ROADMAP TECHNIQUE                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Phase 1 (Actuel)                                           │
│  ├── ✅ COCO-SSD pour détection                            │
│  ├── ✅ Gemini Vision pour description                     │
│  ├── ✅ Groq pour recommandations                          │
│  └── ✅ TTS français                                       │
│                                                             │
│  Phase 2 (Court terme)                                      │
│  ├── 🔄 Modèle YOLO custom (datasets préparés)             │
│  ├── 🔄 OCR pour lecture étiquettes                        │
│  └── 🔄 Reconnaissance vocale native (mobile)              │
│                                                             │
│  Phase 3 (Moyen terme)                                      │
│  ├── 📋 Mode hors-ligne (modèle embarqué)                  │
│  ├── 📋 Intégration GPS + navigation                       │
│  └── 📋 Retour haptique (vibrations)                       │
│                                                             │
│  Phase 4 (Long terme)                                       │
│  ├── 📋 Partenariats (Carrefour, SNCF)                     │
│  ├── 📋 Profondeur (LiDAR/ARCore)                          │
│  └── 📋 Multi-langues                                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```
