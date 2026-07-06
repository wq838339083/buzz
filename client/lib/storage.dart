import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class Storage {
  static const _kToken = 'token';
  static const _kUsername = 'username';
  static const _kDeviceId = 'device_id';
  static const _kDeviceName = 'device_name';
  static const _kPatterns = 'patterns';

  static Future<SharedPreferences> _p() => SharedPreferences.getInstance();

  static Future<void> saveSession({
    required String token,
    required String username,
  }) async {
    final p = await _p();
    await p.setString(_kToken, token);
    await p.setString(_kUsername, username);
  }

  static Future<void> clearSession() async {
    final p = await _p();
    await p.remove(_kToken);
    await p.remove(_kUsername);
  }

  static Future<String?> getToken() async => (await _p()).getString(_kToken);
  static Future<String?> getUsername() async =>
      (await _p()).getString(_kUsername);

  static Future<String> getOrCreateDeviceId() async {
    final p = await _p();
    var id = p.getString(_kDeviceId);
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      final bytes = List<int>.generate(12, (_) => r.nextInt(256));
      id = bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      await p.setString(_kDeviceId, id);
    }
    return id;
  }

  static Future<void> setDeviceName(String name) async {
    final p = await _p();
    await p.setString(_kDeviceName, name);
  }

  static Future<String> getDeviceName() async {
    final p = await _p();
    return p.getString(_kDeviceName) ?? 'Android';
  }

  static Future<List<SavedPattern>> loadPatterns() async {
    final p = await _p();
    final raw = p.getString(_kPatterns);
    if (raw == null || raw.isEmpty) return _defaultPatterns();
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => SavedPattern.fromJson(e as Map<String, dynamic>))
          .toList();
      return list.isEmpty ? _defaultPatterns() : list;
    } catch (_) {
      return _defaultPatterns();
    }
  }

  static Future<void> savePatterns(List<SavedPattern> patterns) async {
    final p = await _p();
    await p.setString(
      _kPatterns,
      jsonEncode(patterns.map((e) => e.toJson()).toList()),
    );
  }

  static List<SavedPattern> _defaultPatterns() => [
        SavedPattern(name: '短震', pattern: [0, 200]),
        SavedPattern(name: '长震', pattern: [0, 800]),
        SavedPattern(name: '双击', pattern: [0, 150, 120, 150]),
        SavedPattern(name: 'SOS', pattern: [
          0, 200, 150, 200, 150, 200,
          400, 500, 150, 500, 150, 500,
          400, 200, 150, 200, 150, 200,
        ]),
      ];
}

class SavedPattern {
  final String name;
  final List<int> pattern;
  SavedPattern({required this.name, required this.pattern});

  Map<String, dynamic> toJson() => {'name': name, 'pattern': pattern};

  factory SavedPattern.fromJson(Map<String, dynamic> j) => SavedPattern(
        name: j['name'] as String,
        pattern: (j['pattern'] as List).map((e) => (e as num).toInt()).toList(),
      );
}
