import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/models/medication.dart';
import '../../core/services/api_client.dart';
import '../../core/theme/colors.dart';
import '../pos/pos_page.dart';
import '../shell/shell_nav.dart';

/// Scanner codes-barres — caméra tablette/smartphone/web + repli HID.
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  MobileScannerController? _controller;
  bool _error = false;
  String _errorMsg = '';
  final _manual = TextEditingController();
  String? _lastCode;
  bool _busy = false;

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
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      await c.start();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
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

  Future<void> _handleCode(String raw) async {
    final code = raw.trim();
    if (code.isEmpty || _busy || code == _lastCode) return;
    _lastCode = code;
    setState(() => _busy = true);
    final result = await ApiClient.instance.get(
      '/catalog/medications/barcode/${Uri.encodeComponent(code)}',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    final med = result.data;
    if (!result.success || med == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Code-barres inconnu : $code\nRecherchez le produit par son nom dans le POS.')));
      return;
    }
    final medMap = med is Map ? Map<String, dynamic>.from(med) : <String, dynamic>{};
    final medication = Medication.fromJson(medMap);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PosPage(initialItems: [medication]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08130E),
      appBar: AppBar(
        leading: const ShellBackButton(),
        title: const Text('Scanner',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3)),
        backgroundColor: const Color(0xFF0C1F16),
        elevation: 0,
        actions: const [],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  color: const Color(0xFF08130E),
                  child: _error || _controller == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.videocam_off_rounded,
                                    size: 44, color: AppColors.textSecondary),
                                const SizedBox(height: 12),
                                const Text(
                                    'Caméra indisponible.\n'
                                    'Autorisez l\'accès caméra ou utilisez la saisie manuelle.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12.5)),
                                if (_errorMsg.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(_errorMsg,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 10)),
                                  ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _error = false;
                                      _errorMsg = '';
                                    });
                                    _startCamera();
                                  },
                                  icon: const Icon(Icons.refresh_rounded,
                                      size: 18),
                                  label: const Text('Réessayer la caméra'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            MobileScanner(
                              controller: _controller!,
                              onDetect: (capture) {
                                for (final b in capture.barcodes) {
                                  final v = b.rawValue;
                                  if (v != null && v.isNotEmpty) {
                                    _handleCode(v);
                                    break;
                                  }
                                }
                              },
                            ),
                            Center(
                              child: Container(
                                width: 280,
                                height: 280,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color(0xFFE9C873),
                                      width: 2.5),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 20,
                              left: 0,
                              right: 0,
                              child: Text(
                                'Placez le code dans le cadre',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (_busy)
                              const Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFF0E8C4F)),
                              ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Mode lecteur HID
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFC9A24B).withValues(alpha: 0.45)),
              ),
              child: Row(children: [
                const Icon(Icons.keyboard_rounded,
                    size: 20, color: Color(0xFFE9C873)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _manual,
                    autofocus: _error,
                    onSubmitted: _handleCode,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText:
                          'Lecteur USB/Bluetooth : scannez ici (ou code + Entrée)',
                      hintStyle:
                          TextStyle(color: Color(0x77FFFFFF), fontSize: 12),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _handleCode(_manual.text),
                  child: const Text('Rechercher',
                      style: TextStyle(
                          color: Color(0xFF7BEBA4),
                          fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Text(
                'Le produit trouvé est ajouté automatiquement au panier du point de vente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}
