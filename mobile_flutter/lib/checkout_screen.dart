// ============================================================================
// Vision360 - Écran d'assistance au passage en caisse
// ============================================================================
// Flux guidé séquentiel pour personnes malvoyantes :
//   1. Scan du tapis de caisse (identification des articles)
//   2. Suivi du transfert tapis -> caddie
//   3. Détection des articles oubliés
//   4. Scan et lecture du ticket de caisse
//   5. Vérification de cohérence ticket / caddie
//
// Chaque étape s'appuie sur les endpoints /api/checkout/* du backend, qui
// renvoient un champ `voice_message` lu par la synthèse vocale.
// ============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

/// Étapes du scénario de passage en caisse.
enum CheckoutStep {
  beltScan, // F1 : identifier les articles sur le tapis
  transfer, // F2 : suivre le transfert vers le caddie
  forgotten, // F3 : vérifier les oublis
  ticket, // F4 : lire le ticket de caisse
  reconcile, // F5 : rapprocher ticket et caddie
  done,
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.apiBase,
    this.largeButtons = true,
  });

  /// Base de l'API Vision360 (ex: https://.../api)
  final String apiBase;

  /// Active les boutons agrandis (accessibilité).
  final bool largeButtons;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // ── Session backend ─────────────────────────────────────────────────────
  String? _sessionId;

  // ── Caméra & TTS ────────────────────────────────────────────────────────
  CameraController? _camera;
  bool _cameraReady = false;
  final FlutterTts _tts = FlutterTts();

  // ── État du flux ────────────────────────────────────────────────────────
  CheckoutStep _step = CheckoutStep.beltScan;
  bool _busy = false;
  String _statusMessage = '';
  bool _statusIsAlert = false;

  // ── Données de session (miroir local de l'état backend) ─────────────────
  List<Map<String, dynamic>> _beltItems = [];
  List<Map<String, dynamic>> _cartItems = [];
  List<Map<String, dynamic>> _ticketItems = [];
  num _ticketTotal = 0;
  bool _beltScanned = false;
  bool _beltEmpty = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _initTts();
    await _initCamera();
    await _startSession();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.5);
      final langs = await _tts.getLanguages;
      if (langs is List && langs.any((l) => l.toString().startsWith('fr'))) {
        await _tts.setLanguage('fr-FR');
      }
    } catch (_) {}
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _statusMessage = 'Aucune caméra détectée.');
        return;
      }
      _camera = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _camera!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Erreur caméra : $e');
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    _tts.stop();
    // Terminer la session backend en arrière-plan (best effort)
    final sid = _sessionId;
    if (sid != null) {
      http.delete(Uri.parse('${widget.apiBase}/checkout/session/$sid')).ignore();
    }
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // APPELS API
  // ──────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body) async {
    try {
      final resp = await http
          .post(
            Uri.parse('${widget.apiBase}/checkout$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 120));
      if (resp.statusCode != 200) {
        final detail = _tryDetail(resp.body);
        _setStatus('Erreur serveur : $detail', alert: true, speak: true);
        return null;
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      _setStatus('Connexion impossible au serveur.', alert: true, speak: true);
      return null;
    }
  }

  String _tryDetail(String body) {
    try {
      final d = jsonDecode(body);
      return (d['detail'] ?? body).toString();
    } catch (_) {
      return body;
    }
  }

  Future<void> _startSession() async {
    final data = await _post('/start', {});
    if (data == null) return;
    setState(() => _sessionId = data['session_id']?.toString());
    _setStatus(data['voice_message']?.toString() ?? 'Session démarrée.', speak: true);
  }

  Future<String?> _capture() async {
    if (_camera == null || !_cameraReady) {
      _setStatus('La caméra n\'est pas prête.', alert: true, speak: true);
      return null;
    }
    try {
      final file = await _camera!.takePicture();
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      _setStatus('Capture échouée.', alert: true, speak: true);
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FONCTIONNALITÉ 1 : scan du tapis
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _scanBelt() async {
    if (_sessionId == null || _busy) return;
    setState(() => _busy = true);
    _setStatus('Analyse du tapis en cours...');
    try {
      final b64 = await _capture();
      if (b64 == null) return;
      final data = await _post('/belt/scan', {'session_id': _sessionId, 'image_b64': b64});
      if (data == null) return;

      final items = (data['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      setState(() {
        _beltItems = items;
        _beltScanned = items.isNotEmpty;
        _beltEmpty = data['empty'] == true;
        if (_beltScanned) _step = CheckoutStep.transfer;
      });
      _setStatus(data['voice_message']?.toString() ?? '', speak: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FONCTIONNALITÉ 2 : transfert tapis -> caddie
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _checkTransfer() async {
    if (_sessionId == null || _busy) return;
    setState(() => _busy = true);
    _setStatus('Vérification du transfert...');
    try {
      final b64 = await _capture();
      if (b64 == null) return;
      final data = await _post('/belt/transfer', {'session_id': _sessionId, 'image_b64': b64});
      if (data == null) return;

      setState(() {
        _cartItems = (data['cart_items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _beltItems = (data['still_on_belt'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _beltEmpty = data['belt_empty'] == true;
        // Fin du passage détectée automatiquement : tapis vide
        if (_beltEmpty) _step = CheckoutStep.forgotten;
      });
      final hasAlert = (data['uncertain'] as List<dynamic>? ?? []).isNotEmpty;
      _setStatus(data['voice_message']?.toString() ?? '', alert: hasAlert, speak: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FONCTIONNALITÉ 3 : détection des oublis
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _checkForgotten({bool withCartPhoto = false}) async {
    if (_sessionId == null || _busy) return;
    setState(() => _busy = true);
    _setStatus(withCartPhoto
        ? 'Scan du caddie et vérification des oublis...'
        : 'Vérification des oublis...');
    try {
      String? cartB64;
      if (withCartPhoto) {
        cartB64 = await _capture();
        if (cartB64 == null) return;
      }
      final data = await _post('/forgotten', {
        'session_id': _sessionId,
        if (cartB64 != null) 'cart_image_b64': cartB64,
      });
      if (data == null) return;

      final allOk = data['all_transferred'] == true;
      setState(() => _step = CheckoutStep.ticket);
      _setStatus(data['voice_message']?.toString() ?? '', alert: !allOk, speak: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FONCTIONNALITÉ 4 : lecture du ticket
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _scanTicket() async {
    if (_sessionId == null || _busy) return;
    setState(() => _busy = true);
    _setStatus('Lecture du ticket en cours...');
    try {
      final b64 = await _capture();
      if (b64 == null) return;
      final data = await _post('/ticket/scan', {'session_id': _sessionId, 'image_b64': b64});
      if (data == null) return;

      final readable = data['readable'] == true;
      if (!readable) {
        // Ticket illisible : rester sur l'étape pour réessayer
        _setStatus(data['voice_message']?.toString() ?? 'Ticket illisible.',
            alert: true, speak: true);
        return;
      }
      setState(() {
        _ticketItems = (data['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _ticketTotal = (data['total'] as num?) ?? 0;
        _step = CheckoutStep.reconcile;
      });
      _setStatus(data['voice_message']?.toString() ?? '', speak: true);
      // Enchaînement automatique sur la vérification de cohérence (F5)
      await _reconcile();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FONCTIONNALITÉ 5 : rapprochement ticket / caddie
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _reconcile() async {
    if (_sessionId == null) return;
    _setStatus('Comparaison du ticket avec votre caddie...');
    final data = await _post('/reconcile', {'session_id': _sessionId});
    if (data == null) return;

    final match = data['match'] == true;
    setState(() => _step = CheckoutStep.done);
    _setStatus(data['voice_message']?.toString() ?? '', alert: !match, speak: true);
  }

  void _skipReconcile() {
    setState(() => _step = CheckoutStep.done);
    _setStatus('Vérification de cohérence ignorée. Passage en caisse terminé.', speak: true);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPERS UI
  // ──────────────────────────────────────────────────────────────────────────

  void _setStatus(String message, {bool alert = false, bool speak = false}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusIsAlert = alert;
    });
    if (speak && message.isNotEmpty) {
      _tts.stop();
      _tts.speak(message);
    }
  }

  String _stepTitle() {
    switch (_step) {
      case CheckoutStep.beltScan:
        return 'Étape 1 — Scan du tapis';
      case CheckoutStep.transfer:
        return 'Étape 2 — Transfert vers le caddie';
      case CheckoutStep.forgotten:
        return 'Étape 3 — Vérification des oublis';
      case CheckoutStep.ticket:
        return 'Étape 4 — Lecture du ticket';
      case CheckoutStep.reconcile:
        return 'Étape 5 — Vérification ticket/caddie';
      case CheckoutStep.done:
        return 'Passage en caisse terminé';
    }
  }

  String _stepHint() {
    switch (_step) {
      case CheckoutStep.beltScan:
        return 'Visez le tapis de caisse avec la caméra puis lancez le scan.';
      case CheckoutStep.transfer:
        return 'Après avoir déplacé des articles dans le caddie, '
            'vérifiez le transfert. Quand le tapis est vide, '
            'l\'étape suivante se lance automatiquement.';
      case CheckoutStep.forgotten:
        return 'Vérifiez qu\'aucun article n\'a été oublié sur le tapis. '
            'Vous pouvez aussi photographier le caddie pour confirmation.';
      case CheckoutStep.ticket:
        return 'Après le paiement, visez le ticket de caisse '
            '(imprimé ou affiché à l\'écran) puis lancez la lecture.';
      case CheckoutStep.reconcile:
        return 'Comparaison automatique entre le ticket et votre caddie.';
      case CheckoutStep.done:
        return 'Vous pouvez fermer cet écran ou recommencer une session.';
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final btnHeight = widget.largeButtons ? 64.0 : 48.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistance caisse'),
        actions: [
          IconButton(
            tooltip: 'Relire le dernier message',
            icon: const Icon(Icons.volume_up),
            onPressed: _statusMessage.isEmpty ? null : () => _tts.speak(_statusMessage),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Aperçu caméra ────────────────────────────────────────────
            if (_cameraReady && _camera != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: _camera!.value.aspectRatio,
                  child: CameraPreview(_camera!),
                ),
              )
            else
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 16),

            // ── Titre et consigne de l'étape ─────────────────────────────
            Text(
              _stepTitle(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _stepHint(),
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // ── Message de statut / alerte ───────────────────────────────
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _statusIsAlert
                      ? cs.errorContainer
                      : cs.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusIsAlert ? Icons.warning_amber_rounded : Icons.info_outline,
                      color: _statusIsAlert ? cs.onErrorContainer : cs.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          fontSize: 15,
                          color: _statusIsAlert ? cs.onErrorContainer : cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Boutons d'action selon l'étape ───────────────────────────
            ..._buildStepActions(btnHeight),

            const SizedBox(height: 24),

            // ── Listes : tapis / caddie / ticket ─────────────────────────
            if (_beltScanned) ...[
              _ItemListCard(
                title: 'Sur le tapis (${_beltItems.length})',
                icon: Icons.conveyor_belt,
                items: _beltItems,
                emptyLabel: 'Tapis vide',
              ),
              const SizedBox(height: 12),
              _ItemListCard(
                title: 'Dans le caddie (${_cartItems.length})',
                icon: Icons.shopping_cart_outlined,
                items: _cartItems,
                emptyLabel: 'Aucun article transféré pour le moment',
              ),
            ],
            if (_ticketItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ItemListCard(
                title: 'Ticket — total $_ticketTotal €',
                icon: Icons.receipt_long_outlined,
                items: _ticketItems,
                emptyLabel: '',
                showPrice: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStepActions(double btnHeight) {
    Widget action(String label, IconData icon, VoidCallback? onTap,
        {bool secondary = false}) {
      final btn = secondary
          ? OutlinedButton.icon(
              onPressed: _busy ? null : onTap,
              icon: Icon(icon),
              label: Text(label, style: const TextStyle(fontSize: 16)),
            )
          : FilledButton.icon(
              onPressed: _busy ? null : onTap,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(icon),
              label: Text(label, style: const TextStyle(fontSize: 16)),
            );
      return SizedBox(
        height: btnHeight,
        width: double.infinity,
        child: btn,
      );
    }

    switch (_step) {
      case CheckoutStep.beltScan:
        return [
          action('Scanner le tapis', Icons.center_focus_strong, _scanBelt),
        ];
      case CheckoutStep.transfer:
        return [
          action('Vérifier le transfert', Icons.swap_vert, _checkTransfer),
          const SizedBox(height: 10),
          action('Passer à la vérification des oublis', Icons.fact_check_outlined,
              () => setState(() => _step = CheckoutStep.forgotten),
              secondary: true),
        ];
      case CheckoutStep.forgotten:
        return [
          action('Vérifier les oublis', Icons.fact_check_outlined,
              () => _checkForgotten()),
          const SizedBox(height: 10),
          action('Photographier le caddie pour confirmer', Icons.photo_camera_outlined,
              () => _checkForgotten(withCartPhoto: true),
              secondary: true),
        ];
      case CheckoutStep.ticket:
        return [
          action('Scanner le ticket', Icons.receipt_long, _scanTicket),
        ];
      case CheckoutStep.reconcile:
        return [
          action('Vérifier la cohérence ticket/caddie', Icons.rule, _reconcile),
          const SizedBox(height: 10),
          action('Ignorer cette vérification', Icons.skip_next, _skipReconcile,
              secondary: true),
        ];
      case CheckoutStep.done:
        return [
          action('Terminer', Icons.check_circle_outline,
              () => Navigator.of(context).pop()),
        ];
    }
  }
}

// ============================================================================
// Widget : carte listant des articles (tapis, caddie ou ticket)
// ============================================================================

class _ItemListCard extends StatelessWidget {
  const _ItemListCard({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyLabel,
    this.showPrice = false,
  });

  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> items;
  final String emptyLabel;
  final bool showPrice;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(emptyLabel,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))
          else
            ...items.map((it) {
              final qty = it['quantity'] ?? 1;
              final name = (it['name'] ?? '').toString();
              final price = it['line_total'] ?? it['unit_price'];
              final lowConf = it['confidence'] == 'low';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$qty × $name${lowConf ? ' (incertain)' : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: lowConf ? cs.error : cs.onSurface,
                        ),
                      ),
                    ),
                    if (showPrice && price != null)
                      Text('$price €',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
