import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../models/watched_movie.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/watched_movie_card.dart';
import '../services/share_service.dart';

class WatchedScreen extends StatelessWidget {
  const WatchedScreen({super.key});

  Future<void> _showRatingDialog(BuildContext context, WatchedMovie watchedMovie) async {
    final app = context.read<AppState>();
    
    final rating = await showDialog<double>(
      context: context,
      builder: (context) => RatingDialog(
        movie: watchedMovie.movie,
        initialRating: watchedMovie.userRating,
      ),
    );

    if (rating != null && context.mounted) {
      await app.updateWatchedRating(watchedMovie.movie.id, rating);
    }
  }


  Future<void> _shareWatchedList(BuildContext context, List<WatchedMovie> movies, AppState app) async {
    // Mostrar spinner de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Compartiendo lista...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final userName = app.userProfile?.name ?? 'Usuario';
      
      // Intentar compartir con método simple (mejor para emuladores)
      bool success = await ShareService.shareWatchedListSimple(
        watchedMovies: movies,
        userName: userName,
      );
      
      // Si falla, intentar copiar al clipboard como fallback
      if (!success) {
        success = await ShareService.copyWatchedToClipboard(
          watchedMovies: movies,
          userName: userName,
        );
      }
      
      // Cerrar el spinner
      if (context.mounted) {
        Navigator.of(context).pop();
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lista copiada al portapapeles! 🎬'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo compartir la lista. Intenta de nuevo.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error compartiendo lista de vistas: $e');
      
      // Cerrar el spinner
      if (context.mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al compartir. Verifica que tengas una app de mensajería instalada.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = app.watched;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ya vistas'),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _shareWatchedList(context, items, app),
              tooltip: 'Compartir lista',
            ),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('Aún no has marcado películas como vistas'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final watchedMovie = items[index];
                return WatchedMovieCard(
                  watchedMovie: watchedMovie,
                  onTap: () => _showRatingDialog(context, watchedMovie),
                );
              },
            ),
    );
  }
}
