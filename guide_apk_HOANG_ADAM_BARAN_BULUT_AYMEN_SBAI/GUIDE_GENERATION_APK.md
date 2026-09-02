# Guide de génération de l'application mobile — Vision360

**Projet** : SAE Vision360 — Assistance IA pour personnes à mobilité réduite
**Formation** : BUT Informatique 3ᵉ année — SAE S5 et S6, Parcours A et C
**Application** : `mobile_flutter` — Flutter 3.6+ / Dart 3.6
**Portée** : génération d'un **APK Android**, et des autres formats de packaging
(AAB, IPA iOS, Web, bureau Linux/Windows/macOS)

---

## Table des matières

1. [Ce que vous allez produire](#1-ce-que-vous-allez-produire)
2. [Prérequis](#2-prérequis)
3. [Installation de la chaîne de compilation](#3-installation-de-la-chaîne-de-compilation)
4. [Préparation du projet](#4-préparation-du-projet)
5. [Génération d'un APK de debug](#5-génération-dun-apk-de-debug)
6. [Signature de l'application](#6-signature-de-lapplication)
7. [Génération d'un APK de release](#7-génération-dun-apk-de-release)
8. [APK découpés par architecture](#8-apk-découpés-par-architecture)
9. [Android App Bundle (AAB)](#9-android-app-bundle-aab)
10. [Installation de l'APK sur un téléphone](#10-installation-de-lapk-sur-un-téléphone)
11. [Relier l'application au backend](#11-relier-lapplication-au-backend)
12. [Autres formats de packaging](#12-autres-formats-de-packaging)
13. [Personnalisation avant publication](#13-personnalisation-avant-publication)
14. [Dépannage](#14-dépannage)
15. [Annexes](#15-annexes)

---

## 1. Ce que vous allez produire

L'application mobile Vision360 est développée avec **Flutter**, ce qui permet de
générer plusieurs formats de distribution depuis une base de code unique
(`mobile_flutter/lib/`, environ 5 300 lignes de Dart).

| Format | Extension | Plateforme | Machine de compilation | Section |
|---|---|---|---|---|
| **APK universel** | `.apk` | Android | Linux / Windows / macOS | [§7](#7-génération-dun-apk-de-release) |
| **APK par ABI** | `.apk` ×3 | Android | Linux / Windows / macOS | [§8](#8-apk-découpés-par-architecture) |
| **App Bundle** | `.aab` | Android (Play Store) | Linux / Windows / macOS | [§9](#9-android-app-bundle-aab) |
| **Archive iOS** | `.ipa` | iOS | **macOS obligatoire** | [§12.1](#121-ios--ipa) |
| **Application Web** | dossier statique | Navigateur | Toutes | [§12.2](#122-web--pwa) |
| **Bureau Linux** | binaire + `.tar.gz` | Linux | Linux | [§12.3](#123-bureau-linux) |
| **Bureau Windows** | `.exe` + DLL | Windows | Windows | [§12.4](#124-bureau-windows) |
| **Bureau macOS** | `.app` | macOS | macOS | [§12.5](#125-bureau-macos) |

> **Le format demandé par défaut est l'APK.** C'est le plus simple à distribuer
> pour une évaluation : un seul fichier, installable directement sur n'importe
> quel téléphone Android sans passer par un magasin d'applications.

### Fonctionnalités embarquées dans le binaire

L'application n'est pas une simple coquille : elle regroupe cinq onglets.

| Onglet | Contenu | Permissions requises |
|---|---|---|
| **Profil** | Compte local, profil santé (allergies, conditions), accessibilité, thème, inventaire maison | — |
| **Guidance** | Capture caméra, analyse Gemini + Groq, lecture vocale des conseils | Caméra, Micro |
| **GPS** | Carte OpenStreetMap, recherche de lieux, itinéraire piéton guidé à la voix | Localisation |
| **Historique** | Journal des analyses, export fichier et presse-papiers | Stockage |
| **Caddie** | Scan de code-barres, passage en caisse assisté, vérification du ticket | Caméra |

Ces fonctions déterminent les permissions déclarées et donc ce que le
téléphone demandera à l'installation. Voir [§15.C](#c-permissions-déclarées).

---

## 2. Prérequis

### Matériel et système

| Élément | Minimum | Recommandé |
|---|---|---|
| RAM | 8 Go | 16 Go |
| Disque libre | 15 Go | 30 Go |
| Système | Linux, Windows 10+, macOS 12+ | — |
| Réseau | Accès Internet (téléchargement Gradle, dépendances) | — |

> La première compilation télécharge Gradle, le SDK Android et les dépendances
> Maven : comptez **plusieurs Go** et **10 à 20 minutes**. Les suivantes prennent
> une à deux minutes.

### Logiciels

| Outil | Version | Rôle |
|---|---|---|
| Flutter SDK | ≥ 3.6.2 | Compilation Dart → natif |
| Android SDK | Platform 36 + Build-Tools | Compilation Android |
| JDK | 17 (LTS) | Exécution de Gradle |
| Git | ≥ 2.25 | Récupération du projet |

> **Le JDK 17 est le bon choix.** Le plugin Android Gradle 8.2 utilisé par ce
> projet ne fonctionne pas avec un JDK 8 ou 11, et le JDK 21 provoque encore des
> incompatibilités avec certains plugins Flutter.

### Versions verrouillées par le projet

Ces valeurs sont fixées dans les fichiers du dépôt ; les connaître évite bien
des erreurs de compilation.

| Paramètre | Valeur | Fichier |
|---|---|---|
| Dart SDK | `^3.6.2` | `mobile_flutter/pubspec.yaml` |
| Version applicative | `1.0.0+1` | `mobile_flutter/pubspec.yaml` |
| `compileSdk` | 36 | `android/app/build.gradle` |
| `minSdk` | 24 (Android 7.0) | `android/app/build.gradle` |
| `targetSdk` | 36 | `android/app/build.gradle` |
| Android Gradle Plugin | 8.2.2 | `android/settings.gradle` |
| Kotlin | 2.2.0 | `android/settings.gradle` |
| Gradle | 8.3 | `android/gradle/wrapper/gradle-wrapper.properties` |
| `applicationId` | `com.example.mobile_flutter` | `android/app/build.gradle` |

> **`minSdk = 24`** signifie que l'application fonctionne sur Android 7.0 et
> plus récent, ce qui couvre plus de 95 % du parc actuel. Ce minimum est imposé
> par les plugins `camera` et `geolocator`.

---

## 3. Installation de la chaîne de compilation

### 3.1 Flutter SDK

#### Linux

```bash
# Dépendances système
sudo apt update
sudo apt install -y curl git unzip xz-utils zip libglu1-mesa

# Téléchargement dans /opt
sudo mkdir -p /opt/flutter
cd /tmp
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.27.1-stable.tar.xz
sudo tar xf flutter_linux_3.27.1-stable.tar.xz -C /opt/
sudo chown -R "$USER" /opt/flutter

# Ajout au PATH (adapter si vous utilisez zsh)
echo 'export PATH="$PATH:/opt/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
```

> Toute version stable **≥ 3.27** convient : elle embarque un Dart ≥ 3.6, ce que
> réclame `pubspec.yaml`. Vérifiez la dernière version publiée sur
> <https://docs.flutter.dev/release/archive>.

#### Windows

1. Télécharger l'archive depuis <https://docs.flutter.dev/get-started/install/windows>
2. Extraire dans `C:\src\flutter` — **jamais** dans un dossier contenant des
   espaces ni sous `C:\Program Files`, Gradle échoue sinon
3. Ajouter `C:\src\flutter\bin` à la variable d'environnement `Path`

#### macOS

```bash
brew install --cask flutter
```

#### Vérification

```bash
flutter --version
```

### 3.2 JDK 17

```bash
# Debian / Ubuntu
sudo apt install -y openjdk-17-jdk

# Fedora
sudo dnf install -y java-17-openjdk-devel

# macOS
brew install --cask temurin@17
```

Vérifier, puis déclarer le chemin à Flutter :

```bash
java -version          # doit afficher 17.x

# Linux
sudo update-alternatives --config java
flutter config --jdk-dir="/usr/lib/jvm/java-17-openjdk-amd64"
```

### 3.3 Android SDK

Deux options.

#### Option A — Android Studio (le plus simple)

1. Installer Android Studio : <https://developer.android.com/studio>
2. Au premier lancement, accepter l'installation du SDK
3. Dans *Settings → Languages & Frameworks → Android SDK*, onglet
   **SDK Platforms**, cocher **Android API 36**
4. Onglet **SDK Tools**, cocher :
   - Android SDK Build-Tools
   - Android SDK Command-line Tools *(indispensable pour les licences)*
   - Android SDK Platform-Tools *(fournit `adb`)*

#### Option B — Ligne de commande seule (serveur, CI)

```bash
# Outils en ligne de commande
mkdir -p ~/Android/Sdk/cmdline-tools && cd ~/Android/Sdk/cmdline-tools
curl -O https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip commandlinetools-linux-*.zip && mv cmdline-tools latest

# Variables d'environnement
cat >> ~/.bashrc << 'EOF'
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"
EOF
source ~/.bashrc

# Composants nécessaires
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"
```

### 3.4 Accepter les licences Android

**Étape obligatoire**, systématiquement oubliée :

```bash
flutter doctor --android-licenses
```

Répondre `y` à chaque question.

### 3.5 Diagnostic complet

```bash
flutter doctor -v
```

Résultat attendu :

```
[✓] Flutter (Channel stable, 3.27.x)
[✓] Android toolchain - develop for Android devices (Android SDK version 36.0.0)
[✓] Android Studio (version 2024.x)
```

> Les lignes `[✗] Chrome`, `[✗] Xcode` ou `[✗] Visual Studio` **ne sont pas
> bloquantes** pour générer un APK : elles concernent les cibles Web, iOS et
> Windows. Seules les deux premières lignes doivent être vertes.

---

## 4. Préparation du projet

### 4.1 Se placer dans le dossier de l'application

```bash
cd VISION360-main/mobile_flutter
```

> ⚠️ **Toutes les commandes de ce guide se lancent depuis `mobile_flutter/`**,
> et non depuis la racine du dépôt.

### 4.2 Récupérer les dépendances

```bash
flutter pub get
```

Cette commande lit `pubspec.yaml` et télécharge les 10 paquets du projet :

| Paquet | Rôle dans Vision360 |
|---|---|
| `camera` | Capture photo pour l'analyse Gemini et le scan de code-barres |
| `http` | Appels REST vers le backend FastAPI |
| `flutter_tts` | Lecture vocale des recommandations et du guidage |
| `speech_to_text` | Commandes vocales de l'utilisateur |
| `flutter_map` + `latlong2` | Carte OpenStreetMap du guidage piéton |
| `geolocator` | Position GPS et suivi de trajet |
| `shared_preferences` | Persistance du profil, du caddie, de l'historique |
| `path_provider` | Export de l'historique dans un fichier |
| `cupertino_icons` | Jeu d'icônes |

Le fichier `pubspec.lock` fige les versions exactes : **ne pas le supprimer**,
c'est lui qui garantit qu'une compilation d'aujourd'hui produit le même binaire
que celle d'il y a six mois.

### 4.3 Note sur le wrapper Gradle

Les fichiers `android/gradlew`, `android/gradlew.bat` et
`gradle/wrapper/gradle-wrapper.jar` **ne sont pas versionnés** dans ce dépôt.
C'est normal : l'outil Flutter les régénère automatiquement à la première
compilation, à partir de la version déclarée dans
`gradle-wrapper.properties` (Gradle 8.3).

De même, `android/local.properties` est généré automatiquement et contient les
chemins locaux vers le SDK Flutter et le SDK Android. Il ne doit jamais être
committé.

### 4.4 Vérification préalable

```bash
flutter analyze          # Analyse statique du code Dart
flutter test             # Tests unitaires
```

> `flutter analyze` peut remonter des avertissements de style sans gravité. Seuls
> les messages préfixés `error` bloquent la compilation.

---

## 5. Génération d'un APK de debug

C'est la compilation la plus rapide, utile pour vérifier que la chaîne
fonctionne avant de s'attaquer à la release.

```bash
flutter build apk --debug
```

Résultat :

```
build/app/outputs/flutter-apk/app-debug.apk
```

| Caractéristique | APK debug | APK release |
|---|---|---|
| Taille | ~90 Mo | ~25 Mo |
| Performance | Réduite (JIT) | Optimale (AOT) |
| Signature | Clé de debug automatique | Votre keystore |
| Distribuable | Non | Oui |
| Temps de build | ~2 min | ~4 min |

> L'APK de debug **fonctionne** et s'installe, mais il est volumineux, lent, et
> ne doit pas être remis comme livrable final.

---

## 6. Signature de l'application

Android **refuse d'installer un APK non signé**. La signature garantit que les
mises à jour proviennent bien du même auteur.

### 6.1 Comment le projet gère la signature

Le fichier `android/app/build.gradle` a été configuré ainsi :

- Si `android/key.properties` **existe** → la release est signée avec votre
  keystore de production.
- S'il **n'existe pas** → la release retombe sur la clé de debug.

Conséquence pratique : **`flutter build apk --release` fonctionne toujours**,
même sans keystore. Sans clé de production, l'APK produit est utilisable pour
une démonstration mais n'est pas distribuable sur un magasin d'applications.

### 6.2 Créer un keystore

```bash
keytool -genkey -v \
  -keystore ~/vision360-release.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias vision360
```

Les questions posées :

| Question | Exemple de réponse |
|---|---|
| Enter keystore password | *(mot de passe fort, à noter)* |
| What is your first and last name? | Equipe Vision360 |
| What is the name of your organizational unit? | BUT Informatique |
| What is the name of your organization? | IUT |
| What is the name of your City or Locality? | *(votre ville)* |
| What is the name of your State or Province? | *(votre région)* |
| What is the two-letter country code | FR |

> ### 🔐 Trois règles à ne jamais enfreindre
>
> 1. **Sauvegardez le fichier `.jks`** hors du poste de développement. Le perdre
>    signifie ne plus jamais pouvoir publier de mise à jour de l'application :
>    Google ne peut pas le régénérer.
> 2. **Ne committez jamais** le `.jks` ni `key.properties` dans Git.
> 3. **`-validity 10000`** correspond à ~27 ans. Google Play exige une validité
>    au moins jusqu'au 22 octobre 2033.

### 6.3 Déclarer le keystore

Créer `android/key.properties` à partir du modèle fourni :

```bash
cp android/key.properties.example android/key.properties
nano android/key.properties
```

Contenu :

```properties
storePassword=votre_mot_de_passe_keystore
keyPassword=votre_mot_de_passe_cle
keyAlias=vision360
storeFile=/home/utilisateur/vision360-release.jks
```

| Clé | Valeur |
|---|---|
| `storePassword` | Mot de passe du keystore (1ʳᵉ question de `keytool`) |
| `keyPassword` | Mot de passe de la clé (souvent identique) |
| `keyAlias` | L'alias passé à `-alias`, ici `vision360` |
| `storeFile` | Chemin **absolu** vers le `.jks` |

> Sous Windows, échapper les antislashs ou utiliser des slashs :
> `storeFile=C:/Users/moi/vision360-release.jks`

Protéger le fichier :

```bash
chmod 600 android/key.properties
```

### 6.4 Vérifier que le fichier n'est pas versionné

```bash
grep -n "key.properties\|\.jks" ../.gitignore android/.gitignore
```

Si aucune règle n'apparaît, l'ajouter :

```bash
printf '\n# Signature Android\nkey.properties\n*.jks\n*.keystore\n' >> ../.gitignore
```

---

## 7. Génération d'un APK de release

### La commande

```bash
cd mobile_flutter
flutter build apk --release
```

### Résultat

```
✓ Built build/app/outputs/flutter-apk/app-release.apk (24.8MB)
```

Le fichier se trouve dans :

```
mobile_flutter/build/app/outputs/flutter-apk/app-release.apk
```

### Ce que fait la commande

1. **Compilation AOT** du code Dart en code machine natif (ARM), par opposition
   au JIT du mode debug — c'est ce qui rend l'application rapide.
2. **Compilation Gradle** de la partie Android (Kotlin, ressources, manifeste).
3. **Fusion** du moteur Flutter, du code compilé et des ressources.
4. **Signature** avec le keystore déclaré en [§6](#6-signature-de-lapplication).
5. **Alignement** (`zipalign`) pour optimiser l'accès mémoire.

### Vérifier l'APK produit

```bash
# Taille et date
ls -lh build/app/outputs/flutter-apk/app-release.apk

# Signature — doit afficher "jar verified"
jarsigner -verify -verbose -certs \
  build/app/outputs/flutter-apk/app-release.apk | head -20

# Métadonnées (nécessite les build-tools dans le PATH)
aapt dump badging build/app/outputs/flutter-apk/app-release.apk | head -10
```

La dernière commande doit afficher :

```
package: name='com.example.mobile_flutter' versionCode='1' versionName='1.0.0'
sdkVersion:'24'
targetSdkVersion:'36'
uses-permission: name='android.permission.CAMERA'
uses-permission: name='android.permission.RECORD_AUDIO'
uses-permission: name='android.permission.INTERNET'
uses-permission: name='android.permission.ACCESS_FINE_LOCATION'
application-label:'Vision360'
```

### Renommer l'APK pour le rendu

```bash
cp build/app/outputs/flutter-apk/app-release.apk \
   ../vision360-v1.0.0-release.apk
```

---

## 8. APK découpés par architecture

L'APK universel embarque le code natif des trois architectures Android, alors
qu'un téléphone donné n'en utilise qu'une. Le découpage réduit la taille d'environ
**deux tiers**.

```bash
flutter build apk --release --split-per-abi
```

Trois fichiers sont produits :

| Fichier | Architecture | Appareils concernés | Taille |
|---|---|---|---|
| `app-armeabi-v7a-release.apk` | ARM 32 bits | Téléphones anciens (< 2017) | ~8 Mo |
| `app-arm64-v8a-release.apk` | ARM 64 bits | **La quasi-totalité des téléphones actuels** | ~9 Mo |
| `app-x86_64-release.apk` | x86 64 bits | Émulateurs, quelques tablettes | ~9 Mo |

> **En cas de doute, distribuez `app-arm64-v8a-release.apk`** : il couvre tous
> les téléphones Android commercialisés depuis 2017.

Pour ne compiler qu'une seule cible :

```bash
flutter build apk --release --target-platform android-arm64
```

---

## 9. Android App Bundle (AAB)

Le format `.aab` est **obligatoire pour publier sur Google Play**. Ce n'est pas
un fichier installable : c'est un conteneur à partir duquel Google génère un APK
optimisé pour chaque appareil.

```bash
flutter build appbundle --release
```

Résultat :

```
build/app/outputs/bundle/release/app-release.aab
```

| Critère | APK | AAB |
|---|:-:|:-:|
| Installable directement | ✅ | ❌ |
| Accepté par Google Play | ❌ | ✅ |
| Distribution hors magasin | ✅ | ❌ |
| Taille de téléchargement | Fixe | Optimisée par appareil |

> **Pour un rendu universitaire, livrez un APK.** L'AAB n'a d'intérêt que si le
> projet est réellement publié sur le Play Store.

Pour tester un AAB localement, il faut passer par `bundletool` :

```bash
java -jar bundletool.jar build-apks \
  --bundle=build/app/outputs/bundle/release/app-release.aab \
  --output=vision360.apks --mode=universal
```

---

## 10. Installation de l'APK sur un téléphone

### Méthode 1 — ADB (câble USB)

```bash
# Activer sur le téléphone : Paramètres > À propos > appuyer 7 fois sur
# "Numéro de build", puis Options développeur > Débogage USB

adb devices                                    # le téléphone doit apparaître
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

L'option `-r` réinstalle par-dessus une version existante en conservant les
données.

### Méthode 2 — Transfert manuel

1. Copier l'APK sur le téléphone (USB, e-mail, cloud, `adb push`)
2. Ouvrir le fichier depuis le gestionnaire de fichiers
3. Autoriser **« Installer des applications inconnues »** pour l'application qui
   ouvre le fichier
4. Confirmer l'installation

### Méthode 3 — Compilation et installation en une commande

```bash
flutter install --release       # sur l'appareil connecté
flutter run --release           # compile, installe et lance
```

### Permissions demandées au premier lancement

L'application demande les autorisations **au moment où la fonction est
utilisée**, pas à l'installation :

| Moment | Permission | Nécessaire pour |
|---|---|---|
| Ouverture de l'onglet Guidance | Caméra | Analyse de scène, scan de produits |
| Première commande vocale | Micro | Reconnaissance vocale |
| Ouverture de l'onglet GPS | Localisation | Guidage piéton, lieux à proximité |

Refuser une permission désactive la fonction correspondante sans faire planter
l'application.

---

## 11. Relier l'application au backend

> ### ⚠️ Point important
>
> L'infrastructure **Google Cloud Run du projet a été supprimée** (comptes fermés
> pour éviter toute facturation). L'URL
> `https://vision360-backend-...run.app` inscrite par défaut dans
> `mobile_flutter/lib/main.dart` **ne répond plus**.
>
> L'application reste pleinement fonctionnelle : il suffit de la faire pointer
> vers le backend lancé en local avec Docker. **Aucune recompilation n'est
> nécessaire**, le champ est modifiable dans l'application.

### 11.1 Démarrer le backend

Depuis la racine du dépôt :

```bash
docker compose up -d --build
curl http://localhost:8000/health      # doit répondre {"status":"ok"}
```

Procédure complète : `docs_docker_.../INSTALLATION_LINUX.md`.

### 11.2 Renseigner l'URL dans l'application

Ouvrir l'application → onglet **Profil** → section **Avancé** → champ
**« API Base »**.

| Contexte d'exécution | URL à saisir |
|---|---|
| Émulateur Android | `http://10.0.2.2:8000/api` |
| Simulateur iOS | `http://localhost:8000/api` |
| **Téléphone réel, même Wi-Fi que le PC** | `http://<IP_DU_PC>:8000/api` |

Trouver l'adresse IP du PC :

```bash
# Linux / macOS
ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1

# Windows
ipconfig | findstr IPv4
```

Exemple : `http://192.168.1.42:8000/api`

> `10.0.2.2` est l'alias par lequel l'émulateur Android joint le `localhost` de
> la machine hôte. Saisir `localhost` depuis l'émulateur désignerait l'émulateur
> lui-même, et échouerait.

### 11.3 Changer la valeur par défaut avant compilation

Pour que l'APK livré pointe d'emblée au bon endroit :

```bash
sed -i "s|https://vision360-backend-[^']*|http://192.168.1.42:8000/api|" \
    mobile_flutter/lib/main.dart

flutter build apk --release
```

Vérifier avant de compiler :

```bash
grep -n "api" mobile_flutter/lib/main.dart | grep -i "http" | head -3
```

### 11.4 Le téléphone ne joint pas le PC

Trois causes possibles, dans l'ordre de fréquence :

1. **Pare-feu du PC** — ouvrir le port 8000 :
   ```bash
   sudo ufw allow 8000/tcp             # Linux
   ```
2. **Isolation des clients Wi-Fi** — certaines box et la plupart des réseaux
   d'établissement empêchent deux appareils de communiquer. Utiliser un partage
   de connexion depuis le téléphone, sur lequel le PC se connecte.
3. **Backend lié à `127.0.0.1`** — vérifier que le port est bien publié :
   ```bash
   docker compose ps        # doit montrer 0.0.0.0:8000->8000/tcp
   ```

Test depuis le navigateur du téléphone : ouvrir `http://<IP_DU_PC>:8000/health`.
Si le JSON s'affiche, le réseau est bon et le problème vient de l'URL saisie.

---

## 12. Autres formats de packaging

### 12.1 iOS — IPA

> **Une machine macOS avec Xcode est indispensable.** Apple ne permet pas de
> compiler pour iOS depuis Linux ou Windows.

```bash
cd mobile_flutter/ios
pod install
cd ..

flutter build ipa --release
```

Résultat : `build/ios/ipa/mobile_flutter.ipa`

Prérequis supplémentaires :

- Un **compte développeur Apple** (99 $/an pour la distribution ; un compte
  gratuit suffit pour installer sur son propre appareil)
- Un profil de provisionnement et un certificat configurés dans Xcode
- Le *Bundle Identifier* défini dans *Xcode → Runner → Signing & Capabilities*

Les descriptions de permissions ont été ajoutées dans
`ios/Runner/Info.plist` — sans elles, iOS fait **planter** l'application au
premier accès au micro ou au GPS :

| Clé | Fonction concernée |
|---|---|
| `NSCameraUsageDescription` | Caméra |
| `NSMicrophoneUsageDescription` | Commandes vocales |
| `NSSpeechRecognitionUsageDescription` | Reconnaissance vocale |
| `NSLocationWhenInUseUsageDescription` | Guidage GPS |

Pour tester sans compte payant :

```bash
flutter build ios --release --no-codesign
# puis ouvrir ios/Runner.xcworkspace dans Xcode et lancer sur un appareil
```

### 12.2 Web — PWA

Flutter peut compiler l'application mobile pour le navigateur.

```bash
flutter build web --release
```

Résultat : dossier `build/web/` (HTML, JS, WASM, assets), servable par n'importe
quel serveur statique.

```bash
cd build/web && python3 -m http.server 8080
```

Limitations réelles pour ce projet :

| Fonction | En Web |
|---|---|
| Caméra | ✅ (nécessite HTTPS ou `localhost`) |
| Synthèse vocale | ✅ (Web Speech API) |
| Reconnaissance vocale | ⚠️ Support inégal selon les navigateurs |
| GPS | ✅ (nécessite HTTPS) |
| Stockage local | ✅ (`localStorage`) |

> Une interface web dédiée existe déjà dans le projet (`web_next/`, Next.js).
> La version Web de l'app Flutter n'a donc d'intérêt que pour une démonstration
> multiplateforme.

### 12.3 Bureau Linux

```bash
sudo apt install -y clang cmake ninja-build pkg-config \
                    libgtk-3-dev liblzma-dev libstdc++-12-dev

flutter config --enable-linux-desktop
flutter build linux --release
```

Résultat : `build/linux/x64/release/bundle/`

Archive distribuable :

```bash
cd build/linux/x64/release
tar czf ~/vision360-linux-x64.tar.gz bundle/
```

### 12.4 Bureau Windows

Nécessite **Visual Studio 2022** avec la charge de travail *Développement
Desktop en C++*.

```powershell
flutter config --enable-windows-desktop
flutter build windows --release
```

Résultat : `build\windows\x64\runner\Release\` (exécutable + DLL — **le dossier
entier doit être distribué**).

### 12.5 Bureau macOS

```bash
flutter config --enable-macos-desktop
flutter build macos --release
```

Résultat : `build/macos/Build/Products/Release/mobile_flutter.app`

---

## 13. Personnalisation avant publication

Ces étapes ne sont **pas nécessaires pour un rendu universitaire**, mais
deviennent obligatoires pour une publication réelle.

### 13.1 Identifiant d'application

L'identifiant actuel est `com.example.mobile_flutter`. **Google Play refuse tout
identifiant commençant par `com.example`.**

```bash
# Méthode automatique (installe l'outil au passage)
dart pub global activate change_app_package_name
dart pub global run change_app_package_name:main fr.vision360.app
```

Cet outil met à jour `build.gradle`, le manifeste, et déplace l'arborescence
Kotlin — trois opérations qu'il est facile de rater à la main.

> ⚠️ **L'identifiant est définitif après la première publication.** Le changer
> revient à publier une application entièrement nouvelle.

### 13.2 Nom affiché

Déjà positionné à **Vision360** dans
`android/app/src/main/AndroidManifest.xml` (`android:label`).

Pour iOS, modifier `CFBundleDisplayName` dans `ios/Runner/Info.plist`.

### 13.3 Icône de l'application

L'icône actuelle est celle par défaut de Flutter. Pour la remplacer :

```yaml
# Ajouter dans pubspec.yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.1

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/vision360.png"   # PNG carré 1024×1024
  adaptive_icon_background: "#0B5FFF"
  adaptive_icon_foreground: "assets/icon/vision360_foreground.png"
```

```bash
flutter pub get
dart run flutter_launcher_icons
```

### 13.4 Numéro de version

Dans `pubspec.yaml` :

```yaml
version: 1.0.0+1
#        │     └── versionCode Android : doit AUGMENTER à chaque envoi au Play Store
#        └──────── versionName : la version lisible par l'utilisateur
```

Ou à la compilation, sans toucher au fichier :

```bash
flutter build apk --release --build-name=1.1.0 --build-number=2
```

### 13.5 Réduction de la taille

```bash
# Retirer les symboles de debug (obligatoire pour un envoi au Play Store)
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```

> Conservez le dossier `build/symbols` : sans lui, les rapports de plantage
> remontés par les utilisateurs sont illisibles.

L'activation de R8 (`minifyEnabled = true` dans `build.gradle`) réduit encore
l'APK, mais **doit être testée** : R8 peut supprimer des classes appelées par
réflexion. Le fichier `android/app/proguard-rules.pro` fourni protège déjà les
plugins sensibles (`speech_to_text`, `flutter_tts`, `camera`, `geolocator`).

---

## 14. Dépannage

### Tableau de résolution rapide

| Message d'erreur | Cause | Solution |
|---|---|---|
| `Android license status unknown` | Licences non acceptées | `flutter doctor --android-licenses` |
| `Could not resolve all files for configuration` | Réseau ou cache Gradle corrompu | `cd android && ./gradlew clean`, puis relancer |
| `Execution failed for task ':app:...'` avec `Unsupported class file major version` | Mauvaise version de JDK | Installer le JDK 17 et le déclarer (§3.2) |
| `Keystore file not found` | Chemin faux dans `key.properties` | Utiliser un chemin **absolu** |
| `Failed to read key from keystore` | Mot de passe ou alias erroné | Vérifier avec `keytool -list -v -keystore <fichier>` |
| `Minimum supported Gradle version is X` | Gradle trop ancien | Relever `distributionUrl` dans `gradle-wrapper.properties` |
| `compileSdk 36 ... requires a newer AGP` | AGP 8.2.2 vs compileSdk 36 | Voir « Conflit de versions » ci-dessous |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | APK déjà installé, signé différemment | `adb uninstall com.example.mobile_flutter` |
| `INSTALL_PARSE_FAILED_NO_CERTIFICATES` | APK non signé | Vérifier la configuration de signature (§6) |
| `Dart SDK version ... doesn't satisfy` | Flutter trop ancien | `flutter upgrade` |
| `MissingPluginException` | Cache de build obsolète | `flutter clean && flutter pub get` |
| `Gradle task assembleRelease failed` sans détail | Sortie tronquée | Relancer avec `--verbose` (voir ci-dessous) |

### Conflit de versions AGP / compileSdk

Le projet cible `compileSdk = 36` avec le plugin Android Gradle **8.2.2**, qui
n'a officiellement été validé que jusqu'à l'API 34. Selon la version exacte de
Flutter installée, cela produit un avertissement — ou une erreur bloquante.

Deux issues, au choix :

**A. Relever le plugin Android Gradle** *(recommandé)* — dans
`android/settings.gradle` :

```groovy
id "com.android.application" version "8.7.0" apply false
```

Et dans `android/gradle/wrapper/gradle-wrapper.properties` :

```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.9-all.zip
```

**B. Neutraliser le contrôle** — dans `android/gradle.properties` :

```properties
android.suppressUnsupportedCompileSdk=36
```

### Nettoyage complet

Quand plus rien ne s'explique :

```bash
cd mobile_flutter
flutter clean
rm -rf android/.gradle build .dart_tool
flutter pub get
flutter build apk --release
```

### Obtenir la vraie erreur

Les messages de Flutter masquent souvent la cause réelle, produite par Gradle :

```bash
flutter build apk --release --verbose 2>&1 | tail -60

# Ou en interrogeant Gradle directement
cd android
./gradlew assembleRelease --stacktrace --info
```

### Vérifier ce que Flutter voit

```bash
flutter doctor -v
flutter --version
java -version
echo "$ANDROID_HOME"
cat android/local.properties     # généré automatiquement
```

### Manque d'espace ou de mémoire

La compilation Android réclame beaucoup de RAM. `gradle.properties` alloue déjà
4 Go à la JVM :

```properties
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G
```

Sur une machine à 8 Go, ramener cette valeur à `-Xmx2G` évite les échecs par
saturation.

---

## 15. Annexes

### A. Aide-mémoire des commandes

```bash
# Préparation
cd mobile_flutter
flutter pub get
flutter doctor -v

# Vérifications
flutter analyze
flutter test

# Compilations
flutter build apk --debug                    # APK de debug rapide
flutter build apk --release                  # APK universel signé
flutter build apk --release --split-per-abi  # 3 APK allégés
flutter build appbundle --release            # AAB pour Google Play
flutter build ipa --release                  # IPA iOS (macOS requis)
flutter build web --release                  # Application Web
flutter build linux --release                # Bureau Linux

# Installation
adb devices
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Dépannage
flutter clean && flutter pub get
flutter build apk --release --verbose
```

### B. Emplacement des artefacts

| Format | Chemin (depuis `mobile_flutter/`) |
|---|---|
| APK debug | `build/app/outputs/flutter-apk/app-debug.apk` |
| APK release | `build/app/outputs/flutter-apk/app-release.apk` |
| APK par ABI | `build/app/outputs/flutter-apk/app-<abi>-release.apk` |
| AAB | `build/app/outputs/bundle/release/app-release.aab` |
| IPA | `build/ios/ipa/mobile_flutter.ipa` |
| Web | `build/web/` |
| Linux | `build/linux/x64/release/bundle/` |
| Windows | `build\windows\x64\runner\Release\` |
| macOS | `build/macos/Build/Products/Release/mobile_flutter.app` |

### C. Permissions déclarées

Déclarées dans `android/app/src/main/AndroidManifest.xml` :

| Permission | Fonction Vision360 | Refus possible ? |
|---|---|---|
| `CAMERA` | Analyse de scène, scan de code-barres, passage en caisse | Oui, désactive Guidance et Caddie |
| `RECORD_AUDIO` | Commandes vocales | Oui, désactive la dictée |
| `INTERNET` | Appels au backend et aux API d'IA | Non (accordée d'office) |
| `ACCESS_FINE_LOCATION` | Guidage piéton précis | Oui, désactive le GPS |
| `ACCESS_COARSE_LOCATION` | Position approximative de repli | Oui |

### D. Fichiers de configuration du packaging

| Fichier | Rôle | Versionné ? |
|---|---|:-:|
| `pubspec.yaml` | Dépendances, version applicative | ✅ |
| `pubspec.lock` | Versions exactes figées | ✅ |
| `android/app/build.gradle` | SDK, signature, types de build | ✅ |
| `android/settings.gradle` | Versions AGP et Kotlin | ✅ |
| `android/gradle.properties` | Options JVM, AndroidX | ✅ |
| `android/app/proguard-rules.pro` | Règles R8 | ✅ |
| `android/app/src/main/AndroidManifest.xml` | Permissions, nom, icône | ✅ |
| `android/key.properties.example` | Modèle de configuration de signature | ✅ |
| **`android/key.properties`** | **Mots de passe du keystore** | ❌ **jamais** |
| **`*.jks` / `*.keystore`** | **Clé de signature** | ❌ **jamais** |
| `android/local.properties` | Chemins locaux des SDK | ❌ (généré) |

### E. Checklist avant remise du livrable

- [ ] `flutter doctor -v` : les lignes Flutter et Android toolchain sont vertes
- [ ] `flutter analyze` ne remonte aucune erreur
- [ ] `flutter test` passe
- [ ] Keystore créé et sauvegardé hors du poste
- [ ] `key.properties` renseigné et **absent de Git**
- [ ] `flutter build apk --release` aboutit
- [ ] `jarsigner -verify` affiche « jar verified »
- [ ] APK installé et lancé sur un appareil réel
- [ ] URL du backend vérifiée depuis l'application
- [ ] Les cinq onglets ont été testés (Profil, Guidance, GPS, Historique, Caddie)
- [ ] APK renommé de façon explicite (`vision360-v1.0.0-release.apk`)

### F. Documents liés

| Document | Contenu |
|---|---|
| `docs_docker_.../INSTALLATION_LINUX.md` | Déploiement du backend Docker à joindre |
| `database_.../README.md` | Base de données : dumps et scripts de création |
| `rapport_technique_.../RAPPORT_TECHNIQUE.md` | Rapport de réalisation du projet |
| `mobile_flutter/README.md` | Notes de développement de l'application |
