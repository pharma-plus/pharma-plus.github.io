// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/widgets.dart';

import 'app_guards.dart';
import '../../features/shell/shell_nav.dart';

BuildContext? _ctx;
Future<void> Function(BuildContext context)? _onBackAtRoot;
bool _quitOpen = false;
bool _inited = false;

/// Arme l'historique navigateur (smartphone / tablette) :
/// · une entrée garde au Dashboard pour empêcher la sortie sauvage ;
/// · une entrée par onglet pour que le retour système recule
///   Onglet → Dashboard → dialogue de confirmation.
void systemBackInit({
  required Future<void> Function(BuildContext context) onBackAtRoot,
}) {
  _onBackAtRoot = onBackAtRoot;
  if (_inited) return;
  _inited = true;
  _pushGuard();
  html.window.onPopState.listen(_onPopState);
}

void systemBackAttachContext(BuildContext? context) {
  _ctx = context;
}

void systemBackNoteShellIndex(int index) {
  if (!_inited) return;
  if (index > 0) {
    html.window.history.pushState({'pmg': true, 'tab': index}, '', '');
  } else {
    _pushGuard();
  }
}

void _pushGuard() {
  html.window.history.pushState({'pmg': true, 'tab': 0}, '', '');
}

bool _isOurs(Object? state) => state is Map && state['pmg'] == true;

void _onPopState(html.PopStateEvent event) {
  final state = event.state;
  // Laisse Flutter consommer d'abord ses propres entrées d'historique
  // (routes poussées : Caméras, Scanner, etc.).
  scheduleMicrotask(() async {
    final ctx = _ctx;
    if (ctx == null || !ctx.mounted) return;

    if (!_isOurs(state)) return; // entrée Flutter / externe

    final tab = state is Map ? state['tab'] : null;

    if (tab is int && tab > 0) {
      ShellNav.index.value = tab;
      return;
    }

    // Entrée garde / Dashboard atteint.
    if (ShellNav.index.value != 0) {
      ShellNav.goHome();
      _pushGuard();
      return;
    }

    // Déjà sur le Dashboard → confirmation obligatoire, pas de fermeture.
    if (_quitOpen) return;
    final nav = Navigator.of(ctx, rootNavigator: true);
    if (nav.canPop()) return;
    _quitOpen = true;
    final cb = _onBackAtRoot;
    if (cb != null) {
      await cb(ctx);
    } else {
      await confirmQuitApp(ctx);
    }
    _quitOpen = false;
    if (ctx.mounted && ShellNav.index.value == 0 && !(nav.canPop())) {
      _pushGuard();
    }
  });
}
