import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/movie.dart';
import '../models/watched_movie.dart';

class ShareService {
  // Generar un enlace único para compartir una lista
  static String generateListShareUrl({
    required String listType, // 'favorites' o 'watched'
    required List<dynamic> items, // List<Movie> o List<WatchedMovie>
    required String userName,
  }) {
    // Crear un objeto con la información de la lista
    final shareData = {
      'type': listType,
      'userName': userName,
      'items': items.map((item) {
        if (item is Movie) {
          return {
            'id': item.id,
            'title': item.title,
            'posterUrl': item.posterUrl,
            'releaseYear': item.releaseYear,
            'voteAverage': item.voteAverage,
            'overview': item.overview,
          };
        } else if (item is WatchedMovie) {
          return {
            'id': item.movie.id,
            'title': item.movie.title,
            'posterUrl': item.movie.posterUrl,
            'releaseYear': item.movie.releaseYear,
            'voteAverage': item.movie.voteAverage,
            'overview': item.movie.overview,
            'userRating': item.userRating,
            'watchedAt': item.watchedAt.toIso8601String(),
          };
        }
        return null;
      }).where((item) => item != null).toList(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    // Codificar los datos en base64 para el URL
    final jsonString = jsonEncode(shareData);
    final base64Data = base64Encode(utf8.encode(jsonString));
    
    // Crear un URL personalizado (en una app real, esto sería un servidor)
    return 'randompeli://shared-list?data=$base64Data';
  }

  // Compartir una lista de favoritos
  static Future<bool> shareFavoritesList({
    required List<Movie> movies,
    required String userName,
  }) async {
    try {
      if (movies.isEmpty) {
        throw Exception('No hay películas para compartir');
      }

      final shareUrl = generateListShareUrl(
        listType: 'favorites',
        items: movies,
        userName: userName,
      );

      final shareText = '''
🎬 Lista de películas de $userName

${movies.map((movie) => '• ${movie.title} (${movie.releaseYear ?? 'N/A'})').join('\n')}

Ver lista completa: $shareUrl

Compartido desde RandomPeli 🍿
''';

      await Share.share(
        shareText,
        subject: 'Lista de películas de $userName',
      );
      
      // Asumir éxito si no hay excepción
      return true;
    } catch (e) {
      print('Error compartiendo lista de favoritos: $e');
      return false;
    }
  }

  // Compartir una lista de películas vistas
  static Future<bool> shareWatchedList({
    required List<WatchedMovie> watchedMovies,
    required String userName,
  }) async {
    try {
      if (watchedMovies.isEmpty) {
        throw Exception('No hay películas para compartir');
      }

      final shareUrl = generateListShareUrl(
        listType: 'watched',
        items: watchedMovies,
        userName: userName,
      );

      final shareText = '''
🎬 Películas vistas por $userName

${watchedMovies.map((wm) => '• ${wm.movie.title} (${wm.movie.releaseYear ?? 'N/A'}) - ${wm.userRating.toStringAsFixed(1)} ⭐').join('\n')}

Ver lista completa: $shareUrl

Compartido desde RandomPeli 🍿
''';

      await Share.share(
        shareText,
        subject: 'Películas vistas por $userName',
      );
      
      // Asumir éxito si no hay excepción
      return true;
    } catch (e) {
      print('Error compartiendo lista de películas vistas: $e');
      return false;
    }
  }

  // Decodificar una lista compartida desde un URL
  static Map<String, dynamic>? decodeSharedList(String shareUrl) {
    try {
      final uri = Uri.parse(shareUrl);
      if (uri.scheme != 'randompeli' || uri.host != 'shared-list') {
        return null;
      }

      final dataParam = uri.queryParameters['data'];
      if (dataParam == null) return null;

      final decodedData = utf8.decode(base64Decode(dataParam));
      return jsonDecode(decodedData) as Map<String, dynamic>;
    } catch (e) {
      print('Error decoding shared list: $e');
      return null;
    }
  }

  // Convertir datos compartidos a objetos Movie
  static List<Movie> parseSharedMovies(List<dynamic> items) {
    return items.map((item) {
      final data = item as Map<String, dynamic>;
      return Movie(
        id: data['id'] as int,
        title: data['title'] as String,
        overview: data['overview'] as String?,
        posterUrl: data['posterUrl'] as String?,
        releaseYear: data['releaseYear'] as String?,
        voteAverage: (data['voteAverage'] as num?)?.toDouble() ?? 0.0,
        cast: [], // No incluimos cast en el share
      );
    }).toList();
  }

  // Convertir datos compartidos a objetos WatchedMovie
  static List<WatchedMovie> parseSharedWatchedMovies(List<dynamic> items) {
    return items.map((item) {
      final data = item as Map<String, dynamic>;
      final movie = Movie(
        id: data['id'] as int,
        title: data['title'] as String,
        overview: data['overview'] as String?,
        posterUrl: data['posterUrl'] as String?,
        releaseYear: data['releaseYear'] as String?,
        voteAverage: (data['voteAverage'] as num?)?.toDouble() ?? 0.0,
        cast: [],
      );
      
      return WatchedMovie(
        movie: movie,
        userRating: (data['userRating'] as num?)?.toDouble() ?? 0.0,
        watchedAt: data['watchedAt'] != null 
            ? DateTime.parse(data['watchedAt'] as String)
            : DateTime.now(),
      );
    }).toList();
  }

  // Abrir URL compartida (para cuando alguien recibe un enlace)
  static Future<bool> openSharedUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      return false;
    } catch (e) {
      print('Error opening shared URL: $e');
      return false;
    }
  }

  // Método alternativo para compartir que funciona mejor en emuladores
  static Future<bool> shareFavoritesListSimple({
    required List<Movie> movies,
    required String userName,
  }) async {
    try {
      if (movies.isEmpty) {
        throw Exception('No hay películas para compartir');
      }

      final shareText = '''
🎬 Lista de películas de $userName

${movies.map((movie) => '• ${movie.title} (${movie.releaseYear ?? 'N/A'})').join('\n')}

Compartido desde RandomPeli 🍿
''';

      // En debug mode (emulador), ir directo al clipboard
      if (kDebugMode) {
        await Clipboard.setData(ClipboardData(text: shareText));
        return true;
      }

      // En release mode, intentar compartir con timeout corto
      await Future.any([
        Share.share(
          shareText,
          subject: 'Lista de películas de $userName',
        ),
        Future.delayed(const Duration(seconds: 2)), // Timeout de 2 segundos
      ]);
      
      return true;
    } catch (e) {
      print('Error compartiendo lista simple: $e');
      return false;
    }
  }

  // Método alternativo para compartir películas vistas
  static Future<bool> shareWatchedListSimple({
    required List<WatchedMovie> watchedMovies,
    required String userName,
  }) async {
    try {
      if (watchedMovies.isEmpty) {
        throw Exception('No hay películas para compartir');
      }

      final shareText = '''
🎬 Películas vistas por $userName

${watchedMovies.map((wm) => '• ${wm.movie.title} (${wm.movie.releaseYear ?? 'N/A'}) - ${wm.userRating.toStringAsFixed(1)} ⭐').join('\n')}

Compartido desde RandomPeli 🍿
''';

      // En debug mode (emulador), ir directo al clipboard
      if (kDebugMode) {
        await Clipboard.setData(ClipboardData(text: shareText));
        return true;
      }

      // En release mode, intentar compartir con timeout corto
      await Future.any([
        Share.share(
          shareText,
          subject: 'Películas vistas por $userName',
        ),
        Future.delayed(const Duration(seconds: 2)), // Timeout de 2 segundos
      ]);
      
      return true;
    } catch (e) {
      print('Error compartiendo lista simple: $e');
      return false;
    }
  }

  // Método de emergencia: copiar al clipboard
  static Future<bool> copyToClipboard({
    required List<Movie> movies,
    required String userName,
    String type = 'favoritas',
  }) async {
    try {
      final shareText = '''
🎬 Lista de películas $type de $userName

${movies.map((movie) => '• ${movie.title} (${movie.releaseYear ?? 'N/A'})').join('\n')}

Compartido desde RandomPeli 🍿
''';

      await Clipboard.setData(ClipboardData(text: shareText));
      return true;
    } catch (e) {
      print('Error copiando al clipboard: $e');
      return false;
    }
  }

  // Método de emergencia: copiar películas vistas al clipboard
  static Future<bool> copyWatchedToClipboard({
    required List<WatchedMovie> watchedMovies,
    required String userName,
  }) async {
    try {
      final shareText = '''
🎬 Películas vistas por $userName

${watchedMovies.map((wm) => '• ${wm.movie.title} (${wm.movie.releaseYear ?? 'N/A'}) - ${wm.userRating.toStringAsFixed(1)} ⭐').join('\n')}

Compartido desde RandomPeli 🍿
''';

      await Clipboard.setData(ClipboardData(text: shareText));
      return true;
    } catch (e) {
      print('Error copiando al clipboard: $e');
      return false;
    }
  }
}
