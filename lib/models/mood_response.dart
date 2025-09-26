class MovieRecommendation {
  final String titulo;
  final int? ano;
  final String razon;
  final String genero;

  MovieRecommendation({
    required this.titulo,
    this.ano,
    required this.razon,
    required this.genero,
  });

  factory MovieRecommendation.fromJson(Map<String, dynamic> json) {
    return MovieRecommendation(
      titulo: json['titulo'] ?? '',
      ano: json['ano'],
      razon: json['razon'] ?? '',
      genero: json['genero'] ?? '',
    );
  }
}

class MoodResponse {
  final String estado;
  final List<MovieRecommendation> peliculas;
  String? conversationalResponse; // Nueva propiedad para respuestas de chat

  MoodResponse({
    required this.estado,
    required this.peliculas,
    this.conversationalResponse,
  });

  factory MoodResponse.fromJson(Map<String, dynamic> json) {
    final peliculasList = (json['peliculas'] as List<dynamic>? ?? [])
        .map((p) => MovieRecommendation.fromJson(p as Map<String, dynamic>))
        .toList();

    return MoodResponse(
      estado: json['estado'] ?? '',
      peliculas: peliculasList,
    );
  }
}