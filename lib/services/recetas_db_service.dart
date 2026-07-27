// lib/services/recetas_db_service.dart
//
// Historial y favoritos: solo llama al backend, sin lógica.

import '../models/recipe.dart';
import 'api_client.dart';
import 'auth_service.dart';

class RecetasDbService {
  // ── HISTORIAL ───────────────────────────────────────────────────────────────

  static Future<List<Recipe>> obtenerHistorial({int limit = 50}) async {
    final data = await ApiClient.get('/historial?limit=$limit');
    final list = data['items'] as List<dynamic>? ?? (data is List ? data : [data]);
    // El endpoint devuelve lista directamente
    return _parseList(data);
  }

  static Future<Recipe> guardarEnHistorial(Recipe recipe) async {
    final data = await ApiClient.post('/historial', _recetaToMap(recipe));
    return Recipe.fromSupabase(data);
  }

  static Future<Recipe> actualizarHistorial({
    required String id,
    required String nombre,
    required String dificultad,
    required int prepTimeMinutes,
  }) async {
    final data = await ApiClient.patch('/historial/$id', {
      'nombre': nombre,
      'dificultad': dificultad,
      'tiempo': '$prepTimeMinutes minutos',
    });
    return Recipe.fromSupabase(data);
  }

  static Future<void> eliminarDeHistorial(String id) async {
    await ApiClient.delete('/historial/$id');
  }

  // ── FAVORITOS ────────────────────────────────────────────────────────────────

  static Future<List<Recipe>> obtenerFavoritos() async {
    final data = await ApiClient.get('/favoritos');
    return _parseList(data)..forEach((r) => r.isFavorite = true);
  }

  static Future<void> agregarFavorito(Recipe recipe) async {
    await ApiClient.post('/favoritos', _recetaToMap(recipe));
  }

  static Future<void> eliminarFavoritoPorId(String id) async {
    await ApiClient.delete('/favoritos/$id');
  }

  static Future<void> eliminarFavoritoPorNombre(String nombre) async {
    await ApiClient.delete('/favoritos/nombre/$nombre');
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static List<Recipe> _parseList(dynamic data) {
    if (data is List) return data.map((r) => Recipe.fromSupabase(r as Map<String, dynamic>)).toList();
    return [];
  }

  static Map<String, dynamic> _recetaToMap(Recipe recipe) => {
        'nombre': recipe.title,
        'descripcion': recipe.description,
        'ingredientes': recipe.ingredients,
        'dificultad': recipe.difficulty,
        'tiempo': '${recipe.prepTimeMinutes} minutos',
        'emoji': recipe.emoji,
        'pasos': recipe.steps
            .map((s) => {'instruccion': s.instruction, 'imageUrl': s.imageUrl, 'durationSeconds': s.durationSeconds ?? 0})
            .toList(),
      };
}
