import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/mood_response.dart';
import '../models/chat_message.dart';
import '../models/movie.dart';
import '../services/groq_service.dart';
import '../services/tmdb_service.dart';
import '../state/app_state.dart';

class MoodChatWidget extends StatefulWidget {
  const MoodChatWidget({super.key});

  @override
  State<MoodChatWidget> createState() => _MoodChatWidgetState();
}

class _MoodChatWidgetState extends State<MoodChatWidget> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  //
  final GroqService _groqService = GroqService();
  
  Movie? _welcomeRecommendation;
  bool _isLoadingRecommendation = false;

  @override
  void initState() {
    super.initState();
    // Cargar recomendación de bienvenida después de que el widget se construya
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWelcomeRecommendation();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadWelcomeRecommendation() async {
    final app = context.read<AppState>();
    
    // Solo mostrar recomendación si no se ha mostrado antes
    if (app.hasShownWelcomeRecommendation) return;
    
    setState(() {
      _isLoadingRecommendation = true;
    });

    try {
      final tmdbService = TmdbService(
        apiKey: 'FALLBACK_KEY_ONLY',
        languageCode: app.languageCode,
        excludeAdult: app.excludeAdult,
      );

      final recommendedMovie = await tmdbService.fetchRecommendedMovie(app.watched);
      
      if (recommendedMovie != null && mounted) {
        setState(() {
          _welcomeRecommendation = recommendedMovie;
        });
        
        // Marcar que ya se mostró la recomendación
        await app.markWelcomeRecommendationShown();
      }
    } catch (e) {
      print('Error loading welcome recommendation: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRecommendation = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final app = context.read<AppState>();

    // Agregar mensaje del usuario
    app.addChatMessage(ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    ));
    _controller.clear();
    _scrollToBottom();

    // Actualizar actividad del usuario
    await app.updateLastActive();

    // Mostrar loading
    app.setLoadingMoodMovies(true);

    try {
      // Obtener contexto del usuario
      final watchedMovies = await app.databaseService.getWatchedMoviesForPrompt();
      final recentTopics = app.recentConversations
          .take(5)
          .map((c) => c.userMessage)
          .toList();

      // Obtener películas calificadas para análisis
      final ratedMovies = await app.databaseService.getRatedMoviesForPrompt();
      
      // Obtener películas ya vistas para evitar recomendarlas
      final watchedMoviesList = await app.databaseService.getWatchedMoviesList();

      // Obtener historial de conversación
      final chatHistory = _buildChatHistory(app.chatMessages);

      // Consultar Groq con contexto personalizado y historial
      final moodResponse = await _groqService.getMoodRecommendation(
        text,
        app.userProfile?.name,
        watchedMovies,
        recentTopics,
        chatHistory,
        ratedMovies,
        watchedMoviesList,
      );

      if (moodResponse == null) {
        app.addChatMessage(ChatMessage(
          text: "¡Ups! Parece que tengo problemas técnicos 🔧. ¿Podrías intentarlo de nuevo?",
          isUser: false,
          timestamp: DateTime.now(),
        ));
        return;
      }

      String aiResponse;
      List<String> recommendedMovieIds = [];

      // Verificar si es respuesta conversacional o recomendación
      if (moodResponse.conversationalResponse != null) {
        // Es una respuesta de chat normal
        aiResponse = moodResponse.conversationalResponse!;
        
        // Verificar si la respuesta contiene JSON (indica que debería ser una recomendación)
        if (aiResponse.contains('{') && aiResponse.contains('"peliculas"')) {
          // Intentar parsear como JSON para obtener las recomendaciones
          try {
            final jsonMatch = RegExp(r'\{[^}]*"peliculas"[^}]*\}').firstMatch(aiResponse);
            if (jsonMatch != null) {
              final jsonStr = jsonMatch.group(0)!;
              final jsonData = jsonDecode(jsonStr);
              final parsedResponse = MoodResponse.fromJson(jsonData);
              
              if (parsedResponse.peliculas.isNotEmpty) {
                // Es una recomendación, procesarla
                print('Procesando recomendaciones: ${parsedResponse.peliculas.length} películas');
                await _searchMoviesInTMDB(parsedResponse, app);
                print('Películas encontradas en TMDB: ${app.moodMovies.length}');
                aiResponse = _createPersonalizedResponse(parsedResponse, app.userProfile?.name);
                recommendedMovieIds = app.moodMovies.map((m) => m.id.toString()).toList();
              }
            }
          } catch (e) {
            print('Error parseando JSON: $e');
          }
        }
        
        // Limpiar cualquier JSON que pueda haber aparecido en la respuesta final
        if (aiResponse.contains('{') || aiResponse.contains('}') || aiResponse.contains('"estado"') || aiResponse.contains('"peliculas"')) {
          // Remover todo el contenido JSON de la respuesta
          aiResponse = aiResponse
              .replaceAll(RegExp(r'\{[^}]*\}'), '') // Remover objetos JSON
              .replaceAll(RegExp(r'"[^"]*":\s*"[^"]*"'), '') // Remover pares clave-valor
              .replaceAll(RegExp(r'"[^"]*":\s*\[[^\]]*\]'), '') // Remover arrays
              .replaceAll(RegExp(r'[{}[\]",:]'), '') // Remover caracteres JSON
              .replaceAll(RegExp(r'\s+'), ' ') // Limpiar espacios múltiples
              .trim();
          
          if (aiResponse.isEmpty || aiResponse.length < 10) {
            aiResponse = "¡Perfecto! He encontrado algunas recomendaciones para ti. ¡Échales un vistazo abajo! 🎬";
          }
        }
      } else if (moodResponse.peliculas.isNotEmpty) {
        // Es una recomendación de películas
        await _searchMoviesInTMDB(moodResponse, app);

        // Crear respuesta personalizada basada en el estado
        String personalizedResponse = _createPersonalizedResponse(moodResponse, app.userProfile?.name);
        aiResponse = personalizedResponse;

        // Recopilar IDs de películas recomendadas
        recommendedMovieIds = app.moodMovies.map((m) => m.id.toString()).toList();
      } else {
        aiResponse = "¡Me encanta hablar contigo! Pero soy especialista en películas 🎬. ¿Qué película te gustaría descubrir hoy?";
      }

      app.addChatMessage(ChatMessage(
        text: aiResponse,
        isUser: false,
        timestamp: DateTime.now(),
      ));

      // Guardar conversación en base de datos
      await app.saveConversation(text, aiResponse, recommendedMovieIds);

    } catch (e) {
      print('Error en chat: $e');
      app.addChatMessage(ChatMessage(
        text: "¡Ups! Parece que tengo problemas técnicos 🔧. ¿Podrías intentarlo de nuevo? Mientras tanto, ¿qué película te gustaría descubrir hoy?",
        isUser: false,
        timestamp: DateTime.now(),
      ));
    } finally {
      app.setLoadingMoodMovies(false);
      _scrollToBottom();
    }
  }

  Future<void> _searchMoviesInTMDB(MoodResponse moodResponse, AppState app) async {
    print('=== INICIANDO BÚSQUEDA EN TMDB ===');
    print('Películas a buscar: ${moodResponse.peliculas.length}');
    
    final tmdbService = TmdbService(
      apiKey: 'be8a60f1538e9470adb291ebfa3c9840',
      languageCode: app.languageCode,
      // regionCode: app.regionCode, // Removido
      excludeAdult: app.excludeAdult,
      minVotes: 50,
    );

    final foundMovies = <Movie>[];
    
    // Obtener películas ya vistas para evitar recomendarlas
    final watchedMovies = await app.databaseService.getWatchedMoviesList();
    final watchedTitles = watchedMovies.map((m) => m['title'].toString().toLowerCase()).toSet();
    print('Películas ya vistas: ${watchedTitles.length}');

    // Buscar cada película recomendada por título
    for (final recommendation in moodResponse.peliculas) {
      try {
        print('🔍 Buscando película: "${recommendation.titulo}" (${recommendation.ano})');
        
        // Verificar si ya la vio
        if (watchedTitles.contains(recommendation.titulo.toLowerCase())) {
          print('⏭️ Película ya vista, saltando: "${recommendation.titulo}"');
          continue;
        }
        
        final movie = await _searchMovieByTitle(tmdbService, recommendation.titulo, recommendation.ano);
        if (movie != null) {
          // Verificar nuevamente con el título de TMDB
          if (!watchedTitles.contains(movie.title.toLowerCase())) {
            foundMovies.add(movie);
            print('✅ Película encontrada: "${movie.title}" (${movie.releaseYear})');
          } else {
            print('⏭️ Película ya vista (título TMDB), saltando: "${movie.title}"');
          }
        } else {
          print('❌ Película no encontrada: "${recommendation.titulo}"');
        }
      } catch (e) {
        print('💥 Error buscando película ${recommendation.titulo}: $e');
      }
    }

    print('=== RESULTADO DE BÚSQUEDA ===');
    print('Total películas encontradas: ${foundMovies.length}');
    print('Películas encontradas: ${foundMovies.map((m) => m.title).toList()}');
    
    // Si no se encontraron películas específicas, buscar películas populares del género
    if (foundMovies.isEmpty && moodResponse.peliculas.isNotEmpty) {
      print('🔄 No se encontraron películas específicas, buscando películas populares del género...');
      final fallbackMovies = await _searchFallbackMovies(tmdbService, moodResponse.peliculas.first.genero, watchedTitles);
      foundMovies.addAll(fallbackMovies);
      print('🎬 Películas de fallback encontradas: ${fallbackMovies.length}');
    }
    
    // Limpiar películas anteriores antes de establecer las nuevas
    app.setMoodMovies([]);
    await Future.delayed(const Duration(milliseconds: 100)); // Pequeña pausa
    
    app.setMoodMovies(foundMovies);
    print('Películas en AppState después de setMoodMovies: ${app.moodMovies.length}');
    print('=== FIN BÚSQUEDA TMDB ===');
  }

  Future<Movie?> _searchMovieByTitle(TmdbService service, String title, int? year) async {
    try {
      // Limpiar el título para mejor búsqueda
      final cleanTitle = title.trim();
      print('🔍 Búsqueda detallada para: "$cleanTitle" (año: $year)');
      
      final uri = Uri.parse('https://api.themoviedb.org/3/search/movie').replace(
        queryParameters: {
          'api_key': 'FALLBACK_KEY_ONLY',
          'language': service.languageCode,
          'query': cleanTitle,
          'include_adult': 'false',
          if (year != null) 'year': year.toString(),
        },
      );

      final response = await http.get(uri);
      print('📡 Respuesta TMDB: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];
        print('📊 Resultados encontrados: ${results.length}');

        if (results.isNotEmpty) {
          // Buscar la mejor coincidencia
          Movie? bestMatch;
          double bestScore = 0.0;
          
          for (final result in results.take(10)) { // Revisar más resultados
            final movieData = result as Map<String, dynamic>;
            final movieTitle = (movieData['title'] ?? '').toString().toLowerCase();
            final originalTitle = (movieData['original_title'] ?? '').toString().toLowerCase();
            final searchTitle = cleanTitle.toLowerCase();
            
            print('🎬 Evaluando: "$movieTitle" vs "$searchTitle"');
            
            // Calcular score de coincidencia
            double score = 0.0;
            if (movieTitle == searchTitle) {
              score = 1.0; // Coincidencia exacta
              print('✅ Coincidencia exacta');
            } else if (originalTitle == searchTitle) {
              score = 0.9; // Coincidencia con título original
              print('✅ Coincidencia con título original');
            } else if (movieTitle.contains(searchTitle) || searchTitle.contains(movieTitle)) {
              score = 0.7; // Coincidencia parcial
              print('✅ Coincidencia parcial');
            } else {
              // Calcular similitud básica
              final words = searchTitle.split(' ');
              final movieWords = movieTitle.split(' ');
              int matches = 0;
              for (final word in words) {
                if (movieWords.any((mw) => mw.contains(word) || word.contains(mw))) {
                  matches++;
                }
              }
              score = matches / words.length;
              print('Score de similitud: $score');
            }
            
            // Verificar año si se proporciona
            if (year != null) {
              final releaseDate = movieData['release_date'] as String?;
              if (releaseDate != null && releaseDate.isNotEmpty) {
                final movieYear = int.tryParse(releaseDate.substring(0, 4));
                if (movieYear == year) {
                  score += 0.2; // Bonus por año correcto
                  print('Bonus por año correcto: $movieYear');
                }
              }
            }
            
            if (score > bestScore) {
              bestScore = score;
              bestMatch = Movie.fromTmdbJson(movieData);
              print('🏆 Nuevo mejor match: "$movieTitle" con score $score');
            }
          }
          
          // Solo devolver si el score es suficientemente bueno
          if (bestMatch != null && bestScore >= 0.2) { // Reducir el umbral
            print('Película aceptada: "${bestMatch.title}" con score $bestScore');
            // Obtener cast
            final cast = await service.fetchMovieCast(bestMatch.id);
            return bestMatch.copyWith(cast: cast);
          } else {
            print('Ninguna película cumple el score mínimo (0.2)');
          }
        } else {
          print('No se encontraron resultados en TMDB');
        }
      } else {
        print('Error en respuesta TMDB: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      print('Error en búsqueda por título: $e');
      return null;
    }
  }

  Future<List<Movie>> _searchFallbackMovies(TmdbService service, String genre, Set<String> watchedTitles) async {
    try {
      print('🔍 Buscando películas de fallback para género: $genre');
      
      // Mapear géneros en español a IDs de TMDB
      final genreMap = {
        'acción': 28,
        'aventura': 12,
        'animación': 16,
        'comedia': 35,
        'crimen': 80,
        'documental': 99,
        'drama': 18,
        'familia': 10751,
        'fantasía': 14,
        'historia': 36,
        'terror': 27,
        'música': 10402,
        'misterio': 9648,
        'romance': 10749,
        'ciencia ficción': 878,
        'thriller': 53,
        'guerra': 10752,
        'western': 37,
      };
      
      final genreId = genreMap[genre.toLowerCase()];
      if (genreId == null) {
        print('Género no reconocido: $genre');
        return [];
      }
      
      // Buscar películas populares del género
      final uri = Uri.parse('https://api.themoviedb.org/3/discover/movie').replace(
        queryParameters: {
          'api_key': 'FALLBACK_KEY_ONLY',
          'language': service.languageCode,
          'with_genres': genreId.toString(),
          'sort_by': 'popularity.desc',
          'include_adult': 'false',
          'page': '1',
        },
      );
      
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];
        
        final movies = <Movie>[];
        for (final result in results.take(10)) { // Tomar más películas para filtrar
          try {
            final movie = Movie.fromTmdbJson(result as Map<String, dynamic>);
            
            // Verificar si ya la vio
            if (!watchedTitles.contains(movie.title.toLowerCase())) {
              movies.add(movie);
              print('Película de fallback: "${movie.title}"');
              
              // Limitar a 5 películas
              if (movies.length >= 5) break;
            } else {
              print('Película de fallback ya vista, saltando: "${movie.title}"');
            }
          } catch (e) {
            print('Error creando película de fallback: $e');
          }
        }
        
        return movies;
      }
      
      return [];
    } catch (e) {
      print('Error en búsqueda de fallback: $e');
      return [];
    }
  }

  String _createPersonalizedResponse(MoodResponse moodResponse, String? userName) {
    final greeting = userName != null ? "¡Perfecto $userName! 😊" : "¡Perfecto! 😊";
    
    // Crear respuesta simple sin mostrar las películas (se mostrarán en el carrusel)
    String response = "$greeting Basándome en tu estado de ánimo y tus gustos, encontré películas perfectas para ti. ¡Échales un vistazo abajo! 🎬";
    
    return response;
  }

  List<Map<String, String>> _buildChatHistory(List<ChatMessage> messages) {
    final history = <Map<String, String>>[];
    
    // Convertir los últimos 20 mensajes a formato de historial
    final recentMessages = messages.take(20).toList();
    for (final message in recentMessages) {
      history.add({
        'role': message.isUser ? 'user' : 'assistant',
        'content': message.text
      });
    }
    
    return history;
  }










  Widget _buildMessage(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMovieCarousel(List<Movie> movies) {
    if (movies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Recomendaciones para ti:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: movies.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final movie = movies[index];
              return InkWell(
                onTap: () => context.pushNamed('detail', extra: movie),
                child: SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: movie.posterUrl != null
                              ? CachedNetworkImage(
                            imageUrl: movie.posterUrl!,
                            fit: BoxFit.cover,
                            width: 120,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade300,
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.movie),
                            ),
                          )
                              : Container(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.movie),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        movie.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    print('MoodChatWidget está construyéndose'); // Debug
    final app = context.watch<AppState>();
    print('Películas en AppState en build: ${app.moodMovies.length}');
    print('Películas: ${app.moodMovies.map((m) => m.title).toList()}');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Chat container
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header compacto
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.smart_toy, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CineBot ${app.userProfile?.name != null ? "• ${app.userProfile!.name}" : ""}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '🎬',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              // Messages área
              Container(
                constraints: const BoxConstraints(
                  minHeight: 150,
                  maxHeight: 250,
                ),
                child: app.chatMessages.isEmpty
                    ? SingleChildScrollView(
                        child: _buildCompactWelcomeMessage(app),
                      )
                    : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: app.chatMessages.length,
                  itemBuilder: (context, index) => _buildMessage(app.chatMessages[index]),
                ),
              ),

              // Loading indicator compacto
              if (app.isLoadingMoodMovies)
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Buscando películas...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),

              // Input field compacto
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Cuéntame tu estado de ánimo...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceVariant,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: IconButton(
                        onPressed: app.isLoadingMoodMovies ? null : _sendMessage,
                        icon: const Icon(Icons.send, color: Colors.white, size: 16),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Movie carousel
        if (app.moodMovies.isNotEmpty) _buildMovieCarousel(app.moodMovies),
        
        // Botón de prueba temporal (remover después)
        if (app.moodMovies.isEmpty) 
          Container(
            margin: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => _testCarousel(app),
              child: const Text('🧪 Probar Carousel'),
            ),
          ),
      ],
    );
  }


  // otro metodo

  // Método de prueba temporal (remover después)
  Future<void> _testCarousel(AppState app) async {
    print('🧪 Iniciando prueba de carousel...');
    
    try {
      // Buscar películas populares
      final uri = Uri.parse('https://api.themoviedb.org/3/movie/popular').replace(
        queryParameters: {
          'api_key': 'FALLBACK_KEY_ONLY',
          'language': app.languageCode,
          'page': '1',
        },
      );
      
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];
        
        final testMovies = <Movie>[];
        for (final result in results.take(5)) {
          try {
            final movie = Movie.fromTmdbJson(result as Map<String, dynamic>);
            testMovies.add(movie);
            print('✅ Película de prueba: "${movie.title}"');
          } catch (e) {
            print('❌ Error creando película de prueba: $e');
          }
        }
        
        app.setMoodMovies(testMovies);
        print('🧪 Películas de prueba establecidas: ${testMovies.length}');
      }
    } catch (e) {
      print('💥 Error en prueba de carousel: $e');
    }
  }

  Widget _buildCompactWelcomeMessage(AppState app) {
    final userName = app.userProfile?.name;
    final hasWatchedMovies = app.watched.isNotEmpty;
    
    String welcomeText;
    if (userName != null) {
      if (hasWatchedMovies) {
        final avgRating = app.watched.map((w) => w.userRating).reduce((a, b) => a + b) / app.watched.length;
        welcomeText = '¡Hola $userName! 😊\n\nHe visto que has calificado ${app.watched.length} película${app.watched.length == 1 ? '' : 's'} con una calificación promedio de ${avgRating.toStringAsFixed(1)}/10. Esto me ayudará a darte mejores recomendaciones basadas en tus gustos.\n\n¿Qué quieres ver hoy? 🎬';
      } else {
        welcomeText = '¡Hola $userName! 😊\n\nSoy CineBot, tu asistente personal de películas. Te ayudo a encontrar películas perfectas para ti.\n\n¿Qué quieres ver hoy? 🎬';
      }
    } else {
      welcomeText = '¡Hola! 😊\n\nSoy CineBot, tu asistente personal de películas. Te ayudo a encontrar películas perfectas para ti.\n\n¿Qué quieres ver hoy? 🎬';
    }

    // Agregar recomendación si está disponible
    if (_welcomeRecommendation != null && !app.hasShownWelcomeRecommendation) {
      welcomeText += '\n\n🎬 Quizá hoy te interese ver "${_welcomeRecommendation!.title}" - ⭐ ${_welcomeRecommendation!.voteAverage.toStringAsFixed(1)}/10';
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.smart_toy,
            size: 28,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 6),
          Text(
            welcomeText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.3),
          ),
          if (_isLoadingRecommendation) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

}