// ignore_for_file: avoid_web_libraries_in_flutter
// PHARMA+ — Moteur de lecture codes-barres PRO (WEB).
// Engine : ZXing (@zxing/library, standard industrie) — lit TOUS les
// formats : EAN-13, EAN-8, UPC-A/E, Code128, Code39, Code93, Codabar,
// ITF, DataMatrix, PDF417, Aztec, QR. Caméra via getUserMedia, décodage
// continu. Chargé UNIQUEMENT à la demande (jamais au démarrage).
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

const _zxingCdn = 'https://unpkg.com/@zxing/library@0.21.3';

/// Noms des formats ZXing, indexés comme l'enum JS BarcodeFormat.
const _formatNames = [
  'AZTEC', 'CODABAR', 'CODE_39', 'CODE_93', 'CODE_128', 'DATA_MATRIX',
  'EAN_8', 'EAN_13', 'ITF', 'MAXICODE', 'PDF_417', 'QR_CODE', 'RSS_14',
  'RSS_EXPANDED', 'UPC_A', 'UPC_E', 'UPC_EAN_EXTENSION',
];

bool _zxingReady = false;
int _viewCounter = 0;
JSObject? _video;
JSObject? _reader;

bool get webScannerSupported => true;

Future<void> _ensureZxing() async {
  if (_zxingReady) return;
  final doc = globalContext['document'] as JSObject;
  final script =
      doc.callMethod('createElement'.toJS, 'script'.toJS) as JSObject;
  script.setProperty('src'.toJS, _zxingCdn.toJS);
  script.setProperty('async'.toJS, true.toJS);
  final head = doc['head'] as JSObject;
  head.callMethod('appendChild'.toJS, script);
  // Le script s'initialise après le chargement : on attend la propriété
  // globale ZXing (jamais plus de 8 s).
  for (var i = 0; i < 80; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
    final z = globalContext['ZXing'];
    if (z != null && !z.isUndefinedOrNull) {
      _zxingReady = true;
      return;
    }
  }
  throw Exception('Moteur ZXing non disponible (réseau ?)');
}

/// Démarre la caméra + le décodage continu ZXing (tous formats).
/// Retourne l'identifiant de vue à passer à HtmlElementView.
Future<String> startBarcodeCamera(
    void Function(String code, String formatName) onCode) async {
  await _ensureZxing();

  final viewId = 'pmg-barcode-camera-pro-${_viewCounter++}';
  final doc = globalContext['document'] as JSObject;
  final video =
      doc.callMethod('createElement'.toJS, 'video'.toJS) as JSObject;
  video.setProperty('autoplay'.toJS, true.toJS);
  video.setProperty('muted'.toJS, true.toJS);
  video.callMethod('setAttribute'.toJS, 'playsinline'.toJS, 'true'.toJS);
  final style = video['style'] as JSObject;
  style.setProperty('width'.toJS, '100%'.toJS);
  style.setProperty('height'.toJS, '100%'.toJS);
  style.setProperty('objectFit'.toJS, 'cover'.toJS);
  style.setProperty('backgroundColor'.toJS, '#03100D'.toJS);
  _video = video;

  ui_web.platformViewRegistry.registerViewFactory(viewId, (int vid) => video);

  final zxing = globalContext['ZXing'] as JSObject;
  final ctor = zxing['BrowserMultiFormatReader'] as JSFunction;
  final reader = ctor.callAsConstructor<JSObject>();
  _reader = reader;

  void handle(JSAny? result, JSAny? err) {
    if (result == null || result.isUndefinedOrNull) return;
    final r = result as JSObject;
    final rawText = r['text'];
    if (rawText == null || rawText.isUndefinedOrNull) return;
    final text = rawText.dartify();
    if (text is! String || text.trim().isEmpty) return;

    var fmt = 'CODE';
    try {
      final f = r.callMethod<JSNumber>('getBarcodeFormat'.toJS).toDartInt;
      if (f >= 0 && f < _formatNames.length) fmt = _formatNames[f];
    } catch (_) {}

    onCode(text.trim(), fmt);
  }

  final constraints = {
    'video': {
      'facingMode': 'environment',
      'width': {'ideal': 1600},
      'height': {'ideal': 900},
    },
    'audio': false,
  }.jsify();

  final promise = reader.callMethod('decodeFromConstraints'.toJS, constraints,
          video, handle.toJS) as JSPromise;
  await promise.toDart;
  return viewId;
}

/// Arrête la caméra + le décodage, libère le flux.
void stopBarcodeCamera() {
  try {
    _reader?.callMethod('reset'.toJS);
  } catch (_) {}
  try {
    _video?.callMethod('pause'.toJS);
  } catch (_) {}
  try {
    _video?.setProperty('srcObject'.toJS, null);
  } catch (_) {}
  try {
    _video?.callMethod('remove'.toJS);
  } catch (_) {}
  _video = null;
  _reader = null;
}


