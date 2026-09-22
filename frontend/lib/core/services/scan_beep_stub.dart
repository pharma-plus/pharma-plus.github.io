import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

final _player = AudioPlayer()..setVolume(1.0);

void initWebAudio() {} // no-op on mobile

Future<void> playBeep() async {
  try { await HapticFeedback.heavyImpact(); } catch (_) {}
  try {
    await _player.stop();
    await _player.play(AssetSource('beep.wav'));
  } catch (_) {}
}
