import 'dart:convert';
import 'movie.dart';

class WatchedMovie {
  final Movie movie;
  final double userRating; // Calificación del usuario (1-10)
  final DateTime watchedAt; // Fecha cuando se marcó como vista

  WatchedMovie({
    required this.movie,
    required this.userRating,
    required this.watchedAt,
  });

  // Validar que la calificación esté en el rango correcto
  static double _validateRating(double rating) {
    if (rating < 1.0) return 1.0;
    if (rating > 10.0) return 10.0;
    return rating;
  }

  WatchedMovie copyWith({
    Movie? movie,
    double? userRating,
    DateTime? watchedAt,
  }) {
    return WatchedMovie(
      movie: movie ?? this.movie,
      userRating: userRating != null ? _validateRating(userRating) : this.userRating,
      watchedAt: watchedAt ?? this.watchedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'movie': movie.toJson(),
        'userRating': userRating,
        'watchedAt': watchedAt.toIso8601String(),
      };

  factory WatchedMovie.fromJson(Map<String, dynamic> json) => WatchedMovie(
        movie: Movie.fromJson(json['movie'] as Map<String, dynamic>),
        userRating: (json['userRating'] as num).toDouble(),
        watchedAt: DateTime.parse(json['watchedAt'] as String),
      );

  static String encodeList(List<WatchedMovie> watchedMovies) => jsonEncode(
        watchedMovies.map((wm) => wm.toJson()).toList(),
      );

  static List<WatchedMovie> decodeList(String source) {
    final List<dynamic> data = jsonDecode(source) as List<dynamic>;
    return data.map((e) => WatchedMovie.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchedMovie &&
          runtimeType == other.runtimeType &&
          movie.id == other.movie.id;

  @override
  int get hashCode => movie.id.hashCode;
}
