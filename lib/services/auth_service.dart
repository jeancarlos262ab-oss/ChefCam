// lib/services/auth_service.dart
//
// Solo llama al backend. Sin lógica de negocio, sin SDKs de Supabase/Google.

import 'package:google_sign_in/google_sign_in.dart';
import 'api_client.dart';

class AuthService {
  static final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  // ── Registro ────────────────────────────────────────────────────────────────
  static Future<AuthUser> signUpWithEmail(
      String email, String password, String name) async {
    final data = await ApiClient.post('/auth/signup', {
      'email': email,
      'password': password,
      'full_name': name,
    });
    return _saveSession(data);
  }

  // ── Login email ─────────────────────────────────────────────────────────────
  static Future<AuthUser> signInWithEmail(String email, String password) async {
    final data = await ApiClient.post('/auth/signin', {
      'email': email,
      'password': password,
    });
    return _saveSession(data);
  }

  // ── Login Google ─────────────────────────────────────────────────────────────
  static Future<AuthUser?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw Exception('No se obtuvo ID token de Google');

    final data = await ApiClient.post('/auth/signin/google', {
      'id_token': idToken,
      if (googleAuth.accessToken != null) 'access_token': googleAuth.accessToken,
    });
    return _saveSession(data);
  }

  // ── Renovar sesión ──────────────────────────────────────────────────────────
  static Future<AuthUser> refresh() async {
    final token = ApiClient.refreshToken;
    if (token == null) throw Exception('No hay sesión activa');
    final data = await ApiClient.post('/auth/refresh', {'refresh_token': token});
    return _saveSession(data);
  }

  // ── Cerrar sesión ───────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    final token = ApiClient.accessToken;
    if (token != null) {
      await ApiClient.post('/auth/signout', {'access_token': token});
    }
    await _googleSignIn.signOut();
    ApiClient.clearTokens();
    _currentUser = null;
  }

  // ── Estado ──────────────────────────────────────────────────────────────────
  static AuthUser? _currentUser;
  static AuthUser? get currentUser => _currentUser;

  static AuthUser _saveSession(Map<String, dynamic> data) {
    ApiClient.setTokens(
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );
    _currentUser = AuthUser.fromMap(data);
    return _currentUser!;
  }
}

// ── Modelo de usuario ──────────────────────────────────────────────────────────
class AuthUser {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;

  const AuthUser({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
  });

  String get displayName =>
      fullName ?? email.split('@').first;

  factory AuthUser.fromMap(Map<String, dynamic> m) => AuthUser(
        id: m['user_id'] as String,
        email: m['email'] as String,
        fullName: m['full_name'] as String?,
        avatarUrl: m['avatar_url'] as String?,
      );
}
