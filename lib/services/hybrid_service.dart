import '../models/movie.dart';
import '../config/backend_config.dart';
import 'backend_service.dart';
import 'tmdb_service.dart';
import 'groq_service.dart';

class HybridService {
  static TmdbService? _tmdbService;
  static GroqService? _groqService;
  
  // Inicializar servicios
  static void _initializeServices() {
    _tmdbService ??= TmdbService(
      languageCode: 'es-ES',
      excludeAdult: false,
    );
    _groqService ??= GroqService();
  }
  
  // Búsqueda de películas
  static Future<List<Movie>> searchMovies({
    required String query,
    String language = 'es-ES',
    int page = 1,
  }) async {
    if (BackendConfig.isBackendEnabled) {
      try {
        final movies = await BackendService.searchMovies(
          query: query,
          language: language,
          page: page,
        );
        if (movies.isNotEmpty) return movies;
      } catch (e) {
        print('Backend falló, usando fallback: $e');
      }
    }

    // Fallback a API directa
    if (BackendConfig.useFallback) {
      _initializeServices();
      try {
        final movies = await _tmdbService!.searchMovies(query);
        return movies;
      } catch (e) {
        print('Error en fallback: $e');
      }
    }

    return [];
  }

  // Métodos específicos para endpoints del backend
  static Future<List<Movie>> fetchNowPlaying({int page = 1}) async {
    if (BackendConfig.isBackendEnabled) {
      try {
        final movies = await BackendService.fetchNowPlaying(page: page);
        if (movies.isNotEmpty) return movies;
      } catch (e) {
        print('Backend falló, usando fallback: $e');
      }
    }

    // Fallback a API directa
    if (BackendConfig.useFallback) {
      _initializeServices();
      try {
        final movies = await _tmdbService!.fetchNowPlaying(page: page);
        return movies;
      } catch (e) {
        print('Error en fallback: $e');
      }
    }

    return [];
  }

  static Future<List<Movie>> fetchTrending({int page = 1}) async {
    if (BackendConfig.isBackendEnabled) {
      try {
        final movies = await BackendService.fetchTrending(page: page);
        if (movies.isNotEmpty) return movies;
      } catch (e) {
        print('Backend falló, usando fallback: $e');
      }
    }

    // Fallback a API directa
    if (BackendConfig.useFallback) {
      _initializeServices();
      try {
        final movies = await _tmdbService!.fetchTrending(page: page);
        return movies;
      } catch (e) {
        print('Error en fallback: $e');
      }
    }

    return [];
  }

  static Future<List<Movie>> fetchUpcoming({int page = 1}) async {
    if (BackendConfig.isBackendEnabled) {
      try {
        final movies = await BackendService.fetchUpcoming(page: page);
        if (movies.isNotEmpty) return movies;
      } catch (e) {
        print('Backend falló, usando fallback: $e');
      }
    }

    // Fallback a API directa
    if (BackendConfig.useFallback) {
      _initializeServices();
      try {
        final movies = await _tmdbService!.fetchUpcoming(page: page);
        return movies;
      } catch (e) {
        print('Error en fallback: $e');
      }
    }

    return [];
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
    if (BackendConfig.isBackendEnabled) {
      try {
        final movie = await BackendService.getRandomMovie(
          genres: genres,
          language: language,
          yearStart: yearStart,
          yearEnd: yearEnd,
          minVotes: minVotes,
          minRating: minRating,
          maxRating: maxRating,
          excludeAdult: excludeAdult,
        );
        if (movie != null) return movie;
      } catch (e) {
        print('Backend falló, usando fallback: $e');
      }
    }
    
    // Fallback a API directa
    if (BackendConfig.useFallback) {
      _initializeServices();
      try {
        final movie = await _tmdbService!.fetchRandomMovieByGenres(genres);
        return movie;
      } catch (e) {
        print('Error en fallback: $e');
      }
    }
    
    return null;
  }
  
  // Detalles de película
  static Future<Movie?> getMovieDetails({
    required int movieId,
    String language = 'es-ES',
  }) async {
    if (BackendConfig.isBackendEnabled) {
      try {
        final movie = await BackendService.getMovieDetails(
          movieId: movieId,
          language: language,
        );
        if (movie != null) return movie;
      } catch (e) {
        print('Backend falló, usando fallback: $e');
      }
    }
    
    // Fallback a API directa
    if (BackendConfig.useFallback) {
      _initializeServices();
      try {
        final movie = await _tmdbService!.fetchMovieDetails(movieId);
        return movie;
      } catch (e) {
        print('Error en fallback: $e');
      }
    }
    
    return null;
  }
  
  // Obtener reparto de película
  static Future<List<String>> getMovieCast({
    required int movieId,
  }) async {
    if (BackendConfig.isBackendEnabled) {
      try {
        final cast = await BackendService.getMovieCast(movieId: movieId);
        if (cast.isNotEmpty) return cast;
      } catch (e) {
        print('Backend falló, usando fallback: $e');
      }
    }
    
    // Fallback a API directa
    if (BackendConfig.useFallback) {
      _initializeServices();
      try {
        final cast = await _tmdbService!.getMovieCast(movieId);
        return cast;
      } catch (e) {
        print('Error en fallback: $e');
      }
    }
    
    return [];
  }

  // Proveedores de streaming
  static Future<List<String>> getWatchProviders({
    required int movieId,
  }) async {
    if (BackendConfig.isBackendEnabled) {
      try {
        final providers = await BackendService.getWatchProviders(movieId: movieId);
        if (providers.isNotEmpty) return providers;
      } catch (e) {
        print('Backend falló, usando fallback: $e');
      }
    }
    
    // Fallback a API directa
    if (BackendConfig.useFallback) {
      _initializeServices();
      try {
        final providers = await _tmdbService!.fetchWatchProviders(movieId);
        return providers;
      } catch (e) {
        print('Error en fallback: $e');
      }
    }
    
    return [];
  }
  
  // Recomendaciones de IA
  static Future<List<String>> getRecommendations({
    String? userPreferences,
    List<Map<String, dynamic>> ratedMovies = const [],
    List<Map<String, dynamic>> watchedMovies = const [],
    String type = 'preferences',
  }) async {
    if (BackendConfig.isBackendEnabled) {
      try {
        final recommendations = await BackendService.getRecommendations(
          userPreferences: userPreferences,
          ratedMovies: ratedMovies,
          watchedMovies: watchedMovies,
          type: type,
        );
        if (recommendations.isNotEmpty) return recommendations;
      } catch (e) {
        print('Backend falló, usando fallback: $e');
      }
    }
    
    // Fallback a API directa
    if (BackendConfig.useFallback) {
      _initializeServices();
      try {
        if (type == 'preferences' && userPreferences != null) {
          final recommendations = await _groqService!.searchMoviesByPreferences(
            userPreferences,
            ratedMovies,
            watchedMovies,
          );
          return recommendations;
        } else {
          final recommendations = await _groqService!.searchMoviesByRatings(
            ratedMovies,
            watchedMovies,
          );
          return recommendations;
        }
      } catch (e) {
        print('Error en fallback: $e');
      }
    }
    
    return [];
  }
  
  // Búsqueda por título (compatibilidad)
  static Future<Movie?> searchMovieByTitle(String title) async {
    final movies = await searchMovies(query: title);
    return movies.isNotEmpty ? movies.first : null;
  }
  
  // Verificar salud del backend
  static Future<bool> checkBackendHealth() async {
    if (!BackendConfig.isBackendEnabled) return false;
    
    try {
      return await BackendService.checkHealth();
    } catch (e) {
      print('Error verificando salud del backend: $e');
      return false;
    }
  }

  // Método de debug para verificar el flujo completo
  static Future<void> debugFullFlow() async {
    print('🔍 HybridService: Ejecutando debug completo del flujo');
    await BackendService.debugFullFlow();
  }
}
