import 'dart:io';

/// Non-web (desktop / mobile) : écriture RÉELLE sur disque.
/// Candidats : <Profil>/Downloads → répertoire courant → temporaire.
bool get downloadSupported => true;

/// Chemin du dernier fichier enregistré (null après échec / sur le web).
String? lastSavedPath;

/// Dernière erreur d'enregistrement (null si succès).
String? lastSaveError;

Iterable<Directory> _candidates() sync* {
  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    yield Directory('$home${Platform.pathSeparator}Downloads');
  }
  yield Directory.current;
  yield Directory.systemTemp;
}

void downloadBytes(String filename, List<int> bytes, String mimeType) =>
    _save(filename, (f) => f.writeAsBytesSync(bytes, flush: true));

void downloadText(String filename, String content, String mimeType) =>
    _save(filename, (f) => f.writeAsStringSync('\uFEFF$content', flush: true));

void _save(String filename, void Function(File) write) {
  Object? last;
  for (final d in _candidates()) {
    try {
      if (!d.existsSync()) d.createSync(recursive: true);
      final f = File('${d.path}${Platform.pathSeparator}$filename');
      write(f);
      lastSavedPath = f.path;
      lastSaveError = null;
      return;
    } catch (e) {
      last = e;
    }
  }
  lastSavedPath = null;
  lastSaveError = '$last';
  throw FileSystemException('Enregistrement impossible', filename);
}
