import 'package:flutter/widgets.dart';

/// Hors web : le bouton retour est géré par [PopScope] uniquement.
void systemBackInit({required Future<void> Function(BuildContext context) onBackAtRoot}) {}

void systemBackAttachContext(BuildContext? context) {}

void systemBackNoteShellIndex(int index) {}
