import '../models/movie.dart';
// import '../config/backend_config.dart'; // Removido
// import 'backend_service.dart'; // Removido
import 'hybrid_service.dart';

/// Servicio seguro que siempre usa el backend cuando está disponible
class SecureService {
  
  // Búsqueda de películas
  static Future<List<Movie>> searchMovies({
    required String query,
    String language = 'es-ES',
    int page = 1,
  }) async {
    print('🔒 SecureService: Buscando películas con backend seguro');
    return await HybridService.searchMovies(
      query: query,
      language: language,
      page: page,
    );
  }
  
  // Película aleatoria
  static Future<Movie?> getRandomMovie({
    required List<int> genres,
    String language = 'es-ES',
    int? yearStart,
    int? yearEnd,
    int minVotes = 50,
    double? minRating,
    double? maxRating,
    bool excludeAdult = true,
  }) async {
    print('🔒 SecureService: Obteniendo película aleatoria con backend seguro');
    return await HybridService.getRandomMovie(
      genres: genres,
      language: language,
      yearStart: yearStart,
      yearEnd: yearEnd,
      minVotes: minVotes,
      minRating: minRating,
      maxRating: maxRating,
      excludeAdult: excludeAdult,
    );
  }
  
  // Detalles de película
  static Future<Movie?> getMovieDetails({
    required int movieId,
    String language = 'es-ES',
  }) async {
    print('🔒 SecureService: Obteniendo detalles con backend seguro');
    return await HybridService.getMovieDetails(
      movieId: movieId,
      language: language,
    );
  }
  
  // Obtener reparto de película
  static Future<List<String>> getMovieCast({
    required int movieId,
  }) async {
    print('🔒 SecureService: Obteniendo reparto con backend seguro');
    return await HybridService.getMovieCast(movieId: movieId);
  }

  // Proveedores de streaming
  static Future<List<String>> getWatchProviders({
    required int movieId,
  }) async {
    print('🔒 SecureService: Obteniendo proveedores con backend seguro');
    return await HybridService.getWatchProviders(movieId: movieId);
  }
  
  // Recomendaciones de IA
  static Future<List<String>> getRecommendations({
    String? userPreferences,
    List<Map<String, dynamic>> ratedMovies = const [],
    List<Map<String, dynamic>> watchedMovies = const [],
    String type = 'preferences',
  }) async {
    print('🔒 SecureService: Obteniendo recomendaciones con backend seguro');
    return await HybridService.getRecommendations(
      userPreferences: userPreferences,
      ratedMovies: ratedMovies,
      watchedMovies: watchedMovies,
      type: type,
    );
  }
  
  // Búsqueda por título (compatibilidad)
  static Future<Movie?> searchMovieByTitle(String title) async {
    print('🔒 SecureService: Búsqueda por título con backend seguro');
    return await HybridService.searchMovieByTitle(title);
  }
  
  // Verificar salud del backend
  static Future<bool> checkBackendHealth() async {
    print('🔒 SecureService: Verificando salud del backend');
    return await HybridService.checkBackendHealth();
  }

  // Método de debug para verificar el flujo completo
  static Future<void> debugFullFlow() async {
    print('🔒 SecureService: Ejecutando debug completo del flujo');
    await HybridService.debugFullFlow();
  }
  
  // Métodos específicos para compatibilidad con TmdbService
  static Future<List<Movie>> fetchNowPlaying({int page = 1}) async {
    print('🔒 SecureService: Obteniendo películas en cartelera con backend seguro');
    return await HybridService.fetchNowPlaying(page: page);
  }
  
  static Future<List<Movie>> fetchUpcoming({int page = 1}) async {
    print('🔒 SecureService: Obteniendo próximos estrenos con backend seguro');
    return await HybridService.fetchUpcoming(page: page);
  }
  
  static Future<List<Movie>> fetchTrending({int page = 1}) async {
    print('🔒 SecureService: Obteniendo tendencias con backend seguro');
    return await HybridService.fetchTrending(page: page);
  }
}
