import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

import '../models/movie.dart';
import '../models/watched_movie.dart';

class TmdbService {
  final String apiKey;
  final String languageCode; // e.g., es-ES
  final bool excludeAdult;
  final int? yearStart;
  final int? yearEnd;
  final int? minVotes;
  final double? minRating; // Nueva: puntuación mínima
  final double? maxRating; // Nueva: puntuación máxima

  static const String _baseUrl = 'https://api.themoviedb.org/3';

  TmdbService({
    String? apiKey,
    required this.languageCode,
    required this.excludeAdult,
    this.yearStart,
    this.yearEnd,
    this.minVotes,
    this.minRating,
    this.maxRating,
  }) : apiKey = apiKey ?? ApiConfig.tmdbApiKey;

  Map<String, String> get _defaultParams => {
        'api_key': apiKey,
        'language': languageCode,
        'include_adult': excludeAdult ? 'false' : 'true',
      };

  // Cliente HTTP con configuración mejorada
  http.Client get _client => http.Client();

  // Método para hacer requests con reintentos
  Future<http.Response> _makeRequest(Uri uri, {int maxRetries = 3}) async {
    final client = _client;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final response = await client.get(uri).timeout(
          const Duration(seconds: 10), // Timeout de 10 segundos
        );
        if (response.statusCode == 200) {
          return response;
        }
        if (attempt == maxRetries - 1) {
          throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
        }
      } catch (e) {
        if (attempt == maxRetries - 1) rethrow;
        // Esperar antes del siguiente intento
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    throw Exception('Max retries exceeded');
  }

  Future<Movie?> fetchRandomMovieByGenres(List<int> genreIds) async {
    if (genreIds.isEmpty) return null;

    final int randomPage = Random().nextInt(20) + 1; // Aumentado de 10 a 20 páginas

    final params = {
      ..._defaultParams,
      'with_genres': genreIds.join(','),
      'page': randomPage.toString(),
      'sort_by': 'popularity.desc',
      'vote_count.gte': (minVotes ?? 20).toString(),
    };

    // Filtros de fecha corregidos
    if (yearStart != null && yearStart! > 1900) {
      params['primary_release_date.gte'] = '${yearStart!}-01-01';
    }
    
    final currentYear = DateTime.now().year;
    final safeYearEnd = (yearEnd != null && yearEnd! <= currentYear) ? yearEnd! : currentYear;
    params['primary_release_date.lte'] = '${safeYearEnd}-12-31';

    // Filtros de puntuación
    if (minRating != null) {
      params['vote_average.gte'] = minRating!.toString();
    }
    if (maxRating != null) {
      params['vote_average.lte'] = maxRating!.toString();
    }

    final uri = Uri.parse('$_baseUrl/discover/movie').replace(queryParameters: params);

    try {
      final res = await _makeRequest(uri);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (json['results'] as List<dynamic>? ?? []);
      
      if (results.isEmpty) return null;
      
      final movieJson = results[Random().nextInt(results.length)] as Map<String, dynamic>;
      var movie = Movie.fromTmdbJson(movieJson);
      
      // Obtener información del cast
      final cast = await fetchMovieCast(movie.id);
      movie = movie.copyWith(cast: cast);
      
      return movie;
    } catch (e) {
      print('Error fetching random movie: $e');
      return null;
    }
  }

  // Nuevo método para obtener el cast de una película
  Future<List<String>> fetchMovieCast(int movieId) async {
    final uri = Uri.parse('$_baseUrl/movie/$movieId/credits').replace(
      queryParameters: {
        'api_key': apiKey,
        'language': languageCode,
      },
    );

    try {
      final res = await _makeRequest(uri);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final cast = (json['cast'] as List<dynamic>? ?? []);
      
      // Tomar solo los primeros 5 actores principales
      return cast
          .take(5)
          .map((actor) => (actor as Map<String, dynamic>)['name'] as String)
          .toList();
    } catch (e) {
      print('Error fetching cast: $e');
      return [];
    }
  }

  // Método para obtener detalles de una película por ID
  Future<Movie?> getMovieDetails(int movieId) async {
    final uri = Uri.parse('$_baseUrl/movie/$movieId').replace(
      queryParameters: {
        'api_key': apiKey,
        'language': languageCode,
      },
    );

    try {
      final res = await _makeRequest(uri);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      
      var movie = Movie.fromTmdbJson(json);
      
      // Obtener información del cast
      final cast = await fetchMovieCast(movie.id);
      movie = movie.copyWith(cast: cast);
      
      return movie;
    } catch (e) {
      print('Error fetching movie details: $e');
      return null;
    }
  }

  // Método alias para compatibilidad
  Future<Movie?> fetchMovieDetails(int movieId) async {
    return await getMovieDetails(movieId);
  }

  Future<List<Movie>> fetchNowPlaying({int page = 1}) async {
    final uri = Uri.parse('$_baseUrl/movie/now_playing').replace(queryParameters: {
      ..._defaultParams,
      'page': page.toString(),
    });
    
    try {
      final res = await _makeRequest(uri);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (json['results'] as List<dynamic>? ?? []);
      return results.map((e) => Movie.fromTmdbJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error fetching now playing: $e');
      return [];
    }
  }

  Future<List<Movie>> fetchTrending({int page = 1}) async {
    final uri = Uri.parse('$_baseUrl/trending/movie/week').replace(queryParameters: {
      ..._defaultParams,
      'page': page.toString(),
    });
    
    try {
      final res = await _makeRequest(uri);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (json['results'] as List<dynamic>? ?? []);
      return results.map((e) => Movie.fromTmdbJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error fetching trending: $e');
      return [];
    }
  }

  Future<List<Movie>> fetchTopRated({int page = 1}) async {
    final uri = Uri.parse('$_baseUrl/movie/top_rated').replace(queryParameters: {
      ..._defaultParams,
      'page': page.toString(),
    });
    
    try {
      final res = await _makeRequest(uri);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (json['results'] as List<dynamic>? ?? []);
      return results.map((e) => Movie.fromTmdbJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error fetching top rated: $e');
      return [];
    }
  }

  // Nuevo método para películas más votadas de la semana
  Future<List<Movie>> fetchTrendingWeek({int page = 1}) async {
    final uri = Uri.parse('$_baseUrl/trending/movie/week').replace(queryParameters: {
      ..._defaultParams,
      'page': page.toString(),
    });
    
    try {
      final res = await _makeRequest(uri);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (json['results'] as List<dynamic>? ?? []);
      return results.map((e) => Movie.fromTmdbJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error fetching trending: $e');
      return [];
    }
  }

  Future<List<Movie>> fetchUpcoming({int page = 1}) async {
    final uri = Uri.parse('$_baseUrl/movie/upcoming').replace(queryParameters: {
      ..._defaultParams,
      'page': page.toString(),
    });
    
    try {
      final res = await _makeRequest(uri);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (json['results'] as List<dynamic>? ?? []);
      return results.map((e) => Movie.fromTmdbJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error fetching upcoming: $e');
      return [];
    }
  }

  Future<List<String>> fetchWatchProviders(int movieId) async {
    final uri = Uri.parse('$_baseUrl/movie/$movieId/watch/providers').replace(
      queryParameters: {
        'api_key': apiKey,
      },
    );
    
    try {
      final res = await _makeRequest(uri);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final providers = <String>[];
      final regionData = (data['results'] as Map<String, dynamic>?)?['ES'] as Map<String, dynamic>?;
      final flatrate = (regionData?['flatrate'] as List<dynamic>? ?? []);
      
      for (final p in flatrate) {
        final name = (p as Map<String, dynamic>)['provider_name'] as String?;
        if (name != null) providers.add(name);
      }
      return providers;
    } catch (e) {
      print('Error fetching providers: $e');
      return [];
    }
  }

  // Método para obtener próximos estrenos
  Future<List<Movie>> fetchUpcomingMovies({int page = 1, int limit = 20}) async {
    final uri = Uri.parse('$_baseUrl/movie/upcoming').replace(
      queryParameters: {
        ..._defaultParams,
        'page': page.toString(),
      },
    );
    
    try {
      final res = await _makeRequest(uri);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (json['results'] as List<dynamic>? ?? []);
      final movies = results.map((e) => Movie.fromTmdbJson(e as Map<String, dynamic>)).toList();
      
      // Mezclar y limitar
      movies.shuffle();
      return movies.take(limit).toList();
    } catch (e) {
      print('Error fetching upcoming movies: $e');
      return [];
    }
  }

  // Método para obtener películas con alta calificación (9-10 estrellas)
  Future<List<Movie>> fetchTopRatedMovies({int page = 1, int limit = 20}) async {
    final uri = Uri.parse('$_baseUrl/movie/top_rated').replace(
      queryParameters: {
        ..._defaultParams,
        'page': page.toString(),
        'vote_average.gte': '9.0', // Solo películas con 9+ estrellas
        'vote_count.gte': '100', // Mínimo 100 votos para asegurar calidad
      },
    );
    
    try {
      final res = await _makeRequest(uri);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (json['results'] as List<dynamic>? ?? []);
      final movies = results.map((e) => Movie.fromTmdbJson(e as Map<String, dynamic>)).toList();
      
      // Filtrar solo las que tienen 9.0 o más
      final topMovies = movies.where((movie) => movie.voteAverage >= 9.0).toList();
      
      // Mezclar y limitar
      topMovies.shuffle();
      return topMovies.take(limit).toList();
    } catch (e) {
      print('Error fetching top rated movies: $e');
      return [];
    }
  }

  // Método para obtener una película recomendada basada en las calificaciones del usuario
  Future<Movie?> fetchRecommendedMovie(List<WatchedMovie> userWatchedMovies) async {
    if (userWatchedMovies.isEmpty) {
      // Si no hay películas vistas, devolver una película popular aleatoria
      final popularMovies = await fetchNowPlaying();
      if (popularMovies.isNotEmpty) {
        return popularMovies[Random().nextInt(popularMovies.length)];
      }
      return null;
    }

    // Calcular el promedio de calificación del usuario
    final avgRating = userWatchedMovies.map((w) => w.userRating).reduce((a, b) => a + b) / userWatchedMovies.length;
    
    // Si el usuario califica alto (8+), buscar películas con alta calificación
    if (avgRating >= 8.0) {
      final topMovies = await fetchTopRatedMovies(limit: 50);
      if (topMovies.isNotEmpty) {
        return topMovies[Random().nextInt(topMovies.length)];
      }
    }
    
    // Si el usuario califica medio (6-8), buscar películas populares
    if (avgRating >= 6.0) {
      final popularMovies = await fetchNowPlaying();
      if (popularMovies.isNotEmpty) {
        return popularMovies[Random().nextInt(popularMovies.length)];
      }
    }
    
    // Si el usuario califica bajo (<6), buscar películas de diferentes géneros
    final trendingMovies = await fetchTrendingWeek();
    if (trendingMovies.isNotEmpty) {
      return trendingMovies[Random().nextInt(trendingMovies.length)];
    }
    
    return null;
  }

  // Método para buscar películas por título
  Future<List<Movie>> searchMovies(String query) async {
    final uri = Uri.parse('$_baseUrl/search/movie').replace(queryParameters: {
      ..._defaultParams,
      'query': query,
      'page': '1',
    });
    
    try {
      final res = await _makeRequest(uri);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (json['results'] as List<dynamic>? ?? []);
      return results.map((e) => Movie.fromTmdbJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error searching movies: $e');
      return [];
    }
  }

  // Método para buscar personas (actores/directores)
  Future<List<Map<String, dynamic>>> searchPeople(String query) async {
    final uri = Uri.parse('$_baseUrl/search/person').replace(queryParameters: {
      ..._defaultParams,
      'query': query,
      'page': '1',
    });
    
    try {
      final res = await _makeRequest(uri);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (json['results'] as List<dynamic>? ?? []);
      return results.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error searching people: $e');
      return [];
    }
  }

  // Método para obtener películas de una persona específica
  Future<List<Movie>> getPersonMovies(int personId) async {
    final uri = Uri.parse('$_baseUrl/person/$personId/movie_credits').replace(queryParameters: {
      'api_key': apiKey,
      'language': languageCode,
    });
    
    try {
      final res = await _makeRequest(uri);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final cast = (json['cast'] as List<dynamic>? ?? []);
      final crew = (json['crew'] as List<dynamic>? ?? []);
      
      // Combinar cast y crew, eliminar duplicados
      final allMovies = <Map<String, dynamic>>[];
      final seenIds = <int>{};
      
      for (final movie in [...cast, ...crew]) {
        final movieData = movie as Map<String, dynamic>;
        final id = movieData['id'] as int;
        if (!seenIds.contains(id)) {
          allMovies.add(movieData);
          seenIds.add(id);
        }
      }
      
      // Ordenar por popularidad y tomar los primeros 20
      allMovies.sort((a, b) {
        final popularityA = (a['popularity'] as num?)?.toDouble() ?? 0.0;
        final popularityB = (b['popularity'] as num?)?.toDouble() ?? 0.0;
        return popularityB.compareTo(popularityA);
      });
      
      return allMovies
          .take(20)
          .map((e) => Movie.fromTmdbJson(e))
          .toList();
    } catch (e) {
      print('Error getting person movies: $e');
      return [];
    }
  }

  // Método para obtener películas de actor separadas en 3 grupos
  Future<Map<String, List<Movie>>> getActorMoviesSeparated(int personId) async {
    final uri = Uri.parse('$_baseUrl/person/$personId/movie_credits').replace(queryParameters: {
      'api_key': apiKey,
      'language': languageCode,
    });
    
    try {
      final res = await _makeRequest(uri);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final cast = (json['cast'] as List<dynamic>? ?? []);
      
      // Filtrar solo películas donde aparece (no solo voces)
      final actingMovies = <Map<String, dynamic>>[];
      
      for (final movie in cast) {
        final movieData = movie as Map<String, dynamic>;
        final character = movieData['character'] as String? ?? '';
        
        // Omitir películas donde solo hizo voces
        if (!character.toLowerCase().contains('voice') && 
            !character.toLowerCase().contains('voz') &&
            character.isNotEmpty) {
          actingMovies.add(movieData);
        }
      }
      
      // Ordenar por popularidad
      actingMovies.sort((a, b) {
        final popularityA = (a['popularity'] as num?)?.toDouble() ?? 0.0;
        final popularityB = (b['popularity'] as num?)?.toDouble() ?? 0.0;
        return popularityB.compareTo(popularityA);
      });
      
      // Separar en tres grupos: principales (primeros 8), secundarias (siguientes 8), y otras (resto)
      final mainMovies = actingMovies.take(8).map((e) => Movie.fromTmdbJson(e)).toList();
      final secondaryMovies = actingMovies.skip(8).take(8).map((e) => Movie.fromTmdbJson(e)).toList();
      final otherMovies = actingMovies.skip(16).map((e) => Movie.fromTmdbJson(e)).toList();
      
      return {
        'main': mainMovies,
        'secondary': secondaryMovies,
        'other': otherMovies,
      };
    } catch (e) {
      print('Error getting actor movies separated: $e');
      return {'main': <Movie>[], 'secondary': <Movie>[], 'other': <Movie>[]};
    }
  }

  // Método para obtener el reparto de una película
  Future<List<String>> getMovieCast(int movieId) async {
    final uri = Uri.parse('$_baseUrl/movie/$movieId/credits').replace(queryParameters: {
      'api_key': apiKey,
      'language': languageCode,
    });
    
    try {
      final res = await _makeRequest(uri);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final cast = (json['cast'] as List<dynamic>? ?? []);
      
      // Obtener solo los primeros 5 actores principales
      final castNames = <String>[];
      for (final actor in cast.take(5)) {
        final name = (actor as Map<String, dynamic>)['name'] as String?;
        if (name != null) castNames.add(name);
      }
      
      return castNames;
    } catch (e) {
      print('Error getting movie cast: $e');
      return [];
    }
  }

  static const Map<String, int> genres = {
    'Acción': 28,
    'Aventura': 12,
    'Animación': 16,
    'Comedia': 35,
    'Crimen': 80,
    'Documental': 99,
    'Drama': 18,
    'Familia': 10751,
    'Fantasía': 14,
    'Historia': 36,
    'Terror': 27,
    'Música': 10402,
    'Misterio': 9648,
    'Romance': 10749,
    'Ciencia Ficción': 878,
    'Película de TV': 10770,
    'Suspenso': 53,
    'Bélica': 10752,
    'Western': 37,
  };
}