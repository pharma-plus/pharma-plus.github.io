// PHARMA+ — OCR d'ordonnance (sections 13–14).
// Web : Tesseract.js chargé UNIQUEMENT à la demande (jamais au démarrage,
// section 42 — le scan produit doit rester rapide). Hors web : non
// supporté (retourne null, jamais une simulation).
library;
export 'ocr_service_stub.dart'
    if (dart.library.html) 'ocr_service_web.dart';

/// Résultat OCR brut : texte extrait + confiance du moteur (0–100).
class OcrResult {
  final String text;
  final double confidence;
  const OcrResult({required this.text, required this.confidence});
}
