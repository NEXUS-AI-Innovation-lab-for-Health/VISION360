/**
 * Page principale de l'application web Vision360.
 *
 * Cette page fournit une interface web complète pour :
 * - Configurer le profil santé de l'utilisateur (allergies, mobilité)
 * - Capturer des images via la webcam
 * - Analyser les images avec l'API Gemini
 * - Obtenir des recommandations personnalisées via Groq
 * - Utiliser la reconnaissance vocale pour les commandes
 *
 * @module page
 */

"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import styles from "./page.module.css";

// =============================================================================
// Types TypeScript
// =============================================================================

/**
 * Profil santé de l'utilisateur.
 * Contient les informations médicales et préférences pour personnaliser
 * les recommandations de l'IA.
 */
type Profile = {
  /** Nom de l'utilisateur */
  name: string;
  /** Liste des allergies (ex: arachide, gluten) */
  allergies: string[];
  /** Conditions médicales (ex: diabète, hypertension) */
  conditions: string[];
  /** Préférences alimentaires (ex: sans sucre, bio) */
  preferences: string[];
  /** Type de mobilité (fauteuil, canne, marche) */
  mobility: string;
  /** Activation de la synthèse vocale */
  tts_enabled: boolean;
};

/**
 * Élément de l'historique des interactions.
 */
type HistoryItem = {
  /** Résumé de la recommandation */
  summary: string;
  /** Date et heure de l'interaction */
  time: string;
};

// =============================================================================
// Valeurs par défaut
// =============================================================================

/**
 * Profil utilisateur par défaut.
 * Utilisé comme point de départ pour les nouveaux utilisateurs.
 */
const defaultProfile: Profile = {
  name: "Utilisateur",
  allergies: ["arachide"],
  conditions: ["diabete"],
  preferences: ["sans sucre"],
  mobility: "fauteuil",
  tts_enabled: true,
};

// =============================================================================
// Composant principal
// =============================================================================

/**
 * Composant Home - Page principale de l'application Vision360.
 *
 * Gère l'ensemble de l'interface utilisateur incluant :
 * - Configuration du profil santé
 * - Capture webcam et analyse Gemini
 * - Génération de recommandations Groq
 * - Reconnaissance vocale
 * - Historique des interactions
 *
 * @returns Composant React de la page d'accueil
 */
export default function Home() {
  // ---------------------------------------------------------------------------
  // État - Configuration API
  // ---------------------------------------------------------------------------

  /**
   * URL de base de l'API Vision360.
   * Par défaut, pointe vers le backend déployé sur Cloud Run.
   */
  const [apiBase, setApiBase] = useState(
    process.env.NEXT_PUBLIC_API_BASE ||
      "https://vision360-backend-276274707876.europe-west1.run.app/api",
  );

  // ---------------------------------------------------------------------------
  // État - Profil utilisateur
  // ---------------------------------------------------------------------------

  /** Profil santé de l'utilisateur */
  const [profile, setProfile] = useState<Profile>(defaultProfile);

  // ---------------------------------------------------------------------------
  // État - Capture d'image
  // ---------------------------------------------------------------------------

  /** Image capturée encodée en base64 */
  const [imageB64, setImageB64] = useState("");

  /** Prompt envoyé à Gemini pour l'analyse */
  const [prompt, setPrompt] = useState(
    "Decris precisement les produits/objets visibles, marques ou categories.",
  );

  // ---------------------------------------------------------------------------
  // État - Reconnaissance vocale
  // ---------------------------------------------------------------------------

  /** Texte de la commande vocale */
  const [voiceText, setVoiceText] = useState("");

  /** Indique si l'écoute vocale est active */
  const [listening, setListening] = useState(false);

  /** Message de statut de la reconnaissance vocale */
  const [voiceStatus, setVoiceStatus] = useState("");

  // ---------------------------------------------------------------------------
  // État - Caméra
  // ---------------------------------------------------------------------------

  /** Indique si la caméra est active */
  const [cameraOn, setCameraOn] = useState(false);

  /** Message de statut de la caméra */
  const [captureStatus, setCaptureStatus] = useState("");

  // ---------------------------------------------------------------------------
  // État - Résultats API
  // ---------------------------------------------------------------------------

  /** Texte de description retourné par Gemini */
  const [geminiText, setGeminiText] = useState("");

  /** JSON des recommandations retourné par Groq */
  const [groqJson, setGroqJson] = useState("");

  /** Réponse brute de Gemini (mode debug) */
  const [geminiRaw, setGeminiRaw] = useState("");

  /** Réponse brute de Groq (mode debug) */
  const [groqRaw, setGroqRaw] = useState("");

  // ---------------------------------------------------------------------------
  // État - Chargement et cooldown
  // ---------------------------------------------------------------------------

  /** Indique si une requête API est en cours */
  const [loading, setLoading] = useState(false);

  /** Historique des interactions */
  const [history, setHistory] = useState<HistoryItem[]>([]);

  /** Timestamp jusqu'auquel les appels sont bloqués */
  const [cooldownUntil, setCooldownUntil] = useState(0);

  /** Message de cooldown affiché à l'utilisateur */
  const [cooldownMsg, setCooldownMsg] = useState("");

  // ---------------------------------------------------------------------------
  // Références DOM
  // ---------------------------------------------------------------------------

  /** Référence à l'élément video pour le flux webcam */
  const videoRef = useRef<HTMLVideoElement | null>(null);

  /** Référence au canvas pour la capture d'image */
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  // ---------------------------------------------------------------------------
  // Mémoïsation
  // ---------------------------------------------------------------------------

  /**
   * Version nettoyée du profil pour envoi à l'API.
   * Filtre les valeurs vides des listes.
   */
  const profileSummary = useMemo(
    () => ({
      ...profile,
      allergies: profile.allergies.filter(Boolean),
      conditions: profile.conditions.filter(Boolean),
      preferences: profile.preferences.filter(Boolean),
    }),
    [profile],
  );

  // ---------------------------------------------------------------------------
  // Fonctions utilitaires
  // ---------------------------------------------------------------------------

  /**
   * Met à jour une liste du profil depuis une chaîne séparée par virgules.
   *
   * @param field - Nom du champ à mettre à jour
   * @param value - Valeur sous forme de chaîne (ex: "arachide, gluten")
   */
  const updateList = (field: keyof Profile, value: string) => {
    setProfile((prev) => ({
      ...prev,
      [field]: value
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean),
    }));
  };

  // ---------------------------------------------------------------------------
  // Appels API
  // ---------------------------------------------------------------------------

  /**
   * Appelle l'endpoint Gemini pour analyser l'image.
   *
   * Envoie l'image base64 et le prompt, puis stocke la description
   * textuelle retournée.
   */
  const callGemini = async () => {
    if (!apiBase) return;
    if (Date.now() < cooldownUntil) {
      setCooldownMsg("Attends 1 minute entre chaque envoi.");
      return;
    }
    setLoading(true);
    try {
      const res = await fetch(`${apiBase}/describe/gemini`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ image_b64: imageB64, prompt }),
      });
      if (!res.ok) {
        throw new Error(await res.text());
      }
      const data = await res.json();
      setGeminiText(data?.structured?.text ?? "");
      setCooldownUntil(Date.now() + 60_000); // Cooldown de 60 secondes
      setCooldownMsg("");
    } catch (err) {
      setGeminiText(`Erreur Gemini: ${String(err)}`);
    } finally {
      setLoading(false);
    }
  };

  /**
   * Appelle l'endpoint Groq pour générer des recommandations.
   *
   * Utilise soit le texte vocal saisi, soit la description Gemini,
   * combiné avec le profil utilisateur pour obtenir des recommandations
   * personnalisées.
   */
  const callGroq = async () => {
    if (!apiBase) return;
    const description = voiceText.trim() || geminiText.trim();
    if (!description) return;
    if (Date.now() < cooldownUntil) {
      setCooldownMsg("Attends 1 minute entre chaque envoi.");
      return;
    }

    setLoading(true);
    try {
      const res = await fetch(`${apiBase}/describe/groq`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          description,
          profile_override: profileSummary,
        }),
      });
      if (!res.ok) {
        throw new Error(await res.text());
      }
      const data = await res.json();
      const structured = data?.structured ?? data;
      setGroqJson(JSON.stringify(structured, null, 2));

      // Ajouter à l'historique
      setHistory((prev) => [
        {
          summary: structured?.summary ?? "Conseil",
          time: new Date().toLocaleString(),
        },
        ...prev,
      ]);
      setCooldownUntil(Date.now() + 60_000);
      setCooldownMsg("");
    } catch (err) {
      setGroqJson(`Erreur Groq: ${String(err)}`);
    } finally {
      setLoading(false);
    }
  };

  // ---------------------------------------------------------------------------
  // Gestion de la caméra
  // ---------------------------------------------------------------------------

  /**
   * Démarre le flux vidéo de la webcam.
   *
   * Utilise l'API MediaDevices pour accéder à la caméra arrière
   * (ou avant si arrière non disponible).
   */
  const startCamera = async () => {
    if (!navigator.mediaDevices?.getUserMedia) {
      setCaptureStatus("Camera non supportee sur ce navigateur.");
      return;
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "environment" }, // Caméra arrière préférée
        audio: false,
      });
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        await videoRef.current.play();
      }
      setCameraOn(true);
      setCaptureStatus("Camera activee.");
    } catch (err) {
      setCaptureStatus(`Erreur camera: ${String(err)}`);
    }
  };

  /**
   * Arrête le flux vidéo de la webcam.
   *
   * Libère les ressources en arrêtant toutes les pistes du stream.
   */
  const stopCamera = () => {
    if (videoRef.current?.srcObject) {
      const tracks = (videoRef.current.srcObject as MediaStream).getTracks();
      tracks.forEach((track) => track.stop());
      videoRef.current.srcObject = null;
    }
    setCameraOn(false);
    setCaptureStatus("Camera arretee.");
  };

  /**
   * Capture une frame de la vidéo et la convertit en base64.
   *
   * Dessine la frame actuelle sur le canvas caché, puis extrait
   * l'image en format JPEG.
   *
   * @returns URL data de l'image capturée
   */
  const captureFrame = () => {
    const video = videoRef.current;
    const canvas = canvasRef.current;
    if (!video || !canvas) return;

    const width = video.videoWidth || 640;
    const height = video.videoHeight || 480;
    canvas.width = width;
    canvas.height = height;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    ctx.drawImage(video, 0, 0, width, height);
    const dataUrl = canvas.toDataURL("image/jpeg", 0.8);
    setImageB64(dataUrl);
    return dataUrl;
  };

  /**
   * Exécute la chaîne complète : capture → Gemini → Groq.
   *
   * @param debug - Si true, affiche les réponses brutes des APIs
   */
  const callChain = async (debug = false) => {
    if (!apiBase) return;
    if (Date.now() < cooldownUntil) {
      setCooldownMsg("Attends 1 minute entre chaque envoi.");
      return;
    }

    // Capturer l'image
    const captured = captureFrame();
    const imagePayload = captured || imageB64;
    if (!imagePayload) {
      setGeminiText("Aucune image a envoyer.");
      return;
    }

    setLoading(true);
    try {
      // Étape 1 : Appel Gemini pour description
      const geminiRes = await fetch(`${apiBase}/describe/gemini`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ image_b64: imagePayload, prompt }),
      });
      if (!geminiRes.ok) {
        throw new Error(await geminiRes.text());
      }
      const geminiData = await geminiRes.json();
      const geminiTextValue = geminiData?.structured?.text ?? "";
      setGeminiText(geminiTextValue);
      if (debug) {
        setGeminiRaw(JSON.stringify(geminiData, null, 2));
      }

      // Étape 2 : Appel Groq pour recommandations
      const groqRes = await fetch(`${apiBase}/describe/groq`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          description: geminiTextValue,
          profile_override: profileSummary,
        }),
      });
      if (!groqRes.ok) {
        throw new Error(await groqRes.text());
      }
      const groqData = await groqRes.json();
      const structured = groqData?.structured ?? groqData;
      setGroqJson(JSON.stringify(structured, null, 2));
      if (debug) {
        setGroqRaw(JSON.stringify(groqData, null, 2));
      }

      // Ajouter à l'historique
      setHistory((prev) => [
        {
          summary: structured?.summary ?? "Conseil",
          time: new Date().toLocaleString(),
        },
        ...prev,
      ]);

      setCooldownUntil(Date.now() + 60_000);
      setCooldownMsg("");
    } catch (err) {
      setGroqJson(`Erreur chaine: ${String(err)}`);
      if (debug) {
        setGeminiRaw("");
        setGroqRaw("");
      }
    } finally {
      setLoading(false);
    }
  };

  // ---------------------------------------------------------------------------
  // Effets
  // ---------------------------------------------------------------------------

  /**
   * Nettoyage à la destruction du composant.
   * Arrête la caméra pour libérer les ressources.
   */
  useEffect(() => {
    return () => stopCamera();
  }, []);

  // ---------------------------------------------------------------------------
  // Reconnaissance vocale
  // ---------------------------------------------------------------------------

  /**
   * Démarre la reconnaissance vocale via l'API Web Speech.
   *
   * Utilise le français (fr-FR) et transcrit la commande vocale
   * dans le champ de texte.
   */
  const startListening = () => {
    const SpeechRecognition =
      (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    if (!SpeechRecognition) {
      setVoiceStatus("Reconnaissance vocale non supportee sur ce navigateur.");
      return;
    }

    const recognition = new SpeechRecognition();
    recognition.lang = "fr-FR";
    recognition.interimResults = false;
    recognition.maxAlternatives = 1;

    recognition.onstart = () => {
      setListening(true);
      setVoiceStatus("Ecoute active...");
    };
    recognition.onresult = (event: any) => {
      const transcript = event.results[0][0].transcript;
      setVoiceText(transcript);
      setVoiceStatus(`Commande captee: ${transcript}`);
    };
    recognition.onerror = (event: any) => {
      setVoiceStatus(`Erreur micro: ${event.error || "inconnue"}`);
    };
    recognition.onend = () => {
      setListening(false);
    };

    recognition.start();
  };

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------

  return (
    <div className={styles.page}>
      {/* Header avec titre et configuration API */}
      <header className={styles.header}>
        <div>
          <p className={styles.kicker}>Vision360</p>
          <h1>Console d&apos;assistance PMR</h1>
          <p className={styles.subtitle}>
            Profil sante, description Gemini et recommandations Groq en temps
            reel.
          </p>
        </div>
        <div className={styles.apiBox}>
          <label>Base API</label>
          <input
            value={apiBase}
            onChange={(event) => setApiBase(event.target.value)}
          />
        </div>
      </header>

      {/* Grille principale avec les 3 cartes */}
      <section className={styles.grid}>
        {/* Carte Profil santé */}
        <div className={styles.card}>
          <h2>Profil sante</h2>
          <div className={styles.field}>
            <label>Nom</label>
            <input
              value={profile.name}
              onChange={(event) =>
                setProfile((prev) => ({ ...prev, name: event.target.value }))
              }
            />
          </div>
          <div className={styles.field}>
            <label>Allergies</label>
            <input
              value={profile.allergies.join(", ")}
              onChange={(event) => updateList("allergies", event.target.value)}
            />
          </div>
          <div className={styles.field}>
            <label>Conditions</label>
            <input
              value={profile.conditions.join(", ")}
              onChange={(event) => updateList("conditions", event.target.value)}
            />
          </div>
          <div className={styles.field}>
            <label>Preferences</label>
            <input
              value={profile.preferences.join(", ")}
              onChange={(event) => updateList("preferences", event.target.value)}
            />
          </div>
          <div className={styles.field}>
            <label>Mobilite</label>
            <select
              value={profile.mobility}
              onChange={(event) =>
                setProfile((prev) => ({ ...prev, mobility: event.target.value }))
              }
            >
              <option value="fauteuil">Fauteuil</option>
              <option value="canne">Canne</option>
              <option value="marche">Marche</option>
            </select>
          </div>
          <label className={styles.switchRow}>
            <input
              type="checkbox"
              checked={profile.tts_enabled}
              onChange={(event) =>
                setProfile((prev) => ({
                  ...prev,
                  tts_enabled: event.target.checked,
                }))
              }
            />
            TTS actif (sortie Groq)
          </label>
        </div>

        {/* Carte Gemini - Capture et analyse */}
        <div className={styles.card}>
          <h2>Gemini</h2>
          <div className={styles.cameraBox}>
            <video ref={videoRef} className={styles.video} playsInline muted />
            <canvas ref={canvasRef} className={styles.canvas} />
          </div>
          <div className={styles.actions}>
            {!cameraOn ? (
              <button className={styles.secondary} onClick={startCamera}>
                Activer la camera
              </button>
            ) : (
              <button className={styles.secondary} onClick={stopCamera}>
                Arreter la camera
              </button>
            )}
            <button onClick={captureFrame}>Capturer</button>
            <button onClick={() => callChain(false)}>
              Envoyer (Recommandations)
            </button>
            <button onClick={() => callChain(true)}>
              Envoyer (Debug)
            </button>
          </div>
          {cooldownMsg && (
            <p className={styles.voiceStatus}>{cooldownMsg}</p>
          )}
          {captureStatus && <p className={styles.voiceStatus}>{captureStatus}</p>}
          <label>Image base64</label>
          <textarea
            rows={5}
            value={imageB64}
            onChange={(event) => setImageB64(event.target.value)}
          />
          <label>Prompt</label>
          <input
            value={prompt}
            onChange={(event) => setPrompt(event.target.value)}
          />
          <pre className={styles.output}>{geminiText || "—"}</pre>
          {geminiRaw && (
            <>
              <p className={styles.debugLabel}>Gemini raw</p>
              <pre className={styles.output}>{geminiRaw}</pre>
            </>
          )}
        </div>

        {/* Carte Groq - Commandes vocales et recommandations */}
        <div className={styles.card}>
          <h2>Groq</h2>
          <label>Commande vocale (texte)</label>
          <textarea
            rows={4}
            value={voiceText}
            onChange={(event) => setVoiceText(event.target.value)}
          />
          <div className={styles.actions}>
            <button
              className={styles.secondary}
              onClick={startListening}
              disabled={listening}
            >
              {listening ? "Ecoute en cours..." : "Activer l'ecoute"}
            </button>
            <button disabled={loading} onClick={callGroq}>
              Envoyer a Groq
            </button>
            <button
              className={styles.secondary}
              onClick={() => setVoiceText("")}
            >
              Reset
            </button>
          </div>
          {cooldownMsg && (
            <p className={styles.voiceStatus}>{cooldownMsg}</p>
          )}
          {voiceStatus && <p className={styles.voiceStatus}>{voiceStatus}</p>}
          <pre className={styles.output}>{groqJson || "—"}</pre>
          {groqRaw && (
            <>
              <p className={styles.debugLabel}>Groq raw</p>
              <pre className={styles.output}>{groqRaw}</pre>
            </>
          )}
        </div>
      </section>

      {/* Section Historique */}
      <section className={styles.card}>
        <h2>Historique</h2>
        {history.length === 0 ? (
          <p>Aucun conseil pour le moment.</p>
        ) : (
          <ul className={styles.history}>
            {history.map((item, index) => (
              <li key={`${item.time}-${index}`}>
                <span>{item.summary}</span>
                <small>{item.time}</small>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
