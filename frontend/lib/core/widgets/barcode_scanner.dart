import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/barcode_engine.dart'
    if (dart.library.html) '../services/barcode_engine_web.dart'
    as engine;
import '../services/gs1_parser.dart';
import '../services/scan_beep.dart';
import '../theme/colors.dart';

/// Résultat du scan : code brut + format détecté + données GS1 extraites.
class ScanResult {
  final String code;
  final BarcodeFormat format;
  final Gs1Data gs1;
  const ScanResult(this.code, this.format, {this.gs1 = const Gs1Data()});

  /// GTIN/EAN à rechercher en base : priorité au GTIN GS1, sinon code brut
  /// (sans l'identifiant de symbologie `]d2` éventuel).
  String get lookupCode {
    if (gs1.gtin != null && gs1.gtin!.isNotEmpty) return gs1.gtin!;
    var c = code.trim();
    // Certains lecteurs préfixent : ]d2 (DataMatrix), ]Q3 (QR), ]C1 (128)…
    if (c.length > 3 && c.startsWith(']')) c = c.substring(3);
    return c;
  }
}

/// Scanner réutilisable — ouvre un écran plein écran (pas un bottom sheet)
/// pour que la caméra ait accès au plein viewport.
/// Supporte : tablette, smartphone, web (desktop avec caméra).
class BarcodeScannerSheet extends StatefulWidget {
  final String title;

  /// Mode scan continu : chaque lecture déclenche [onScan] sans fermer l'écran.
  final bool continuous;

  /// Callback par lecture (mode continu uniquement).
  final void Function(ScanResult result)? onScan;

  const BarcodeScannerSheet({
    super.key,
    this.title = 'Scanner un code',
    this.continuous = false,
    this.onScan,
  });

  /// Ouvre le scanner plein écran et retourne le code scanné.
  static Future<ScanResult?> show(BuildContext context,
      {String title = 'Scanner un code'}) {
    return Navigator.of(context).push<ScanResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BarcodeScannerSheet(title: title),
      ),
    );
  }

  /// Ouvre le scanner en mode CONTINU : chaque scan déclenche [onScan].
  /// L'écran se ferme via « Terminer » (retourne le nombre de scans).
  static Future<int?> showContinuous(
    BuildContext context, {
    String title = 'Scan continu',
    required void Function(ScanResult result) onScan,
  }) {
    return Navigator.of(context).push<int>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BarcodeScannerSheet(
          title: title,
          continuous: true,
          onScan: onScan,
        ),
      ),
    );
  }

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet>
    with TickerProviderStateMixin {
  MobileScannerController? _controller;
  bool _error = false;
  String _errorMsg = '';
  bool _started = false;
  final _manual = TextEditingController();

  // ── Moteur web PRO (ZXing, tous formats) ──
  String? _webViewId;

  // ── Mode continu ──
  int _count = 0;
  ScanResult? _last;
  bool _paused = false;
  Timer? _duplicateReset;
  String? _lastRawCode;

  bool get _continuous => widget.continuous && widget.onScan != null;

  @override
  void initState() {
    super.initState();
    initScanAudio(); // Init audio dans le user gesture d'ouverture
    _startCamera();
  }

  Future<void> _startCamera() async {
    try {
      // ── Web : moteur PRO ZXing (tous formats 1D + 2D) ──
      // mobile_scanner est défaillant en navigateur ; on utilise ZXing
      // (standard industrie) + getUserMedia. Erreurs -> fallback.
      if (kIsWeb && engine.webScannerSupported) {
        final viewId = await engine.startBarcodeCamera(_onEngineCode);
        if (!mounted) {
          engine.stopBarcodeCamera();
          return;
        }
        setState(() {
          _webViewId = viewId;
          _started = true;
        });
        return;
      }

      // ── Natif (mobile / tablette) : mobile_scanner ──
      final c = MobileScannerController(
        detectionSpeed: DetectionSpeed.unrestricted,
        facing: CameraFacing.back,
        autoStart: false,
        // Lecteur professionnel : TOUS les formats codes-barres
        // (1D pharmacie + 2D), pas seulement le QR.
        formats: const [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.code93,
          BarcodeFormat.codabar,
          BarcodeFormat.itf,
          BarcodeFormat.dataMatrix,
          BarcodeFormat.pdf417,
          BarcodeFormat.aztec,
          BarcodeFormat.qrCode,
        ],
      );
      // Small delay to ensure widget tree is ready
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      await c.start();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _started = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _errorMsg = e.toString();
        _controller = null;
      });
    }
  }

  @override
  void dispose() {
    _duplicateReset?.cancel();
    if (kIsWeb) engine.stopBarcodeCamera();
    _controller?.stop();
    _controller?.dispose();
    _manual.dispose();
    super.dispose();
  }

  /// Lecture du moteur web PRO (ZXing) : texte + nom de format.
  void _onEngineCode(String code, String formatName) {
    if (!mounted) return;
    final result = ScanResult(code, BarcodeFormat.unknown,
        gs1: Gs1Parser.parse(code));
    playScanBeep();
    if (!_continuous) {
      engine.stopBarcodeCamera();
      Navigator.of(context).pop(result);
      return;
    }
    _handleContinuous(result);
  }

  void _submit(String v) {
    final code = v.trim();
    if (code.isEmpty) return;
    final result =
        ScanResult(code, BarcodeFormat.unknown, gs1: Gs1Parser.parse(code));
    if (_continuous) {
      _handleContinuous(result);
      _manual.clear();
      return;
    }
    Navigator.of(context).pop(result);
  }

  /// Détection caméra : en mode unique, premier code = retour.
  /// En mode continu, chaque lecture transmet via l'anti-doublon.
  void _onDetect(BarcodeCapture capture) {
    for (final bar in capture.barcodes) {
      final raw = bar.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      final result =
          ScanResult(raw.trim(), bar.format, gs1: Gs1Parser.parse(raw));
      playScanBeep();
      if (!_continuous) {
        Navigator.of(context).pop(result);
        return;
      }
      _handleContinuous(result);
    }
  }

  void _handleContinuous(ScanResult result) {
    // Anti-doublon : le même code brut est ignoré pendant 2,5 s.
    if (result.code == _lastRawCode) return;
    _lastRawCode = result.code;
    _duplicateReset?.cancel();
    _duplicateReset = Timer(const Duration(milliseconds: 2500), () {
      _lastRawCode = null;
    });

    // Retour haptique + son (best effort, silencieux si non supporté).
    playScanBeep();

    setState(() {
      _count++;
      _last = result;
    });
    widget.onScan?.call(result);
  }

  Future<void> _togglePause() async {
    final c = _controller;
    if (c == null) return;
    if (_paused) {
      await c.start();
    } else {
      await c.stop();
    }
    if (mounted) setState(() => _paused = !_paused);
  }

  Future<void> _toggleFlash() async {
    try {
      await _controller?.toggleTorch();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    try {
      await _controller?.switchCamera();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08130E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1F16),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        actions: _continuous
            ? [
                IconButton(
                  tooltip: _paused ? 'Reprendre le scan' : 'Pause',
                  icon: Icon(_paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded),
                  color: const Color(0xFFE9C873),
                  onPressed: _togglePause,
                ),
                IconButton(
                  tooltip: 'Flash',
                  icon: const Icon(Icons.flash_on_rounded),
                  color: const Color(0xFFE9C873),
                  onPressed: _toggleFlash,
                ),
                IconButton(
                  tooltip: 'Changer de caméra',
                  icon: const Icon(Icons.cameraswitch_rounded),
                  color: const Color(0xFFE9C873),
                  onPressed: _switchCamera,
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(_count),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Terminer',
                      style: TextStyle(
                          color: Color(0xFF7BEBA4),
                          fontWeight: FontWeight.w800)),
                ),
              ]
            : const [
                SizedBox.shrink(),
              ],
      ),
      body: Column(
        children: [
          // ── Bandeau scan continu : compteur + dernière lecture ──
          if (_continuous)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF0C1F16),
              child: Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9C873).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFE9C873).withValues(alpha: 0.5)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.qr_code_scanner_rounded,
                        size: 14, color: Color(0xFFE9C873)),
                    const SizedBox(width: 6),
                    Text('$_count',
                        style: const TextStyle(
                            color: Color(0xFFE9C873),
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _paused
                        ? '⏸ Scan en pause'
                        : _last == null
                            ? 'Scannez les produits…'
                            : 'Dernier : ${_last!.lookupCode}'
                                '${_last!.gs1.expiry != null ? ' · Exp. ${_last!.gs1.expiry}' : ''}'
                                '${_last!.gs1.lot != null ? ' · Lot ${_last!.gs1.lot}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: _paused
                            ? const Color(0xFFE9C873)
                            : Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          // ── Zone caméra ──
          Expanded(
            child: _error
                ? _buildFallback()
                : !_started
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                                color: Color(0xFFE9C873)),
                            SizedBox(height: 14),
                            Text('Initialisation de la caméra...',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      )
                    : Stack(
                    fit: StackFit.expand,
                    children: [
                      if (kIsWeb && _webViewId != null)
                        // Moteur web PRO : flux caméra natif DOM + ZXing.
                        HtmlElementView(viewType: _webViewId!)
                      else if (_controller != null)
                        MobileScanner(
                          controller: _controller!,
                          onDetect: _onDetect,
                        )
                      else
                        _buildFallback(),
                      // Visée professionnelle : masque + coins or +
                      // LIGNE LASER animée au milieu du carré.
                      Center(
                        child: _ProReticle(
                          side: MediaQuery.of(context).size.width < 420
                              ? 250
                              : 300,
                        ),
                      ),
                      // Hint text
                      Positioned(
                        bottom: 24,
                        left: 0,
                        right: 0,
                        child: Text(
                          'Lecteur PRO : EAN · UPC · Code128 · Code39 · ITF · DataMatrix · QR · Aztec',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
          ),
          // ── Saisie manuelle (lecteur HID USB/Bluetooth) ──
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              color: const Color(0xFF0C1F16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFC9A24B).withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.keyboard_rounded,
                      size: 20, color: Color(0xFFE9C873)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _manual,
                      autofocus: _error,
                      onSubmitted: _submit,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Saisir le code-barres manuellement',
                        hintStyle:
                            TextStyle(color: Color(0x77FFFFFF), fontSize: 12),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _submit(_manual.text),
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('OK',
                        style: TextStyle(
                            color: Color(0xFF7BEBA4),
                            fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded,
                size: 52, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            const Text('Caméra indisponible',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Autorisez l\'accès à la caméra dans votre navigateur,\n'
              'ou saisissez le code-barres manuellement ci-dessous.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
            ),
            if (_errorMsg.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_errorMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.danger, fontSize: 10)),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _error = false;
                  _errorMsg = '';
                  _started = false;
                });
                _startCamera();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E8C4F)),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Réessayer la caméra',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// VISÉE PROFESSIONNELLE : masque sombre autour d'une fenêtre
/// de scan, coins or épais, et LIGNE LASER animée qui balaie
/// verticalement le milieu du carré (repère de lecture clair).
/// ============================================================
class _ProReticle extends StatefulWidget {
  final double side;
  const _ProReticle({required this.side});

  @override
  State<_ProReticle> createState() => _ProReticleState();
}

class _ProReticleState extends State<_ProReticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _laser = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _laser.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.side,
      height: widget.side,
      child: Stack(
        children: [
          // Masque : assombrit tout sauf la fenêtre de scan.
          Positioned.fill(
            child: CustomPaint(
              painter: _ReticleMaskPainter(),
            ),
          ),
          // Coins or épais (style lecteur professionnel).
          Positioned.fill(
            child: CustomPaint(
              painter: _CornerPainter(),
            ),
          ),
          // LIGNE LASER animée : balaie le carré de haut en bas.
          AnimatedBuilder(
            animation: _laser,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_laser.value);
              return Positioned(
                left: 14,
                right: 14,
                top: 14 + t * (widget.side - 28),
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0x00E9C873),
                        Color(0xFFE9C873),
                        Color(0xFFFFE9B0),
                        Color(0xFFE9C873),
                        Color(0x00E9C873),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE9C873).withValues(alpha: 0.75),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Masque sombre : fenêtre claire au centre, voile sombre autour.
class _ReticleMaskPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    const radius = Radius.circular(20);
    final window = RRect.fromRectAndRadius(
        Offset.zero & s, const Radius.circular(20));
    final full = RRect.fromRectAndRadius(
        (Offset.zero - const Offset(-5000, -5000)) & (s + const Offset(10000, 10000)),
        radius);
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    c.save();
    // Fenêtre percée : on dessine le voile partout SAUF la fenêtre (even-odd).
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(full)
      ..addRRect(window);
    c.drawPath(path, paint);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Coins or épais de la fenêtre de scan.
class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0xFFE9C873)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const r = 20.0;
    const len = 42.0;
    final path = Path()
      // Top-left
      ..moveTo(0, r + len)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(r + len, 0)
      // Top-right
      ..moveTo(s.width - r - len, 0)
      ..lineTo(s.width - r, 0)
      ..quadraticBezierTo(s.width, 0, s.width, r)
      ..lineTo(s.width, r + len)
      // Bottom-right
      ..moveTo(s.width, s.height - r - len)
      ..lineTo(s.width, s.height - r)
      ..quadraticBezierTo(s.width, s.height, s.width - r, s.height)
      ..lineTo(s.width - r - len, s.height)
      // Bottom-left
      ..moveTo(r + len, s.height)
      ..lineTo(r, s.height)
      ..quadraticBezierTo(0, s.height, 0, s.height - r)
      ..lineTo(0, s.height - r - len);
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
