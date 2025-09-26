import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/mood_response.dart';

class GroqService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1';
  final String apiKey;

  GroqService({String? apiKey}) : apiKey = apiKey ?? ApiConfig.groqApiKey;

  Future<MoodResponse?> getMoodRecommendation(
      String mood,
      String? userName,
      String favoriteMovies,
      List<String> recentTopics,
      List<Map<String, String>> chatHistory,
      List<Map<String, dynamic>> ratedMovies,
      List<Map<String, dynamic>> watchedMovies
      ) async {
    try {
      final contextInfo = _buildUserContext(userName, favoriteMovies, recentTopics, ratedMovies, watchedMovies);

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
          'messages': [
            {
              "role": "system",
              "content": "... aquí tu prompt estricto ..."
            },
            ..._buildMessagesWithHistory(mood, contextInfo, chatHistory)
          ],
          "temperature": 0.2,   // baja creatividad
          "top_p": 0.8,         // restringe la diversidad de tokens
          "max_tokens": 1500     // límite de salida
        }),

      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        print('Respuesta de Groq: $content');

        // Intentar parsear como JSON primero
        try {
          final jsonData = jsonDecode(content);
          // Verificar si tiene la estructura esperada para recomendaciones
          if (jsonData is Map<String, dynamic> && jsonData.containsKey('peliculas')) {
            return MoodResponse.fromJson(jsonData);
          } else {
            // Si es JSON pero no tiene la estructura correcta, tratarlo como conversación
            return MoodResponse(
              estado: 'conversacion',
              peliculas: [],
            )..conversationalResponse = content;
          }
        } catch (e) {
          // No es JSON válido, es una respuesta conversacional
          return MoodResponse(
            estado: 'conversacion',
            peliculas: [],
          )..conversationalResponse = content;
        }
      }
      return null;
    } catch (e) {
      print('Error en Groq: $e');
      return null;
    }
  }

  String _buildUserContext(String? userName, String favoriteMovies, List<String> recentTopics, List<Map<String, dynamic>> ratedMovies, List<Map<String, dynamic>> watchedMovies) {
    final buffer = StringBuffer();

    if (userName != null) {
      buffer.writeln('Nombre del usuario: $userName');
    }

    // Análisis de películas calificadas para entender gustos
    if (ratedMovies.isNotEmpty) {
      buffer.writeln('\n=== ANÁLISIS DE PELÍCULAS CALIFICADAS ===');
      
      final highRated = ratedMovies.where((m) => (m['userRating'] as double) >= 7.0).toList();
      final lowRated = ratedMovies.where((m) => (m['userRating'] as double) < 5.0).toList();
      
      if (highRated.isNotEmpty) {
        final highRatedTitles = highRated.map((m) => '${m['title']} (${m['userRating']}/10)').join(', ');
        buffer.writeln('Películas que le gustaron mucho (7+ estrellas): $highRatedTitles');
      }
      
      if (lowRated.isNotEmpty) {
        final lowRatedTitles = lowRated.map((m) => '${m['title']} (${m['userRating']}/10)').join(', ');
        buffer.writeln('Películas que no le gustaron (<5 estrellas): $lowRatedTitles');
      }
      
      // Análisis de géneros preferidos
      final genres = <String, int>{};
      for (final movie in highRated) {
        final movieGenres = (movie['genres'] as String).split(', ');
        for (final genre in movieGenres) {
          genres[genre] = (genres[genre] ?? 0) + 1;
        }
      }
      
      if (genres.isNotEmpty) {
        final sortedGenres = genres.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final topGenres = sortedGenres.take(3).map((e) => '${e.key} (${e.value} películas)').join(', ');
        buffer.writeln('Géneros favoritos basados en calificaciones: $topGenres');
      }
      
      // Calificación promedio
      final avgRating = ratedMovies.map((m) => m['userRating'] as double).reduce((a, b) => a + b) / ratedMovies.length;
      buffer.writeln('Calificación promedio del usuario: ${avgRating.toStringAsFixed(1)}/10');
    }

    // Solo incluir películas ya vistas para evitar repeticiones
    if (watchedMovies.isNotEmpty) {
      buffer.writeln('\n=== PELÍCULAS YA VISTAS (NO RECOMENDAR) ===');
      final watchedTitles = watchedMovies.map((m) => m['title']).join(', ');
      buffer.writeln('Películas ya vistas: $watchedTitles');
      buffer.writeln('IMPORTANTE: NO recomiendes ninguna de estas películas.');
    }

    return buffer.toString();
  }

  List<Map<String, String>> _buildMessagesWithHistory(String currentMessage, String contextInfo, List<Map<String, String>> chatHistory) {
    final messages = <Map<String, String>>[];
    
    // Agregar el mensaje del sistema
    messages.add({
      'role': 'system',
      'content': '''Eres CineBot, un asistente especializado en recomendaciones de películas personalizadas. Solo respondes sobre películas, series, animes o temas relacionados con el cine.

CONTEXTO DEL USUARIO:
$contextInfo

INSTRUCCIONES CRÍTICAS (sigue en orden):

1. ANÁLISIS DE PELÍCULAS CALIFICADAS:
   - Si el usuario tiene películas calificadas, analiza sus gustos basándote en:
     * Películas que le gustaron (7+ estrellas)
     * Géneros favoritos
     * Calificación promedio
     * Patrones en sus preferencias
   - Si NO tiene películas calificadas, pregunta sobre sus gustos y guarda esa información

2. EVITAR PELÍCULAS YA VISTAS:
   - NUNCA recomiendes películas que ya ha visto (lista en contexto)
   - Si todas las películas de un género ya las vio, sugiere géneros similares

3. RECOMENDACIONES PERSONALIZADAS:
   - Basa las recomendaciones en sus películas calificadas
   - Si pide "más" o "recomiéndame más", da más del mismo estilo
   - Si no tiene calificaciones, pregunta sobre géneros, actores, directores favoritos

4. PREGUNTAS INTELIGENTES:
   - Si no tienes suficiente información, pregunta específicamente:
     * "¿Qué géneros te gustan más?"
     * "¿Tienes algún actor o director favorito?"
     * "¿Prefieres películas nuevas o clásicas?"
     * "¿Te gustan más las comedias, dramas, acción?"

5. RESPUESTA EN JSON:
   - Solo cuando tengas suficiente información para recomendar
   - Formato JSON válido, sin texto adicional
   - 5-10 películas máximo
   - Títulos exactos de themoviedb.org

FORMATO JSON:
{
  "estado": "descripción del estado de ánimo",
  "peliculas": [
    {
      "titulo": "Título exacto",
      "ano": 2020,
      "razon": "Por qué es perfecta para él",
      "genero": "Género principal"
    }
  ]
}

EJEMPLO:
Usuario: "Recomiéndame algo"
Respuesta: "Veo que te gustan las películas de acción y comedia. ¿Prefieres algo más reciente o no te importa la época? También, ¿hay algún actor que te guste especialmente?"'''
    });

    // Agregar historial de conversación (últimas 20 conversaciones para no sobrecargar)
    final recentHistory = chatHistory.take(20).toList();
    for (final message in recentHistory) {
      messages.add({
        'role': message['role']!,
        'content': message['content']!
      });
    }

    // Agregar el mensaje actual
    messages.add({
      'role': 'user',
      'content': currentMessage
    });

    return messages;
  }

  // Método para buscar películas específicas basándose en gustos del usuario
  Future<List<String>> searchMoviesByPreferences(
    String userPreferences,
    List<Map<String, dynamic>> ratedMovies,
    List<Map<String, dynamic>> watchedMovies,
  ) async {
    try {
      final contextInfo = _buildUserContext(null, '', [], ratedMovies, watchedMovies);
      
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
          'messages': [
            {
              "role": "system",
              "content": '''Eres un experto en películas que recomienda títulos específicos basándose en las preferencias del usuario.

CONTEXTO DEL USUARIO:
$contextInfo

PREFERENCIAS DEL USUARIO: $userPreferences

INSTRUCCIONES:
1. Analiza ÚNICAMENTE las preferencias descritas por el usuario
2. Recomienda EXACTAMENTE 20 películas específicas que coincidan con sus gustos
3. NO importa la calificación de la película - solo que coincida con sus gustos
4. NO recomiendes películas que ya ha visto (lista en contexto)
5. Incluye películas de cualquier época y calificación
6. Si menciona gore, terror, violencia, etc., incluye películas de esos géneros sin censura
7. NO te bases en las películas calificadas del usuario, solo en sus preferencias descritas

RESPUESTA: Solo devuelve una lista de EXACTAMENTE 20 títulos de películas, uno por línea, sin explicaciones adicionales.

EJEMPLO:
The Exorcist
Saw
Hostel
The Texas Chainsaw Massacre
A Nightmare on Elm Street'''
            },
            {
              "role": "user",
              "content": "Recomiéndame películas basándome en mis gustos: $userPreferences"
            }
          ],
          "temperature": 0.7,
          "max_tokens": 500
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        
        // Parsear la respuesta para extraer títulos de películas
        final lines = content.split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty && !line.startsWith('#'))
            .toList();
            
        print('Películas recomendadas por Groq: $lines');
        return lines;
      }
      return [];
    } catch (e) {
      print('Error en búsqueda de películas por Groq: $e');
      return [];
    }
  }

  // Método para buscar películas basándose en calificaciones del usuario
  Future<List<String>> searchMoviesByRatings(
    List<Map<String, dynamic>> ratedMovies,
    List<Map<String, dynamic>> watchedMovies,
  ) async {
    try {
      final contextInfo = _buildUserContext(null, '', [], ratedMovies, watchedMovies);
      
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
          'messages': [
            {
              "role": "system",
              "content": '''Eres un experto en películas que recomienda títulos específicos basándose en las calificaciones del usuario.

CONTEXTO DEL USUARIO:
$contextInfo

INSTRUCCIONES:
1. Analiza las películas calificadas del usuario para entender sus gustos
2. Identifica patrones en géneros, actores, directores, épocas, etc.
3. Recomienda EXACTAMENTE 20 películas específicas que coincidan con sus gustos
4. NO importa la calificación general de la película - solo que coincida con sus gustos
5. NO recomiendes películas que ya ha visto (lista en contexto)
6. Incluye películas de cualquier época y calificación
7. Si le gustan películas de terror/gore, incluye películas de esos géneros sin censura

RESPUESTA: Solo devuelve una lista de EXACTAMENTE 20 títulos de películas, uno por línea, sin explicaciones adicionales.

EJEMPLO:
The Exorcist
Saw
Hostel
The Texas Chainsaw Massacre
A Nightmare on Elm Street'''
            },
            {
              "role": "user",
              "content": "Recomiéndame películas basándome en mis calificaciones de películas vistas"
            }
          ],
          "temperature": 0.7,
          "max_tokens": 500
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        
        // Parsear la respuesta para extraer títulos de películas
        final lines = content.split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty && !line.startsWith('#'))
            .toList();
            
        print('Películas recomendadas por Groq basándose en calificaciones: $lines');
        return lines;
      }
      return [];
    } catch (e) {
      print('Error en búsqueda de películas por calificaciones con Groq: $e');
      return [];
    }
  }

  // Método para buscar películas por género considerando calificaciones del usuario
  Future<List<String>> searchMoviesByGenre(
    String genre,
    List<Map<String, dynamic>> ratedMovies,
    List<Map<String, dynamic>> watchedMovies,
  ) async {
    try {
      final contextInfo = _buildUserContext(null, '', [], ratedMovies, watchedMovies);
      
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
          'messages': [
            {
              "role": "system",
              "content": '''Eres un experto en películas que recomienda títulos específicos de un género considerando las calificaciones del usuario.

CONTEXTO DEL USUARIO:
$contextInfo

GÉNERO SOLICITADO: $genre

INSTRUCCIONES:
1. Analiza ÚNICAMENTE las preferencias descritas por el usuario
2. Recomienda EXACTAMENTE 20 películas específicas del género $genre
3. NO te bases en las películas calificadas del usuario, solo en sus preferencias descritas
4. NO importa la calificación general de la película - solo que sea del género y coincida con sus gustos
5. NO recomiendes películas que ya ha visto (lista en contexto)
6. Incluye películas de cualquier época y calificación
7. Si el género es terror/gore, incluye películas sin censura

RESPUESTA: Solo devuelve una lista de EXACTAMENTE 20 títulos de películas, uno por línea, sin explicaciones adicionales.

EJEMPLO para Terror:
The Exorcist
Saw
Hostel
The Texas Chainsaw Massacre
A Nightmare on Elm Street'''
            },
            {
              "role": "user",
              "content": "Recomiéndame películas de $genre basándome en mis calificaciones y gustos"
            }
          ],
          "temperature": 0.7,
          "max_tokens": 500
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        
        // Parsear la respuesta para extraer títulos de películas
        final lines = content.split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty && !line.startsWith('#'))
            .toList();
            
        print('Películas de $genre recomendadas por Groq: $lines');
        return lines;
      }
      return [];
    } catch (e) {
      print('Error en búsqueda de películas por género con Groq: $e');
      return [];
    }
  }

  // Método simple para búsqueda de películas por descripción
  Future<String> getMoodResponse(String prompt, List<String> recentTopics) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
          'messages': [
            {
              "role": "system",
              "content": "Eres un asistente especializado en encontrar películas, series y animes. Responde solo con títulos de películas, series o animes. Un título por línea."
            },
            {
              "role": "user",
              "content": prompt
            }
          ],
          "temperature": 0.3,
          "max_tokens": 500
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      }
      return 'Error al procesar la solicitud';
    } catch (e) {
      print('Error en Groq: $e');
      return 'Error al procesar la solicitud';
    }
  }

}