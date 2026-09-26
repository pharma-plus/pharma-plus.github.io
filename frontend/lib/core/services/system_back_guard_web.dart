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
/// true pendant qu'on restaure un onglet / ferme une route depuis
/// l'historique : on ne doit PAS pousser une nouvelle entree.
bool _restoring = false;

/// Arme l'historique navigateur (smartphone / tablette) :
/// · une entree garde au Dashboard pour empecher la sortie sauvage ;
/// · une entree par onglet pour que le retour systeme recule
///   Onglet -> Dashboard -> dialogue de confirmation.
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

/// Retour systeme (bouton Android / geste) — TOUTES les pages :
/// 1) dialogue / formulaire / page poussee -> on le FERME et on reste
///    sur la page courante (l'entree consommee n'est PAS repoussee si
///    le pop est empeche par un formulaire non sauve) ;
/// 2) onglet != Dashboard -> Dashboard ;
/// 3) Dashboard -> dialogue "Voulez-vous quitter PHARMA+ ?".
void _onPopState(html.PopStateEvent event) {
  final state = event.state;
  // Laisse d'abord les handlers Flutter (engine) tourner, puis on agit.
  scheduleMicrotask(() {
    Future<void>.delayed(Duration.zero, () async {
      final ctx = _ctx;
      if (ctx == null || !ctx.mounted) return;

      final nav = Navigator.of(ctx, rootNavigator: true);

      // 1) Route Flutter encore ouverte (formulaire, dialogue, bottom
      //    sheet, sous-page) -> tenter de la fermer.
      //    Si le pop est empeche (unsaved changes), NE PAS toucher a
      //    l'historique navigateur (le navigateur a deja consomme son
      //    entree, on ne doit pas en ajouter une nouvelle).
      if (nav.canPop()) {
        _restoring = true;
        final beforePop = nav.canPop();
        nav.pop();
        // Attendre une micro-tache pour voir si le pop a reussi
        // (le PopScope local aura gere unsaved changes).
        await Future<void>.delayed(Duration.zero);
        _restoring = false;

        // Si le pop a reussi (route fermee), le navigateur a deja
        // recule dans son historique -> RIEN A FAIRE.
        // Si le pop a ECHOUE (formulaire non sauve), le navigateur a
        // quand meme consomme l'entree d'historique -> on NE repousse
        // PAS (sinon entree fantome). L'utilisateur reste sur la page.
        return;
      }

      if (!_isOurs(state)) return; // entree Flutter / externe

      final tab = state is Map ? state['tab'] : null;

      // 2) Entree d'un onglet : on restaure cet onglet (sans re-pousser).
      if (tab is int && tab > 0) {
        if (ShellNav.index.value != tab) {
          _restoring = true;
          ShellNav.index.value = tab;
          _restoring = false;
        }
        return;
      }

      // 3) Entree garde / Dashboard atteint depuis un autre onglet.
      if (ShellNav.index.value != 0) {
        _restoring = true;
        ShellNav.goHome();
        _restoring = false;
        return;
      }

      // 4) Deja sur le Dashboard -> confirmation obligatoire, pas de fermeture.
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
  });
}