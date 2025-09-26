import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../models/watched_movie.dart';

class WatchedMovieCard extends StatelessWidget {
  final WatchedMovie watchedMovie;
  final VoidCallback? onTap;

  const WatchedMovieCard({
    super.key,
    required this.watchedMovie,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final movie = watchedMovie.movie;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: InkWell(
          onTap: onTap ?? () => context.pushNamed('detail', extra: movie),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Poster
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: movie.posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: movie.posterUrl!,
                          width: 80,
                          height: 120,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 80,
                            height: 120,
                            color: Colors.grey.shade300,
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 80,
                            height: 120,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.movie),
                          ),
                        )
                      : Container(
                          width: 80,
                          height: 120,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.movie),
                        ),
                ),
                const SizedBox(width: 16),
                // Información
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        movie.releaseYear ?? 'N/A',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Calificación del usuario (azul)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.blue, size: 14),
                                const SizedBox(width: 2),
                                Text(
                                  '${watchedMovie.userRating.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Calificación de TMDB (naranja)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.orange, size: 14),
                                const SizedBox(width: 2),
                                Text(
                                  movie.voteAverage.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
