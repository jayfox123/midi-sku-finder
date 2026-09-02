import 'package:flutter/services.dart';

class AudioFeedbackService {
  /// Plays haptic vibration and system audio alert on barcode detection.
  static Future<void> playScanSuccess() async {
    try {
      await HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Plays distinct haptic feedback on match found.
  static Future<void> playMatchFound() async {
    try {
      await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Plays light haptic feedback on no match.
  static Future<void> playNoMatch() async {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }
}
