import 'dart:convert';

class Movie {
  final int id;
  final String title;
  final String? overview;
  final String? releaseYear;
  final double voteAverage;
  final String? posterUrl;
  final List<String> cast; // Nuevo campo para actores

  Movie({
    required this.id,
    required this.title,
    required this.overview,
    required this.releaseYear,
    required this.voteAverage,
    required this.posterUrl,
    this.cast = const [],
  });

  factory Movie.fromTmdbJson(Map<String, dynamic> json) {
    final String? posterPath = json['poster_path'];
    final String? releaseDate = json['release_date'];
    return Movie(
      id: json['id'] as int,
      title: (json['title'] ?? json['name'] ?? '').toString(),
      overview: (json['overview'] as String?)?.trim(),
      releaseYear: (releaseDate != null && releaseDate.isNotEmpty)
          ? releaseDate.substring(0, 4)
          : null,
      voteAverage: (json['vote_average'] != null && json['vote_average'] is num)
          ? (json['vote_average'] as num).toDouble()
          : 0.0,
      posterUrl: posterPath != null
          ? 'https://image.tmdb.org/t/p/w500$posterPath'
          : null,
      cast: [], // Se llenará desde el servicio
    );
  }

  // Método para crear una copia con cast incluido
  Movie copyWith({
    int? id,
    String? title,
    String? overview,
    String? releaseYear,
    double? voteAverage,
    String? posterUrl,
    List<String>? cast,
  }) {
    return Movie(
      id: id ?? this.id,
      title: title ?? this.title,
      overview: overview ?? this.overview,
      releaseYear: releaseYear ?? this.releaseYear,
      voteAverage: voteAverage ?? this.voteAverage,
      posterUrl: posterUrl ?? this.posterUrl,
      cast: cast ?? this.cast,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'overview': overview,
        'releaseYear': releaseYear,
        'voteAverage': voteAverage,
        'posterUrl': posterUrl,
        'cast': cast,
      };

  static Movie fromJson(Map<String, dynamic> json) => Movie(
        id: json['id'] as int,
        title: json['title'] as String,
        overview: json['overview'] as String?,
        releaseYear: json['releaseYear'] as String?,
        voteAverage: (json['voteAverage'] as num).toDouble(),
        posterUrl: json['posterUrl'] as String?,
        cast: List<String>.from(json['cast'] ?? []),
      );

  static String encodeList(List<Movie> movies) => jsonEncode(
        movies.map((m) => m.toJson()).toList(),
      );

  static List<Movie> decodeList(String source) {
    final List<dynamic> data = jsonDecode(source) as List<dynamic>;
    return data.map((e) => Movie.fromJson(e as Map<String, dynamic>)).toList();
  }
}