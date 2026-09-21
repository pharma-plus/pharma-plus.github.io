// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js_util' as js;

import 'ocr_service.dart';

/// OCR WEB — Tesseract.js v5 (français + anglais), chargé depuis le CDN
/// uniquement au premier usage. Le document reste LOCAL : l'image est
/// traitée dans le navigateur (WASM/Worker), rien n'est envoyé au backend
/// ni à un service tiers (confidentialité, section 17).
const _cdn = 'https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/tesseract.min.js';

bool get ocrSupported => true;

Future<void> _ensureTesseract() async {
  if (js.hasProperty(html.window, 'Tesseract')) return;
  final script = html.ScriptElement()
    ..src = _cdn
    ..async = true;
  html.document.head!.append(script);
  await script.onLoad.first;
  // Attends la propriété globale (le script s'initialise après load).
  for (var i = 0; i < 50 && !js.hasProperty(html.window, 'Tesseract'); i++) {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

/// Ouvre le sélecteur de fichier image (caméra acceptée sur mobile) puis
/// lance la reconnaissance. Retourne null si annulé ou si le moteur échoue.
Future<OcrResult?> captureAndRecognize() async {
  try {
    await _ensureTesseract();
    if (!js.hasProperty(html.window, 'Tesseract')) return null;

    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = false;
    input.click();
    await input.onChange.first;
    final files = input.files;
    if (files == null || files.isEmpty) return null; // annulé
    final file = files.first;

    final tesseract = js.getProperty(html.window, 'Tesseract');
    final promise = js.callMethod(tesseract, 'recognize', [file, 'fra+eng']);
    final result = await js.promiseToFuture(promise);
    final data = js.getProperty(result, 'data');
    final text = (js.getProperty(data, 'text') as String?) ?? '';
    final confidence = switch (js.getProperty(data, 'confidence')) {
      final num c => c.toDouble(),
      _ => 0.0,
    };
    return OcrResult(text: text.trim(), confidence: confidence);
  } catch (_) {
    return null;
  }
}
