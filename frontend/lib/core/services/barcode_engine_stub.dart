// Hors web : le moteur natif (mobile_scanner) est utilisé directement
// par barcode_scanner.dart. Le moteur web ZXing n'est pas applicable.
bool get webScannerSupported => false;

/// Démarre la caméra + décodage continu (web uniquement).
/// Retourne l'identifiant de vue pour HtmlElementView.
Future<String> startBarcodeCamera(
    void Function(String code, String formatName) onCode) async {
  throw UnsupportedError('Moteur ZXing disponible uniquement sur le web');
}

/// Arrête la caméra et le décodage (web uniquement).
void stopBarcodeCamera() {}
