import 'scan_beep_web.dart' if (dart.library.io) 'scan_beep_stub.dart'
    as beep;

/// Son de confirmation pour le scanner code-barres/QR.
Future<void> playScanBeep() => beep.playBeep();

/// Initialiser l'audio (à appeler dans un user gesture, ex: ouverture scanner).
void initScanAudio() => beep.initWebAudio();
