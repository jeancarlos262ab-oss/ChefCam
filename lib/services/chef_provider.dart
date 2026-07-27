// lib/services/chef_provider.dart
//
// Provider limpio: solo orquesta servicios y estado UI.
// Cero lógica de negocio, cero llamadas HTTP directas.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'supabase_service.dart';
import 'recetas_db_service.dart';
import 'tts_service.dart';

export 'recetas_db_service.dart';

enum ChefState { idle, scanning, analyzing, recipesReady, cooking }

class ChefProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  final TtsService _ttsService = TtsService();

  ChefState _state = ChefState.idle;
  List<String> _detectedIngredients = [];
  List<Recipe> _recipes = [];
  Recipe? _selectedRecipe;
  int _currentStep = 0;
  String _statusMessage = '';
  bool _isSpeaking = false;
  String? _error;
  bool _errorEsNoComida = false;
  bool _errorEsYaPreparada = false;
  String? _nombreYaPreparada;
  bool _cookingFromHistory = false;

  List<Recipe> _historial = [];
  List<Recipe> _favoritos = [];
  bool _loadingHistorial = false;
  bool _loadingFavoritos = false;

  // ── Getters ────────────────────────────────────────────────────────────────
  ChefState get state => _state;
  List<String> get detectedIngredients => _detectedIngredients;
  List<Recipe> get recipes => _recipes;
  Recipe? get selectedRecipe => _selectedRecipe;
  int get currentStep => _currentStep;
  String get statusMessage => _statusMessage;
  bool get isSpeaking => _isSpeaking;
  String? get error => _error;
  bool get errorEsNoComida => _errorEsNoComida;
  bool get errorEsYaPreparada => _errorEsYaPreparada;
  String? get nombreYaPreparada => _nombreYaPreparada;
  bool get cookingFromHistory => _cookingFromHistory;
  List<Recipe> get historial => _historial;
  List<Recipe> get favoritos => _favoritos;
  bool get loadingHistorial => _loadingHistorial;
  bool get loadingFavoritos => _loadingFavoritos;

  CookingStep? get currentStepData {
    if (_selectedRecipe == null) return null;
    if (_currentStep >= _selectedRecipe!.steps.length) return null;
    return _selectedRecipe!.steps[_currentStep];
  }

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await _ttsService.init();
    await Future.wait([cargarHistorial(), cargarFavoritos()]);
  }

  // ── ANÁLISIS ───────────────────────────────────────────────────────────────
  Future<void> analyzeImage(Uint8List imageBytes) async {
    _resetError();
    _state = ChefState.analyzing;
    _statusMessage = 'Analizando ingredientes...';
    notifyListeners();

    await _ttsService.speak('Analizando los ingredientes...');

    try {
      final data = await _supabaseService.analizarRefri(imageBytes);
      _detectedIngredients = _supabaseService.parseIngredientes(data);
      _recipes = _supabaseService.parseRecetas(data);
      await _marcarFavoritos(_recipes);

      if (_detectedIngredients.isEmpty && _recipes.isEmpty) {
        _state = ChefState.idle;
        _statusMessage = 'No encontré ingredientes. Intenta de nuevo.';
        await _ttsService.speak('No pude detectar ingredientes. Apunta la cámara a los alimentos.');
        notifyListeners();
        return;
      }

      _state = ChefState.recipesReady;
      _statusMessage = '¡${_recipes.length} recetas encontradas!';
      await _ttsService.speak('¡Listo! Encontré ${_recipes.length} recetas. Elige la que quieras preparar.');
    } on ApiException catch (e) {
      _state = ChefState.idle;
      _statusMessage = '';
      _error = e.message;

      if (e.code == 'no_es_comida') {
        _errorEsNoComida = true;
        await _ttsService.speak('Eso no parece comida. Apunta al refrigerador e intenta de nuevo.');
      } else if (e.code == 'ya_preparada') {
        _errorEsYaPreparada = true;
        _nombreYaPreparada = e.nombre;
        await _ttsService.speak('¡Eso ya está listo para comer! Apunta al refrigerador para encontrar ingredientes.');
      }
    } catch (e) {
      _state = ChefState.idle;
      _statusMessage = '';
      _error = 'Error al analizar la imagen. Intenta de nuevo.';
    }

    notifyListeners();
  }

  // ── COCINAR ────────────────────────────────────────────────────────────────
  Future<void> selectRecipe(Recipe recipe) async {
    _cookingFromHistory = false;
    _selectedRecipe = recipe;
    _currentStep = 0;
    _state = ChefState.cooking;
    notifyListeners();
    await _ttsService.speak('Vamos a preparar ${recipe.title}. ${recipe.description}.');
    await Future.delayed(const Duration(seconds: 1));
    await speakCurrentStep();
  }

  Future<void> selectRecipeFromHistory(Recipe recipe) async {
    _cookingFromHistory = true;
    _selectedRecipe = recipe;
    _currentStep = 0;
    _state = ChefState.cooking;
    notifyListeners();
    await _ttsService.speak('Vamos a preparar ${recipe.title}.');
    await Future.delayed(const Duration(milliseconds: 800));
    await speakCurrentStep();
  }

  Future<void> speakCurrentStep() async {
    final step = currentStepData;
    if (step == null) return;
    _isSpeaking = true;
    notifyListeners();
    await _ttsService.speakStep(step.stepNumber, step.instruction);
    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> nextStep() async {
    if (_selectedRecipe == null) return;
    if (_currentStep < _selectedRecipe!.steps.length - 1) {
      _currentStep++;
      notifyListeners();
      await speakCurrentStep();
    } else {
      if (!_cookingFromHistory) await _guardarRecetaCompletada();
      await _ttsService.speak('¡Felicidades! Has terminado de preparar ${_selectedRecipe!.title}. ¡Buen provecho!');
      _statusMessage = '¡Receta completada!';
      notifyListeners();
    }
  }

  Future<void> previousStep() async {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
      await speakCurrentStep();
    }
  }

  Future<void> repeatStep() async => speakCurrentStep();

  // ── HISTORIAL ──────────────────────────────────────────────────────────────
  Future<void> cargarHistorial() async {
    _loadingHistorial = true;
    notifyListeners();
    try {
      _historial = await RecetasDbService.obtenerHistorial();
    } catch (_) {}
    _loadingHistorial = false;
    notifyListeners();
  }

  Future<void> editarHistorial({
    required Recipe recipe,
    required String nombre,
    required String dificultad,
    required int prepTimeMinutes,
  }) async {
    if (recipe.id == null) return;
    try {
      final updated = await RecetasDbService.actualizarHistorial(
        id: recipe.id!,
        nombre: nombre,
        dificultad: dificultad,
        prepTimeMinutes: prepTimeMinutes,
      );
      final idx = _historial.indexWhere((r) => r.id == recipe.id);
      if (idx != -1) _historial[idx] = updated;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> eliminarDeHistorial(Recipe recipe) async {
    if (recipe.id == null) return;
    try {
      await RecetasDbService.eliminarDeHistorial(recipe.id!);
      _historial.removeWhere((r) => r.id == recipe.id);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _guardarRecetaCompletada() async {
    final recipe = _selectedRecipe;
    if (recipe == null) return;
    try {
      final saved = await RecetasDbService.guardarEnHistorial(recipe);
      _historial.insert(0, saved);
      notifyListeners();
    } catch (_) {}
  }

  // ── FAVORITOS ──────────────────────────────────────────────────────────────
  Future<void> cargarFavoritos() async {
    _loadingFavoritos = true;
    notifyListeners();
    try {
      _favoritos = await RecetasDbService.obtenerFavoritos();
    } catch (_) {}
    _loadingFavoritos = false;
    notifyListeners();
  }

  Future<void> toggleFavorito(Recipe recipe) async {
    final eraFavorito = recipe.isFavorite;
    recipe.isFavorite = !eraFavorito;
    notifyListeners();

    try {
      if (!eraFavorito) {
        await RecetasDbService.agregarFavorito(recipe);
        if (!_favoritos.any((f) => f.title == recipe.title)) {
          _favoritos.insert(0, recipe);
        }
      } else {
        if (recipe.id != null) {
          await RecetasDbService.eliminarFavoritoPorId(recipe.id!);
        } else {
          await RecetasDbService.eliminarFavoritoPorNombre(recipe.title);
        }
        _favoritos.removeWhere((f) => f.title == recipe.title);
        for (final h in _historial) {
          if (h.title == recipe.title) h.isFavorite = false;
        }
      }
      notifyListeners();
    } catch (_) {
      recipe.isFavorite = eraFavorito;
      notifyListeners();
    }
  }

  Future<void> eliminarFavorito(Recipe recipe) async {
    try {
      if (recipe.id != null) {
        await RecetasDbService.eliminarFavoritoPorId(recipe.id!);
      } else {
        await RecetasDbService.eliminarFavoritoPorNombre(recipe.title);
      }
      recipe.isFavorite = false;
      _favoritos.removeWhere((f) => f.title == recipe.title);
      for (final h in _historial) {
        if (h.title == recipe.title) h.isFavorite = false;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _marcarFavoritos(List<Recipe> recipes) async {
    final favTitles = _favoritos.map((f) => f.title).toSet();
    for (final r in recipes) {
      r.isFavorite = favTitles.contains(r.title);
    }
  }

  // ── Navegación ─────────────────────────────────────────────────────────────
  void clearError() {
    _resetError();
    notifyListeners();
  }

  void resetToCamera() {
    _state = ChefState.idle;
    _detectedIngredients = [];
    _recipes = [];
    _selectedRecipe = null;
    _currentStep = 0;
    _statusMessage = '';
    _cookingFromHistory = false;
    _resetError();
    _ttsService.stop();
    notifyListeners();
  }

  void backToRecipes() {
    if (_cookingFromHistory) {
      _state = ChefState.idle;
      _selectedRecipe = null;
      _currentStep = 0;
      _cookingFromHistory = false;
    } else {
      _state = ChefState.recipesReady;
      _selectedRecipe = null;
      _currentStep = 0;
    }
    _ttsService.stop();
    notifyListeners();
  }

  void _resetError() {
    _error = null;
    _errorEsNoComida = false;
    _errorEsYaPreparada = false;
    _nombreYaPreparada = null;
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }
}
