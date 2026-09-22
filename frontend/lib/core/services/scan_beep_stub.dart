import 'package:flutter/services.dart';

Future<void> playBeep() async {
  try { await HapticFeedback.mediumImpact(); } catch (_) {}
  try { await SystemSound.play(SystemSoundType.alert); } catch (_) {}
}
