import 'package:vibration/vibration.dart';

class VibratorService {
  static bool _hasVibrator = true;
  static bool _hasAmplitudeControl = false;
  static bool _inited = false;

  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      _hasVibrator = (await Vibration.hasVibrator()) ?? false;
      _hasAmplitudeControl =
          (await Vibration.hasAmplitudeControl()) ?? false;
    } catch (_) {}
  }

  static Future<void> play(List<int> pattern, {int intensity = 255}) async {
    await init();
    if (!_hasVibrator) return;
    if (pattern.isEmpty) return;

    try {
      if (_hasAmplitudeControl) {
        final intensities = List<int>.filled(pattern.length, intensity);
        await Vibration.vibrate(pattern: pattern, intensities: intensities);
      } else {
        await Vibration.vibrate(pattern: pattern);
      }
    } catch (_) {}
  }

  static Future<void> stop() async {
    try { await Vibration.cancel(); } catch (_) {}
  }
}
