import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/colors.dart';

/// Résultat du scan : code brut + format détecté.
class ScanResult {
  final String code;
  final BarcodeFormat format;
  const ScanResult(this.code, this.format);
}

/// Scanner réutilisable — ouvre un écran plein écran (pas un bottom sheet)
/// pour que la caméra ait accès au plein viewport.
/// Supporte : tablette, smartphone, web (desktop avec caméra).
class BarcodeScannerSheet extends StatefulWidget {
  final String title;
  const BarcodeScannerSheet({super.key, this.title = 'Scanner un code'});

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

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  MobileScannerController? _controller;
  bool _error = false;
  String _errorMsg = '';
  bool _started = false;
  final _manual = TextEditingController();

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
    _controller?.stop();
    _controller?.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _submit(String v) {
    final code = v.trim();
    if (code.isEmpty) return;
    Navigator.of(context).pop(ScanResult(code, BarcodeFormat.unknown));
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
        actions: const [
          SizedBox.shrink(),
        ],
      ),
      body: Column(
        children: [
          // ── Zone caméra ──
          Expanded(
            child: _error || _controller == null
                ? _buildFallback()
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller!,
                        onDetect: (capture) {
                          for (final b in capture.barcodes) {
                            final v = b.rawValue;
                            if (v != null && v.isNotEmpty) {
                              Navigator.of(context).pop(
                                  ScanResult(v, b.format ?? BarcodeFormat.unknown));
                              return;
                            }
                          }
                        },
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
