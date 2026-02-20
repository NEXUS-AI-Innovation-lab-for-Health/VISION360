# Guide Complet pour l'Entretien - Vision360

## Comment utiliser ce guide

Ce document explique **TOUT** le projet de manière simple. Lis-le plusieurs fois avant l'entretien. Les questions probables du jury sont indiquées avec ❓.

---

# PARTIE 1 : C'EST QUOI LE PROJET ?

## En une phrase
> Vision360 est une application qui aide les personnes malvoyantes et en fauteuil roulant en leur **décrivant ce qu'ils voient** grâce à l'intelligence artificielle.

## Comment ça marche (version simple)

```
1. L'utilisateur prend une photo avec son téléphone
                    ↓
2. La photo est envoyée à une IA (Gemini) qui la décrit
   "Je vois un rayon de supermarché avec des chips et des cacahuètes"
                    ↓
3. Cette description + le profil de l'utilisateur (allergies, etc.)
   sont envoyés à une autre IA (Groq)
                    ↓
4. Groq génère des conseils personnalisés
   "Attention : cacahuètes détectées, vous êtes allergique !"
                    ↓
5. Le téléphone LIT à voix haute les conseils
```

## ❓ Questions possibles du jury

**Q : Pourquoi deux IA et pas une seule ?**
> R : Gemini est spécialisé dans l'analyse d'images (il "voit"). Groq est spécialisé dans la génération de texte intelligent. Chacun fait ce qu'il sait faire le mieux. C'est comme avoir un photographe ET un rédacteur plutôt qu'une seule personne qui fait les deux moins bien.

**Q : Pourquoi ce projet ?**
> R : 1,7 million de personnes sont malvoyantes en France. Elles ont du mal à faire leurs courses, lire les menus au restaurant, détecter les obstacles. Notre app les aide au quotidien.

**Q : C'est quoi PMR ?**
> R : Personne à Mobilité Réduite. Ça inclut les personnes en fauteuil roulant, avec une canne, malvoyantes, etc.

---

# PARTIE 2 : L'ARCHITECTURE (Les différentes parties du projet)

## Vue globale

```
┌─────────────────────────────────────────────────────────────┐
│                    CE QUE L'UTILISATEUR UTILISE             │
│                                                             │
│   📱 App Mobile        🌐 Site Web         🧪 POC           │
│   (Flutter)            (Next.js)           (TensorFlow)     │
│                                                             │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          │ Les apps envoient des requêtes HTTP
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    NOTRE SERVEUR (Backend)                  │
│                                                             │
│                      FastAPI (Python)                       │
│                                                             │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          │ Le serveur appelle les IA externes
                          │
            ┌─────────────┴─────────────┐
            ▼                           ▼
┌─────────────────────┐      ┌─────────────────────┐
│   GEMINI (Google)   │      │   GROQ (Startup)    │
│                     │      │                     │
│   Comprend les      │      │   Génère du texte   │
│   images            │      │   intelligent       │
└─────────────────────┘      └─────────────────────┘
```

## ❓ Questions possibles

**Q : Pourquoi avoir un serveur backend ? Pourquoi pas appeler Gemini directement depuis l'app ?**
> R : Pour la SÉCURITÉ. Les clés API (les "mots de passe" pour utiliser Gemini et Groq) sont secrètes. Si on les mettait dans l'app mobile, n'importe qui pourrait les récupérer et utiliser notre compte. Le backend garde les clés secrètes.

**Q : C'est quoi la différence entre Frontend et Backend ?**
> R :
> - **Frontend** = Ce que l'utilisateur voit et touche (l'app mobile, le site web)
> - **Backend** = Le serveur qui fait le travail en coulisses (invisible pour l'utilisateur)

---

# PARTIE 3 : LE BACKEND (Python/FastAPI)

## C'est quoi FastAPI ?
FastAPI est un **framework Python** pour créer des APIs (des serveurs qui répondent à des requêtes).

**Analogie** : FastAPI c'est comme un serveur de restaurant. Le client (l'app) passe une commande, le serveur (FastAPI) transmet à la cuisine (Gemini/Groq), et ramène le plat.

## Les fichiers du backend

```
backend/
├── app/
│   ├── main.py          ← Point d'entrée (lance le serveur)
│   ├── describe.py      ← Endpoints pour Gemini et Groq
│   ├── guidance.py      ← Enrichissement des détections
│   └── reservations.py  ← Gestion des réservations (bonus)
├── requirements.txt     ← Liste des dépendances Python
└── Dockerfile           ← Instructions pour Docker
```

## main.py expliqué simplement

```python
# main.py - Le fichier principal

# 1. On importe FastAPI (le framework)
from fastapi import FastAPI

# 2. On crée l'application
app = FastAPI(title="Vision360 API")

# 3. On configure CORS (pour que le site web puisse appeler notre API)
# CORS = Cross-Origin Resource Sharing
# Sans ça, le navigateur bloque les requêtes vers notre serveur
app.add_middleware(CORSMiddleware, allow_origins=["*"])  # "*" = tout le monde peut appeler

# 4. On ajoute un endpoint simple pour vérifier que le serveur marche
@app.get("/health")
def health():
    return {"status": "ok"}

# 5. On branche les autres fichiers (describe.py, guidance.py)
app.include_router(describe_router, prefix="/api")
```

## ❓ Questions sur main.py

**Q : C'est quoi un endpoint ?**
> R : C'est une URL sur le serveur qui fait quelque chose. Par exemple `/health` est un endpoint qui répond "ok". `/api/describe/gemini` est un endpoint qui analyse une image.

**Q : C'est quoi CORS ?**
> R : C'est une sécurité du navigateur. Par défaut, un site web sur `localhost:3000` ne peut pas appeler un serveur sur `localhost:8000`. CORS dit au navigateur "c'est OK, laisse passer".

**Q : Pourquoi `allow_origins=["*"]` ?**
> R : Le `*` veut dire "tout le monde". C'est pratique pour le développement. En production, on mettrait les vrais domaines autorisés.

## describe.py expliqué simplement

```python
# describe.py - Les endpoints pour l'IA

# === ENDPOINT GEMINI ===
@router.post("/describe/gemini")
async def describe_gemini(payload: DescribeRequest):
    """
    Reçoit une image, l'envoie à Gemini, retourne la description.
    """

    # 1. On récupère l'image en base64
    image_b64 = payload.image_b64

    # 2. On construit la requête pour Gemini
    body = {
        "contents": [{
            "parts": [
                {"text": "Décris cette image"},  # Le prompt
                {"inline_data": {"data": image_b64}}  # L'image
            ]
        }]
    }

    # 3. On appelle l'API Gemini
    response = await client.post(GEMINI_URL, json=body)

    # 4. On extrait le texte de la réponse
    text = response.json()["candidates"][0]["content"]["parts"][0]["text"]

    # 5. On retourne
    return {"structured": {"text": text}}


# === ENDPOINT GROQ ===
@router.post("/describe/groq")
async def describe_groq(payload: GroqRequest):
    """
    Reçoit une description + profil, génère des recommandations.
    """

    # 1. On construit le prompt avec le profil utilisateur
    prompt = f"""
    L'utilisateur a ces allergies : {payload.profile["allergies"]}
    Description de la scène : {payload.description}

    Génère des conseils en JSON.
    """

    # 2. On appelle Groq
    response = await client.post(GROQ_URL, json={
        "model": "llama-3.1-8b-instant",
        "messages": [{"role": "user", "content": prompt}]
    })

    # 3. On retourne le JSON généré
    return {"structured": response.json()["choices"][0]["message"]["content"]}
```

## ❓ Questions sur describe.py

**Q : C'est quoi base64 ?**
> R : C'est une façon de transformer une image (des données binaires) en texte. Ça permet d'envoyer l'image dans une requête JSON. Exemple : `/9j/4AAQSkZJRgABAQ...` c'est une image en base64.

**Q : C'est quoi `async` ?**
> R : Ça veut dire "asynchrone". Le serveur peut traiter plusieurs requêtes en même temps sans attendre. Quand on appelle Gemini (ça prend 3 secondes), le serveur peut faire autre chose en attendant.

**Q : Pourquoi Llama 3.1 et pas GPT ?**
> R : Groq utilise Llama (modèle open source de Meta). C'est gratuit et très rapide. GPT d'OpenAI serait payant.

## guidance.py expliqué simplement

```python
# guidance.py - Enrichissement des détections

# Dictionnaire de descriptions en français
OBSTACLE_DESCRIPTIONS = {
    "person": "Personne à proximité",
    "stairs": "Escalier",
    "puddle": "Zone glissante",
}

def describe_detection(detection):
    """
    Prend une détection brute et l'enrichit.

    Entrée : {"class": "stairs", "score": 0.95, "zone": "near"}
    Sortie : {"summary": "Escalier", "risks": ["Obstacle proche", "Prévoir montée"]}
    """

    # 1. Traduire la classe en français
    summary = OBSTACLE_DESCRIPTIONS.get(detection.class_name, "Objet inconnu")

    # 2. Calculer les risques
    risks = []
    if detection.zone == "near":
        risks.append("Obstacle proche")
    if detection.class_name == "stairs":
        risks.append("Prévoir montée/descente")

    return {"summary": summary, "risks": risks}
```

## ❓ Questions sur guidance.py

**Q : C'est quoi "zone" et "side" ?**
> R :
> - **Zone** = distance de l'objet. `near` = proche, `mid` = moyen, `far` = loin
> - **Side** = position. `left` = à gauche, `center` = au centre, `right` = à droite
> On calcule ça en regardant la taille et la position de la boîte de détection.

---

# PARTIE 4 : L'APPLICATION MOBILE (Flutter)

## C'est quoi Flutter ?
Flutter est un **framework de Google** pour créer des applications mobiles. On écrit le code UNE FOIS en Dart, et ça marche sur Android ET iOS.

## Structure simplifiée de main.dart

```dart
// main.dart - L'application mobile complète (900+ lignes)

// 1. Point d'entrée
void main() {
  runApp(Vision360App());  // Lance l'app
}

// 2. Widget principal
class Vision360App extends StatelessWidget {
  Widget build(context) {
    return MaterialApp(
      title: 'Vision360',
      home: HomeScreen(),  // L'écran principal
    );
  }
}

// 3. Écran principal (avec état)
class HomeScreen extends StatefulWidget { ... }

class _HomeScreenState extends State<HomeScreen> {

  // === VARIABLES D'ÉTAT ===
  int _tabIndex = 0;              // Onglet actif (Profil, Guidance, Historique)
  bool _isAuthenticated = false;  // L'utilisateur est-il connecté ?
  CameraController? _camera;      // Contrôleur de la caméra
  FlutterTts _tts;                // Synthèse vocale

  // === MÉTHODES PRINCIPALES ===

  Future<void> _startCamera() async {
    // Démarre la caméra
    final cameras = await availableCameras();
    _camera = CameraController(cameras.first, ResolutionPreset.medium);
    await _camera.initialize();
  }

  Future<String> _captureImage() async {
    // Prend une photo et la convertit en base64
    final photo = await _camera.takePicture();
    final bytes = await photo.readAsBytes();
    return base64Encode(bytes);  // Retourne l'image en texte
  }

  Future<void> _callChain() async {
    // La chaîne complète : capture → Gemini → Groq → TTS

    // 1. Capturer l'image
    final imageB64 = await _captureImage();

    // 2. Appeler Gemini
    final geminiResponse = await http.post(
      Uri.parse('$apiBase/describe/gemini'),
      body: jsonEncode({'image_b64': imageB64}),
    );
    final description = geminiResponse['structured']['text'];

    // 3. Appeler Groq avec le profil
    final groqResponse = await http.post(
      Uri.parse('$apiBase/describe/groq'),
      body: jsonEncode({
        'description': description,
        'profile_override': {
          'allergies': ['arachide'],
          'mobility': 'fauteuil',
        },
      }),
    );

    // 4. Lire à voix haute
    final conseils = groqResponse['structured'];
    await _tts.speak("Risques: ${conseils['risks'].join(', ')}");
  }

  // === INTERFACE ===
  Widget build(context) {
    return Scaffold(
      body: /* 3 onglets : Profil, Guidance, Historique */,
      bottomNavigationBar: NavigationBar(/* ... */),
    );
  }
}
```

## ❓ Questions sur Flutter

**Q : C'est quoi StatelessWidget vs StatefulWidget ?**
> R :
> - **StatelessWidget** = Ne change jamais (ex: un texte fixe)
> - **StatefulWidget** = Peut changer (ex: un bouton qui change de couleur quand on clique)
>
> `HomeScreen` est Stateful car la caméra s'active, les résultats changent, etc.

**Q : C'est quoi `async` et `await` ?**
> R : `async` = la fonction peut attendre. `await` = on attend que ça finisse.
> Exemple : `await _camera.takePicture()` → on attend que la photo soit prise avant de continuer.

**Q : Comment marche la caméra ?**
> R : On utilise le package `camera`.
> 1. `availableCameras()` → liste les caméras du téléphone
> 2. `CameraController()` → on en choisit une
> 3. `takePicture()` → on prend la photo

**Q : Comment marche le TTS (Text-to-Speech) ?**
> R : On utilise le package `flutter_tts`.
> 1. `setLanguage('fr-FR')` → on choisit le français
> 2. `speak("Bonjour")` → le téléphone dit "Bonjour"

**Q : Comment vous sauvegardez les données localement ?**
> R : Avec `SharedPreferences`. C'est un stockage clé-valeur simple.
> ```dart
> // Sauvegarder
> prefs.setString('user_email', 'jean@email.com');
> // Charger
> String email = prefs.getString('user_email');
> ```

**Q : Pourquoi un cooldown de 60 secondes ?**
> R : Pour éviter de surcharger les APIs (et dépenser trop de crédits). L'utilisateur doit attendre 1 minute entre chaque envoi.

---

# PARTIE 5 : L'APPLICATION WEB (Next.js)

## C'est quoi Next.js ?
Next.js est un **framework React** pour créer des sites web modernes. React c'est pour créer des interfaces, Next.js ajoute le routage, le rendu serveur, etc.

## Structure simplifiée de page.tsx

```typescript
// page.tsx - La page principale du site web

"use client";  // Composant côté client (pas serveur)

export default function Home() {

  // === ÉTAT (useState) ===
  const [apiBase, setApiBase] = useState("http://...");  // URL du backend
  const [profile, setProfile] = useState({               // Profil utilisateur
    name: "Utilisateur",
    allergies: ["arachide"],
    mobility: "fauteuil",
  });
  const [imageB64, setImageB64] = useState("");          // Image capturée
  const [geminiText, setGeminiText] = useState("");      // Résultat Gemini
  const [groqJson, setGroqJson] = useState("");          // Résultat Groq
  const [cameraOn, setCameraOn] = useState(false);       // Caméra active ?

  // === RÉFÉRENCES (useRef) ===
  const videoRef = useRef<HTMLVideoElement>(null);  // Element <video>
  const canvasRef = useRef<HTMLCanvasElement>(null); // Element <canvas>

  // === FONCTIONS ===

  const startCamera = async () => {
    // Demande accès à la webcam
    const stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: "environment" },  // Caméra arrière si dispo
    });
    videoRef.current.srcObject = stream;  // Affiche le flux dans <video>
    setCameraOn(true);
  };

  const captureFrame = () => {
    // Capture la frame actuelle de la vidéo
    const ctx = canvasRef.current.getContext("2d");
    ctx.drawImage(videoRef.current, 0, 0);  // Dessine la vidéo sur le canvas
    return canvasRef.current.toDataURL("image/jpeg");  // Exporte en base64
  };

  const callChain = async () => {
    // Même logique que Flutter : Gemini → Groq
    const image = captureFrame();

    // Appel Gemini
    const geminiRes = await fetch(`${apiBase}/describe/gemini`, {
      method: "POST",
      body: JSON.stringify({ image_b64: image }),
    });
    const geminiData = await geminiRes.json();
    setGeminiText(geminiData.structured.text);

    // Appel Groq
    const groqRes = await fetch(`${apiBase}/describe/groq`, {
      method: "POST",
      body: JSON.stringify({
        description: geminiData.structured.text,
        profile_override: profile,
      }),
    });
    const groqData = await groqRes.json();
    setGroqJson(JSON.stringify(groqData.structured, null, 2));
  };

  // === INTERFACE ===
  return (
    <div>
      <video ref={videoRef} />          {/* Flux de la webcam */}
      <canvas ref={canvasRef} hidden /> {/* Canvas caché pour capture */}

      <button onClick={startCamera}>Activer caméra</button>
      <button onClick={callChain}>Analyser</button>

      <pre>{geminiText}</pre>  {/* Affiche le résultat Gemini */}
      <pre>{groqJson}</pre>    {/* Affiche le résultat Groq */}
    </div>
  );
}
```

## ❓ Questions sur Next.js/React

**Q : C'est quoi `useState` ?**
> R : C'est un "hook" React pour gérer l'état. Quand la valeur change, l'interface se met à jour automatiquement.
> ```typescript
> const [count, setCount] = useState(0);  // count = 0
> setCount(5);  // count devient 5, l'interface se rafraîchit
> ```

**Q : C'est quoi `useRef` ?**
> R : C'est pour accéder directement à un élément HTML. On l'utilise pour le `<video>` car on a besoin de manipuler le flux vidéo.

**Q : Pourquoi `"use client"` ?**
> R : Next.js peut rendre les pages côté serveur ou côté client. Ici on utilise la webcam, donc ça doit être côté client (dans le navigateur).

**Q : Comment marche la webcam ?**
> R : Avec l'API `navigator.mediaDevices.getUserMedia()`. Ça demande la permission à l'utilisateur puis retourne un flux vidéo qu'on affiche dans un `<video>`.

**Q : Comment marche la reconnaissance vocale ?**
> R : Avec l'API Web Speech :
> ```typescript
> const recognition = new SpeechRecognition();
> recognition.lang = "fr-FR";
> recognition.onresult = (event) => {
>   const texte = event.results[0][0].transcript;
>   console.log("Vous avez dit :", texte);
> };
> recognition.start();
> ```

---

# PARTIE 6 : LE POC TENSORFLOW.JS

## C'est quoi le POC ?
POC = Proof of Concept (Preuve de concept). C'est un prototype qui montre que la détection temps réel est possible DANS LE NAVIGATEUR, sans serveur.

## Comment ça marche

```
┌─────────────────────────────────────────────────────────────┐
│                    NAVIGATEUR WEB                           │
│                                                             │
│   ┌─────────┐     ┌─────────┐     ┌─────────┐              │
│   │ Webcam  │────▶│ COCO-SSD│────▶│ Canvas  │              │
│   │ (vidéo) │     │ (IA)    │     │(affiche)│              │
│   └─────────┘     └─────────┘     └─────────┘              │
│                        │                                    │
│                        ▼                                    │
│                   Détections :                              │
│                   - person (95%)                            │
│                   - chair (87%)                             │
│                   - bottle (72%)                            │
└─────────────────────────────────────────────────────────────┘
```

## Code simplifié

```javascript
// Charger le modèle COCO-SSD
const model = await cocoSsd.load();

// Boucle de détection (30 fois par seconde)
function loop() {
  // 1. Dessiner la vidéo sur le canvas
  ctx.drawImage(video, 0, 0);

  // 2. Faire la détection
  const predictions = await model.detect(canvas);
  // predictions = [{class: "person", score: 0.95, bbox: [x,y,w,h]}, ...]

  // 3. Dessiner les boîtes
  for (const pred of predictions) {
    ctx.strokeRect(pred.bbox[0], pred.bbox[1], pred.bbox[2], pred.bbox[3]);
    ctx.fillText(`${pred.class} ${Math.round(pred.score*100)}%`, ...);
  }

  // 4. Recommencer
  requestAnimationFrame(loop);
}
```

## ❓ Questions sur le POC

**Q : C'est quoi COCO-SSD ?**
> R : C'est un modèle de détection d'objets pré-entraîné sur le dataset COCO (80 classes : personne, chaise, voiture, etc.). SSD = Single Shot Detector, une architecture rapide.

**Q : Pourquoi TensorFlow.js et pas Python ?**
> R : TensorFlow.js tourne DANS LE NAVIGATEUR. Pas besoin de serveur. L'IA tourne sur l'ordinateur de l'utilisateur.

**Q : C'est quoi l'ontologie ?**
> R : C'est le fichier `ontology.json` qui définit les catégories d'objets à détecter selon le contexte :
> - **obstacles** : person, stairs, puddle...
> - **retail** : product, shelf, bottle...
> - **restaurant** : table, chair, menu...

**Q : Pourquoi le POC n'utilise pas YOLO ?**
> R : COCO-SSD est plus simple à utiliser dans le navigateur. YOLO nécessite plus de configuration. Le POC est juste une démonstration, pas le produit final.

---

# PARTIE 7 : DOCKER

## C'est quoi Docker ?
Docker permet de "containeriser" une application. C'est comme une boîte qui contient tout ce dont l'app a besoin pour fonctionner (code, dépendances, configuration).

**Analogie** : C'est comme un plat surgelé. Tout est dedans, prêt à être réchauffé n'importe où.

## Dockerfile du backend expliqué

```dockerfile
# Dockerfile - Instructions pour construire l'image

# 1. Image de base : Python 3.12 (version légère)
FROM python:3.12-slim

# 2. Dossier de travail dans le conteneur
WORKDIR /app

# 3. Variables d'environnement Python
ENV PYTHONDONTWRITEBYTECODE=1  # Pas de fichiers .pyc
ENV PYTHONUNBUFFERED=1         # Logs en temps réel

# 4. Copier et installer les dépendances
COPY backend/requirements.txt ./
RUN pip install -r requirements.txt

# 5. Copier le code
COPY backend/app ./app

# 6. Port exposé
EXPOSE 8000

# 7. Commande de démarrage
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## docker-compose.yml expliqué

```yaml
# docker-compose.yml - Lance plusieurs conteneurs ensemble

services:
  # Service 1 : Le backend Python
  backend:
    build:
      context: .
      dockerfile: backend/Dockerfile
    ports:
      - "8000:8000"    # Port local:port conteneur
    env_file:
      - .env           # Charge les variables d'environnement

  # Service 2 : Le frontend Next.js
  web_next:
    build:
      context: ./web_next
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      NEXT_PUBLIC_API_BASE: "http://localhost:8000/api"
    depends_on:
      - backend        # Attend que le backend soit prêt
```

## Commandes Docker essentielles

```bash
# Construire et lancer
docker compose up --build

# Lancer en arrière-plan
docker compose up -d

# Voir les logs
docker compose logs -f

# Arrêter
docker compose down

# Reconstruire un service
docker compose build backend
```

## ❓ Questions sur Docker

**Q : C'est quoi la différence entre une image et un conteneur ?**
> R :
> - **Image** = La recette (le Dockerfile compilé)
> - **Conteneur** = Le plat préparé (l'image en cours d'exécution)
>
> On peut lancer plusieurs conteneurs à partir de la même image.

**Q : Pourquoi utiliser Docker ?**
> R :
> 1. **Reproductibilité** : Ça marche pareil sur tous les ordis
> 2. **Isolation** : Les apps ne se mélangent pas
> 3. **Déploiement facile** : On envoie l'image sur le cloud

**Q : C'est quoi `depends_on` ?**
> R : Ça dit à Docker de démarrer le backend AVANT le frontend. Comme ça, quand le site web démarre, l'API est déjà prête.

**Q : C'est quoi le fichier `.env` ?**
> R : C'est un fichier qui contient les variables secrètes (clés API). Il n'est JAMAIS mis sur GitHub.
> ```
> GEMINI_API_KEY=AIzaSy...
> GROQ_API_KEY=gsk_...
> ```

---

# PARTIE 8 : LES APIs EXTERNES

## Gemini (Google)

**Ce que c'est** : Une IA multimodale de Google qui comprend les images.

**Comment on l'utilise** :
```python
# On envoie une requête POST
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent

# Avec ce body
{
  "contents": [{
    "parts": [
      {"text": "Décris cette image"},
      {"inline_data": {"mime_type": "image/jpeg", "data": "base64..."}}
    ]
  }]
}

# On reçoit
{
  "candidates": [{
    "content": {
      "parts": [{"text": "L'image montre un supermarché..."}]
    }
  }]
}
```

## Groq (Llama)

**Ce que c'est** : Une plateforme ultra-rapide pour exécuter des LLMs (Large Language Models). Ils utilisent Llama de Meta.

**Comment on l'utilise** :
```python
# On envoie une requête POST (format OpenAI)
POST https://api.groq.com/openai/v1/chat/completions

{
  "model": "llama-3.1-8b-instant",
  "messages": [
    {"role": "system", "content": "Tu es un assistant pour PMR. Réponds en JSON."},
    {"role": "user", "content": "L'utilisateur est allergique aux arachides. Voici la scène : ..."}
  ]
}

# On reçoit
{
  "choices": [{
    "message": {
      "content": "{\"summary\": \"...\", \"risks\": [...], \"actions\": [...]}"
    }
  }]
}
```

## ❓ Questions sur les APIs

**Q : Pourquoi Gemini et pas GPT-4 Vision ?**
> R : Gemini a une offre gratuite généreuse et est très performant pour la vision. GPT-4 Vision d'OpenAI est payant.

**Q : Pourquoi Groq et pas OpenAI ?**
> R : Groq est TRÈS rapide (ils ont un hardware spécial) et propose des modèles open source (Llama). C'est gratuit pour un usage raisonnable.

**Q : C'est quoi une clé API ?**
> R : C'est un mot de passe pour utiliser le service. On la met dans le header des requêtes :
> ```
> Authorization: Bearer gsk_abc123...
> ```

**Q : Combien ça coûte ?**
> R : Pour notre usage (projet étudiant), c'est gratuit. Les deux services ont des quotas gratuits suffisants.

---

# PARTIE 9 : SÉCURITÉ

## Les clés API

```
PROBLÈME : Les clés API sont secrètes. Si quelqu'un les vole, il peut utiliser notre compte.

SOLUTION :
- Les clés sont dans le fichier .env (JAMAIS sur GitHub)
- Le fichier .gitignore contient ".env"
- Le backend garde les clés, les apps ne les voient jamais
```

## CORS (Cross-Origin Resource Sharing)

```
PROBLÈME : Par défaut, un site web ne peut pas appeler une API sur un autre domaine.

SOLUTION : On configure CORS sur le backend pour autoriser les appels.

En développement : allow_origins=["*"]  (tout le monde)
En production : allow_origins=["https://monsite.com"]  (seulement notre site)
```

## Authentification mobile (mock)

```
PROBLÈME : On veut que chaque utilisateur ait son profil.

SOLUTION : Authentification locale avec SharedPreferences.
- Les mots de passe sont stockés localement (pas sécurisé pour la prod !)
- C'est un "mock" = une simulation pour le prototype
- En vrai, on utiliserait Firebase Auth ou un backend d'auth
```

---

# PARTIE 10 : QUESTIONS GÉNÉRALES

## ❓ Questions techniques diverses

**Q : C'est quoi REST ?**
> R : REST (Representational State Transfer) est un style d'architecture pour les APIs. On utilise :
> - GET pour récupérer des données
> - POST pour créer/envoyer des données
> - PUT pour modifier
> - DELETE pour supprimer

**Q : C'est quoi JSON ?**
> R : JavaScript Object Notation. Un format de données universel.
> ```json
> {
>   "name": "Jean",
>   "age": 25,
>   "allergies": ["arachide", "gluten"]
> }
> ```

**Q : C'est quoi HTTP vs HTTPS ?**
> R : HTTPS = HTTP + Sécurité (chiffrement). Les données sont cryptées pendant le transport.

**Q : C'est quoi une requête POST ?**
> R : Une requête HTTP qui ENVOIE des données au serveur (contrairement à GET qui RÉCUPÈRE).

**Q : Pourquoi Python pour le backend ?**
> R : Python est simple, a beaucoup de librairies pour l'IA, et FastAPI est très performant.

**Q : Pourquoi Flutter pour le mobile ?**
> R : Code unique pour Android ET iOS. Google le maintient activement.

**Q : Pourquoi Next.js pour le web ?**
> R : C'est le framework React le plus populaire, avec de bonnes performances et un écosystème riche.

## ❓ Questions sur le projet

**Q : Quelles sont les limites du projet ?**
> R :
> 1. Nécessite une connexion internet (pas de mode hors-ligne)
> 2. Latence de 4-7 secondes pour une analyse complète
> 3. COCO-SSD détecte 80 classes génériques, pas spécifiques PMR
> 4. Authentification mock (pas sécurisée pour la production)

**Q : Quelles améliorations futures ?**
> R :
> 1. Modèle YOLO custom entraîné sur des données PMR
> 2. Mode hors-ligne avec IA embarquée
> 3. OCR pour lire les étiquettes
> 4. Intégration GPS pour la navigation
> 5. Retour haptique (vibrations) pour les alertes

**Q : Comment vous avez travaillé en équipe ?**
> R : Git pour le versioning, branches par fonctionnalité, Pull Requests pour review.

**Q : Qu'est-ce qui a été le plus difficile ?**
> R : (À personnaliser selon votre expérience)
> - L'intégration des APIs externes
> - La gestion de la caméra sur différents appareils
> - Le déploiement Docker

---

# AIDE-MÉMOIRE RAPIDE

## Les URLs importantes
```
Backend local :     http://localhost:8000
Backend prod :      https://vision360-backend-xxx.run.app
Web local :         http://localhost:3000
Documentation API : http://localhost:8000/docs
```

## Les commandes importantes
```bash
# Backend
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload

# Frontend web
cd web_next
npm install
npm run dev

# Mobile
cd mobile_flutter
flutter pub get
flutter run

# Docker
docker compose up --build
```

## Les fichiers clés
```
backend/app/main.py       → Point d'entrée API
backend/app/describe.py   → Gemini + Groq
mobile_flutter/lib/main.dart → App mobile complète
web_next/src/app/page.tsx → Site web complet
poc-web/index.html        → POC détection
docker-compose.yml        → Configuration Docker
.env                      → Clés secrètes (NE PAS PARTAGER)
```

---

**Bonne chance pour l'entretien ! 🍀**
