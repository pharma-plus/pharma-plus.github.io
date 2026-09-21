// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'page_reload_stub.dart';

bool get pageReloadSupported => true;

/// Rechargement complet de la page (nouveau build servi, cache contourné).
void reloadPage() => html.window.location.reload();
