import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/favorite_rating_dialog.dart';
import '../widgets/movie_card.dart';
import '../services/share_service.dart';
import '../models/movie.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = app.favorites;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ver después'),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _shareFavoritesList(context, items, app),
              tooltip: 'Compartir lista',
            ),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('No hay películas guardadas para ver después'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final m = items[index];
                return MovieCard(
                  movie: m,
                  onTap: () => _showRatingDialog(context, m, app),
                );
              },
            ),
    );
  }

  void _showRatingDialog(BuildContext context, dynamic movie, AppState app) {
    showDialog(
      context: context,
      builder: (context) => FavoriteRatingDialog(
        movie: movie,
      ),
    );
  }

  Future<void> _shareFavoritesList(BuildContext context, List<dynamic> movies, AppState app) async {
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
      bool success = await ShareService.shareFavoritesListSimple(
        movies: movies.cast<Movie>(),
        userName: userName,
      );
      
      // Si falla, intentar copiar al clipboard como fallback
      if (!success) {
        success = await ShareService.copyToClipboard(
          movies: movies.cast<Movie>(),
          userName: userName,
          type: 'favoritas',
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
      print('Error compartiendo lista de favoritos: $e');
      
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
} 