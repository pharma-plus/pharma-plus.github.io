// PMG-SCANNER-REAL
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/models/medication.dart';
import '../../core/services/api_client.dart';
import '../../core/theme/colors.dart';
import '../pos/pos_page.dart';
import '../shell/shell_nav.dart';

/// ============================================================
/// SCANNER CODES-BARRES — opérationnel de bout en bout :
/// · caméra (web/mobile) lorsque disponible
/// · lecteur USB / Bluetooth HID : saisie manuelle + Entrée
/// · recherche du produit par code-barres via l'API
/// · ajout automatique au panier (POS complet pré-rempli)
/// Caméra indisponible → message clair, l'application ne plante pas.
/// ============================================================
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  MobileScannerController? _controller;
  bool _cameraError = false;
  String _cameraMessage = '';
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
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        // Formats métier (§15) : EAN-13, EAN-8, Code128, QR.
        formats: const [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.code128,
          BarcodeFormat.qrCode,
        ],
      );
      await c.start();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraError = true;
        _controller = null;
        _cameraMessage =
            'Caméra indisponible sur cet appareil/navigateur.\n'
            'Utilisez un lecteur USB/Bluetooth (mode saisie) ci-dessous — '
            'le scan fonctionne aussi au clavier.';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String raw) async {
    final code = raw.trim();
    if (code.isEmpty || _busy || code == _lastCode) return;
    _lastCode = code;
    setState(() => _busy = true);
    final result = await ApiClient.instance.get<Map<String, dynamic>>(
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
    // Produit trouvé → ajout automatique au panier : POS pré-rempli.
    final medication = Medication.fromJson(med);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PosPage(initialItems: [medication]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.menu,
      appBar: AppBar(
        // ← HOME : retour toujours disponible (sous-page → pop ;
        // racine du shell → retour au Tableau de bord).
        leading: const ShellBackButton(),
        title: const Text('Scanner',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3)),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                  child: _cameraError || _controller == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.videocam_off_rounded,
                                    size: 44, color: AppColors.textSecondary),
                                const SizedBox(height: 12),
                                Text(_cameraMessage,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12.5)),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _cameraError = false;
                                      _cameraMessage = '';
                                    });
                                    _startCamera();
                                  },
                                  icon:
                                      const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text('Réessayer la caméra'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : MobileScanner(
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
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Mode lecteur HID (USB / Bluetooth) : la douchette « tape » le
            // code puis Entrée — on capte exactement cela ici.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                    autofocus: _cameraError,
                    onSubmitted: _handleCode,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText:
                          'Lecteur USB/Bluetooth : scannez ici (ou tapez le code + Entrée)',
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
