import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../state/app_state.dart';
import '../services/share_service.dart';
import '../models/movie.dart';
import '../models/watched_movie.dart';

class SharedListScreen extends StatefulWidget {
  final Map<String, dynamic> sharedData;

  const SharedListScreen({
    super.key,
    required this.sharedData,
  });

  @override
  State<SharedListScreen> createState() => _SharedListScreenState();
}

class _SharedListScreenState extends State<SharedListScreen> {
  List<Movie> _movies = [];
  List<WatchedMovie> _watchedMovies = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _parseSharedData();
  }

  void _parseSharedData() {
    try {
      final items = widget.sharedData['items'] as List<dynamic>;
      final listType = widget.sharedData['type'] as String;
      
      if (listType == 'favorites') {
        _movies = ShareService.parseSharedMovies(items);
      } else if (listType == 'watched') {
        _watchedMovies = ShareService.parseSharedWatchedMovies(items);
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar la lista compartida: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveList() async {
    final app = context.read<AppState>();
    final listType = widget.sharedData['type'] as String;
    
    try {
      if (listType == 'favorites') {
        // Agregar todas las películas a favoritos
        for (final movie in _movies) {
          if (!app.isFavorite(movie.id)) {
            await app.toggleFavorite(movie);
          }
        }
      } else if (listType == 'watched') {
        // Agregar todas las películas vistas
        for (final watchedMovie in _watchedMovies) {
          if (!app.isWatched(watchedMovie.movie.id)) {
            await app.addToWatched(watchedMovie.movie, watchedMovie.userRating);
          }
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              listType == 'favorites' 
                  ? 'Lista guardada en "Ver después"'
                  : 'Lista guardada en "Ya vistas"',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar la lista: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMovieItem(Movie movie) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: movie.posterUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: movie.posterUrl!,
                  width: 40,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 40,
                    height: 60,
                    color: Colors.grey,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 40,
                    height: 60,
                    color: Colors.grey,
                    child: const Icon(Icons.movie),
                  ),
                ),
              )
            : Container(
                width: 40,
                height: 60,
                color: Colors.grey,
                child: const Icon(Icons.movie),
              ),
        title: Text(movie.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                    if (movie.releaseYear != null)
                      Text('Año: ${movie.releaseYear}'),
            if (movie.voteAverage > 0)
              Text('⭐ ${movie.voteAverage.toStringAsFixed(1)}'),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          context.go('/detail', extra: movie);
        },
      ),
    );
  }

  Widget _buildWatchedMovieItem(WatchedMovie watchedMovie) {
    final movie = watchedMovie.movie;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: movie.posterUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: movie.posterUrl!,
                  width: 40,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 40,
                    height: 60,
                    color: Colors.grey,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 40,
                    height: 60,
                    color: Colors.grey,
                    child: const Icon(Icons.movie),
                  ),
                ),
              )
            : Container(
                width: 40,
                height: 60,
                color: Colors.grey,
                child: const Icon(Icons.movie),
              ),
        title: Text(movie.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                    if (movie.releaseYear != null)
                      Text('Año: ${movie.releaseYear}'),
            Row(
              children: [
                Text('⭐ ${movie.voteAverage.toStringAsFixed(1)}'),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${watchedMovie.userRating.toStringAsFixed(1)} ⭐',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          context.go('/detail', extra: movie);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando lista...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      );
    }

    final userName = widget.sharedData['userName'] as String? ?? 'Usuario';
    final listType = widget.sharedData['type'] as String;
    final itemCount = listType == 'favorites' ? _movies.length : _watchedMovies.length;
    final listTitle = listType == 'favorites' ? 'Ver después' : 'Ya vistas';

    return Scaffold(
      appBar: AppBar(
        title: Text('$listTitle de $userName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveList,
            tooltip: 'Guardar lista',
          ),
        ],
      ),
      body: Column(
        children: [
          // Información de la lista
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      listType == 'favorites' ? Icons.bookmark : Icons.visibility,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$listTitle de $userName',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('$itemCount películas'),
                const SizedBox(height: 8),
                Text(
                  'Compartido desde RandomPeli',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de películas
          Expanded(
            child: listType == 'favorites'
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _movies.length,
                    itemBuilder: (context, index) => _buildMovieItem(_movies[index]),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _watchedMovies.length,
                    itemBuilder: (context, index) => _buildWatchedMovieItem(_watchedMovies[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveList,
        icon: const Icon(Icons.save),
        label: const Text('Guardar lista'),
      ),
    );
  }
}
