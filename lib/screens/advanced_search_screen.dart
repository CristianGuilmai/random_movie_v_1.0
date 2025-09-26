import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../services/groq_service.dart';
import '../services/tmdb_service.dart';
import '../services/rate_limiting_service.dart';
import '../models/movie.dart';
import '../widgets/movie_card.dart';

class AdvancedSearchScreen extends StatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _chatMessages = [];
  List<Movie> _actorMainMovies = [];
  List<Movie> _actorSecondaryMovies = [];
  List<Movie> _actorOtherMovies = [];
  List<Movie> _directorMovies = [];
  List<Movie> _searchMovies = [];
  bool _isLoading = false;
  String? _currentSearchType; // 'actor', 'director', 'movie'
  RateLimitInfo? _rateLimitInfo;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
    _loadRateLimitInfo();
  }

  Future<void> _loadRateLimitInfo() async {
    final rateLimitService = RateLimitingService();
    final info = await rateLimitService.getRateLimitInfo();
    setState(() {
      _rateLimitInfo = info;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    _chatMessages.add(ChatMessage(
      text: "¡Hola! Soy CineBot 🎬 tu asistente de cine.\n\n"
          "Puedo ayudarte a:\n"
          "• Encontrar películas si no recuerdas el nombre\n"
          "• Buscar por actores: 'películas de Keanu Reeves'\n"
          "• Buscar por directores: 'películas de Christopher Nolan'\n\n"
          "Escríbeme lo que recuerdes y yo te ayudo 😉",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    // Verificar rate limiting
    final rateLimitService = RateLimitingService();
    final canMakeQuery = await rateLimitService.canMakeQuery();
    
    if (!canMakeQuery) {
      final info = await rateLimitService.getRateLimitInfo();
      _addBotMessage(
        "🚫 Has alcanzado el límite diario de consultas (${info.maxPerDay}/día).\n\n"
        "Tienes que esperar ${info.timeUntilReset} para hacer más consultas.\n\n"
        "¡Vuelve mañana para seguir buscando películas! 🍿"
      );
      return;
    }

    setState(() {
      _chatMessages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final groqService = GroqService();

      // Prompt mejorado
      final analysisPrompt = '''
Eres CineBot 🎬, un experto en cine. Tu tarea es analizar lo que escribe el usuario y ayudarle a encontrar películas, actores o directores, aunque escriba mal los nombres.

Responde SOLO con uno de estos tipos:
- "actor: [nombre corregido]"
- "director: [nombre corregido]"
- "movie: [título corregido]"
- "unknown: [mensaje]"

Reglas criticas:
1. Si el nombre está mal escrito, corrígelo (ej: "kenu revs" → "actor: Keanu Reeves").
2. Si el usuario recuerda solo parte de un título ("matrix 1999" o "matrx"), intenta inferirlo y corrígelo.
3. Si no entiendes, responde con "unknown: No entendí bien tu búsqueda".
4. No hagas preguntas en las respuestas

Ejemplos:
- "kenu revs" → "actor: Keanu Reeves"
- "cristopher nolan" → "director: Christopher Nolan"
- "incepton film" → "movie: Inception"
- "busco una peli con un sueño compartido" → "movie: Inception"

Mensaje del usuario: "$message"
''';

      final analysisResponse =
      await groqService.getMoodResponse(analysisPrompt, []);

      // 🔹 Mostrar respuesta cruda en consola
      print("🔍 Respuesta de Groq: $analysisResponse");

      final analysis = analysisResponse.trim().toLowerCase();

      if (analysis.startsWith('actor:')) {
        final actorName = analysis.substring(6).trim();
        await _searchActor(actorName, message);
      } else if (analysis.startsWith('director:')) {
        final directorName = analysis.substring(9).trim();
        await _searchDirector(directorName, message);
      } else if (analysis.startsWith('movie:')) {
        final movieTitle = analysis.substring(6).trim();
        await _searchMovie(movieTitle, message);
      } else {
        _addBotMessage(
            "No pude entender tu búsqueda 🤔. Intenta algo como:\n"
                "• 'películas de Tom Hanks'\n"
                "• 'películas dirigidas por Steven Spielberg'\n"
                "• 'busco The Matrix'");
      }
    } catch (e) {
      _addBotMessage(
          "Lo siento 😔, hubo un error al procesar tu solicitud. Intenta de nuevo.");
    } finally {
      // Registrar la consulta realizada
      await rateLimitService.recordQuery();
      
      // Actualizar información de rate limiting
      await _loadRateLimitInfo();
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchActor(String actorName, String originalMessage) async {
    try {
      final app = context.read<AppState>();
      final tmdbService = TmdbService(
        languageCode: app.languageCode,
        excludeAdult: app.excludeAdult,
      );

      final people = await tmdbService.searchPeople(actorName);

      if (people.isEmpty) {
        _addBotMessage(
            "No encontré ningún actor con ese nombre. ¿Podrías verificar la ortografía?");
        return;
      }

      final person = people.first;
      final personName = person['name'] as String;

      String responseMessage;
      if (originalMessage.toLowerCase() != actorName.toLowerCase()) {
        responseMessage =
        "Parece que quisiste decir **$personName** 🎭. Aquí tienes sus películas más conocidas:";
      } else {
        responseMessage =
        "Aquí tienes las películas más populares de **$personName** 🎬:";
      }

      _addBotMessage(responseMessage);

      // Obtener películas del actor separadas
      final moviesData = await tmdbService.getActorMoviesSeparated(person['id'] as int);

      setState(() {
        _actorMainMovies = moviesData['main'] ?? [];
        _actorSecondaryMovies = moviesData['secondary'] ?? [];
        _actorOtherMovies = moviesData['other'] ?? [];
        _directorMovies.clear();
        _searchMovies.clear();
        _currentSearchType = 'actor';
      });
    } catch (e) {
      _addBotMessage("Error al buscar el actor 😓. Intenta de nuevo.");
    }
  }

  Future<void> _searchDirector(
      String directorName, String originalMessage) async {
    try {
      final app = context.read<AppState>();
      final tmdbService = TmdbService(
        languageCode: app.languageCode,
        excludeAdult: app.excludeAdult,
      );

      final people = await tmdbService.searchPeople(directorName);

      if (people.isEmpty) {
        _addBotMessage(
            "No encontré ningún director con ese nombre. ¿Podrías verificar la ortografía?");
        return;
      }

      final person = people.first;
      final personName = person['name'] as String;

      String responseMessage;
      if (originalMessage.toLowerCase() != directorName.toLowerCase()) {
        responseMessage =
        "Parece que quisiste decir **$personName** 🎥. Aquí tienes sus películas dirigidas:";
      } else {
        responseMessage =
        "Aquí tienes las películas dirigidas por **$personName** 🎬:";
      }

      _addBotMessage(responseMessage);

      final movies = await tmdbService.getPersonMovies(person['id'] as int);

      setState(() {
        _directorMovies = movies.take(10).toList();
        _actorMainMovies.clear();
        _actorSecondaryMovies.clear();
        _actorOtherMovies.clear();
        _searchMovies.clear();
        _currentSearchType = 'director';
      });
    } catch (e) {
      _addBotMessage("Error al buscar el director 😓. Intenta de nuevo.");
    }
  }

  Future<void> _searchMovie(String movieTitle, String originalMessage) async {
    try {
      final app = context.read<AppState>();
      final tmdbService = TmdbService(
        languageCode: app.languageCode,
        excludeAdult: app.excludeAdult,
      );

      final movies = await tmdbService.searchMovies(movieTitle);

      if (movies.isEmpty) {
        _addBotMessage(
            "No encontré ninguna película con ese título 😕. ¿Podrías verificar el nombre?");
        return;
      }

      if (movies.length > 1) {
        final suggestions =
        movies.take(3).map((m) => m.title).join(", ");
        _addBotMessage(
            "Encontré varias opciones 🍿. ¿Puede ser alguna de estas?: $suggestions");
      }

      final movie = movies.first;
      _addBotMessage(
          "Creo que hablas de **${movie.title}** (${movie.releaseYear ?? 'Año no disponible'}) 🎬. "
              "¿Es esta la película que buscabas?");

      setState(() {
        _searchMovies = [movie];
        _actorMainMovies.clear();
        _actorSecondaryMovies.clear();
        _actorOtherMovies.clear();
        _directorMovies.clear();
        _currentSearchType = 'movie';
      });
    } catch (e) {
      _addBotMessage("Error al buscar la película 😓. Intenta de nuevo.");
    }
  }

  void _addBotMessage(String text) {
    setState(() {
      _chatMessages.add(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
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

  Widget _buildChatMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.psychology,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: message.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 12),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMovieCarousel(String title, List<Movie> movies) {
    if (movies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...movies.map((movie) => MovieCard(movie: movie)),
        const SizedBox(height: 16),
      ],
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inDays}d';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Búsqueda Avanzada'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Chat y carouseles en scroll
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  // Chat
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ..._chatMessages.map((message) => _buildChatMessage(message)),
                        if (_isLoading)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.psychology,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                      SizedBox(width: 8),
                                      Text('CineBot está pensando...'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Carouseles de resultados
                  if (_currentSearchType == 'actor') ...[
                    if (_actorMainMovies.isNotEmpty)
                      _buildMovieCarousel('Películas Principales', _actorMainMovies),
                    if (_actorSecondaryMovies.isNotEmpty)
                      _buildMovieCarousel('Películas Secundarias', _actorSecondaryMovies),
                    if (_actorOtherMovies.isNotEmpty)
                      _buildMovieCarousel('Más Películas', _actorOtherMovies),
                  ],
                  if (_currentSearchType == 'director' && _directorMovies.isNotEmpty)
                    _buildMovieCarousel('Películas del Director', _directorMovies),
                  if (_currentSearchType == 'movie' && _searchMovies.isNotEmpty)
                    _buildMovieCarousel('Película Encontrada', _searchMovies),
                  
                  // Espacio adicional al final para evitar que el input tape el contenido
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          
          // Input de mensaje (fijo en la parte inferior)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withOpacity(0.2),
                ),
              ),
            ),
            child: Column(
              children: [
                // Indicador de consultas restantes
                if (_rateLimitInfo != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _rateLimitInfo!.isLimitReached 
                          ? Colors.red.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _rateLimitInfo!.isLimitReached 
                            ? Colors.red.withOpacity(0.3)
                            : Colors.blue.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _rateLimitInfo!.isLimitReached 
                              ? Icons.block 
                              : Icons.query_stats,
                          size: 16,
                          color: _rateLimitInfo!.isLimitReached 
                              ? Colors.red 
                              : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _rateLimitInfo!.isLimitReached
                                ? 'Límite alcanzado. Reset en ${_rateLimitInfo!.timeUntilReset}'
                                : 'Consultas restantes: ${_rateLimitInfo!.remaining}/${_rateLimitInfo!.maxPerDay}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _rateLimitInfo!.isLimitReached 
                                  ? Colors.red 
                                  : Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Campo de texto y botón
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText:
                          'Pregúntame sobre actores, directores o películas...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        enabled: !_isLoading && (_rateLimitInfo?.isLimitReached != true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      onPressed: (_isLoading || _rateLimitInfo?.isLimitReached == true) 
                          ? null 
                          : _sendMessage,
                      child: _isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
