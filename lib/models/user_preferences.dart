class UserPreferences {
  final String? description;
  final List<String> favoriteGenres;
  final List<String> favoriteActors;
  final List<String> favoriteDirectors;
  final bool isFirstTime;
  final DateTime? lastRecommendationDate;
  final int recommendationCount;

  UserPreferences({
    this.description,
    this.favoriteGenres = const [],
    this.favoriteActors = const [],
    this.favoriteDirectors = const [],
    this.isFirstTime = true,
    this.lastRecommendationDate,
    this.recommendationCount = 0,
  });

  UserPreferences copyWith({
    String? description,
    List<String>? favoriteGenres,
    List<String>? favoriteActors,
    List<String>? favoriteDirectors,
    bool? isFirstTime,
    DateTime? lastRecommendationDate,
    int? recommendationCount,
  }) {
    return UserPreferences(
      description: description ?? this.description,
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      favoriteActors: favoriteActors ?? this.favoriteActors,
      favoriteDirectors: favoriteDirectors ?? this.favoriteDirectors,
      isFirstTime: isFirstTime ?? this.isFirstTime,
      lastRecommendationDate: lastRecommendationDate ?? this.lastRecommendationDate,
      recommendationCount: recommendationCount ?? this.recommendationCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'favoriteGenres': favoriteGenres,
      'favoriteActors': favoriteActors,
      'favoriteDirectors': favoriteDirectors,
      'isFirstTime': isFirstTime,
      'lastRecommendationDate': lastRecommendationDate?.millisecondsSinceEpoch,
      'recommendationCount': recommendationCount,
    };
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      description: json['description'],
      favoriteGenres: List<String>.from(json['favoriteGenres'] ?? []),
      favoriteActors: List<String>.from(json['favoriteActors'] ?? []),
      favoriteDirectors: List<String>.from(json['favoriteDirectors'] ?? []),
      isFirstTime: json['isFirstTime'] ?? true,
      lastRecommendationDate: json['lastRecommendationDate'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['lastRecommendationDate'])
          : null,
      recommendationCount: json['recommendationCount'] ?? 0,
    );
  }

  bool get hasPreferences => description != null || favoriteGenres.isNotEmpty || favoriteActors.isNotEmpty || favoriteDirectors.isNotEmpty;
}
