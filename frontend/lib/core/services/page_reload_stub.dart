library;
export 'page_reload_stub.dart'
    if (dart.library.html) 'page_reload_web.dart';

/// Retourne true si un vrai rechargement de page a été déclenché.
bool get pageReloadSupported => false;

void reloadPage() {}
