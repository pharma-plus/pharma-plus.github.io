// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Beep web via Web Audio API — sine 1200 Hz, 80 ms, vol 0.3.
Future<void> playBeep() async {
  try {
    final AudioCtx = globalContext.callMethod(
      'Function'.toJS,
      'return new(window.AudioContext||window.webkitAudioContext)()'.toJS,
    ) as JSObject?;
    if (AudioCtx == null) return;

    final state = AudioCtx.getProperty('state'.toJS)?.dartify() as String?;
    if (state == 'suspended') {
      AudioCtx.callMethod('resume'.toJS);
    }

    final osc = AudioCtx.callMethod('createOscillator'.toJS) as JSObject;
    final gain = AudioCtx.callMethod('createGain'.toJS) as JSObject;
    osc.callMethod('connect'.toJS, gain);
    gain.callMethod('connect'.toJS, AudioCtx.getProperty('destination'.toJS));

    osc.setProperty('type'.toJS, 'sine'.toJS);
    (osc.getProperty('frequency'.toJS) as JSObject)
        .setProperty('value'.toJS, 1200.jsify());
    (gain.getProperty('gain'.toJS) as JSObject)
        .setProperty('value'.toJS, 0.3.jsify());

    final now = (AudioCtx.getProperty('currentTime'.toJS)!.dartify() as num).toDouble();
    osc.callMethod('start'.toJS, now.jsify());
    (gain.getProperty('gain'.toJS) as JSObject).callMethod(
        'exponentialRampToValueAtTime'.toJS,
        0.001.jsify(), (now + 0.08).jsify());
    osc.callMethod('stop'.toJS, (now + 0.1).jsify());
  } catch (_) {}
}
