import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../services/database_service.dart';
import '../models/user_profile.dart';
import '../models/conversation.dart';
import '../models/movie.dart';
import '../models/watched_movie.dart';
import '../models/user_preferences.dart';


class AppState extends ChangeNotifier {
  AppState({
    required bool initialExcludeAdult,
    required String initialLanguage,
    required ThemeMode initialThemeMode,
  })  : _excludeAdult = initialExcludeAdult,
        _languageCode = initialLanguage,
        _themeMode = initialThemeMode;

  static const List<String> allowedLanguages = ['es-ES', 'en-US', 'pt-BR'];

  bool _excludeAdult;
  String _languageCode;
  ThemeMode _themeMode;
  String? _lastSelectedGenreKey;
  Movie? _lastMovie;
  final List<Movie> _favorites = [];
  final List<WatchedMovie> _watched = [];
  final List<Movie> _history = [];
  // Variables del chat
  final List<ChatMessage> _chatMessages = [];
  List<Movie> _moodMovies = [];
  bool _isLoadingMoodMovies = false;

  int _yearStart = 2000;
  int _yearEnd = DateTime.now().year;
  int _minVotes = 20;

  // Base de datos y perfil de usuario
  final DatabaseService _databaseService = DatabaseService();
  UserProfile? _userProfile;
  List<Conversation> _recentConversations = [];
  bool _isFirstTime = true;
  bool _hasShownWelcomeRecommendation = false;
  UserPreferences? _userPreferences;

  // Nuevos campos para rating
  double _minRating = 0.0;
  double _maxRating = 10.0;
  bool _useRatingFilter = false;

  bool get excludeAdult => _excludeAdult;
  String get languageCode => _languageCode;
  ThemeMode get themeMode => _themeMode;
  String? get lastSelectedGenreKey => _lastSelectedGenreKey;
  Movie? get lastMovie => _lastMovie;
  List<Movie> get favorites => List.unmodifiable(_favorites);
  List<WatchedMovie> get watched => List.unmodifiable(_watched);
  List<Movie> get history => List.unmodifiable(_history);

  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  List<Movie> get moodMovies => List.unmodifiable(_moodMovies);
  bool get isLoadingMoodMovies => _isLoadingMoodMovies;

  int get yearStart => _yearStart;
  int get yearEnd => _yearEnd;
  int get minVotes => _minVotes;
  double get minRating => _minRating;
  double get maxRating => _maxRating;
  bool get useRatingFilter => _useRatingFilter;

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _excludeAdult = prefs.getBool('excludeAdult') ?? _excludeAdult;
    _languageCode = prefs.getString('languageCode') ?? _languageCode;
    _themeMode = ThemeMode.values[prefs.getInt('themeMode') ?? _themeMode.index];

    // Saneamiento contra listas permitidas para evitar errores en Dropdowns
    if (!allowedLanguages.contains(_languageCode)) {
      _languageCode = 'es-ES';
    }

    _yearStart = prefs.getInt('yearStart') ?? _yearStart;
    _yearEnd = prefs.getInt('yearEnd') ?? _yearEnd;

    // Corrección del año final para que no exceda el año actual
    final currentYear = DateTime.now().year;
    if (_yearEnd > currentYear) {
      _yearEnd = currentYear;
    }

    _minVotes = prefs.getInt('minVotes') ?? _minVotes;

    // Cargar configuración de rating
    _minRating = prefs.getDouble('minRating') ?? _minRating;
    _maxRating = prefs.getDouble('maxRating') ?? _maxRating;
    _useRatingFilter = prefs.getBool('useRatingFilter') ?? _useRatingFilter;
    _hasShownWelcomeRecommendation = prefs.getBool('hasShownWelcomeRecommendation') ?? false;

    _lastSelectedGenreKey = prefs.getString('lastSelectedGenreKey');
    final lastMovieStr = prefs.getString('lastMovie');
    if (lastMovieStr != null) {
      try {
        _lastMovie = Movie.decodeList('[$lastMovieStr]').first;
      } catch (_) {}
    }

    // Cargar favoritas desde SharedPreferences (migración)
    final favsStr = prefs.getString('favorites');
    if (favsStr != null) {
      try {
        final oldFavorites = Movie.decodeList(favsStr);
        // Migrar a base de datos
        for (final movie in oldFavorites) {
          await _databaseService.insertFavoriteMovie(movie);
        }
        // Limpiar SharedPreferences después de migrar
        await prefs.remove('favorites');
      } catch (_) {}
    }

    final watchedStr = prefs.getString('watched');
    if (watchedStr != null) {
      try {
        _watched
          ..clear()
          ..addAll(WatchedMovie.decodeList(watchedStr));
      } catch (_) {}
    }

    final historyStr = prefs.getString('history');
    if (historyStr != null) {
      try {
        _history
          ..clear()
          ..addAll(Movie.decodeList(historyStr));
      } catch (_) {}
    }

    // Cargar perfil de usuario y conversaciones recientes
    await _loadUserProfile();
    await _loadRecentConversations();
    await _loadUserPreferences();
    await _loadFavoritesFromDB();
    await _loadWatchedFromDB();

    notifyListeners();
  }

  Future<void> setExcludeAdult(bool value) async {
    _excludeAdult = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('excludeAdult', value);
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    _languageCode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', value);
    notifyListeners();
  }


  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
    notifyListeners();
  }

  Future<void> setYearRange(int start, int end) async {
    final currentYear = DateTime.now().year;
    
    // Asegurar que no se exceda el año actual
    if (end > currentYear) {
      end = currentYear;
    }
    
    _yearStart = start;
    _yearEnd = end;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('yearStart', start);
    await prefs.setInt('yearEnd', end);
    notifyListeners();
  }

  Future<void> setMinVotes(int value) async {
    _minVotes = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('minVotes', value);
    notifyListeners();
  }

  // Nuevos métodos para rating
  Future<void> setRatingRange(double min, double max) async {
    _minRating = min;
    _maxRating = max;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('minRating', min);
    await prefs.setDouble('maxRating', max);
    notifyListeners();
  }

  Future<void> setUseRatingFilter(bool value) async {
    _useRatingFilter = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useRatingFilter', value);
    notifyListeners();
  }

  Future<void> setLastGenreKey(String? key) async {
    _lastSelectedGenreKey = key;
    final prefs = await SharedPreferences.getInstance();
    if (key == null) {
      await prefs.remove('lastSelectedGenreKey');
    } else {
      await prefs.setString('lastSelectedGenreKey', key);
    }
    notifyListeners();
  }

  Future<void> setLastMovie(Movie? movie) async {
    _lastMovie = movie;
    final prefs = await SharedPreferences.getInstance();
    if (movie == null) {
      await prefs.remove('lastMovie');
    } else {
      await prefs.setString('lastMovie', Movie.encodeList([movie]));
    }
    notifyListeners();
  }

  Future<void> toggleFavorite(Movie movie) async {
    final index = _favorites.indexWhere((m) => m.id == movie.id);
    if (index >= 0) {
      _favorites.removeAt(index);
      await _databaseService.removeFavoriteMovie(movie.id);
    } else {
      // Si la película está en "Ya vistas", quitarla de ahí primero
      if (isWatched(movie.id)) {
        await removeFromWatched(movie.id);
      }
      _favorites.insert(0, movie);
      await _databaseService.insertFavoriteMovie(movie);
    }
    // Ya no guardamos en SharedPreferences, solo en DB
    notifyListeners();
  }

  bool isFavorite(int movieId) => _favorites.any((m) => m.id == movieId);

  Future<void> addToWatched(Movie movie, double userRating) async {
    final existingIndex = _watched.indexWhere((wm) => wm.movie.id == movie.id);
    if (existingIndex >= 0) {
      _watched.removeAt(existingIndex);
    }
    
    // Si la película está en "Ver después", quitarla de ahí primero
    if (isFavorite(movie.id)) {
      await _databaseService.removeFavoriteMovie(movie.id);
      _favorites.removeWhere((m) => m.id == movie.id);
    }
    
    final watchedMovie = WatchedMovie(
      movie: movie,
      userRating: userRating,
      watchedAt: DateTime.now(),
    );
    
    _watched.insert(0, watchedMovie);
    
    // Guardar en base de datos
    await _databaseService.insertWatchedMovie(watchedMovie);
    
    // También guardar en SharedPreferences para compatibilidad
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('watched', WatchedMovie.encodeList(_watched));
    notifyListeners();
  }

  bool isWatched(int movieId) => _watched.any((wm) => wm.movie.id == movieId);

  WatchedMovie? getWatchedMovie(int movieId) {
    try {
      return _watched.firstWhere((wm) => wm.movie.id == movieId);
    } catch (_) {
      return null;
    }
  }

  Future<void> removeFromWatched(int movieId) async {
    _watched.removeWhere((wm) => wm.movie.id == movieId);
    
    // Remover de base de datos
    await _databaseService.removeWatchedMovie(movieId);
    
    // También actualizar SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('watched', WatchedMovie.encodeList(_watched));
    notifyListeners();
  }

  Future<void> updateWatchedRating(int movieId, double newRating) async {
    final index = _watched.indexWhere((wm) => wm.movie.id == movieId);
    if (index >= 0) {
      _watched[index] = _watched[index].copyWith(userRating: newRating);
      
      // Actualizar en base de datos
      await _databaseService.updateWatchedMovieRating(movieId, newRating);
      
      // También actualizar SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('watched', WatchedMovie.encodeList(_watched));
      notifyListeners();
    }
  }

  Future<void> addToHistory(Movie movie) async {
    final existingIndex = _history.indexWhere((m) => m.id == movie.id);
    if (existingIndex >= 0) {
      _history.removeAt(existingIndex);
    }
    _history.insert(0, movie);
    if (_history.length > 10) {
      _history.removeRange(10, _history.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('history', Movie.encodeList(_history));
    notifyListeners();
  }
// integracion ultima del chat
  UserProfile? get userProfile => _userProfile;
  List<Conversation> get recentConversations => List.unmodifiable(_recentConversations);
  bool get isFirstTime => _isFirstTime;
  bool get hasShownWelcomeRecommendation => _hasShownWelcomeRecommendation;
  UserPreferences? get userPreferences => _userPreferences;
  DatabaseService get databaseService => _databaseService;

  void addChatMessage(ChatMessage message) {
    _chatMessages.add(message);
    notifyListeners();
  }

  void setLoadingMoodMovies(bool loading) {
    _isLoadingMoodMovies = loading;
    notifyListeners();
  }

  void setMoodMovies(List<Movie> movies) {
    print('setMoodMovies llamado con ${movies.length} películas');
    print('Películas recibidas: ${movies.map((m) => m.title).toList()}');
    _moodMovies = movies;
    print('_moodMovies actualizado: ${_moodMovies.length} películas');
    notifyListeners();
    print('notifyListeners() llamado');
  }


  Future<void> _loadUserProfile() async {
    _userProfile = await _databaseService.getUserProfile();
    _isFirstTime = _userProfile == null;
    print('Perfil cargado: $_userProfile, isFirstTime: $_isFirstTime'); // Debug
  }

  Future<void> _loadRecentConversations() async {
    _recentConversations = await _databaseService.getRecentConversations();
  }

  Future<void> _loadUserPreferences() async {
    _userPreferences = await _databaseService.getUserPreferences();
  }

  Future<void> _loadFavoritesFromDB() async {
    final dbFavorites = await _databaseService.getFavoriteMovies();
    _favorites
      ..clear()
      ..addAll(dbFavorites);
  }

  Future<void> _loadWatchedFromDB() async {
    final dbWatched = await _databaseService.getWatchedMovies();
    _watched
      ..clear()
      ..addAll(dbWatched);
  }

  Future<void> createUserProfile(String name) async {
    final profile = UserProfile(
      name: name,
      createdAt: DateTime.now(),
      lastActive: DateTime.now(),
    );

    final id = await _databaseService.insertUserProfile(profile);
    _userProfile = UserProfile(
      id: id,
      name: name,
      createdAt: profile.createdAt,
      lastActive: profile.lastActive,
    );
    _isFirstTime = false;
    notifyListeners();
  }

  Future<void> updateLastActive() async {
    if (_userProfile != null) {
      final updatedProfile = UserProfile(
        id: _userProfile!.id,
        name: _userProfile!.name,
        createdAt: _userProfile!.createdAt,
        lastActive: DateTime.now(),
      );
      await _databaseService.updateUserProfile(updatedProfile);
      _userProfile = updatedProfile;
    }
  }

  Future<void> saveConversation(String userMessage, String aiResponse, List<String> recommendedMovies) async {
    final conversation = Conversation(
      userMessage: userMessage,
      aiResponse: aiResponse,
      timestamp: DateTime.now(),
      recommendedMovies: recommendedMovies,
    );

    await _databaseService.insertConversation(conversation);
    await _loadRecentConversations();
    notifyListeners();
  }

  Future<void> markWelcomeRecommendationShown() async {
    _hasShownWelcomeRecommendation = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasShownWelcomeRecommendation', true);
    notifyListeners();
  }

}