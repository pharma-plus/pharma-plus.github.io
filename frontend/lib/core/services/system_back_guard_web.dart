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
/// true pendant qu'on restaure un onglet depuis l'historique :
/// on ne doit PAS pousser une nouvelle entrée (sinon doublon).
bool _restoring = false;

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
  if (!_inited || _restoring) return;
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

/// Retour système (bouton Android / geste) — valable sur TOUTES les pages :
/// 1) dialogue / formulaire / page poussée ouverte → Flutter la ferme seule
///    (on ne touche ni l'onglet ni la confirmation) ;
/// 2) onglet ≠ Dashboard → Dashboard ;
/// 3) Dashboard → dialogue « Voulez-vous quitter PHARMA+ ? » (jamais sans).
void _onPopState(html.PopStateEvent event) {
  final state = event.state;
  // Laisse Flutter consommer d'abord ses propres entrées d'historique
  // (routes poussées : formulaires, bottom sheets, Caméras, etc.).
  scheduleMicrotask(() async {
    final ctx = _ctx;
    if (ctx == null || !ctx.mounted) return;

    // 1) Une route Flutter est encore empilée (dialogue/form/sous-page) :
    //    c'est Flutter qui la pop — on sort sans changer d'onglet.
    final nav = Navigator.of(ctx, rootNavigator: true);
    if (nav.canPop()) return;

    if (!_isOurs(state)) return; // entrée Flutter / externe

    final tab = state is Map ? state['tab'] : null;

    // 2) Entrée d'un onglet : on restaure cet onglet (sans re-pousser).
    if (tab is int && tab > 0) {
      if (ShellNav.index.value != tab) {
        _restoring = true;
        ShellNav.index.value = tab;
        _restoring = false;
      }
      return;
    }

    // 3) Entrée garde / Dashboard atteint depuis un autre onglet.
    if (ShellNav.index.value != 0) {
      _restoring = true;
      ShellNav.goHome();
      _restoring = false;
      return; // la garde déjà en dessous sert de sommet
    }

    // 4) Déjà sur le Dashboard → confirmation obligatoire, pas de fermeture.
    if (_quitOpen) return;
    if (nav.canPop()) return;
    _quitOpen = true;
    final cb = _onBackAtRoot;
    if (cb != null) {
      await cb(ctx);
    } else {
      await confirmQuitApp(ctx);
    }
    _quitOpen = false;
    if (ctx.mounted && ShellNav.index.value == 0 && !nav.canPop()) {
      _pushGuard();
    }
  });
}
