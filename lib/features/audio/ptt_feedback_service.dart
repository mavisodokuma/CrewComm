import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class PttFeedbackService {
  Future<void> openingTone() async {
    await SystemSound.play(SystemSoundType.click);
    await HapticFeedback.selectionClick();
  }

  Future<void> closingTone() async {
    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.lightImpact();
  }

  Future<void> adminBroadcastHaptic() async {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(pattern: <int>[0, 90, 50, 160, 50, 240]);
      return;
    }
    await HapticFeedback.heavyImpact();
  }
}
