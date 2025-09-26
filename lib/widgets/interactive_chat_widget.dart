import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/movie.dart';
import '../models/user_preferences.dart';
import '../services/tmdb_service.dart';
import '../services/groq_service.dart';
import 'movie_card.dart';
import '../state/app_state.dart';
import '../config/api_config.dart';

class InteractiveChatWidget extends StatefulWidget {
  const InteractiveChatWidget({super.key});

  @override
  State<InteractiveChatWidget> createState() => _InteractiveChatWidgetState();
}

class _InteractiveChatWidgetState extends State<InteractiveChatWidget> {
  final TextEditingController _descriptionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  UserPreferences? _userPreferences;
  bool _isLoading = false;
  bool _isEditingPreferences = false;
  List<Movie> _recommendedMovies = [];
  List<String> _rejectedMoviesThisSession = []; // Películas rechazadas en esta sesión
  List<String> _groqRecommendations = []; // Recomendaciones de Groq para esta sesión
  int _currentRecommendationIndex = 0; // Índice de la recomendación actual
  int _apiRequestsThisSession = 0; // Contador de solicitudes API en esta sesión
  static const int _maxApiRequestsPerSession = 3; // Máximo 3 solicitudes por sesión
  bool _hasReachedMaxRequests = false; // Indica si se alcanzó el límite de solicitudes


  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserPreferences() async {
    final app = context.read<AppState>();
    final preferences = await app.databaseService.getUserPreferences();
    setState(() {
      _userPreferences = preferences;
    });
    
    // Si no es primera vez, generar recomendación automática
    if (preferences != null && !preferences.isFirstTime) {
      _generateAutomaticRecommendation();
    }
  }

  Future<void> _savePreferences() async {
    final app = context.read<AppState>();
    final description = _descriptionController.text.trim();
    
    // Si la descripción está vacía, mostrar mensaje explicativo
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se guardarán tus gustos basándose en las calificaciones de tus películas'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    final preferences = UserPreferences(
      description: description.isEmpty ? null : description, // Permitir null si está vacío
      isFirstTime: false,
    );

    await app.databaseService.saveUserPreferences(preferences);
    await app.databaseService.markFirstTimeCompleted();
    
        setState(() {
          _userPreferences = preferences;
          _isEditingPreferences = false;
          // Limpiar recomendaciones anteriores para generar nuevas con los gustos actualizados
          _groqRecommendations.clear();
          _currentRecommendationIndex = 0;
          _rejectedMoviesThisSession.clear();
          _apiRequestsThisSession = 0; // Reiniciar contador de solicitudes API
          _hasReachedMaxRequests = false; // Reiniciar bandera de límite alcanzado
        });

    if (description.isNotEmpty) {
      _addBotMessage("¡Perfecto! He guardado tus gustos. Ahora te recomendaré películas basadas en lo que me contaste. 🎬");
    } else {
      _addBotMessage("¡Perfecto! Ahora te recomendaré películas basándome en las calificaciones de tus películas vistas. 🎬");
    }
    
    _generateAutomaticRecommendation();
  }

  Future<void> _generateAutomaticRecommendation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final app = context.read<AppState>();
      
      // Obtener películas ya vistas
      final watchedMovies = await app.databaseService.getWatchedMoviesList();
      final watchedTitles = watchedMovies.map((m) => m['title'].toString().toLowerCase()).toSet();
      
      // Obtener películas calificadas
      final ratedMovies = await app.databaseService.getRatedMoviesForPrompt();
      
      // Generar recomendación basada en preferencias y calificaciones
      final recommendation = await _generateRecommendation(ratedMovies, watchedTitles);
      
      if (recommendation != null) {
        setState(() {
          _recommendedMovies = [recommendation];
        });
        
        await app.databaseService.updateRecommendationCount();
        
        _addBotMessage(
          "He encontrado esta película para ti basándome en tus gustos y calificaciones. "
          "El dia de hoy tengo estos resultados para ti 🎬"
        );
      } else {
        _addBotMessage(
          "No pude encontrar una película específica en este momento. "
          "¿Te gustaría explorar algún género en particular? 🎭"
        );
      }
    } catch (e) {
      print('Error generando recomendación: $e');
      _addBotMessage("¡Ups! Hubo un problema. ¿Te gustaría probar con algún género específico? 🔧");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Movie?> _generateRecommendation(List<Map<String, dynamic>> ratedMovies, Set<String> watchedTitles) async {
    try {
      // Si no hay recomendaciones de Groq para esta sesión, obtenerlas
      if (_groqRecommendations.isEmpty) {
        _apiRequestsThisSession++; // Incrementar contador de solicitudes API
        await _getGroqRecommendations(ratedMovies, watchedTitles);
      }
      
      // Buscar la siguiente película no rechazada
      return await _getNextMovieFromGroqRecommendations(watchedTitles);
    } catch (e) {
      print('Error en generación de recomendación: $e');
      return null;
    }
  }

  Future<void> _getGroqRecommendations(List<Map<String, dynamic>> ratedMovies, Set<String> watchedTitles) async {
    try {
      final app = context.read<AppState>();
      final groqService = GroqService();
      
      // Obtener películas ya vistas
      final watchedMovies = await app.databaseService.getWatchedMoviesList();
      
      List<String> recommendations = [];
      
      if (_userPreferences?.description != null && _userPreferences!.description!.isNotEmpty) {
        // Buscar por preferencias del usuario
        recommendations = await groqService.searchMoviesByPreferences(
          _userPreferences!.description!,
          ratedMovies,
          watchedMovies,
        );
      } else {
        // Si no hay preferencias, buscar basándose en calificaciones
        recommendations = await groqService.searchMoviesByRatings(
          ratedMovies,
          watchedMovies,
        );
      }
      
      setState(() {
        _groqRecommendations = recommendations;
        _currentRecommendationIndex = 0;
      });
      
      print('DEBUG: Obtenidas ${recommendations.length} recomendaciones de Groq');
      print('DEBUG: Solicitudes API esta sesión: $_apiRequestsThisSession');
    } catch (e) {
      print('Error obteniendo recomendaciones de Groq: $e');
    }
  }


  Future<Movie?> _getNextMovieFromGroqRecommendations(Set<String> watchedTitles) async {
    try {
      final app = context.read<AppState>();
      final tmdbService = TmdbService(
        languageCode: app.languageCode,
        excludeAdult: false,
        minVotes: 0, // Sin restricción de votos
      );

      // Buscar desde el índice actual
      print('DEBUG: Buscando desde índice $_currentRecommendationIndex hasta ${_groqRecommendations.length}');
      for (int i = _currentRecommendationIndex; i < _groqRecommendations.length; i++) {
        final title = _groqRecommendations[i];
        print('DEBUG: Verificando película $i: $title');
        
        // Solo verificar si ya la vio (NO rechazar por sesión)
        final normalizedTitle = title.toLowerCase().trim();
        final isWatched = watchedTitles.any((watchedTitle) => 
          watchedTitle.contains(normalizedTitle) || normalizedTitle.contains(watchedTitle));
        
        if (isWatched) {
          print('DEBUG: Película omitida - Ya vista: $title');
          continue;
        }
        
        // Buscar la película en TMDB
        final movie = await _searchMovieByTitle(tmdbService, title);
        if (movie != null) {
          setState(() {
            _currentRecommendationIndex = i + 1;
          });
          print('DEBUG: Película encontrada: ${movie.title}');
          return movie;
        } else {
          print('DEBUG: Película no encontrada en TMDB: $title');
        }
      }
      
      // Si no encuentra más películas en la lista actual
      print('DEBUG: No hay más películas válidas en la lista actual');
      return null;
    } catch (e) {
      print('Error obteniendo siguiente película: $e');
      return null;
    }
  }

  Future<Movie?> _searchMovieByTitle(TmdbService service, String title) async {
    try {
      final uri = Uri.parse('https://api.themoviedb.org/3/search/movie').replace(
        queryParameters: {
          'api_key': ApiConfig.tmdbApiKey,
          'language': service.languageCode,
          'query': title,
          'include_adult': 'false',
        },
      );

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];

        if (results.isNotEmpty) {
          // Tomar el primer resultado (mejor coincidencia)
          final movieData = results.first as Map<String, dynamic>;
          return Movie.fromTmdbJson(movieData);
        }
      }
      return null;
    } catch (e) {
      print('Error buscando película por título: $e');
      return null;
    }
  }




  Future<void> _searchAnotherMovie() async {
    if (_recommendedMovies.isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      print('DEBUG: Índice actual: $_currentRecommendationIndex');
      print('DEBUG: Total recomendaciones: ${_groqRecommendations.length}');
      print('DEBUG: Solicitudes API esta sesión: $_apiRequestsThisSession');
      print('DEBUG: Límite alcanzado: $_hasReachedMaxRequests');
      
      // Obtener películas ya vistas
      final app = context.read<AppState>();
      final watchedMovies = await app.databaseService.getWatchedMoviesList();
      final watchedTitles = watchedMovies.map((m) => m['title'].toString().toLowerCase()).toSet();
      
      // Buscar la siguiente película en la lista actual
      final nextMovie = await _getNextMovieFromGroqRecommendations(watchedTitles);
      
      if (nextMovie != null) {
        setState(() {
          _recommendedMovies = [nextMovie];
        });
        _addBotMessage("Aquí tienes otra recomendación. ¿Te gusta esta? 🎬");
      } else {
        // Si no hay más películas en la lista actual, verificar si podemos hacer más solicitudes
        if (_apiRequestsThisSession < _maxApiRequestsPerSession) {
          // Hacer nueva solicitud a la API
          _apiRequestsThisSession++;
          final ratedMovies = await app.databaseService.getRatedMoviesForPrompt();
          await _getGroqRecommendations(ratedMovies, watchedTitles);
          
          final newMovie = await _getNextMovieFromGroqRecommendations(watchedTitles);
          if (newMovie != null) {
            setState(() {
              _recommendedMovies = [newMovie];
            });
            _addBotMessage("He encontrado nuevas recomendaciones para ti. ¿Te gusta esta? 🎬");
          } else {
            _addBotMessage("No tengo más recomendaciones en este momento. ¿Te gustaría explorar algún género específico? 🤔");
          }
        } else {
          // Límite de solicitudes alcanzado - iterar por las listas ya obtenidas
          if (!_hasReachedMaxRequests) {
            setState(() {
              _hasReachedMaxRequests = true;
            });
            _addBotMessage("He alcanzado el límite de recomendaciones por hoy. ¡Vuelve mañana para más películas! 🌅");
          } else {
            // Reiniciar iteración por las listas ya obtenidas
            setState(() {
              _currentRecommendationIndex = 0;
            });
            
            final recycledMovie = await _getNextMovieFromGroqRecommendations(watchedTitles);
            if (recycledMovie != null) {
              setState(() {
                _recommendedMovies = [recycledMovie];
              });
              _addBotMessage("Aquí tienes otra recomendación de las que ya obtuve. ¿Te gusta esta? 🎬");
            } else {
              _addBotMessage("Ya revisé todas las películas disponibles. ¡Vuelve mañana para más recomendaciones! 🌅");
            }
          }
        }
      }
    } catch (e) {
      print('Error buscando otra película: $e');
      _addBotMessage("¡Ups! Hubo un problema. ¿Te gustaría probar con algún género específico? 🔧");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addBotMessage(String message) {
    // Aquí podrías agregar el mensaje a una lista de mensajes del chat
    // Por ahora solo mostramos el mensaje en la UI
  }

  Widget _buildFirstTimeInterface() {
    return Column(
      children: [
        // Mensaje de bienvenida
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Icon(Icons.smart_toy, size: 32, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                '¡Hola! Soy CineBot 🤖',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cada vez que entres a la app, te recomendaré una película basada en tus gustos y calificaciones. ¡Cuéntame qué te gusta!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Campo de descripción
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Describe tus gustos en películas...',
              hintText: 'Ej: Me gustan las películas de acción, comedia y ciencia ficción...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            enabled: !_isLoading,
          ),
        ),

        const SizedBox(height: 16),

        // Botón para guardar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _savePreferences,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Guardar mis gustos'),
          ),
        ),
      ],
    );
  }

  Widget _buildMainInterface() {
    return Column(
      children: [
        // Mensaje de CineBot
        if (_recommendedMovies.isNotEmpty)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.smart_toy, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "He encontrado esta película para ti basándome en tus gustos. ¿Te gusta o prefieres que busque otra del mismo género? 🎬",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),

        // Título de recomendaciones
        if (_recommendedMovies.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Películas recomendadas hoy',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),

        // Película recomendada
        if (_recommendedMovies.isNotEmpty)
          MovieCard(movie: _recommendedMovies.first),

        // Botón de acción
        if (_recommendedMovies.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _searchAnotherMovie(),
              icon: const Icon(Icons.refresh),
              label: const Text('Buscar otra'),
            ),
          ),
        ],


        // Loading indicator
        if (_isLoading)
          Container(
            margin: const EdgeInsets.all(16),
            child: const CircularProgressIndicator(),
          ),
      ],
    );
  }



  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8), // Reducir margen vertical
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // Reducir padding vertical aún más
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
            ),
            borderRadius: BorderRadius.circular(5), // Reducir radio de bordes
          ),
          child: Row(
            children: [
              const Icon(Icons.smart_toy, color: Colors.white, size: 18), // Reducir tamaño del icono
              const SizedBox(width: 6), // Reducir espacio
              Expanded(
                child: Text(
                  'CineBot ${app.userProfile?.name != null ? "• ${app.userProfile!.name}" : ""}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 13, // Reducir tamaño de fuente
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Botón "Mis gustos"
              if (_userPreferences != null && !_userPreferences!.isFirstTime)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isEditingPreferences = true;
                      _descriptionController.text = _userPreferences?.description ?? '';
                    });
                  },
                  icon: const Icon(Icons.person, color: Colors.white, size: 18), // Reducir tamaño del icono
                  tooltip: 'Mis gustos',
                  padding: const EdgeInsets.all(4), // Reducir padding del botón
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32), // Reducir tamaño del botón
                ),
            ],
          ),
        ),

        // Contenido principal
        if (_userPreferences == null || _userPreferences!.isFirstTime || _isEditingPreferences)
          _buildFirstTimeInterface()
        else
          _buildMainInterface(),
      ],
    );
  }
}

