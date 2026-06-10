/// Vision360 — Application mobile IA pour PMR
/// Version 2.0 : interface minimaliste, thème sombre/clair, accessibilité adaptable.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'checkout_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// POINT D'ENTRÉE
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  runApp(const Vision360App());
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET RACINE — gère le mode de thème global
// ═══════════════════════════════════════════════════════════════════════════════

class Vision360App extends StatefulWidget {
  const Vision360App({super.key});

  @override
  State<Vision360App> createState() => _Vision360AppState();
}

class _Vision360AppState extends State<Vision360App> {
  ThemeMode _themeMode = ThemeMode.system;

  void _setThemeMode(ThemeMode mode) => setState(() => _themeMode = mode);

  static const _seed = Color(0xFF1A73E8);

  ThemeData _lightTheme() => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: _inputTheme(Brightness.light),
        filledButtonTheme: _filledBtnTheme(),
        outlinedButtonTheme: _outlinedBtnTheme(),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xFFF5F7FA),
        ),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          backgroundColor: Colors.white,
          indicatorColor: _seed.withOpacity(0.12),
        ),
        dividerTheme: const DividerThemeData(space: 1, thickness: 1),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? Colors.white : null),
        ),
      );

  ThemeData _darkTheme() => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF161B22),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: _inputTheme(Brightness.dark),
        filledButtonTheme: _filledBtnTheme(),
        outlinedButtonTheme: _outlinedBtnTheme(),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xFF0D1117),
        ),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          backgroundColor: const Color(0xFF161B22),
          indicatorColor: const Color(0xFF58A6FF).withOpacity(0.15),
        ),
        dividerTheme: const DividerThemeData(space: 1, thickness: 1),
      );

  InputDecorationTheme _inputTheme(Brightness b) {
    final isDark = b == Brightness.dark;
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1C2128) : const Color(0xFFF0F2F5),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: isDark ? const Color(0xFF58A6FF) : _seed, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  FilledButtonThemeData _filledBtnTheme() => FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(0, 48),
        ),
      );

  OutlinedButtonThemeData _outlinedBtnTheme() => OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(0, 48),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vision360',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      themeMode: _themeMode,
      home: HomeScreen(
        onThemeModeChanged: _setThemeMode,
        currentThemeMode: _themeMode,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ÉCRAN PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  final void Function(ThemeMode) onThemeModeChanged;
  final ThemeMode currentThemeMode;

  const HomeScreen({
    super.key,
    required this.onThemeModeChanged,
    required this.currentThemeMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Navigation ──────────────────────────────────────────────────────────────
  int _tabIndex = 1;
  bool _loadingApp = true;

  // ── Profil & API ────────────────────────────────────────────────────────────
  final _apiBaseController = TextEditingController(
    text: 'https://vision360-backend-276274707876.europe-west1.run.app/api',
  );
  final _nameController = TextEditingController(text: 'Utilisateur');
  final _allergiesController = TextEditingController(text: 'arachide');
  final _conditionsController = TextEditingController(text: 'diabete');
  final _preferencesController = TextEditingController(text: 'sans sucre');
  String _mobility = 'fauteuil';
  bool _ttsEnabled = true;

  // ── Commandes internes (masqués de l'UI) ────────────────────────────────────
  final _imageB64Controller = TextEditingController();
  final _promptController = TextEditingController(
    text:
        'Decris precisement les produits/objets visibles, marques ou categories.',
  );
  final _voiceController = TextEditingController();

  // ── Auth ────────────────────────────────────────────────────────────────────
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isAuthenticated = false;
  bool _registerMode = false;
  String _currentUserEmail = '';
  String _authMessage = '';
  bool _authLoading = false;

  // ── Caméra & chargement ─────────────────────────────────────────────────────
  bool _isLoading = false;
  CameraController? _cameraController;
  bool _cameraReady = false;
  String _cameraStatus = '';

  // ── Cooldown ─────────────────────────────────────────────────────────────────
  int _cooldownUntilMs = 0;
  Timer? _cooldownTicker;
  String _cooldownMsg = '';

  // ── Résultats ────────────────────────────────────────────────────────────────
  String _geminiText = '';
  Map<String, dynamic>? _groqStructured;
  bool _hasResults = false;

  // ── Historique & TTS ─────────────────────────────────────────────────────────
  final List<Map<String, String>> _history = [];
  final FlutterTts _tts = FlutterTts();

  // ── Reconnaissance vocale ────────────────────────────────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _voiceTranscript = '';

  // ── GPS / Navigation ─────────────────────────────────────────────────────────
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  ll.LatLng? _currentPosition;
  ll.LatLng? _destination;
  String _destinationName = '';
  List<ll.LatLng> _routePoints = [];
  List<Map<String, dynamic>> _routeSteps = [];
  int _currentStep = 0;
  bool _isNavigating = false;
  bool _gpsReady = false;
  bool _loadingRoute = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _showSearchResults = false;
  List<Map<String, dynamic>> _nearbyPlaces = [];
  bool _loadingNearby = false;
  double _totalRouteDistance = 0;
  double _totalRouteDuration = 0;
  StreamSubscription<Position>? _positionStream;
  Timer? _searchDebounce;

  // ── Mode produit ─────────────────────────────────────────────────────────────
  bool _productMode = false;
  String? _productFrontB64;
  String? _productBackB64;

  // ── Inventaire maison ────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _homeInventory = [];
  final _inventoryAddController = TextEditingController();

  // ── Caddie (courses) ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _cartItems = [];
  int _caddieMode = 0; // 0=scanner, 1=vérif caddie, 2=vérif caisse
  bool _cartVerifying = false;

  // ── Accessibilité ────────────────────────────────────────────────────────────
  bool _largeFontSize = false;
  bool _largeButtons = false;
  bool _highContrast = false;

  // ── Clés SharedPreferences ───────────────────────────────────────────────────
  static const _usersKey = 'vision360_users';
  static const _sessionKey = 'vision360_session';
  static const _apiBaseKey = 'vision360_api_base';
  static const _accessKey = 'vision360_accessibility';
  static const _themeModeKey = 'vision360_theme_mode';

  // ─────────────────────────────────────────────────────────────────────────────
  // CYCLE DE VIE
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _initTts();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (_) => setState(() => _isListening = false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
          if (_voiceTranscript.trim().isNotEmpty) {
            _voiceController.text = _voiceTranscript.trim();
            _callGroqManual();
          }
        }
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      _showSnack('Reconnaissance vocale non disponible sur cet appareil.');
      return;
    }
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    setState(() {
      _isListening = true;
      _voiceTranscript = '';
    });
    await _tts.stop();
    await _speech.listen(
      onResult: (result) => setState(() {
        _voiceTranscript = result.recognizedWords;
      }),
      localeId: 'fr_FR',
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  Future<void> _initTts() async {
    try {
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.5);
      // Tenter le français, sinon laisser la langue système
      final langs = await _tts.getLanguages;
      if (langs is List && langs.any((l) => l.toString().startsWith('fr'))) {
        await _tts.setLanguage('fr-FR');
      }
    } catch (_) {}
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();

    final savedApi = prefs.getString(_apiBaseKey);
    if (savedApi != null && savedApi.isNotEmpty) {
      _apiBaseController.text = savedApi;
    }

    final sessionEmail = prefs.getString(_sessionKey);
    if (sessionEmail != null && sessionEmail.isNotEmpty) {
      _currentUserEmail = sessionEmail;
      _isAuthenticated = true;
      await _loadUserData();
    }

    final accessRaw = prefs.getString(_accessKey);
    if (accessRaw != null) {
      final access = jsonDecode(accessRaw) as Map<String, dynamic>;
      _largeFontSize = access['largeFontSize'] == true;
      _largeButtons = access['largeButtons'] == true;
      _highContrast = access['highContrast'] == true;
    }

    final themeSaved = prefs.getString(_themeModeKey);
    if (themeSaved != null) {
      final mode = ThemeMode.values.firstWhere(
        (m) => m.name == themeSaved,
        orElse: () => ThemeMode.system,
      );
      widget.onThemeModeChanged(mode);
    }

    if (mounted) setState(() => _loadingApp = false);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PERSISTANCE
  // ─────────────────────────────────────────────────────────────────────────────

  String _profileKey() => 'vision360_profile_$_currentUserEmail';
  String _historyKey() => 'vision360_history_$_currentUserEmail';

  Map<String, dynamic> _buildProfile() => {
        'name': _nameController.text.trim(),
        'allergies': _splitList(_allergiesController.text),
        'conditions': _splitList(_conditionsController.text),
        'preferences': _splitList(_preferencesController.text),
        'mobility': _mobility,
        'tts_enabled': _ttsEnabled,
      };

  List<String> _splitList(String raw) =>
      raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<Map<String, String>> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usersKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v.toString()));
  }

  Future<void> _saveUsers(Map<String, String> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersKey, jsonEncode(users));
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, _currentUserEmail);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<void> _saveApiBase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiBaseKey, _apiBaseController.text.trim());
  }

  Future<void> _saveProfile() async {
    if (_currentUserEmail.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey(), jsonEncode(_buildProfile()));
  }

  Future<void> _saveHistory() async {
    if (_currentUserEmail.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey(), jsonEncode(_history));
  }

  String _inventoryStoreKey() => 'vision360_inventory_$_currentUserEmail';
  String _cartStoreKey() => 'vision360_cart_$_currentUserEmail';

  Future<void> _loadInventory() async {
    if (_currentUserEmail.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_inventoryStoreKey());
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List;
      _homeInventory = list.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    }
  }

  Future<void> _saveInventory() async {
    if (_currentUserEmail.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_inventoryStoreKey(), jsonEncode(_homeInventory));
  }

  Future<void> _loadCart() async {
    if (_currentUserEmail.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cartStoreKey());
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List;
      _cartItems = list.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    }
  }

  Future<void> _saveCart() async {
    if (_currentUserEmail.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cartStoreKey(), jsonEncode(_cartItems));
  }

  /// Ajoute tous les articles du caddie à l'inventaire maison après vérif caisse validée.
  void _addCartItemsToInventory() {
    if (_cartItems.isEmpty) return;
    final today = DateTime.now().toLocal().toString().substring(0, 10);
    final added = <String>[];
    for (final item in _cartItems) {
      final name = (item['name'] ?? 'Produit').toString();
      // Éviter les doublons (même nom + même date)
      final exists = _homeInventory.any((e) => e['name'] == name && e['date'] == today);
      if (!exists) {
        _homeInventory.insert(0, {'name': name, 'summary': item['summary'] ?? '', 'date': today});
        added.add(name);
      }
    }
    if (added.isEmpty) return;
    _saveInventory();
    _showSnack('${added.length} produit(s) ajouté(s) à l\'inventaire');
    if (_ttsEnabled) {
      _tts.speak('${added.length} produit${added.length > 1 ? 's' : ''} ajouté${added.length > 1 ? 's' : ''} à votre inventaire maison.');
    }
  }

  void _removeFromInventory(int index) {
    setState(() => _homeInventory.removeAt(index));
    _saveInventory();
  }

  void _addToInventoryManual() {
    final name = _inventoryAddController.text.trim();
    if (name.isEmpty) return;
    final item = {
      'name': name,
      'summary': '',
      'date': DateTime.now().toLocal().toString().substring(0, 10),
    };
    setState(() => _homeInventory.insert(0, item));
    _saveInventory();
    _inventoryAddController.clear();
    _showSnack('Ajouté : $name');
  }

  Future<void> _editInventoryItem(int index) async {
    final current = _homeInventory[index]['name']?.toString() ?? '';
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer le produit'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Nom du produit'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && result.isNotEmpty) {
      setState(() => _homeInventory[index] = {..._homeInventory[index], 'name': result});
      _saveInventory();
    }
  }

  void _addToCart() {
    if (_groqStructured == null) return;
    final name = (_groqStructured!['name'] ?? _groqStructured!['summary'] ?? 'Produit').toString().split('.').first.trim();
    final item = {
      'name': name.length > 60 ? '${name.substring(0, 57)}...' : name,
      'summary': (_groqStructured!['summary'] ?? '').toString(),
      'date': DateTime.now().toLocal().toString().substring(0, 16),
    };
    setState(() => _cartItems.add(item));
    _saveCart();
    _showSnack('Ajouté au caddie : ${item['name']}');
    if (_ttsEnabled) _tts.speak('Ajouté au caddie : ${item['name']}');
  }

  void _removeFromCart(int index) {
    final name = _cartItems[index]['name'] ?? 'Produit';
    setState(() => _cartItems.removeAt(index));
    _saveCart();
    _showSnack('Retiré du caddie : $name');
  }

  Future<void> _verifyCartOrBelt() async {
    if (!_cameraReady) {
      _showSnack('Activez la caméra d\'abord.', isError: true);
      return;
    }
    setState(() { _cartVerifying = true; _isLoading = true; });
    try {
      final b64 = await _captureImage();
      if (b64 == null) return;
      final apiBase = _apiBaseController.text.trim();
      final surface = _caddieMode == 2 ? 'tapis roulant de caisse' : 'caddie de supermarché';
      final geminiR = await http.post(
        Uri.parse('$apiBase/describe/gemini'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image_b64': b64,
          'prompt': 'Liste précisément tous les produits visibles sur ce $surface.',
        }),
      );
      if (geminiR.statusCode != 200) throw Exception('Gemini error');
      final geminiD = jsonDecode(geminiR.body) as Map<String, dynamic>;
      final seen = ((geminiD['structured'] as Map<String, dynamic>?) ?? {})['text']?.toString() ?? '';
      final cartDesc = _cartItems.isEmpty
          ? 'Aucun produit enregistré dans le caddie'
          : _cartItems.map((i) => '• ${i['name']}').join('\n');
      await _callGroqWithDescription(
        'Produits attendus :\n$cartDesc\n\nProduits visibles sur le $surface :\n$seen',
        skipHistory: true,
        customInstruction:
            'Génère un JSON strict : {"summary": string, "risks": [string], "actions": [string]}. '
            '"summary" : 2-3 phrases confirmant ce qui est visible vs attendu, pour personne malvoyante. '
            'Sois très direct et précis. '
            '"risks" : produits manquants ou non reconnus. "actions" : que faire.',
      );
      // Vérif caisse réussie → tous les articles du caddie passent dans l'inventaire maison
      if (_caddieMode == 2) {
        setState(_addCartItemsToInventory);
      }
    } catch (e) {
      _showSnack('Erreur de vérification.', isError: true);
    } finally {
      setState(() { _cartVerifying = false; _isLoading = false; });
    }
  }

  Future<void> _saveAccessibility() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _accessKey,
      jsonEncode({
        'largeFontSize': _largeFontSize,
        'largeButtons': _largeButtons,
        'highContrast': _highContrast,
      }),
    );
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
    widget.onThemeModeChanged(mode);
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    final profileRaw = prefs.getString(_profileKey());
    if (profileRaw != null && profileRaw.isNotEmpty) {
      final profile = jsonDecode(profileRaw) as Map<String, dynamic>;
      _nameController.text = (profile['name'] ?? '').toString();
      _allergiesController.text =
          (profile['allergies'] as List<dynamic>? ?? []).join(', ');
      _conditionsController.text =
          (profile['conditions'] as List<dynamic>? ?? []).join(', ');
      _preferencesController.text =
          (profile['preferences'] as List<dynamic>? ?? []).join(', ');
      _mobility = (profile['mobility'] ?? 'fauteuil').toString();
      _ttsEnabled = profile['tts_enabled'] == true;
    }

    final historyRaw = prefs.getString(_historyKey());
    _history.clear();
    if (historyRaw != null && historyRaw.isNotEmpty) {
      final list = jsonDecode(historyRaw) as List<dynamic>;
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          _history.add({
            'summary': (item['summary'] ?? '').toString(),
            'time': (item['time'] ?? '').toString(),
          });
        }
      }
    }
    await _loadInventory();
    await _loadCart();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // AUTHENTIFICATION
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim().toLowerCase();
    final pass = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _authMessage = 'Email et mot de passe obligatoires.');
      return;
    }

    setState(() => _authLoading = true);
    final users = await _loadUsers();

    if (_registerMode) {
      if (pass != confirm) {
        setState(() {
          _authMessage = 'Les mots de passe ne correspondent pas.';
          _authLoading = false;
        });
        return;
      }
      if (users.containsKey(email)) {
        setState(() {
          _authMessage = 'Ce compte existe déjà.';
          _authLoading = false;
        });
        return;
      }
      users[email] = pass;
      await _saveUsers(users);
      setState(() {
        _authMessage = 'Inscription réussie. Connecte-toi.';
        _registerMode = false;
        _authLoading = false;
      });
      return;
    }

    if (!users.containsKey(email) || users[email] != pass) {
      setState(() {
        _authMessage = 'Identifiants invalides.';
        _authLoading = false;
      });
      return;
    }

    _currentUserEmail = email;
    await _saveSession();
    await _loadUserData();
    setState(() {
      _isAuthenticated = true;
      _authMessage = '';
      _authLoading = false;
      _tabIndex = 1;
    });
  }

  Future<void> _logout() async {
    await _clearSession();
    if (_cameraReady) await _stopCamera();
    setState(() {
      _isAuthenticated = false;
      _currentUserEmail = '';
      _tabIndex = 1;
      _hasResults = false;
      _geminiText = '';
      _groqStructured = null;
      _homeInventory = [];
      _cartItems = [];
      _productFrontB64 = null;
      _productBackB64 = null;
      _productMode = false;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CAMÉRA
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _startCamera() async {
    if (_cameraReady) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraStatus = 'Aucune caméra détectée.');
        return;
      }
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _cameraReady = true;
          _cameraStatus = '';
        });
      }
    } catch (exc) {
      setState(() => _cameraStatus = 'Erreur caméra: $exc');
    }
  }

  Future<void> _stopCamera() async {
    await _cameraController?.dispose();
    _cameraController = null;
    setState(() {
      _cameraReady = false;
      _cameraStatus = '';
    });
  }

  Future<String?> _captureImage() async {
    if (_cameraController == null || !_cameraReady) return null;
    try {
      final file = await _cameraController!.takePicture();
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      _imageB64Controller.text = b64;
      return b64;
    } catch (exc) {
      setState(() => _cameraStatus = 'Capture échouée: $exc');
      return null;
    }
  }

  /// Capture une face de produit et affiche un dialog de prévisualisation/validation.
  Future<void> _captureProductFace(bool isFront) async {
    final b64 = await _captureImage();
    if (b64 == null || !mounted) return;

    final cs = Theme.of(context).colorScheme;
    final label = isFront ? 'Face avant' : 'Face arrière';

    // Afficher la prévisualisation pour valider ou reprendre
    final validated = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    isFront ? Icons.flip_to_front_outlined : Icons.flip_to_back_outlined,
                    size: 18,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(b64),
                  height: 260,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx, false),
                      icon: const Icon(Icons.replay, size: 16),
                      label: const Text('Reprendre'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Valider'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (validated == true) {
      setState(() {
        if (isFront) { _productFrontB64 = b64; }
        else { _productBackB64 = b64; }
      });
      if (_ttsEnabled) _tts.speak('$label validée');
    }
  }

  /// Envoie les deux faces en un seul appel Gemini (économie de tokens),
  /// puis passe la description combinée à Groq.
  Future<void> _analyzeProductFaces() async {
    if (_productFrontB64 == null) {
      _showSnack('Capturez au moins la face avant.', isError: true);
      return;
    }
    if (DateTime.now().millisecondsSinceEpoch < _cooldownUntilMs) {
      setState(() => _cooldownMsg = 'Patientez avant un nouvel envoi.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final apiBase = _apiBaseController.text.trim();

      // Un seul appel Gemini avec les deux images
      final r = await http.post(
        Uri.parse('$apiBase/describe/gemini/product'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'front_b64': _productFrontB64,
          if (_productBackB64 != null) 'back_b64': _productBackB64,
        }),
      );

      if (r.statusCode != 200) throw Exception(r.body);

      final d = jsonDecode(r.body) as Map<String, dynamic>;
      final description = ((d['structured'] as Map<String, dynamic>?) ?? {})['text']?.toString() ?? '';

      if (description.isEmpty) {
        _showSnack('Impossible d\'analyser le produit.', isError: true);
        return;
      }

      setState(() => _geminiText = description);

      await _callGroqWithDescription(
        description,
        customInstruction:
            'Génère un JSON strict : {"name": string, "summary": string, "risks": [string], "actions": [string]}. '
            '"name" : nom commercial exact du produit. '
            '"summary" en 2-3 phrases : description du produit + points importants pour l\'utilisateur. '
            'N\'inclure QUE les éléments du profil directement liés au produit (allergies si aliment, mobilité si obstacle). '
            '"risks" : risques réels (allergies, contre-indications). '
            '"actions" : recommandations concrètes.',
      );
    } catch (e) {
      _showSnack('Erreur analyse produit.', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // APPELS API
  // ─────────────────────────────────────────────────────────────────────────────

  /// Tente d'extraire un Map JSON depuis la réponse Groq.
  /// Gère les cas où Groq enveloppe sa réponse dans des blocs markdown ```json```.
  Map<String, dynamic>? _parseGroqResponse(Map<String, dynamic> decoded) {
    // Cas 1 : backend a déjà parsé correctement
    final structured = decoded['structured'];
    if (structured is Map<String, dynamic>) return structured;

    // Cas 2 : Groq a retourné du texte (markdown ou JSON brut)
    final rawText = decoded['raw_text']?.toString() ?? '';
    if (rawText.isEmpty) return null;
    try {
      var text = rawText.trim();
      // Supprimer les balises ```json ... ```
      text = text.replaceFirst(RegExp(r'^```(?:json)?\s*', multiLine: false), '');
      text = text.replaceFirst(RegExp(r'\s*```\s*$', multiLine: false), '');
      // Extraire le premier objet JSON { ... }
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start != -1 && end != -1) {
        text = text.substring(start, end + 1);
      }
      final parsed = jsonDecode(text);
      if (parsed is Map<String, dynamic>) return parsed;
    } catch (_) {}
    return null;
  }

  Future<void> _callGroqWithDescription(String description, {String? customInstruction, bool skipHistory = false}) async {
    final apiBase = _apiBaseController.text.trim();
    final response = await http.post(
      Uri.parse('$apiBase/describe/groq'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'description': description,
        'profile_override': _buildProfile(),
        'instruction': customInstruction ??
            'Génère un JSON strict : {"summary": string, "risks": [string], "actions": [string]}. '
            'Règle absolue : n\'inclure dans le résumé QUE les éléments du profil utilisateur directement liés à la scène ou à la question posée. '
            'Si la question porte sur un aliment, cite uniquement les allergies/conditions alimentaires concernées — ignore la mobilité. '
            'Si la question porte sur un obstacle/navigation, cite uniquement la mobilité — ignore les allergies. '
            'Le "summary" en 2-3 phrases max : situation + conseil essentiel adapté au contexte. '
            '"risks" uniquement si risque réel et pertinent. "actions" : ce qu\'il faut faire concrètement.',
      }),
    );

    if (response.statusCode != 200) throw Exception(response.body);

    final groqDecoded = jsonDecode(response.body) as Map<String, dynamic>;
    final parsed = _parseGroqResponse(groqDecoded);

    setState(() {
      _groqStructured = parsed;
      _hasResults = true;
      _cooldownUntilMs = DateTime.now().millisecondsSinceEpoch + 60000;
      _cooldownMsg = '';
    });
    _startCooldownTicker();

    if (!skipHistory) {
      _history.insert(0, {
        'summary': (parsed?['summary'] ?? 'Conseil').toString(),
        'time': DateTime.now().toLocal().toString(),
      });
      await _saveHistory();
    }

    if (_ttsEnabled && _groqStructured != null) {
      await _speakGroq(_groqStructured);
    }
  }


  Future<void> _speakGroq(dynamic structured) async {
    if (!_ttsEnabled || structured is! Map) return;
    final summary = structured['summary']?.toString() ?? '';
    if (summary.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(summary);
    } catch (_) {}
  }

  Future<void> _callChain() async {
    final apiBase = _apiBaseController.text.trim();
    if (apiBase.isEmpty) return;

    if (DateTime.now().millisecondsSinceEpoch < _cooldownUntilMs) {
      setState(() => _cooldownMsg = 'Patientez avant un nouvel envoi.');
      return;
    }

    await _saveApiBase();
    await _saveProfile();

    final b64 = await _captureImage();
    if (b64 == null || b64.isEmpty) {
      _showSnack('Aucune image à envoyer.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final geminiResponse = await http.post(
        Uri.parse('$apiBase/describe/gemini'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image_b64': b64,
          'prompt': _promptController.text.trim(),
        }),
      );

      if (geminiResponse.statusCode != 200) {
        throw Exception(geminiResponse.body);
      }

      final geminiDecoded =
          jsonDecode(geminiResponse.body) as Map<String, dynamic>;
      final structuredGemini =
          geminiDecoded['structured'] as Map<String, dynamic>? ?? {};
      final geminiTextValue = (structuredGemini['text'] ?? '').toString();
      setState(() => _geminiText = geminiTextValue);

      await _callGroqWithDescription(geminiTextValue);
    } catch (exc) {
      _showSnack('Erreur lors de l\'analyse.', isError: true);
      setState(() => _hasResults = false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _callGroqManual() async {
    final description = _voiceController.text.trim().isEmpty
        ? _geminiText.trim()
        : _voiceController.text.trim();
    if (description.isEmpty) return;

    if (DateTime.now().millisecondsSinceEpoch < _cooldownUntilMs) {
      setState(() => _cooldownMsg = 'Patientez avant un nouvel envoi.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _callGroqWithDescription(description);
    } catch (exc) {
      _showSnack('Erreur Groq.', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startCooldownTicker() {
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (DateTime.now().millisecondsSinceEpoch >= _cooldownUntilMs) {
        timer.cancel();
        setState(() => _cooldownMsg = '');
      } else {
        final s =
            ((_cooldownUntilMs - DateTime.now().millisecondsSinceEpoch) / 1000)
                .ceil();
        setState(() => _cooldownMsg = '$s s avant le prochain envoi');
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HISTORIQUE
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _exportHistoryToFile() async {
    final jsonData = const JsonEncoder.withIndent('  ').convert(_history);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/vision360_history_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonData);
    if (!mounted) return;
    _showSnack('Exporté: ${file.path}');
  }

  Future<void> _copyHistoryToClipboard() async {
    final jsonData = const JsonEncoder.withIndent('  ').convert(_history);
    await Clipboard.setData(ClipboardData(text: jsonData));
    if (!mounted) return;
    _showSnack('Historique copié dans le presse-papiers.');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // GPS & NAVIGATION
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _initGps() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack('Le GPS est désactivé. Activez-le dans les paramètres.');
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnack('Permission GPS refusée.', isError: true);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showSnack('Permission GPS bloquée. Modifiez-la dans les paramètres.');
      return;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    setState(() {
      _currentPosition = ll.LatLng(pos.latitude, pos.longitude);
      _gpsReady = true;
    });
    _mapController.move(_currentPosition!, 15);
    _startPositionStream();
    _loadNearbyPlaces();
  }

  void _startPositionStream() {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      ),
    ).listen((pos) {
      final newPos = ll.LatLng(pos.latitude, pos.longitude);
      setState(() => _currentPosition = newPos);
      if (_isNavigating) _checkStepAdvance(newPos);
    });
  }

  void _checkStepAdvance(ll.LatLng pos) {
    if (_routeSteps.isEmpty || _currentStep >= _routeSteps.length) return;
    final stepCoord = _routeSteps[_currentStep]['coord'] as ll.LatLng?;
    if (stepCoord == null) return;
    final dist = const ll.Distance().as(ll.LengthUnit.Meter, pos, stepCoord);
    if (dist < 25) _advanceStep();
  }

  void _advanceStep() {
    if (_currentStep < _routeSteps.length - 1) {
      setState(() => _currentStep++);
      _speakStep(_currentStep);
    } else {
      setState(() => _isNavigating = false);
      _tts.speak('Vous êtes arrivé à destination.');
    }
  }

  void _speakStep(int index) {
    if (!_ttsEnabled || index >= _routeSteps.length) return;
    final instruction = _routeSteps[index]['instruction']?.toString() ?? '';
    if (instruction.isNotEmpty) _tts.speak(instruction);
  }

  Future<void> _searchPlaces(String query) async {
    if (query.trim().length < 3) {
      setState(() { _searchResults = []; _showSearchResults = false; });
      return;
    }
    try {
      // Photon (komoot) : spécialisé autocomplete/commerces, biais lat/lon natif, sans clé
      // Stratégie :
      //  - 1 mot  → bbox local (~50 km) + bias fort (0.9) : trouve le commerce le plus proche
      //  - 2+ mots → pas de bbox + bias faible (0.3) : les mots du query précisent déjà la zone
      //    Ex: "Leclerc Orly" → Photon comprend "Orly" comme filtre géographique
      //    Ex: "Leclerc Paris" depuis Orly → cherche Leclerc à Paris, pas dans la bbox locale
      final wordCount = query.trim().split(RegExp(r'\s+')).length;
      final isMultiWord = wordCount >= 2;

      final params = <String, String>{
        'q': query,
        'limit': '8',
        'lang': 'fr',
        'location_bias_scale': isMultiWord ? '0.3' : '0.9',
      };

      if (_currentPosition != null) {
        final lat = _currentPosition!.latitude;
        final lon = _currentPosition!.longitude;
        params['lat'] = lat.toString();
        params['lon'] = lon.toString();
        // bbox uniquement pour les recherches courtes (un mot = cherche autour de moi)
        if (!isMultiWord) {
          const d = 0.45; // ~50 km
          params['bbox'] = '${lon - d},${lat - d},${lon + d},${lat + d}';
        }
      } else if (!isMultiWord) {
        // Sans position et sans ville dans la recherche : France uniquement
        params['bbox'] = '-5.142,41.333,9.561,51.089';
      }
      final uri = Uri.parse('https://photon.komoot.io/api/')
          .replace(queryParameters: params);
      final response = await http
          .get(uri, headers: {'User-Agent': 'Vision360App/1.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _showSnack('Recherche indisponible (${response.statusCode})', isError: true);
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = (data['features'] as List? ?? []);

      final mapped = features.map<Map<String, dynamic>>((f) {
        final props = f['properties'] as Map<String, dynamic>? ?? {};
        final coords = (f['geometry']['coordinates'] as List);
        final fLon = (coords[0] as num).toDouble();
        final fLat = (coords[1] as num).toDouble();

        // Construire un nom lisible
        final parts = <String>[];
        final name = props['name']?.toString();
        final street = props['street']?.toString();
        final housenum = props['housenumber']?.toString();
        final city = props['city']?.toString();
        final postcode = props['postcode']?.toString();
        if (name != null) parts.add(name);
        if (street != null) {
          parts.add(housenum != null ? '$housenum $street' : street);
        }
        if (city != null) {
          parts.add(postcode != null ? '$postcode $city' : city);
        }
        if (parts.isEmpty) parts.add(props['extent']?.toString() ?? 'Lieu');

        double? dist;
        if (_currentPosition != null) {
          dist = Geolocator.distanceBetween(
              _currentPosition!.latitude, _currentPosition!.longitude, fLat, fLon);
        }
        final osmKey = props['osm_key']?.toString() ?? '';
        final osmVal = props['osm_value']?.toString() ?? '';
        return {
          'name': parts.join(', '),
          'lat': fLat,
          'lon': fLon,
          'distance': dist,
          'type': osmVal.isNotEmpty ? osmVal : osmKey,
          'class': osmKey,
        };
      }).toList();

      setState(() {
        _searchResults = mapped;
        _showSearchResults = mapped.isNotEmpty;
      });
    } on TimeoutException {
      _showSnack('Délai de recherche dépassé.', isError: true);
    } catch (e) {
      _showSnack('Erreur de recherche.', isError: true);
    }
  }

  Future<void> _loadNearbyPlaces() async {
    if (_currentPosition == null) return;
    setState(() => _loadingNearby = true);
    final lat = _currentPosition!.latitude;
    final lon = _currentPosition!.longitude;

    // Rayon 2 km — couvre les grandes surfaces (Leclerc, Franprix, Carrefour…)
    // node + way + relation pour capturer tout type d'élément OSM
    // shop=hypermarket|supermarket|… couvre les grandes et moyennes surfaces
    const r = 2000;
    final shopTypes =
        'supermarket|hypermarket|convenience|bakery|mall|department_store'
        '|variety_store|grocery|butcher|chemist|clothes|electronics|hardware';
    final amenityTypes =
        'pharmacy|hospital|clinic|doctors|supermarket|restaurant|fast_food'
        '|cafe|bar|bank|atm|bus_stop|school|fuel|post_office|police|fire_station';

    final query =
        '[out:json][timeout:20];('
        'node["shop"~"$shopTypes"](around:$r,$lat,$lon);'
        'way["shop"~"$shopTypes"](around:$r,$lat,$lon);'
        'relation["shop"~"$shopTypes"](around:$r,$lat,$lon);'
        'node["amenity"~"$amenityTypes"](around:$r,$lat,$lon);'
        'way["amenity"~"$amenityTypes"](around:$r,$lat,$lon);'
        'relation["amenity"~"$amenityTypes"](around:$r,$lat,$lon);'
        ');out center 40;';

    try {
      final response = await http
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            body: 'data=${Uri.encodeComponent(query)}',
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        setState(() => _loadingNearby = false);
        return;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = (data['elements'] as List? ?? []);

      // Dédupliquer par nom + type (évite doublons node/way/relation du même lieu)
      final seen = <String>{};
      final places = <Map<String, dynamic>>[];

      for (final e in elements) {
        final tags = e['tags'] as Map<String, dynamic>? ?? {};
        // Utiliser 'name' ou 'brand' comme fallback (ex: stations-service sans nom propre)
        final name = (tags['name'] ?? tags['brand'])?.toString();
        if (name == null) continue;

        final type = (tags['amenity'] ?? tags['shop'] ?? '').toString();
        final key = '$name|$type';
        if (seen.contains(key)) continue;
        seen.add(key);

        final eLat = (e['lat'] ?? (e['center'] as Map?)?['lat'] ?? 0.0) as num;
        final eLon = (e['lon'] ?? (e['center'] as Map?)?['lon'] ?? 0.0) as num;
        if (eLat == 0.0 && eLon == 0.0) continue;

        final dist = Geolocator.distanceBetween(
            lat, lon, eLat.toDouble(), eLon.toDouble());
        places.add({
          'name': name,
          'lat': eLat.toDouble(),
          'lon': eLon.toDouble(),
          'distance': dist,
          'type': type,
          'class': tags.containsKey('shop') ? 'shop' : 'amenity',
        });
      }

      places.sort((a, b) =>
          (a['distance'] as double).compareTo(b['distance'] as double));

      setState(() {
        _nearbyPlaces = places.take(30).toList();
        _loadingNearby = false;
      });
    } catch (_) {
      setState(() => _loadingNearby = false);
    }
  }

  Future<void> _selectPlace(Map<String, dynamic> place) async {
    final dest = ll.LatLng(place['lat'] as double, place['lon'] as double);
    setState(() {
      _destination = dest;
      _destinationName = place['name'].toString();
      _showSearchResults = false;
      _searchController.text = _destinationName.split(',').first.trim();
      _routePoints = [];
      _routeSteps = [];
      _isNavigating = false;
    });
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([
          _currentPosition ?? dest,
          dest,
        ]),
        padding: const EdgeInsets.all(60),
      ),
    );
    await _fetchRoute();
  }

  /// Décode un polyline encodé (algorithme Google, précision configurable).
  List<ll.LatLng> _decodePolyline(String encoded, {int precision = 6}) {
    final factor = precision == 6 ? 1000000 : 100000;
    final points = <ll.LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      points.add(ll.LatLng(lat / factor, lng / factor));
    }
    return points;
  }

  Future<void> _fetchRoute() async {
    if (_currentPosition == null || _destination == null) return;
    setState(() => _loadingRoute = true);

    final from = _currentPosition!;
    final to = _destination!;

    // ── Essai 1 : Valhalla (instructions FR natives, très fiable) ────────────
    try {
      final body = jsonEncode({
        'locations': [
          {'lon': from.longitude, 'lat': from.latitude},
          {'lon': to.longitude, 'lat': to.latitude},
        ],
        'costing': 'pedestrian',
        'directions_options': {
          'language': 'fr-FR',
          'units': 'km',
        },
      });
      final resp = await http
          .post(
            Uri.parse('https://valhalla1.openstreetmap.de/route'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Vision360App/1.0',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final trip = data['trip'] as Map<String, dynamic>;
        final leg = (trip['legs'] as List).first as Map<String, dynamic>;

        // Valhalla retourne la route en polyline encodé (précision 6)
        final shape = leg['shape']?.toString() ?? '';
        final coords = shape.isNotEmpty ? _decodePolyline(shape, precision: 6) : <ll.LatLng>[];

        final maneuvers = (leg['maneuvers'] as List? ?? []);
        final parsedSteps = maneuvers.map<Map<String, dynamic>>((m) {
          final beginIdx = (m['begin_shape_index'] as int? ?? 0)
              .clamp(0, coords.isEmpty ? 0 : coords.length - 1);
          return {
            'instruction': m['instruction']?.toString() ?? 'Continuer',
            'distance': ((m['length'] as num? ?? 0) * 1000).round(), // km → m
            'coord': coords.isEmpty ? to : coords[beginIdx],
          };
        }).toList();

        final summary = trip['summary'] as Map<String, dynamic>? ?? {};
        setState(() {
          _routePoints = coords;
          _routeSteps = parsedSteps;
          _currentStep = 0;
          _loadingRoute = false;
          _totalRouteDistance = ((summary['length'] as num?) ?? 0) * 1000;
          _totalRouteDuration = ((summary['time'] as num?) ?? 0).toDouble();
        });
        return;
      }
    } catch (_) {}

    // ── Essai 2 : OSRM (fallback) ────────────────────────────────────────────
    try {
      final url = 'https://router.project-osrm.org/route/v1/foot/'
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
          '?steps=true&overview=full&geometries=geojson';
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'Vision360App/1.0'})
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final route = (data['routes'] as List).first as Map<String, dynamic>;

        final coords = (route['geometry']['coordinates'] as List)
            .map((c) => ll.LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList();

        final steps = (route['legs'] as List).first['steps'] as List;
        final parsedSteps = steps.map<Map<String, dynamic>>((s) {
          final maneuver = s['maneuver'] as Map<String, dynamic>;
          final loc = maneuver['location'] as List;
          final instr = _formatOsrmStep(
            maneuver['type']?.toString() ?? '',
            maneuver['modifier']?.toString() ?? '',
            s['name']?.toString() ?? '',
          );
          return {
            'instruction': instr.isNotEmpty ? instr : 'Continuer',
            'distance': ((s['distance'] as num?) ?? 0).round(),
            'coord': ll.LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
          };
        }).toList();

        setState(() {
          _routePoints = coords;
          _routeSteps = parsedSteps;
          _currentStep = 0;
          _loadingRoute = false;
          _totalRouteDistance = (route['distance'] as num?)?.toDouble() ?? 0;
          _totalRouteDuration = (route['duration'] as num?)?.toDouble() ?? 0;
        });
        return;
      }
    } catch (_) {}

    setState(() => _loadingRoute = false);
    _showSnack('Impossible de calculer l\'itinéraire. Vérifiez votre connexion.', isError: true);
  }

  String _formatOsrmStep(String type, String modifier, String street) {
    final s = street.isNotEmpty ? ' sur $street' : '';
    switch (type) {
      case 'depart':          return 'Démarrer$s';
      case 'arrive':          return 'Vous êtes arrivé à destination';
      case 'turn':
        switch (modifier) {
          case 'left':          return 'Tourner à gauche$s';
          case 'right':         return 'Tourner à droite$s';
          case 'slight left':   return 'Légèrement à gauche$s';
          case 'slight right':  return 'Légèrement à droite$s';
          case 'sharp left':    return 'Virage serré à gauche$s';
          case 'sharp right':   return 'Virage serré à droite$s';
          case 'uturn':         return 'Faire demi-tour$s';
          default:              return 'Continuer$s';
        }
      case 'continue':        return 'Continuer tout droit$s';
      case 'new name':        return 'Continuer$s';
      case 'merge':           return 'Rejoindre$s';
      case 'roundabout':      return 'Prendre le rond-point$s';
      case 'exit roundabout': return 'Sortir du rond-point$s';
      case 'fork':
        return modifier.contains('left') ? 'Prendre à gauche$s' : 'Prendre à droite$s';
      default:                return street.isNotEmpty ? 'Continuer$s' : 'Continuer';
    }
  }

  void _startNavigation() {
    if (_routeSteps.isEmpty) return;
    setState(() { _isNavigating = true; _currentStep = 0; });
    _speakStep(0);
  }

  void _stopNavigation() {
    setState(() { _isNavigating = false; _currentStep = 0; });
    _tts.stop();
  }

  void _clearDestination() {
    setState(() {
      _destination = null;
      _destinationName = '';
      _routePoints = [];
      _routeSteps = [];
      _isNavigating = false;
      _searchController.clear();
    });
  }

  void _recenterMap() {
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, 15);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _searchDebounce?.cancel();
    _positionStream?.cancel();
    _mapController.dispose();
    _cameraController?.dispose();
    _tts.stop();
    for (final c in [
      _apiBaseController,
      _nameController,
      _allergiesController,
      _conditionsController,
      _preferencesController,
      _imageB64Controller,
      _promptController,
      _voiceController,
      _emailController,
      _passwordController,
      _confirmPasswordController,
      _searchController,
      _inventoryAddController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HELPERS ACCESSIBILITÉ
  // ─────────────────────────────────────────────────────────────────────────────

  double _fs(double base) => _largeFontSize ? base * 1.25 : base;
  double get _btnHeight => _largeButtons ? 60.0 : 48.0;

  ButtonStyle _primaryStyle(BuildContext ctx) => FilledButton.styleFrom(
        minimumSize: Size(double.infinity, _btnHeight),
        backgroundColor: _highContrast
            ? Colors.yellow.shade700
            : Theme.of(ctx).colorScheme.primary,
        foregroundColor: _highContrast ? Colors.black : Colors.white,
        textStyle:
            TextStyle(fontSize: _fs(15), fontWeight: FontWeight.w600),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );


  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingApp) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAuthenticated) return _buildAuthScreen();

    return Scaffold(
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildProfileTab(),
          _buildGuidanceTab(),
          _buildGpsTab(),
          _buildCaddieTab(),
          _buildHistoryTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
          NavigationDestination(
            icon: Icon(Icons.visibility_outlined),
            selectedIcon: Icon(Icons.visibility),
            label: 'Guidance',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'GPS',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Caddie',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historique',
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      title: Row(
        children: [
          Icon(Icons.visibility_rounded, color: cs.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            'Vision360',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: _fs(18),
              color: cs.primary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: [
        _UserAvatar(email: _currentUserEmail, onLogout: _logout),
        const SizedBox(width: 8),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ÉCRAN D'AUTHENTIFICATION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAuthScreen() {
    final cs = Theme.of(context).colorScheme;
    final isSuccess = _authMessage.contains('réussie');

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.visibility_rounded,
                        color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Vision360',
                    style: TextStyle(
                      fontSize: _fs(30),
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Votre assistant IA',
                    style: TextStyle(
                      fontSize: _fs(14),
                      color: cs.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Carte formulaire
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _registerMode
                                ? 'Créer un compte'
                                : 'Se connecter',
                            style: TextStyle(
                              fontSize: _fs(20),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            textInputAction: _registerMode
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onSubmitted:
                                _registerMode ? null : (_) => _handleAuth(),
                            decoration: const InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon: Icon(Icons.lock_outlined),
                            ),
                          ),
                          if (_registerMode) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleAuth(),
                              decoration: const InputDecoration(
                                labelText: 'Confirmer le mot de passe',
                                prefixIcon: Icon(Icons.lock_outlined),
                              ),
                            ),
                          ],
                          if (_authMessage.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSuccess
                                    ? Colors.green.withOpacity(0.1)
                                    : cs.errorContainer.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSuccess
                                        ? Icons.check_circle_outline
                                        : Icons.error_outline,
                                    size: 16,
                                    color: isSuccess
                                        ? Colors.green.shade700
                                        : cs.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _authMessage,
                                      style: TextStyle(
                                        fontSize: _fs(13),
                                        color: isSuccess
                                            ? Colors.green.shade700
                                            : cs.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _authLoading ? null : _handleAuth,
                            style: _primaryStyle(context),
                            child: _authLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : Text(_registerMode
                                    ? 'Créer le compte'
                                    : 'Se connecter'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => setState(() {
                              _registerMode = !_registerMode;
                              _authMessage = '';
                            }),
                            child: Text(
                              _registerMode
                                  ? 'J\'ai déjà un compte'
                                  : 'Créer un compte',
                              style: TextStyle(fontSize: _fs(14)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ONGLET PROFIL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildProfileTab() {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Carte utilisateur ───────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    _nameController.text.isNotEmpty
                        ? _nameController.text[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: _fs(20),
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameController.text.isEmpty
                            ? 'Utilisateur'
                            : _nameController.text,
                        style: TextStyle(
                            fontSize: _fs(15), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentUserEmail,
                        style: TextStyle(
                          fontSize: _fs(12),
                          color: cs.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.logout_outlined,
                      color: cs.onSurface.withOpacity(0.5)),
                  tooltip: 'Se déconnecter',
                  onPressed: _logout,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Profil santé ────────────────────────────────────────────────────
        _SectionHeader(
            title: 'Profil santé',
            icon: Icons.health_and_safety_outlined),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  style: TextStyle(fontSize: _fs(14)),
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _allergiesController,
                  style: TextStyle(fontSize: _fs(14)),
                  decoration: const InputDecoration(
                    labelText: 'Allergies',
                    hintText: 'arachide, gluten, lait...',
                    prefixIcon: Icon(Icons.warning_amber_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _conditionsController,
                  style: TextStyle(fontSize: _fs(14)),
                  decoration: const InputDecoration(
                    labelText: 'Conditions médicales',
                    hintText: 'diabète, hypertension...',
                    prefixIcon:
                        Icon(Icons.medical_information_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _preferencesController,
                  style: TextStyle(fontSize: _fs(14)),
                  decoration: const InputDecoration(
                    labelText: 'Préférences alimentaires',
                    hintText: 'sans sucre, végétarien...',
                    prefixIcon: Icon(Icons.restaurant_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _mobility,
                  style: TextStyle(
                      fontSize: _fs(14),
                      color: cs.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Mobilité',
                    prefixIcon: Icon(Icons.accessible_outlined),
                  ),
                  items: [
                    DropdownMenuItem(
                        value: 'fauteuil',
                        child: Text('Fauteuil roulant',
                            style: TextStyle(fontSize: _fs(14)))),
                    DropdownMenuItem(
                        value: 'canne',
                        child: Text('Canne / béquilles',
                            style: TextStyle(fontSize: _fs(14)))),
                    DropdownMenuItem(
                        value: 'marche',
                        child: Text('Marche autonome',
                            style: TextStyle(fontSize: _fs(14)))),
                  ],
                  onChanged: (v) =>
                      setState(() => _mobility = v ?? _mobility),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  title: Text('Synthèse vocale (TTS)',
                      style: TextStyle(fontSize: _fs(14))),
                  subtitle: Text('Lecture automatique des recommandations',
                      style: TextStyle(fontSize: _fs(12))),
                  value: _ttsEnabled,
                  onChanged: (v) => setState(() => _ttsEnabled = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Accessibilité ───────────────────────────────────────────────────
        _SectionHeader(
            title: 'Accessibilité',
            icon: Icons.accessibility_new_outlined),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              _AccessSwitch(
                title: 'Grandes polices',
                subtitle: 'Augmenter la taille du texte',
                icon: Icons.text_fields_rounded,
                value: _largeFontSize,
                onChanged: (v) async {
                  setState(() => _largeFontSize = v);
                  await _saveAccessibility();
                },
              ),
              Divider(
                  indent: 56,
                  endIndent: 16,
                  color: cs.onSurface.withOpacity(0.08)),
              _AccessSwitch(
                title: 'Grands boutons',
                subtitle: 'Augmenter la taille des boutons',
                icon: Icons.touch_app_outlined,
                value: _largeButtons,
                onChanged: (v) async {
                  setState(() => _largeButtons = v);
                  await _saveAccessibility();
                },
              ),
              Divider(
                  indent: 56,
                  endIndent: 16,
                  color: cs.onSurface.withOpacity(0.08)),
              _AccessSwitch(
                title: 'Fort contraste',
                subtitle: 'Améliorer la lisibilité visuelle',
                icon: Icons.contrast_rounded,
                value: _highContrast,
                onChanged: (v) async {
                  setState(() => _highContrast = v);
                  await _saveAccessibility();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Thème ───────────────────────────────────────────────────────────
        _SectionHeader(title: 'Thème', icon: Icons.palette_outlined),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mode d\'affichage',
                    style: TextStyle(fontSize: _fs(14))),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  expandedInsets: EdgeInsets.zero,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined, size: 18),
                      label: Text('Auto'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined, size: 18),
                      label: Text('Clair'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined, size: 18),
                      label: Text('Sombre'),
                    ),
                  ],
                  selected: {widget.currentThemeMode},
                  onSelectionChanged: (modes) =>
                      _saveThemeMode(modes.first),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Avancé (repliable) ──────────────────────────────────────────────
        _ExpandableSection(
          title: 'Avancé',
          icon: Icons.settings_outlined,
          child: Column(
            children: [
              TextField(
                controller: _apiBaseController,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'URL de l\'API',
                  prefixIcon: Icon(Icons.link_outlined),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  await _saveApiBase();
                  await _saveProfile();
                  _showSnack('Profil sauvegardé.');
                },
                style: _primaryStyle(context),
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Sauvegarder le profil'),
              ),
            ],
          ),
        ),

        // ── Inventaire maison ────────────────────────────────────────────────
        const SizedBox(height: 8),
        _SectionHeader(icon: Icons.home_outlined, title: 'Inventaire maison'),
        const SizedBox(height: 8),
        // Champ d'ajout manuel
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inventoryAddController,
                decoration: InputDecoration(
                  hintText: 'Ajouter un produit manuellement…',
                  hintStyle: TextStyle(fontSize: _fs(13)),
                  prefixIcon: const Icon(Icons.add_box_outlined, size: 18),
                  isDense: true,
                ),
                style: TextStyle(fontSize: _fs(13)),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addToInventoryManual(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _addToInventoryManual,
              style: FilledButton.styleFrom(
                minimumSize: const Size(56, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Icon(Icons.add, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_homeInventory.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                'Inventaire vide — ajoutez un produit ci-dessus\nou analysez un produit depuis Guidance',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: _fs(13), color: cs.onSurface.withValues(alpha: 0.4), height: 1.5),
              ),
            ),
          )
        else
          Column(
            children: List.generate(_homeInventory.length, (i) {
              final item = _homeInventory[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                    leading: Icon(Icons.inventory_2_outlined, size: 20, color: cs.primary.withValues(alpha: 0.7)),
                    title: Text(
                      item['name']?.toString() ?? 'Produit',
                      style: TextStyle(fontSize: _fs(13), fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: item['date'] != null
                        ? Text(item['date'].toString(), style: TextStyle(fontSize: _fs(11), color: cs.onSurface.withValues(alpha: 0.45)))
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: cs.primary.withValues(alpha: 0.7), size: 18),
                          onPressed: () => _editInventoryItem(i),
                          tooltip: 'Renommer',
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: cs.error.withValues(alpha: 0.6), size: 18),
                          onPressed: () => _removeFromInventory(i),
                          tooltip: 'Supprimer',
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ONGLET GUIDANCE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildGuidanceTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Caméra
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _buildCameraPreview(),
        ),
        const SizedBox(height: 12),

        // Boutons d'action
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildGuidanceActions(),
        ),

        // Bandeaux de statut
        if (_cooldownMsg.isNotEmpty)
          _StatusBanner(
            message: _cooldownMsg,
            icon: Icons.timer_outlined,
            color: Colors.orange,
          ),
        if (_cameraStatus.isNotEmpty)
          _StatusBanner(
            message: _cameraStatus,
            icon: Icons.info_outline,
            color: Theme.of(context).colorScheme.primary,
          ),

        // Zone résultats / état vide
        Expanded(
          child: _hasResults
              ? _buildResultsSection()
              : _buildGuidanceEmptyState(),
        ),
      ],
    );
  }

  Widget _buildCameraPreview() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 255,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _cameraReady
              ? cs.primary.withOpacity(0.4)
              : cs.onSurface.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Prévisualisation caméra
          if (_cameraReady && _cameraController != null)
            CameraPreview(_cameraController!)
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off_outlined,
                      color: Colors.white24,
                      size: _largeButtons ? 56 : 44),
                  const SizedBox(height: 10),
                  Text(
                    'Caméra inactive',
                    style: TextStyle(
                        color: Colors.white24, fontSize: _fs(14)),
                  ),
                ],
              ),
            ),

          // Overlay chargement
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 14),
                    Text(
                      'Analyse en cours…',
                      style: TextStyle(
                          color: Colors.white, fontSize: _fs(14)),
                    ),
                  ],
                ),
              ),
            ),

          // Badge caméra active
          if (_cameraReady && !_isLoading)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text('LIVE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGuidanceActions() {
    final cs = Theme.of(context).colorScheme;

    if (!_cameraReady) {
      return FilledButton.icon(
        onPressed: _startCamera,
        style: _primaryStyle(context),
        icon: const Icon(Icons.videocam_outlined, size: 20),
        label: Text('Activer la caméra', style: TextStyle(fontSize: _fs(15))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Boutons principaux
        Row(
          children: [
            Expanded(
              flex: 4,
              child: FilledButton.icon(
                onPressed: _isLoading
                    ? null
                    : (_productMode ? _analyzeProductFaces : _callChain),
                style: _primaryStyle(context),
                icon: Icon(
                  _productMode ? Icons.inventory_2_outlined : Icons.bolt_rounded,
                  size: 20,
                ),
                label: Text(
                  _productMode ? 'Analyser le produit' : 'Analyser',
                  style: TextStyle(fontSize: _fs(15)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _isListening
                    ? cs.error.withValues(alpha: 0.12)
                    : cs.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: _isListening
                    ? Border.all(color: cs.error, width: 1.5)
                    : null,
              ),
              child: IconButton(
                onPressed: _isLoading ? null : _toggleListening,
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none_outlined,
                  color: _isListening ? cs.error : cs.onSurface,
                  size: 22,
                ),
                tooltip: _isListening ? 'Arrêter l\'écoute' : 'Commande vocale',
                style: IconButton.styleFrom(
                  minimumSize: Size(_btnHeight, _btnHeight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _isLoading ? null : _stopCamera,
              style: OutlinedButton.styleFrom(
                minimumSize: Size(_btnHeight, _btnHeight),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Icon(Icons.videocam_off_outlined, size: 20),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Toggle Mode Produit
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() {
                _productMode = !_productMode;
                if (!_productMode) {
                  _productFrontB64 = null;
                  _productBackB64 = null;
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _productMode
                      ? cs.primaryContainer
                      : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: _productMode
                      ? Border.all(color: cs.primary.withValues(alpha: 0.4))
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.view_in_ar_outlined,
                      size: 15,
                      color: _productMode ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Mode produit',
                      style: TextStyle(
                        fontSize: _fs(12),
                        color: _productMode ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
                        fontWeight: _productMode ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Boutons face avant / arrière (uniquement en mode produit)
        if (_productMode) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _captureProductFace(true),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    side: BorderSide(
                      color: _productFrontB64 != null
                          ? Colors.green
                          : cs.outline.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(
                    _productFrontB64 != null ? Icons.check_circle : Icons.flip_to_front_outlined,
                    size: 16,
                    color: _productFrontB64 != null ? Colors.green : null,
                  ),
                  label: Text(
                    _productFrontB64 != null ? 'Face avant ✓' : 'Face avant',
                    style: TextStyle(
                      fontSize: _fs(13),
                      color: _productFrontB64 != null ? Colors.green : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _captureProductFace(false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    side: BorderSide(
                      color: _productBackB64 != null
                          ? Colors.green
                          : cs.outline.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(
                    _productBackB64 != null ? Icons.check_circle : Icons.flip_to_back_outlined,
                    size: 16,
                    color: _productBackB64 != null ? Colors.green : null,
                  ),
                  label: Text(
                    _productBackB64 != null ? 'Face arrière ✓' : 'Face arrière',
                    style: TextStyle(
                      fontSize: _fs(13),
                      color: _productBackB64 != null ? Colors.green : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],

        // Bandeau d'écoute active
        if (_isListening) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                _PulsingDot(color: cs.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _voiceTranscript.isEmpty ? 'Parlez maintenant…' : _voiceTranscript,
                    style: TextStyle(
                      fontSize: _fs(13),
                      color: _voiceTranscript.isEmpty
                          ? cs.onSurface.withValues(alpha: 0.5)
                          : cs.onSurface,
                      fontStyle: _voiceTranscript.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGuidanceEmptyState() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_search_outlined,
                    size: 52, color: cs.onSurface.withOpacity(0.18)),
                const SizedBox(height: 12),
                Text(
                  'Activez la caméra et appuyez\nsur Analyser pour commencer',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _fs(14),
                    color: cs.onSurface.withOpacity(0.38),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Saisie manuelle (alternative à la caméra)
        _ManualInputSection(
          controller: _voiceController,
          isLoading: _isLoading,
          fontSize: _fs,
          btnHeight: _btnHeight,
          onSend: _callGroqManual,
        ),
      ],
    );
  }

  Widget _buildResultsSection() {
    final cs = Theme.of(context).colorScheme;
    final s = _groqStructured;
    final summary = s?['summary']?.toString() ?? '';
    final risks = s?['risks'];
    final actions = s?['actions'];
    final hasRisks = risks is List && risks.isNotEmpty;
    final hasActions = actions is List && actions.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        // ── Résumé principal ─────────────────────────────────────────────────
        Card(
          color: cs.primaryContainer.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: 7),
                    Text(
                      'RÉSUMÉ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    if (s?['name'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s!['name'].toString(),
                          style: TextStyle(
                            fontSize: _fs(11),
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  summary.isNotEmpty ? summary : 'Aucun résultat.',
                  style: TextStyle(
                    fontSize: _fs(16),
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Contrôles TTS ────────────────────────────────────────────────────
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _ttsEnabled && summary.isNotEmpty ? () => _speakGroq(s) : null,
                style: FilledButton.styleFrom(
                  minimumSize: Size(0, _btnHeight),
                  backgroundColor: cs.secondaryContainer,
                  foregroundColor: cs.onSecondaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.volume_up_outlined, size: 18),
                label: Text('Lire le résumé', style: TextStyle(fontSize: _fs(14))),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _tts.stop(),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(_btnHeight, _btnHeight),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Icon(Icons.stop_outlined, size: 18),
            ),
          ],
        ),

        // ── Bouton "Au caddie" uniquement ────────────────────────────────────
        if (s != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addToCart,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.shopping_cart_outlined, size: 16),
            label: Text('Ajouter au caddie', style: TextStyle(fontSize: _fs(13))),
          ),
        ],

        // ── Risques (visible directement) ────────────────────────────────────
        if (hasRisks) ...[
          const SizedBox(height: 10),
          _buildRisksCard(risks),
        ],

        // ── Actions (visible directement) ────────────────────────────────────
        if (hasActions) ...[
          const SizedBox(height: 10),
          _buildActionsCard(actions),
        ],

        // ── Description scène (repliable) ────────────────────────────────────
        if (_geminiText.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ExpandableSection(
            title: 'Description de la scène',
            icon: Icons.camera_outlined,
            child: _ResultCard(
              icon: Icons.camera_outlined,
              iconColor: cs.tertiary,
              title: 'Vue de la caméra',
              child: Text(
                _geminiText,
                style: TextStyle(
                  fontSize: _fs(13),
                  color: cs.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],

        // ── Saisie manuelle ──────────────────────────────────────────────────
        const SizedBox(height: 10),
        _ManualInputSection(
          controller: _voiceController,
          isLoading: _isLoading,
          fontSize: _fs,
          btnHeight: _btnHeight,
          onSend: _callGroqManual,
        ),
      ],
    );
  }

  Widget _buildRisksCard(dynamic risks) {
    final cs = Theme.of(context).colorScheme;
    final items = risks is List
        ? risks.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : [risks.toString()];
    if (items.isEmpty) return const SizedBox.shrink();

    final riskColor = _highContrast ? Colors.yellow.shade700 : cs.error;

    return _ResultCard(
      icon: Icons.warning_amber_rounded,
      iconColor: riskColor,
      title: 'Points d\'attention',
      child: Column(
        children: items
            .map((r) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Icon(Icons.circle, size: 5, color: riskColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(r,
                            style: TextStyle(
                                fontSize: _fs(13),
                                height: 1.45,
                                color: cs.onSurface.withOpacity(0.8))),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildActionsCard(dynamic actions) {
    final cs = Theme.of(context).colorScheme;
    final items = actions is List
        ? actions.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : [actions.toString()];
    if (items.isEmpty) return const SizedBox.shrink();

    return _ResultCard(
      icon: Icons.checklist_rounded,
      iconColor: cs.tertiary,
      title: 'Actions recommandées',
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key + 1;
          final action = entry.value;
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('$i',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: cs.onTertiaryContainer)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(action,
                      style: TextStyle(
                          fontSize: _fs(13),
                          height: 1.45,
                          color: cs.onSurface.withOpacity(0.8))),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ONGLET HISTORIQUE
  // ═══════════════════════════════════════════════════════════════════════════
  // ONGLET GPS
  // ═══════════════════════════════════════════════════════════════════════════

  IconData _placeTypeIcon(String type) {
    switch (type) {
      case 'pharmacy': case 'chemist':    return Icons.local_pharmacy_outlined;
      case 'hospital': case 'clinic':
      case 'doctors':                     return Icons.local_hospital_outlined;
      case 'supermarket': case 'hypermarket':
      case 'grocery':                     return Icons.shopping_cart_outlined;
      case 'convenience':                 return Icons.store_outlined;
      case 'bakery':                      return Icons.bakery_dining_outlined;
      case 'butcher':                     return Icons.set_meal_outlined;
      case 'mall': case 'department_store':
      case 'variety_store':               return Icons.storefront_outlined;
      case 'clothes':                     return Icons.checkroom_outlined;
      case 'electronics': case 'hardware': return Icons.devices_outlined;
      case 'restaurant': case 'fast_food': return Icons.restaurant_outlined;
      case 'cafe': case 'bar':            return Icons.local_cafe_outlined;
      case 'bank': case 'atm':            return Icons.account_balance_outlined;
      case 'bus_stop':                    return Icons.directions_bus_outlined;
      case 'fuel':                        return Icons.local_gas_station_outlined;
      case 'school':                      return Icons.school_outlined;
      case 'post_office':                 return Icons.mail_outline;
      case 'police':                      return Icons.local_police_outlined;
      default:                            return Icons.place_outlined;
    }
  }

  String _placeTypeLabel(String type) {
    switch (type) {
      case 'pharmacy':          return 'Pharmacie';
      case 'chemist':           return 'Parapharmacie';
      case 'hospital':          return 'Hôpital';
      case 'clinic': case 'doctors': return 'Cabinet médical';
      case 'supermarket':       return 'Supermarché';
      case 'hypermarket':       return 'Hypermarché';
      case 'grocery':           return 'Épicerie';
      case 'convenience':       return 'Épicerie';
      case 'bakery':            return 'Boulangerie';
      case 'butcher':           return 'Boucherie';
      case 'mall':              return 'Centre commercial';
      case 'department_store':  return 'Grand magasin';
      case 'variety_store':     return 'Bazar';
      case 'clothes':           return 'Vêtements';
      case 'electronics':       return 'Électronique';
      case 'hardware':          return 'Bricolage';
      case 'restaurant':        return 'Restaurant';
      case 'fast_food':         return 'Restauration rapide';
      case 'cafe':              return 'Café';
      case 'bar':               return 'Bar';
      case 'bank':              return 'Banque';
      case 'atm':               return 'Distributeur';
      case 'bus_stop':          return 'Arrêt de bus';
      case 'fuel':              return 'Station-service';
      case 'school':            return 'École';
      case 'post_office':       return 'La Poste';
      case 'police':            return 'Police';
      default:                  return 'Lieu';
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(double seconds) {
    final min = (seconds / 60).round();
    if (min < 60) return '$min min';
    return '${min ~/ 60}h${(min % 60).toString().padLeft(2, '0')}';
  }

  Widget _buildGpsTab() {
    if (!_gpsReady) return _buildGpsInitView();
    return Stack(
      children: [
        _buildMapWidget(),
        _buildSearchOverlay(),
        if (_loadingRoute)
          const Center(child: CircularProgressIndicator()),
        _buildGpsFabs(),
        if (_isNavigating) _buildNavigationPanel(),
      ],
    );
  }

  Widget _buildGpsInitView() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.map_outlined, size: 40, color: cs.primary),
            ),
            const SizedBox(height: 24),
            Text('Navigation GPS',
                style: TextStyle(fontSize: _fs(20), fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Activez le GPS pour voir votre position et calculer des itinéraires piétons.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: _fs(14),
                  color: cs.onSurface.withValues(alpha: 0.6),
                  height: 1.5),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _initGps,
              style: _primaryStyle(context),
              icon: const Icon(Icons.my_location, size: 20),
              label: Text('Activer le GPS', style: TextStyle(fontSize: _fs(15))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapWidget() {
    final cs = Theme.of(context).colorScheme;
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentPosition ?? const ll.LatLng(48.8566, 2.3522),
        initialZoom: 15,
        onTap: (_, __) => setState(() => _showSearchResults = false),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.mobile_flutter',
        ),
        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 5,
                color: cs.primary,
                borderStrokeWidth: 2,
                borderColor: Colors.white.withValues(alpha: 0.6),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (_currentPosition != null)
              Marker(
                point: _currentPosition!,
                width: 22, height: 22,
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                ),
              ),
            if (_destination != null)
              Marker(
                point: _destination!,
                width: 44, height: 44,
                alignment: Alignment.topCenter,
                child: Icon(Icons.location_pin,
                    color: cs.error, size: 44,
                    shadows: const [Shadow(color: Colors.black26, blurRadius: 4)]),
              ),
            if (_isNavigating && _routeSteps.isNotEmpty &&
                _currentStep < _routeSteps.length)
              Marker(
                point: _routeSteps[_currentStep]['coord'] as ll.LatLng,
                width: 32, height: 32,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.navigation, color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchOverlay() {
    final cs = Theme.of(context).colorScheme;
    final showNearby = !_showSearchResults &&
        _searchController.text.isEmpty &&
        _destination == null &&
        _nearbyPlaces.isNotEmpty;

    return SafeArea(
      child: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(14),
              shadowColor: Colors.black26,
              child: TextField(
                controller: _searchController,
                style: TextStyle(fontSize: _fs(14)),
                decoration: InputDecoration(
                  hintText: 'Rechercher un lieu, commerce…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _clearDestination();
                            setState(() {
                              _searchResults = [];
                              _showSearchResults = false;
                            });
                          },
                        )
                      : _loadingNearby
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (v) {
                  setState(() {}); // rafraîchit le suffixIcon
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 500),
                    () => _searchPlaces(v),
                  );
                },
              ),
            ),
          ),

          // Résultats de recherche
          if (_showSearchResults && _searchResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Material(
                elevation: 4,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(14)),
                shadowColor: Colors.black26,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(14)),
                  child: Column(
                    children: _searchResults.take(6).map((place) {
                      final parts = place['name'].toString().split(',');
                      final title = parts.first.trim();
                      final subtitle = parts.length > 1
                          ? parts.skip(1).take(2).join(',').trim()
                          : '';
                      final dist = place['distance'] as double?;
                      final type = place['type']?.toString() ?? '';
                      return ListTile(
                        dense: true,
                        leading: Icon(_placeTypeIcon(type),
                            size: 20, color: cs.primary),
                        title: Text(title,
                            style: TextStyle(
                                fontSize: _fs(13),
                                fontWeight: FontWeight.w500)),
                        subtitle: subtitle.isNotEmpty
                            ? Text(subtitle,
                                style: TextStyle(
                                    fontSize: _fs(11),
                                    color: cs.onSurface.withValues(alpha: 0.5)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)
                            : null,
                        trailing: dist != null
                            ? Text(_formatDistance(dist),
                                style: TextStyle(
                                    fontSize: _fs(11),
                                    color: cs.primary,
                                    fontWeight: FontWeight.w500))
                            : null,
                        onTap: () => _selectPlace(place),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

          // Lieux à proximité (quand recherche vide)
          if (showNearby)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(14),
                shadowColor: Colors.black26,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                        child: Row(
                          children: [
                            Icon(Icons.near_me_outlined,
                                size: 15, color: cs.primary),
                            const SizedBox(width: 6),
                            Text('À proximité',
                                style: TextStyle(
                                    fontSize: _fs(12),
                                    fontWeight: FontWeight.w600,
                                    color: cs.primary)),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ..._nearbyPlaces.take(6).map((place) {
                        final dist = place['distance'] as double? ?? 0;
                        final type = place['type']?.toString() ?? '';
                        return ListTile(
                          dense: true,
                          leading: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_placeTypeIcon(type),
                                size: 16, color: cs.onPrimaryContainer),
                          ),
                          title: Text(place['name'].toString(),
                              style: TextStyle(
                                  fontSize: _fs(13),
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(_placeTypeLabel(type),
                              style: TextStyle(
                                  fontSize: _fs(11),
                                  color: cs.onSurface.withValues(alpha: 0.5))),
                          trailing: Text(_formatDistance(dist),
                              style: TextStyle(
                                  fontSize: _fs(11),
                                  color: cs.primary,
                                  fontWeight: FontWeight.w500)),
                          onTap: () => _selectPlace(place),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

          // Bandeau destination sélectionnée
          if (_destination != null && !_showSearchResults && !_isNavigating)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.route_outlined, size: 18, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _destinationName.split(',').first.trim(),
                              style: TextStyle(
                                  fontSize: _fs(13),
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_totalRouteDistance > 0)
                              Text(
                                '${_formatDistance(_totalRouteDistance)} · ${_formatDuration(_totalRouteDuration)}',
                                style: TextStyle(
                                    fontSize: _fs(11),
                                    color: cs.onSurface.withValues(alpha: 0.5)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_routeSteps.isNotEmpty)
                        FilledButton.icon(
                          onPressed: _startNavigation,
                          style: FilledButton.styleFrom(
                            minimumSize: Size(0, _btnHeight - 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.navigation, size: 16),
                          label: Text('Démarrer',
                              style: TextStyle(fontSize: _fs(13))),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGpsFabs() {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      right: 12,
      bottom: _isNavigating ? 200 : 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'recenter',
            onPressed: _recenterMap,
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            elevation: 3,
            child: const Icon(Icons.my_location, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationPanel() {
    final cs = Theme.of(context).colorScheme;
    if (_routeSteps.isEmpty) return const SizedBox.shrink();
    final step = _routeSteps[_currentStep];
    final instruction = step['instruction']?.toString() ?? '';
    final distance = step['distance'] as int? ?? 0;
    final isLast = _currentStep == _routeSteps.length - 1;
    final hasNext = _currentStep + 1 < _routeSteps.length;
    final nextInstruction = hasNext
        ? _routeSteps[_currentStep + 1]['instruction']?.toString() ?? ''
        : '';

    // Distance/durée restantes (somme des étapes restantes)
    final remainingDist = _routeSteps
        .skip(_currentStep)
        .fold<int>(0, (s, e) => s + ((e['distance'] as int?) ?? 0));
    final remainingMin = _totalRouteDuration > 0
        ? ((_totalRouteDuration *
                (_routeSteps.length - _currentStep) /
                _routeSteps.length) /
            60)
            .round()
        : 0;

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),

                // Bandeau ETA + destination
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, size: 16, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _destinationName.split(',').first.trim(),
                          style: TextStyle(
                              fontSize: _fs(12),
                              fontWeight: FontWeight.w500,
                              color: cs.onPrimaryContainer),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${_formatDistance(remainingDist.toDouble())} · ${remainingMin > 0 ? '$remainingMin min' : '—'}',
                        style: TextStyle(
                            fontSize: _fs(12),
                            fontWeight: FontWeight.w600,
                            color: cs.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Étape courante
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _stepIcon(instruction),
                        color: cs.onPrimary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            instruction,
                            style: TextStyle(
                                fontSize: _fs(15),
                                fontWeight: FontWeight.w700,
                                height: 1.3),
                          ),
                          if (distance > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Dans ${_formatDistance(distance.toDouble())}',
                                style: TextStyle(
                                    fontSize: _fs(13),
                                    color: cs.primary,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.volume_up_outlined,
                          size: 20, color: cs.onSurface.withValues(alpha: 0.6)),
                      onPressed: () => _speakStep(_currentStep),
                      tooltip: 'Relire',
                    ),
                  ],
                ),

                // Aperçu étape suivante
                if (hasNext && nextInstruction.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(_stepIcon(nextInstruction),
                            size: 14, color: cs.onSurface.withValues(alpha: 0.5)),
                        const SizedBox(width: 6),
                        Text('Ensuite : ',
                            style: TextStyle(
                                fontSize: _fs(11),
                                color: cs.onSurface.withValues(alpha: 0.45))),
                        Expanded(
                          child: Text(
                            nextInstruction,
                            style: TextStyle(
                                fontSize: _fs(11),
                                color: cs.onSurface.withValues(alpha: 0.65)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                // Barre de progression + contrôles
                Row(
                  children: [
                    Text(
                      '${_currentStep + 1} / ${_routeSteps.length}',
                      style: TextStyle(
                          fontSize: _fs(11),
                          color: cs.onSurface.withValues(alpha: 0.45)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / _routeSteps.length,
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (!isLast)
                      OutlinedButton(
                        onPressed: _advanceStep,
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(0, _btnHeight - 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Suivant',
                            style: TextStyle(fontSize: _fs(12))),
                      ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      onPressed: _stopNavigation,
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(0, _btnHeight - 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        foregroundColor: cs.error,
                        side: BorderSide(
                            color: cs.error.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Arrêter',
                          style: TextStyle(fontSize: _fs(12))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _stepIcon(String instruction) {
    final i = instruction.toLowerCase();
    if (i.contains('gauche')) return Icons.turn_left;
    if (i.contains('droite')) return Icons.turn_right;
    if (i.contains('demi-tour')) return Icons.u_turn_left;
    if (i.contains('rond-point')) return Icons.roundabout_left;
    if (i.contains('arrivé')) return Icons.flag_outlined;
    if (i.contains('démarrer')) return Icons.play_arrow;
    return Icons.straight;
  }

  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHistoryTab() {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // En-tête
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _history.isEmpty
                      ? 'Aucune interaction'
                      : '${_history.length} interaction${_history.length > 1 ? 's' : ''}',
                  style: TextStyle(
                      fontSize: _fs(16), fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_outlined,
                    size: 20, color: cs.onSurface.withOpacity(0.5)),
                tooltip: 'Copier JSON',
                onPressed:
                    _history.isEmpty ? null : _copyHistoryToClipboard,
              ),
              IconButton(
                icon: Icon(Icons.download_outlined,
                    size: 20, color: cs.onSurface.withOpacity(0.5)),
                tooltip: 'Exporter',
                onPressed:
                    _history.isEmpty ? null : _exportHistoryToFile,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 20, color: cs.onSurface.withOpacity(0.5)),
                tooltip: 'Vider l\'historique',
                onPressed: _history.isEmpty
                    ? null
                    : () async {
                        setState(() => _history.clear());
                        await _saveHistory();
                      },
              ),
            ],
          ),
        ),

        // Liste
        Expanded(
          child: _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_outlined,
                          size: 52,
                          color: cs.onSurface.withOpacity(0.18)),
                      const SizedBox(height: 12),
                      Text(
                        'Aucune interaction pour le moment',
                        style: TextStyle(
                          fontSize: _fs(14),
                          color: cs.onSurface.withOpacity(0.38),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: _history.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(
                            14, 8, 10, 8),
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.auto_awesome_outlined,
                            size: 18,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          item['summary'] ?? 'Conseil',
                          style: TextStyle(
                              fontSize: _fs(13),
                              fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _relativeTime(item['time'] ?? ''),
                          style: TextStyle(
                            fontSize: _fs(11),
                            color: cs.onSurface.withOpacity(0.45),
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right,
                            size: 16,
                            color: cs.onSurface.withOpacity(0.3)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _relativeTime(String raw) {
    try {
      final dt = DateTime.parse(raw);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
      return 'Il y a ${diff.inDays} j';
    } catch (_) {
      return raw;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ONGLET CADDIE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCaddieTab() {
    final cs = Theme.of(context).colorScheme;
    final modeLabels = ['Scanner', 'Vérif. caddie', 'Vérif. caisse'];
    final modeIcons = [Icons.qr_code_scanner_outlined, Icons.shopping_cart_checkout, Icons.point_of_sale_outlined];

    // Tout dans un CustomScrollView pour éviter tout overflow quelle que soit
    // la taille du résultat ou du nombre d'articles dans le caddie.
    return CustomScrollView(
      slivers: [
        // ── Sélecteur de mode ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: List.generate(3, (i) {
                final selected = _caddieMode == i;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i > 0 ? 6 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _caddieMode = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: selected ? Border.all(color: cs.primary.withValues(alpha: 0.3)) : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(modeIcons[i], size: 18, color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.5)),
                            const SizedBox(height: 4),
                            Text(
                              modeLabels[i],
                              style: TextStyle(
                                fontSize: _fs(11),
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),

        // ── Mode passage en caisse (flux guidé complet) ────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: OutlinedButton.icon(
              onPressed: () async {
                // L'écran checkout gère sa propre caméra : libérer la nôtre
                if (_cameraReady) await _stopCamera();
                if (!mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CheckoutScreen(
                      apiBase: _apiBaseController.text.trim(),
                      largeButtons: _largeButtons,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.point_of_sale, size: 20),
              label: Text(
                'Mode passage en caisse (assistant guidé)',
                style: TextStyle(fontSize: _fs(14)),
              ),
            ),
          ),
        ),

        // ── Caméra ─────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCameraPreview(),
          ),
        ),

        // ── Bouton d'action ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _caddieMode == 0
                ? FilledButton.icon(
                    onPressed: _isLoading || !_cameraReady
                        ? (_cameraReady ? null : _startCamera)
                        : _callChain,
                    style: _primaryStyle(context),
                    icon: Icon(_cameraReady ? Icons.bolt_rounded : Icons.videocam_outlined, size: 20),
                    label: Text(
                      _cameraReady ? 'Analyser et ajouter' : 'Activer la caméra',
                      style: TextStyle(fontSize: _fs(15)),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: (_isLoading || _cartVerifying) ? null : _verifyCartOrBelt,
                    style: _primaryStyle(context),
                    icon: const Icon(Icons.camera_alt_outlined, size: 20),
                    label: Text(
                      _caddieMode == 2 ? 'Vérifier la caisse' : 'Vérifier le caddie',
                      style: TextStyle(fontSize: _fs(15)),
                    ),
                  ),
          ),
        ),

        // ── Résultat vérification ──────────────────────────────────────────
        if (_caddieMode != 0 && _hasResults && _groqStructured != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Card(
                color: cs.primaryContainer.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 15, color: cs.primary),
                          const SizedBox(width: 6),
                          Text('RÉSULTAT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary, letterSpacing: 0.8)),
                          const Spacer(),
                          IconButton(
                            onPressed: () => _speakGroq(_groqStructured),
                            icon: Icon(Icons.volume_up_outlined, size: 18, color: cs.primary),
                            style: IconButton.styleFrom(minimumSize: const Size(32, 32), padding: EdgeInsets.zero),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(_groqStructured!['summary']?.toString() ?? '', style: TextStyle(fontSize: _fs(14), height: 1.5)),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── En-tête liste caddie ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(Icons.shopping_cart_outlined, size: 16, color: cs.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Text(
                  'Caddie (${_cartItems.length} article${_cartItems.length != 1 ? 's' : ''})',
                  style: TextStyle(fontSize: _fs(13), fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.6)),
                ),
                const Spacer(),
                if (_cartItems.isNotEmpty)
                  TextButton(
                    onPressed: () { setState(() => _cartItems.clear()); _saveCart(); _showSnack('Caddie vidé'); },
                    child: Text('Vider', style: TextStyle(fontSize: _fs(12), color: cs.error)),
                  ),
              ],
            ),
          ),
        ),

        // ── Articles ou état vide ──────────────────────────────────────────
        if (_cartItems.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 44, color: cs.onSurface.withValues(alpha: 0.15)),
                  const SizedBox(height: 10),
                  Text(
                    'Le caddie est vide\nScannez des produits pour commencer',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: _fs(13), color: cs.onSurface.withValues(alpha: 0.35), height: 1.5),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                  child: _buildCartItemTile(cs, i),
                ),
                childCount: _cartItems.length,
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );

    // NOTE: ce code n'est jamais atteint — conservé pour référence de l'ancien
    // ListView.separated qui était imbriqué dans Expanded :
    // ignore: dead_code
  }

  Widget _buildCartItemTile(ColorScheme cs, int i) {
    final item = _cartItems[i];
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${i + 1}',
              style: TextStyle(fontSize: _fs(12), fontWeight: FontWeight.w700, color: cs.primary),
            ),
          ),
        ),
        title: Text(
          item['name']?.toString() ?? 'Produit',
          style: TextStyle(fontSize: _fs(13), fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: item['date'] != null
            ? Text(item['date'].toString(),
                style: TextStyle(fontSize: _fs(11), color: cs.onSurface.withValues(alpha: 0.45)))
            : null,
        trailing: IconButton(
          icon: Icon(Icons.remove_circle_outline, color: cs.error.withValues(alpha: 0.7), size: 20),
          onPressed: () => _removeFromCart(i),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS RÉUTILISABLES
// ═══════════════════════════════════════════════════════════════════════════════

/// Avatar utilisateur dans l'AppBar avec menu de déconnexion.
class _UserAvatar extends StatelessWidget {
  final String email;
  final VoidCallback onLogout;

  const _UserAvatar({required this.email, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return PopupMenuButton<String>(
      child: CircleAvatar(
        radius: 16,
        backgroundColor: cs.primaryContainer,
        child: Text(
          initial,
          style: TextStyle(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              fontSize: 13),
        ),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Text(email,
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withOpacity(0.5))),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_outlined, size: 18),
              SizedBox(width: 10),
              Text('Se déconnecter'),
            ],
          ),
        ),
      ],
      onSelected: (v) {
        if (v == 'logout') onLogout();
      },
    );
  }
}

/// Titre de section avec icône.
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: cs.primary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

/// Ligne de switch pour les options d'accessibilité.
class _AccessSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AccessSwitch({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, size: 20),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle:
          Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

/// Section repliable (accordéon).
class _ExpandableSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _ExpandableSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(widget.icon,
                      size: 20, color: cs.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: cs.onSurface.withOpacity(0.4),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

/// Bandeau de statut coloré.
class _StatusBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;

  const _StatusBanner(
      {required this.message,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 13, color: color)),
          ),
        ],
      ),
    );
  }
}

/// Carte de résultat IA avec icône et titre.
class _ResultCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _ResultCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withOpacity(0.55),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// Point animé pulsant pour indiquer une écoute active.
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Saisie manuelle de description (alternative à la caméra).
class _ManualInputSection extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final double Function(double) fontSize;
  final double btnHeight;
  final VoidCallback onSend;

  const _ManualInputSection({
    required this.controller,
    required this.isLoading,
    required this.fontSize,
    required this.btnHeight,
    required this.onSend,
  });

  @override
  State<_ManualInputSection> createState() => _ManualInputSectionState();
}

class _ManualInputSectionState extends State<_ManualInputSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Card(
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.keyboard_outlined,
                        size: 18, color: cs.onSurface.withOpacity(0.45)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Saisie manuelle',
                        style: TextStyle(
                          fontSize: widget.fontSize(13),
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: cs.onSurface.withOpacity(0.35),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  children: [
                    TextField(
                      controller: widget.controller,
                      minLines: 2,
                      maxLines: 4,
                      style:
                          TextStyle(fontSize: widget.fontSize(13)),
                      decoration: const InputDecoration(
                        hintText:
                            'Décrivez la scène pour obtenir des conseils…',
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: widget.btnHeight,
                      child: FilledButton.icon(
                        onPressed: widget.isLoading ? null : widget.onSend,
                        icon: const Icon(Icons.send_outlined, size: 16),
                        label: Text('Envoyer',
                            style: TextStyle(
                                fontSize: widget.fontSize(14))),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
