// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Beep web via Web Audio API — sine 1200 Hz, 150 ms, vol 1.0.
/// Safari iOS exige que AudioContext soit créé dans un user gesture direct.
/// On crée le contexte au premier appel de playBeep() (depuis un callback
/// caméra, pas un user gesture) — Safari le suspend, mais on peut le
/// reprendre au prochain tap utilisateur via initWebAudio().
JSObject? _audioCtx;

/// Appeler lors d'un user gesture (tap écran scanner) pour activer l'audio.
/// Si le contexte existe déjà mais est suspendu, on le reprend.
void initWebAudio() {
  try {
    if (_audioCtx == null) {
      _audioCtx = globalContext.callMethod(
        'Function'.toJS,
        'return new(window.AudioContext||window.webkitAudioContext)()'.toJS,
      ) as JSObject?;
    }
    final ctx = _audioCtx;
    if (ctx != null) {
      final state = ctx.getProperty('state'.toJS)?.dartify() as String?;
      if (state == 'suspended') {
        ctx.callMethod('resume'.toJS);
      }
    }
  } catch (_) {}
}

Future<void> playBeep() async {
  try {
    // Créer si nécessaire (même si suspendu, on essaie quand même)
    if (_audioCtx == null) initWebAudio();
    final ctx = _audioCtx;
    if (ctx == null) return;

    final state = ctx.getProperty('state'.toJS)?.dartify() as String?;
    if (state == 'suspended') {
      ctx.callMethod('resume'.toJS);
    }

    final osc = ctx.callMethod('createOscillator'.toJS) as JSObject;
    final gain = ctx.callMethod('createGain'.toJS) as JSObject;
    osc.callMethod('connect'.toJS, gain);
    gain.callMethod('connect'.toJS, ctx.getProperty('destination'.toJS));

    osc.setProperty('type'.toJS, 'sine'.toJS);
    (osc.getProperty('frequency'.toJS) as JSObject)
        .setProperty('value'.toJS, 1200.jsify());
    (gain.getProperty('gain'.toJS) as JSObject)
        .setProperty('value'.toJS, 1.0.jsify());

    final now = (ctx.getProperty('currentTime'.toJS)!.dartify() as num).toDouble();
    osc.callMethod('start'.toJS, now.jsify());
    (gain.getProperty('gain'.toJS) as JSObject).callMethod(
        'exponentialRampToValueAtTime'.toJS,
        0.001.jsify(), (now + 0.12).jsify());
    osc.callMethod('stop'.toJS, (now + 0.15).jsify());
  } catch (_) {}
}
