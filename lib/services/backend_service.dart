import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'package:crypto/crypto.dart'; // Removido
import '../models/movie.dart';
// import '../config/api_config.dart'; // Removido

// Modelo para proveedores de streaming
class StreamingProvider {
  final String name;
  final String logoUrl;
  final String type; // 'flatrate', 'rent', 'buy'
  final int providerId;
  final int displayPriority;

  StreamingProvider({
    required this.name,
    required this.logoUrl,
    required this.type,
    required this.providerId,
    required this.displayPriority,
  });

  factory StreamingProvider.fromJson(Map<String, dynamic> json) {
    return StreamingProvider(
      name: json['name'] as String,
      logoUrl: json['logo'] as String? ?? '',
      type: json['type'] as String,
      providerId: json['providerId'] as int,
      displayPriority: json['displayPriority'] as int,
    );
  }

  String get typeDisplayName {
    switch (type) {
      case 'flatrate':
        return 'Streaming';
      case 'rent':
        return 'Alquiler';
      case 'buy':
        return 'Compra';
      default:
        return type;
    }
  }
}

class ProvidersResponse {
  final List<StreamingProvider> providers;
  final String region;
  final List<String> availableRegions;
  final String? message;

  ProvidersResponse({
    required this.providers,
    required this.region,
    required this.availableRegions,
    this.message,
  });

  factory ProvidersResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final providers = (data['providers'] as List<dynamic>? ?? [])
        .map((p) => StreamingProvider.fromJson(p as Map<String, dynamic>))
        .toList();

    return ProvidersResponse(
      providers: providers,
      region: data['region'] as String? ?? 'ES',
      availableRegions: List<String>.from(data['availableRegions'] ?? []),
      message: data['message'] as String?,
    );
  }
}

class BackendService {
  static const String _baseUrl = 'https://web-production-e93e.up.railway.app';
  static const String _appSignature = 'randomovie_2024_secure_signature';
  
  // Headers comunes
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-app-signature': _appSignature,
  };

  // Métodos específicos para endpoints del backend
  static Future<List<Movie>> fetchNowPlaying({int page = 1}) async {
    try {
      print('🔍 BackendService: Llamando a $_baseUrl/api/movies/now-playing');
      final response = await http.get(
        Uri.parse('$_baseUrl/api/movies/now-playing?page=$page'),
        headers: _headers,
      );

      print('🔍 BackendService: Status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔍 BackendService: Respuesta del backend: ${data['success']}');
        print('🔍 BackendService: Cantidad de películas: ${(data['data'] as List).length}');
        if (data['success'] == true) {
          final results = data['data'] as List<dynamic>;
          print('🔍 BackendService: Procesando ${results.length} películas');
          return results.map((json) => Movie.fromTmdbJson(json)).toList();
        }
      }
      throw Exception('Error en now playing: ${response.statusCode}');
    } catch (e) {
      print('Error en fetchNowPlaying: $e');
      rethrow;
    }
  }

  static Future<List<Movie>> fetchTrending({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/movies/trending?page=$page'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final results = data['data'] as List<dynamic>;
          return results.map((json) => Movie.fromTmdbJson(json)).toList();
        }
      }
      throw Exception('Error en trending: ${response.statusCode}');
    } catch (e) {
      print('Error en fetchTrending: $e');
      rethrow;
    }
  }

  static Future<List<Movie>> fetchUpcoming({int page = 1}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/movies/upcoming?page=$page'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final results = data['data'] as List<dynamic>;
          return results.map((json) => Movie.fromTmdbJson(json)).toList();
        }
      }
      throw Exception('Error en upcoming: ${response.statusCode}');
    } catch (e) {
      print('Error en fetchUpcoming: $e');
      rethrow;
    }
  }

  // Generar signature dinámico (opcional)
  static Future<String> _getDynamicSignature() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/signature'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['signature'] ?? _appSignature;
      }
    } catch (e) {
      print('Error obteniendo signature dinámico: $e');
    }
    
    return _appSignature; // Fallback
  }

  // Búsqueda de películas
  static Future<List<Movie>> searchMovies({
    required String query,
    String language = 'es-ES',
    int page = 1,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/movies/search'),
        headers: _headers,
        body: jsonEncode({
          'query': query,
          'language': language,
          'page': page,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final results = data['data']['results'] as List;
          return results.map((json) => Movie.fromJson(json)).toList();
        }
      }
      
      throw Exception('Error en búsqueda: ${response.statusCode}');
    } catch (e) {
      print('Error en búsqueda de películas: $e');
      return [];
    }
  }

  // Película aleatoria por género
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
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/movies/random'),
        headers: _headers,
        body: jsonEncode({
          'genres': genres,
          'language': language,
          'yearStart': yearStart,
          'yearEnd': yearEnd,
          'minVotes': minVotes,
          'minRating': minRating,
          'maxRating': maxRating,
          'excludeAdult': excludeAdult,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return Movie.fromJson(data['data']);
        }
      }
      
      throw Exception('Error en película aleatoria: ${response.statusCode}');
    } catch (e) {
      print('Error obteniendo película aleatoria: $e');
      return null;
    }
  }

  // Detalles de película
  static Future<Movie?> getMovieDetails({
    required int movieId,
    String language = 'es-ES',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/movies/$movieId?language=$language'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return Movie.fromTmdbJson(data['data']);
        }
      }
      
      throw Exception('Error en detalles: ${response.statusCode}');
    } catch (e) {
      print('Error obteniendo detalles de película: $e');
      return null;
    }
  }

  // Obtener reparto de película
  static Future<List<String>> getMovieCast({
    required int movieId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/movies/$movieId/cast'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final cast = <String>[];
          final results = data['data']['cast'] as List<dynamic>? ?? [];
          
          for (final actor in results.take(5)) { // Solo los primeros 5
            final name = (actor as Map<String, dynamic>)['name'] as String?;
            if (name != null) cast.add(name);
          }
          
          return cast;
        }
      }
      
      throw Exception('Error en cast: ${response.statusCode}');
    } catch (e) {
      print('Error obteniendo cast: $e');
      return [];
    }
  }

  // Proveedores de streaming
  static Future<List<String>> getWatchProviders({
    required int movieId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/movies/$movieId/providers'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final providers = <String>[];
          final results = data['data']['results'] as Map<String, dynamic>?;
          final regionData = results?['ES'] as Map<String, dynamic>?;
          final flatrate = regionData?['flatrate'] as List<dynamic>? ?? [];
          
          for (final provider in flatrate) {
            final name = (provider as Map<String, dynamic>)['provider_name'] as String?;
            if (name != null) providers.add(name);
          }
          
          return providers;
        }
      }
      
      throw Exception('Error en proveedores: ${response.statusCode}');
    } catch (e) {
      print('Error obteniendo proveedores: $e');
      return [];
    }
  }

  // Método de debug para verificar el flujo completo
  static Future<void> debugFullFlow() async {
    print('🔍 DEBUG: Iniciando verificación completa del flujo...');
    
    try {
      // 1. Verificar headers
      print('🔍 DEBUG: Headers configurados: $_headers');
      
      // 2. Verificar endpoint de salud
      print('🔍 DEBUG: Verificando salud del backend...');
      final healthResponse = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: _headers,
      );
      print('🔍 DEBUG: Health status: ${healthResponse.statusCode}');
      print('🔍 DEBUG: Health response: ${healthResponse.body}');
      
      // 3. Verificar endpoint de now-playing
      print('🔍 DEBUG: Verificando endpoint now-playing...');
      final nowPlayingResponse = await http.get(
        Uri.parse('$_baseUrl/api/movies/now-playing'),
        headers: _headers,
      );
      print('🔍 DEBUG: Now-playing status: ${nowPlayingResponse.statusCode}');
      print('🔍 DEBUG: Now-playing response: ${nowPlayingResponse.body.substring(0, 200)}...');
      
      // 4. Verificar endpoint de proveedores
      print('🔍 DEBUG: Verificando endpoint providers...');
      final providersResponse = await http.get(
        Uri.parse('$_baseUrl/api/movies/550/providers'),
        headers: _headers,
      );
      print('🔍 DEBUG: Providers status: ${providersResponse.statusCode}');
      print('🔍 DEBUG: Providers response: ${providersResponse.body.substring(0, 200)}...');
      
    } catch (e) {
      print('🔍 DEBUG: Error en verificación: $e');
    }
  }

  // Recomendaciones de IA
  static Future<List<String>> getRecommendations({
    String? userPreferences,
    List<Map<String, dynamic>> ratedMovies = const [],
    List<Map<String, dynamic>> watchedMovies = const [],
    String type = 'preferences', // 'preferences' o 'ratings'
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/recommendations'),
        headers: _headers,
        body: jsonEncode({
          'userPreferences': userPreferences,
          'ratedMovies': ratedMovies,
          'watchedMovies': watchedMovies,
          'type': type,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<String>.from(data['data']);
        }
      }
      
      throw Exception('Error en recomendaciones: ${response.statusCode}');
    } catch (e) {
      print('Error obteniendo recomendaciones: $e');
      return [];
    }
  }

  // Verificar salud del servidor
  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error verificando salud del servidor: $e');
      return false;
    }
  }

  // Búsqueda de película por título (para compatibilidad)
  static Future<Movie?> searchMovieByTitle(String title) async {
    final movies = await searchMovies(query: title);
    return movies.isNotEmpty ? movies.first : null;
  }

  // Obtener películas por género (para compatibilidad)
  static Future<List<Movie>> getMoviesByGenre({
    required int genreId,
    String language = 'es-ES',
    int page = 1,
  }) async {
    return await searchMovies(query: '', language: language, page: page);
  }

  // Método mejorado para obtener proveedores detallados
  static Future<ProvidersResponse> getWatchProvidersDetailed({
    required int movieId,
    String region = 'ES',
  }) async {
    try {
      print('🔍 BackendService: Obteniendo proveedores para película $movieId');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/api/movies/$movieId/providers?region=$region'),
        headers: _headers,
      );

      print('🔍 BackendService: Status code providers: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔍 BackendService: Respuesta providers: ${data['success']}');
        
        if (data['success'] == true) {
          final providersResponse = ProvidersResponse.fromJson(data);
          print('🔍 BackendService: ${providersResponse.providers.length} proveedores encontrados');
          
          // Log detallado de proveedores
          for (final provider in providersResponse.providers) {
            print('📺 Provider: ${provider.name} (${provider.typeDisplayName})');
          }
          
          return providersResponse;
        }
      }
      
      print('⚠️ BackendService: Response body: ${response.body}');
      throw Exception('Error en proveedores: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en getWatchProvidersDetailed: $e');
      rethrow;
    }
  }

  // Método simple mantenido para compatibilidad
  static Future<List<String>> getWatchProviders({
    required int movieId,
  }) async {
    try {
      final providersResponse = await getWatchProvidersDetailed(movieId: movieId);
      
      // Retornar solo nombres de proveedores de streaming (flatrate)
      return providersResponse.providers
          .where((p) => p.type == 'flatrate')
          .map((p) => p.name)
          .toList();
    } catch (e) {
      print('❌ Error en getWatchProviders: $e');
      return [];
    }
  }

  // Método para debug
  static Future<Map<String, dynamic>> debugProviders(int movieId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/debug/providers/$movieId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔍 DEBUG Providers: ${jsonEncode(data)}');
        return data;
      }
      
      throw Exception('Error en debug: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en debugProviders: $e');
      return {};
    }
  }
}
