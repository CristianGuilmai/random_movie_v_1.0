import 'package:flutter/material.dart';
import '../models/movie.dart';

class RatingDialog extends StatefulWidget {
  final Movie movie;
  final double? initialRating;

  const RatingDialog({
    super.key,
    required this.movie,
    this.initialRating,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late double _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating ?? 5.0;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar calificación', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.95,
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
          
          // Calificación
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
              // Botones de calificación rápida sin emojis
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
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar', style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  if (mounted) {
                    Navigator.of(context).pop(_rating);
                  }
                },
                child: const Text('Guardar', style: TextStyle(fontSize: 14)),
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