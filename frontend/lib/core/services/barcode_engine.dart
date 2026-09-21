// PHARMA+ — Moteur de lecture codes-barres PRO.
// Répartiteur : stub natif (mobile_scanner) ou moteur web ZXing (tous formats).
library;
export 'barcode_engine_stub.dart'
    if (dart.library.html) 'barcode_engine_web.dart';

/// Résultat brut du moteur : texte + nom du format lisible.
class EngineBarcode {
  final String text;
  final String formatName;
  const EngineBarcode(this.text, this.formatName);
}
