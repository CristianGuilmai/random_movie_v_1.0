class Conversation {
  final int? id;
  final String userMessage;
  final String aiResponse;
  final DateTime timestamp;
  final List<String> recommendedMovies; // IDs de películas recomendadas

  Conversation({
    this.id,
    required this.userMessage,
    required this.aiResponse,
    required this.timestamp,
    this.recommendedMovies = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_message': userMessage,
      'ai_response': aiResponse,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'recommended_movies': recommendedMovies.join(','),
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'],
      userMessage: map['user_message'],
      aiResponse: map['ai_response'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      recommendedMovies: map['recommended_movies']?.split(',') ?? [],
    );
  }
}