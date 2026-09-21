import 'ocr_service.dart';

/// Plateforme non web : l'OCR ordonnance n'est PAS supporté.
/// Jamais de simulation — retourne null.
Future<OcrResult?> captureAndRecognize() async => null;
