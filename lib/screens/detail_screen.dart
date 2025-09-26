import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/movie.dart';
import '../state/app_state.dart';
import '../widgets/rating_dialog.dart';
import '../services/secure_service.dart';

class DetailScreen extends StatefulWidget {
  final Movie movie;
  const DetailScreen({super.key, required this.movie});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  List<String> _providers = [];
  bool _loadingProviders = false;

  @override
  void initState() {
    super.initState();
    _loadWatchProviders();
  }

  Future<void> _loadWatchProviders() async {
    setState(() {
      _loadingProviders = true;
    });

    try {
      // Usar SecureService en lugar de TmdbService directo
      // final service = TmdbService(...); // Removido - usar backend
      
      final providers = await SecureService.getWatchProviders(movieId: widget.movie.id);
      
      if (mounted) {
        setState(() {
          _providers = providers;
          _loadingProviders = false;
        });
      }
    } catch (e) {
      print('Error loading watch providers: $e');
      if (mounted) {
        setState(() {
          _loadingProviders = false;
        });
      }
    }
  }

  Widget _buildCastSection(List<String> cast, BuildContext context) {
    if (cast.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Reparto principal',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: cast.map((actor) => Chip(
            label: Text(actor),
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRatingDialog() async {
    final app = context.read<AppState>();
    final watchedMovie = app.getWatchedMovie(widget.movie.id);
    
    final rating = await showDialog<double>(
      context: context,
      builder: (context) => RatingDialog(
        movie: widget.movie,
        initialRating: watchedMovie?.userRating,
      ),
    );
    
    if (rating != null) {
      await app.addToWatched(widget.movie, rating);
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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isFav = app.isFavorite(widget.movie.id);
    final isSeen = app.isWatched(widget.movie.id);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.movie.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Agregar padding inferior para evitar la barra de navegación
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster y información básica
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster
                if (widget.movie.posterUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: widget.movie.posterUrl!,
                      width: 120,
                      height: 180,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 120,
                        height: 180,
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 120,
                        height: 180,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.movie, size: 48),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 120,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.movie, size: 48),
                  ),
                const SizedBox(width: 16),
                
                // Información básica
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.movie.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.movie.releaseYear != null) ...[
                        const SizedBox(height: 4),
                        _buildInfoRow(
                          Icons.calendar_today,
                          'Año',
                            widget.movie.releaseYear!, context),
                      ],
                      if (widget.movie.voteAverage > 0) ...[
                        const SizedBox(height: 4),
                        _buildInfoRow(
                          Icons.star,
                          'Puntuación',
                          '${widget.movie.voteAverage.toStringAsFixed(1)}/10',
                          context,
                        ),
                      ],
                      const SizedBox(height: 12),
                      
                      // Botones de acción
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isSeen ? () => app.removeFromWatched(widget.movie.id) : _showRatingDialog,
                              icon: Icon(
                                isSeen ? Icons.visibility : Icons.visibility_outlined,
                                size: 16,
                              ),
                              label: Text(
                                isSeen ? 'Vista' : 'Marcar vista',
                                style: const TextStyle(fontSize: 11),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSeen ? Colors.green : null,
                                foregroundColor: isSeen ? Colors.white : null,
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isSeen ? null : () => app.toggleFavorite(widget.movie),
                              icon: Icon(
                                isFav ? Icons.bookmark : Icons.bookmark_border,
                                size: 16,
                                color: isFav ? Colors.blue : (isSeen ? Colors.grey : null),
                              ),
                              label: Text(
                                'Ver después',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSeen ? Colors.grey : null,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Sinopsis
            if (widget.movie.overview != null && widget.movie.overview!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Sinopsis',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.movie.overview!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
                textAlign: TextAlign.justify,
              ),
            ],
            
            // Reparto
            _buildCastSection(widget.movie.cast, context),
            
            // Dónde ver
            if (_providers.isNotEmpty || _loadingProviders) ...[
              const SizedBox(height: 24),
              Text(
                'Dónde ver:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_loadingProviders)
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Cargando plataformas...'),
                  ],
                )
              else if (_providers.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _providers.map((provider) => Chip(
                    label: Text(provider),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  )).toList(),
                )
              else
                Text(
                  'No hay información de plataformas disponibles',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}