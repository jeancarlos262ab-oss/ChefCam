// lib/services/api_client.dart
//
// Cliente HTTP base. Todos los servicios lo usan.
// Guarda el access_token en memoria; se setea tras login.

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'http://192.168.1.71:8000';

  static String? _accessToken;
  static String? _refreshToken;

  static void setTokens({required String access, required String refresh}) {
    _accessToken = access;
    _refreshToken = refresh;
  }

  static void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  static String? get accessToken => _accessToken;
  static String? get refreshToken => _refreshToken;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  // ── HTTP helpers ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> get(String path) async {
    final r = await http
        .get(Uri.parse('$baseUrl$path'), headers: _headers)
        .timeout(const Duration(seconds: 30));
    return _handle(r);
  }

  static Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    final r = await http
        .post(Uri.parse('$baseUrl$path'),
            headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 90));
    return _handle(r);
  }

  static Future<Map<String, dynamic>> patch(
      String path, Map<String, dynamic> body) async {
    final r = await http
        .patch(Uri.parse('$baseUrl$path'),
            headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    return _handle(r);
  }

  static Future<void> delete(String path) async {
    final r = await http
        .delete(Uri.parse('$baseUrl$path'), headers: _headers)
        .timeout(const Duration(seconds: 30));
    if (r.statusCode >= 400) _throwError(r);
  }

  // ── Error handling ──────────────────────────────────────────────────────────

  static Map<String, dynamic> _handle(http.Response r) {
    if (r.statusCode == 204) return {};
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode >= 400) {
      // Errores directos en el body (ej: no_es_comida, ya_preparada)
      if (body.containsKey('error')) throw ApiException.fromMap(body);
      // Errores envueltos en detail (HTTPException de FastAPI)
      final detail = body['detail'];
      if (detail is Map<String, dynamic>) throw ApiException.fromMap(detail);
      throw ApiException(
          code: 'error', message: detail?.toString() ?? 'Error desconocido');
    }
    return body;
  }

  static Never _throwError(http.Response r) {
    throw ApiException(code: 'http_${r.statusCode}', message: r.body);
  }
}

// ── Excepción tipada ──────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String code;
  final String message;
  final String? nombre; // para "ya_preparada"

  const ApiException({required this.code, required this.message, this.nombre});

  factory ApiException.fromMap(Map<String, dynamic> m) => ApiException(
        code: m['error']?.toString() ?? 'error',
        message: m['mensaje']?.toString() ?? m['detail']?.toString() ?? 'Error',
        nombre: m['nombre']?.toString(),
      );

  @override
  String toString() => message;
}
