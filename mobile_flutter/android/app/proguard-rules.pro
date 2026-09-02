# =============================================================================
# Règles ProGuard / R8 - Vision360 Mobile
# =============================================================================
# Ce fichier n'est utilisé que si minifyEnabled est passé à true dans
# android/app/build.gradle (désactivé par défaut).
#
# R8 supprime le code qu'il croit inatteignable. Or plusieurs plugins de ce
# projet sont appelés par réflexion depuis le code natif : sans les règles
# ci-dessous, l'APK compile mais plante à l'exécution.
# =============================================================================

# --- Moteur Flutter -----------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# --- Reconnaissance vocale (speech_to_text) -----------------------------------
# Les callbacks de reconnaissance sont invoqués par le système Android.
-keep class com.csdcorp.speech_to_text.** { *; }
-keep class android.speech.** { *; }

# --- Synthèse vocale (flutter_tts) --------------------------------------------
-keep class android.speech.tts.** { *; }

# --- Caméra (camera) ----------------------------------------------------------
-keep class io.flutter.plugins.camera.** { *; }
-keep class androidx.camera.** { *; }

# --- Géolocalisation (geolocator) ---------------------------------------------
-keep class com.baseflow.geolocator.** { *; }

# --- Annotations et signatures génériques -------------------------------------
# Nécessaires au décodage JSON et à la réflexion.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# --- Silence les avertissements sur des classes optionnelles absentes ---------
-dontwarn io.flutter.embedding.**
-dontwarn javax.annotation.**
