// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

bool get downloadSupported => true;

/// Déclenche le téléchargement d'un fichier binaire côté navigateur.
void downloadBytes(String filename, List<int> bytes, String mimeType) {
  final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body!.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

/// Déclenche le téléchargement d'un fichier texte (CSV, HTML/DOC…).
void downloadText(String filename, String content, String mimeType) {
  final bytes = utf8.encode('\uFEFF$content'); // BOM UTF-8 → Excel lisible
  downloadBytes(filename, bytes, mimeType);
}
