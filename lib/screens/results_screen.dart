import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/movie.dart';
import '../services/tmdb_service.dart';
import '../services/secure_service.dart';
import '../state/app_state.dart';
import '../widgets/rating_dialog.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  Movie? _movie;
  List<String> _providers = [];
  bool _loading = true;
  String? _error;
  int _retryCount = 0;

  Future<void> _showRatingDialog() async {
    if (_movie == null) return;
    
    final app = context.read<AppState>();
    final watchedMovie = app.getWatchedMovie(_movie!.id);
    
    final rating = await showDialog<double>(
      context: context,
      builder: (context) => RatingDialog(
        movie: _movie!,
        initialRating: watchedMovie?.userRating,
      ),
    );
    
    if (rating != null) {
      await app.addToWatched(_movie!, rating);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Película calificada con ${rating.toStringAsFixed(1)}/10'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final app = context.read<AppState>();
      final selectedKey = app.lastSelectedGenreKey;
      if (selectedKey == null) {
        setState(() {
          _error = 'No hay género seleccionado';
          _loading = false;
        });
        return;
      }
      
      final genreId = TmdbService.genres[selectedKey]!;
      // Usar SecureService en lugar de TmdbService directo
      // final service = TmdbService(...); // Removido - usar backend
      
      final movie = await SecureService.getRandomMovie(
        genres: [genreId],
        language: app.languageCode,
        yearStart: app.yearStart,
        yearEnd: app.yearEnd,
        minVotes: app.minVotes,
        minRating: app.useRatingFilter ? app.minRating : null,
        maxRating: app.useRatingFilter ? app.maxRating : null,
        excludeAdult: app.excludeAdult,
      );
      if (movie == null) {
        setState(() {
          _error = 'No se encontraron películas con los filtros seleccionados. Prueba ampliando los criterios de búsqueda.';
          _loading = false;
        });
        return;
      }
      
      final providers = await SecureService.getWatchProviders(movieId: movie.id);
      await app.setLastMovie(movie);
      await app.addToHistory(movie);
      
      if (mounted) {
        setState(() {
          _movie = movie;
          _providers = providers;
          _loading = false;
          _retryCount = 0; // Reset retry count on success
        });
      }
    } catch (e) {
      print('Error loading movie: $e');
      _retryCount++;
      
      String errorMessage = 'Error de conexión. ';
      if (_retryCount >= 3) {
        errorMessage += 'Después de varios intentos, no se pudo conectar. Verifica tu conexión a internet.';
      } else {
        errorMessage += 'Intenta nuevamente.';
      }
      
      if (mounted) {
        setState(() {
          _error = errorMessage;
          _loading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_retryCount >= 3 
                ? 'Problema persistente de conexión'
                : 'Error de red (intento $_retryCount/3)'),
            action: SnackBarAction(
              label: 'Reintentar',
              onPressed: _load,
            ),
            duration: Duration(seconds: _retryCount >= 3 ? 5 : 3),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Widget _buildCastInfo(List<String> cast) {
    if (cast.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Reparto principal:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          cast.join(', '),
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isSeen = _movie != null && app.isWatched(_movie!.id);
    final isFav = _movie != null && app.isFavorite(_movie!.id);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado al azar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Color(0xFFFFD700),
            onPressed: _loading ? null : _load,
            tooltip: 'Volver a buscar',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? _LoadingSkeleton()
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _retryCount >= 3 ? Icons.wifi_off : Icons.error_outline,
                          size: 48,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Volver'),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: _load,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : _movie == null
                    ? const Center(child: Text('Sin resultados'))
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_movie!.posterUrl != null)
                              Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: _movie!.posterUrl!,
                                    width: 240,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 240,
                                      height: 360,
                                      color: Colors.grey.shade300,
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      width: 240,
                                      height: 360,
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.movie, size: 48),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              _movie!.title + (_movie!.releaseYear != null ? ' (${_movie!.releaseYear})' : ''),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            if (_movie!.voteAverage > 0)
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 20),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_movie!.voteAverage.toStringAsFixed(1)}/10',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            Text(_movie!.overview ?? 'Sin descripción'),
                            
                            // Información del reparto
                            _buildCastInfo(_movie!.cast),
                            
                            const SizedBox(height: 12),
                            const Text(
                              'Dónde ver:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            if (_providers.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: _providers.map((provider) => Chip(
                                  label: Text(provider),
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                )).toList(),
                              )
                            else
                              const Text(
                                'No disponible en streaming en tu región',
                                style: TextStyle(color: Colors.grey),
                              ),
                            
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _movie == null ? null : (isSeen ? () => app.removeFromWatched(_movie!.id) : _showRatingDialog),
                                    icon: Icon(isSeen ? Icons.visibility : Icons.visibility_outlined),
                                    label: Text(isSeen ? 'Vista' : 'Ya la vi'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _movie == null ? null : () => app.toggleFavorite(_movie!),
                                    icon: Icon(
                                      isFav ? Icons.bookmark : Icons.bookmark_border,
                                      color: isFav ? Colors.blue : null,
                                    ),
                                    label: const Text('Ver después'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              height: 360,
              width: 240,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 24, width: 250, color: Colors.white),
          const SizedBox(height: 8),
          Container(height: 16, width: 100, color: Colors.white),
          const SizedBox(height: 12),
          Container(height: 16, width: double.infinity, color: Colors.white),
          const SizedBox(height: 8),
          Container(height: 16, width: double.infinity, color: Colors.white),
          const SizedBox(height: 8),
          Container(height: 16, width: 200, color: Colors.white),
        ],
      ),
    );
  }
}