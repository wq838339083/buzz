import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiError implements Exception {
  final String message;
  ApiError(this.message);
  @override
  String toString() => message;
}

class Api {
  static Future<Map<String, dynamic>> register(
      String username, String password) async {
    return _post('/api/register', {'username': username, 'password': password});
  }

  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    return _post('/api/login', {'username': username, 'password': password});
  }

  static Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConfig.httpBase}$path');
    final res = await http
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || data['ok'] != true) {
      throw ApiError(data['error']?.toString() ?? 'HTTP ${res.statusCode}');
    }
    return data;
  }
}
