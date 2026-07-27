// lib/services/supabase_service.dart
//
// Llama a POST /analizar. Sin lógica, sin parsing manual.

import 'dart:typed_data';
import 'dart:convert';
import '../models/recipe.dart';
import 'api_client.dart';

export 'api_client.dart' show ApiException;

class SupabaseService {
  Future<Map<String, dynamic>> analizarRefri(Uint8List imageBytes) async {
    // ApiClient lanza ApiException si el servidor devuelve error
    return await ApiClient.post('/analizar', {
      'imagenBase64': base64Encode(imageBytes),
    });
  }

  List<String> parseIngredientes(Map<String, dynamic> data) =>
      List<String>.from(data['ingredientes'] ?? []);

  List<Recipe> parseRecetas(Map<String, dynamic> data) {
    final list = data['recetas'] as List<dynamic>? ?? [];
    return list.map((r) => Recipe.fromSupabase(r as Map<String, dynamic>)).toList();
  }
}
