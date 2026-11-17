import 'dart:html' as html;

/// Version web : émet l'événement « pharma-ready » écouté par
/// web/index.html pour retirer le splash HTML au bon moment
/// (application initialisée, pas seulement premier pixel Flutter).
void notifyAppReady() {
  html.window.dispatchEvent(html.CustomEvent('pharma-ready'));
}
