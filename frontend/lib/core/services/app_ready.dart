library;

/// Signale au splash HTML (web/index.html) que l'application est prête :
/// le splash peut alors se retirer, sans écran intermédiaire.
export 'app_ready_stub.dart' if (dart.library.html) 'app_ready_web.dart';
