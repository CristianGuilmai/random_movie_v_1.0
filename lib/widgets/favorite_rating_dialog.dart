import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/movie.dart';

class FavoriteRatingDialog extends StatefulWidget {
  final Movie movie;

  const FavoriteRatingDialog({
    super.key,
    required this.movie,
  });

  @override
  State<FavoriteRatingDialog> createState() => _FavoriteRatingDialogState();
}

class _FavoriteRatingDialogState extends State<FavoriteRatingDialog> {
  double _rating = 5.0;
  bool _hasWatched = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Ya viste esta película?', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.98,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Información de la película
          Row(
            children: [
              if (widget.movie.posterUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    widget.movie.posterUrl!,
                    width: 50,
                    height: 75,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 50,
                      height: 75,
                      color: Colors.grey,
                      child: const Icon(Icons.movie, size: 20),
                    ),
                  ),
                )
              else
                Container(
                  width: 50,
                  height: 75,
                  color: Colors.grey,
                  child: const Icon(Icons.movie, size: 20),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.movie.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.movie.releaseYear != null)
                      Text(
                        'Año: ${widget.movie.releaseYear}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (widget.movie.voteAverage > 0)
                      Text(
                        '⭐ ${widget.movie.voteAverage.toStringAsFixed(1)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Pregunta si ya la vio
          const Text(
            '¿Ya viste esta película?',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          
          // Botones de respuesta (solo se muestran si no se ha seleccionado "Sí")
          if (!_hasWatched)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _hasWatched = false);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('No', style: TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _hasWatched = true);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Sí', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ),
          
          // Calificación si ya la vio
          if (_hasWatched) ...[
            const SizedBox(height: 20),
            const Text(
              '¿Cómo la calificarías?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            
            // Slider de calificación
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('0'),
                    Text(
                      _rating.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Text('10'),
                  ],
                ),
                Slider(
                  value: _rating,
                  min: 0.0,
                  max: 10.0,
                  divisions: 20,
                  label: _rating.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() => _rating = value);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSimpleRatingButton(1.0),
                    _buildSimpleRatingButton(3.0),
                    _buildSimpleRatingButton(5.0),
                    _buildSimpleRatingButton(7.0),
                    _buildSimpleRatingButton(9.0),
                  ],
                ),
              ],
            ),
          ],
        ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: const Text('Cancelar', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  final app = context.read<AppState>();
                  
                  if (_hasWatched) {
                    // Agregar a películas vistas con calificación
                    await app.addToWatched(widget.movie, _rating);
                  }
                  
                  // Remover de favoritos
                  await app.toggleFavorite(widget.movie);
                  
                  if (mounted) {
                    Navigator.of(context).pop();
                    
                    // Mostrar mensaje de confirmación
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _hasWatched 
                              ? 'Película movida a "Ya vistas" con calificación ${_rating.toStringAsFixed(1)} ⭐'
                              : 'Película removida de "Ver después"',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(
                  _hasWatched ? 'Guardar y remover' : 'Solo remover',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSimpleRatingButton(double rating) {
    final isSelected = (_rating - rating).abs() < 0.5;
    
    return GestureDetector(
      onTap: () {
        setState(() => _rating = rating);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
        ),
        child: Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
      ),
    );
  }
}
