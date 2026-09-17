import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/colors.dart';

/// Résultat du scan : code brut + format détecté.
class ScanResult {
  final String code;
  final BarcodeFormat format;
  const ScanResult(this.code, this.format);
}

/// Scanner réutilisable (caméra tablette/smartphone + repli HID USB/BT).
/// Utilisé par : stock (ajout réception), POS (ajout panier), paiement.
class BarcodeScannerSheet extends StatefulWidget {
  final String title;
  const BarcodeScannerSheet({super.key, this.title = 'Scanner un code'});

  /// Ouvre le scanner en bottomSheet et retourne le code scanné.
  static Future<ScanResult?> show(BuildContext context, {String title = 'Scanner un code'}) {
    return showModalBottomSheet<ScanResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BarcodeScannerSheet(title: title),
    );
  }

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  MobileScannerController? _controller;
  bool _error = false;
  final _manual = TextEditingController();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final c = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        formats: const [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.code128,
          BarcodeFormat.qrCode,
          BarcodeFormat.code39,
          BarcodeFormat.code93,
        ],
      );
      await c.start();
      if (!mounted) { await c.dispose(); return; }
      setState(() => _controller = c);
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = true; _controller = null; });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _submit(String v) {
    final code = v.trim();
    if (code.isEmpty || _done) return;
    _done = true;
    Navigator.of(context).pop(ScanResult(code, BarcodeFormat.unknown));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF0C1F16),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppColors.goldBorder)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 44, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2)),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner, color: Color(0xFFE9C873), size: 20),
                  const SizedBox(width: 8),
                  Text(widget.title,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            // Camera
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: const Color(0xFF08130E),
                  child: _error || _controller == null
                      ? Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.videocam_off_rounded,
                                size: 40, color: AppColors.textSecondary),
                            const SizedBox(height: 10),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                'Caméra indisponible.\nUtilisez un lecteur USB/Bluetooth ou saisissez le code ci-dessous.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: () { setState(() => _error = false); _start(); },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Réessayer'),
                            ),
                          ]),
                        )
                      : MobileScanner(
                          controller: _controller!,
                          onDetect: (capture) {
                            if (_done) return;
                            for (final b in capture.barcodes) {
                              final v = b.rawValue;
                              if (v != null && v.isNotEmpty) {
                                _done = true;
                                Navigator.of(context).pop(
                                    ScanResult(v, b.format ?? BarcodeFormat.unknown));
                                break;
                              }
                            }
                          },
                        ),
                ),
              ),
            ),
            // Manual input (HID USB/Bluetooth)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC9A24B).withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.keyboard_rounded, size: 18, color: Color(0xFFE9C873)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _manual,
                      autofocus: _error,
                      onSubmitted: _submit,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Code-barres manuel ou lecteur HID + Entrée',
                        hintStyle: TextStyle(color: Color(0x77FFFFFF), fontSize: 11),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _submit(_manual.text),
                    child: const Text('OK',
                        style: TextStyle(color: Color(0xFF7BEBA4), fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
