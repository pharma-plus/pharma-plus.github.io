import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/gs1_parser.dart';
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

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  MobileScannerController? _controller;
  bool _error = false;
  String _errorMsg = '';
  bool _started = false;
  final _manual = TextEditingController();

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
    _startCamera();
  }

  Future<void> _startCamera() async {
    try {
      final c = MobileScannerController(
        detectionSpeed: DetectionSpeed.unrestricted,
        facing: CameraFacing.back,
        autoStart: false,
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
    _controller?.stop();
    _controller?.dispose();
    _manual.dispose();
    super.dispose();
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
    HapticFeedback.mediumImpact();
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}

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
            child: _error || _controller == null
                ? _buildFallback()
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller!,
                        onDetect: _onDetect,
                      ),
                      // Crosshair overlay
                      Center(
                        child: Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFE9C873), width: 2.5),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: CustomPaint(
                            painter: _CrosshairPainter(),
                          ),
                        ),
                      ),
                      // Hint text
                      Positioned(
                        bottom: 24,
                        left: 0,
                        right: 0,
                        child: Text(
                          'Placez le code-barres ou QR dans le cadre',
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

/// Croix de visée overlay.
class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0xFFE9C873)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const len = 24.0;
    // Top-left
    c.drawLine(const Offset(0, len), const Offset(0, 0), p);
    c.drawLine(const Offset(0, 0), const Offset(len, 0), p);
    // Top-right
    c.drawLine(Offset(s.width - len, 0), Offset(s.width, 0), p);
    c.drawLine(Offset(s.width, 0), Offset(s.width, len), p);
    // Bottom-left
    c.drawLine(Offset(0, s.height - len), Offset(0, s.height), p);
    c.drawLine(Offset(0, s.height), Offset(len, s.height), p);
    // Bottom-right
    c.drawLine(
        Offset(s.width, s.height - len), Offset(s.width, s.height), p);
    c.drawLine(Offset(s.width - len, s.height), Offset(s.width, s.height), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
