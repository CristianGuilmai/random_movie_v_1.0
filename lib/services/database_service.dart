import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_profile.dart';
import '../models/conversation.dart';
import '../models/movie.dart';
import '../models/watched_movie.dart';
import '../models/user_preferences.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'movies_app.db';
  static const int _databaseVersion = 3;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getDatabasesPath();
    final path = join(documentsDirectory, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Tabla de perfil de usuario
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        last_active INTEGER NOT NULL
      )
    ''');

    // Tabla de conversaciones
    await db.execute('''
      CREATE TABLE conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_message TEXT NOT NULL,
        ai_response TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        recommended_movies TEXT
      )
    ''');

    // Tabla de películas para ver después (watchlist)
    await db.execute('''
      CREATE TABLE favorite_movies (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        overview TEXT,
        release_year TEXT,
        vote_average REAL,
        poster_url TEXT,
        cast TEXT,
        added_at INTEGER NOT NULL,
        user_rating INTEGER, -- Rating personal del usuario 1-5
        user_notes TEXT      -- Notas personales
      )
    ''');

    // Tabla de películas ya vistas
    await db.execute('''
      CREATE TABLE watched_movies (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        overview TEXT,
        release_year TEXT,
        vote_average REAL NOT NULL,
        poster_url TEXT,
        cast TEXT,
        user_rating REAL NOT NULL,
        watched_at INTEGER NOT NULL
      )
    ''');

    // Tabla de preferencias del usuario
    await db.execute('''
      CREATE TABLE user_preferences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT,
        favorite_genres TEXT,
        favorite_actors TEXT,
        favorite_directors TEXT,
        is_first_time INTEGER NOT NULL DEFAULT 1,
        last_recommendation_date INTEGER,
        recommendation_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Agregar tabla de películas ya vistas
      await db.execute('''
        CREATE TABLE watched_movies (
          id INTEGER PRIMARY KEY,
          title TEXT NOT NULL,
          overview TEXT,
          release_year TEXT,
          vote_average REAL NOT NULL,
          poster_url TEXT,
          cast TEXT,
          user_rating REAL NOT NULL,
          watched_at INTEGER NOT NULL
        )
      ''');
    }
    
    if (oldVersion < 3) {
      // Agregar tabla de preferencias del usuario
      await db.execute('''
        CREATE TABLE user_preferences (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          description TEXT,
          favorite_genres TEXT,
          favorite_actors TEXT,
          favorite_directors TEXT,
          is_first_time INTEGER NOT NULL DEFAULT 1,
          last_recommendation_date INTEGER,
          recommendation_count INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
    }
  }

  // Métodos para UserProfile
  Future<int> insertUserProfile(UserProfile profile) async {
    final db = await database;
    return await db.insert('user_profile', profile.toMap());
  }

  Future<UserProfile?> getUserProfile() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('user_profile', limit: 1);

    if (maps.isNotEmpty) {
      return UserProfile.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    final db = await database;
    await db.update(
      'user_profile',
      profile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  // Métodos para Conversaciones
  Future<int> insertConversation(Conversation conversation) async {
    final db = await database;
    return await db.insert('conversations', conversation.toMap());
  }

  Future<List<Conversation>> getRecentConversations({int limit = 10}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'conversations',
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) => Conversation.fromMap(maps[i]));
  }

  // Métodos para Películas "Ver después" (watchlist)
  // Método para agregar película a "ver después"
  Future<void> insertFavoriteMovie(Movie movie, {int? userRating, String? userNotes}) async {
    final db = await database;
    await db.insert(
      'favorite_movies',
      {
        'id': movie.id,
        'title': movie.title,
        'overview': movie.overview,
        'release_year': movie.releaseYear,
        'vote_average': movie.voteAverage,
        'poster_url': movie.posterUrl,
        'cast': movie.cast.join(','),
        'added_at': DateTime.now().millisecondsSinceEpoch,
        'user_rating': userRating,
        'user_notes': userNotes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Movie>> getFavoriteMovies() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'favorite_movies',
      orderBy: 'added_at DESC',
    );

    return List.generate(maps.length, (i) {
      return Movie(
        id: maps[i]['id'],
        title: maps[i]['title'],
        overview: maps[i]['overview'],
        releaseYear: maps[i]['release_year'],
        voteAverage: maps[i]['vote_average'] ?? 0.0,
        posterUrl: maps[i]['poster_url'],
        cast: maps[i]['cast']?.split(',') ?? [],
      );
    });
  }

  Future<void> removeFavoriteMovie(int movieId) async {
    final db = await database;
    await db.delete('favorite_movies', where: 'id = ?', whereArgs: [movieId]);
  }

  Future<String> getFavoriteMoviesForPrompt() async {
    final movies = await getFavoriteMovies();
    if (movies.isEmpty) return "El usuario aún no tiene películas guardadas para ver después.";

    final movieTitles = movies.take(10).map((m) => "${m.title} (${m.releaseYear})").join(", ");
    return "Películas guardadas para ver después: $movieTitles";
  }

  // Métodos para películas ya vistas
  Future<void> insertWatchedMovie(WatchedMovie watchedMovie) async {
    final db = await database;
    await db.insert(
      'watched_movies',
      {
        'id': watchedMovie.movie.id,
        'title': watchedMovie.movie.title,
        'overview': watchedMovie.movie.overview,
        'release_year': watchedMovie.movie.releaseYear,
        'vote_average': watchedMovie.movie.voteAverage,
        'poster_url': watchedMovie.movie.posterUrl,
        'cast': watchedMovie.movie.cast.join(','),
        'user_rating': watchedMovie.userRating,
        'watched_at': watchedMovie.watchedAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<WatchedMovie>> getWatchedMovies() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'watched_movies',
      orderBy: 'watched_at DESC',
    );

    return List.generate(maps.length, (i) {
      return WatchedMovie(
        movie: Movie(
          id: maps[i]['id'],
          title: maps[i]['title'],
          overview: maps[i]['overview'],
          releaseYear: maps[i]['release_year'],
          voteAverage: maps[i]['vote_average'] ?? 0.0,
          posterUrl: maps[i]['poster_url'],
          cast: maps[i]['cast']?.split(',') ?? [],
        ),
        userRating: maps[i]['user_rating'],
        watchedAt: DateTime.fromMillisecondsSinceEpoch(maps[i]['watched_at']),
      );
    });
  }

  Future<void> removeWatchedMovie(int movieId) async {
    final db = await database;
    await db.delete('watched_movies', where: 'id = ?', whereArgs: [movieId]);
  }

  Future<void> updateWatchedMovieRating(int movieId, double newRating) async {
    final db = await database;
    await db.update(
      'watched_movies',
      {'user_rating': newRating},
      where: 'id = ?',
      whereArgs: [movieId],
    );
  }

  Future<String> getWatchedMoviesForPrompt() async {
    final watchedMovies = await getWatchedMovies();
    if (watchedMovies.isEmpty) return "El usuario aún no ha calificado películas.";

    final movieInfo = watchedMovies.take(10).map((wm) => 
      "${wm.movie.title} (${wm.movie.releaseYear}) - Calificación del usuario: ${wm.userRating}/10"
    ).join(", ");
    
    final avgRating = watchedMovies.map((w) => w.userRating).reduce((a, b) => a + b) / watchedMovies.length;
    
    return "Películas ya vistas y calificadas por el usuario: $movieInfo. Calificación promedio del usuario: ${avgRating.toStringAsFixed(1)}/10";
  }

  // Método para obtener películas calificadas para análisis de IA
  Future<List<Map<String, dynamic>>> getRatedMoviesForPrompt() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'watched_movies',
      where: 'user_rating IS NOT NULL',
      orderBy: 'watched_at DESC',
    );

    return maps.map((map) => {
      'id': map['id'],
      'title': map['title'],
      'userRating': map['user_rating'],
      'genres': 'Drama, Acción', // TODO: Agregar géneros a la base de datos
      'voteAverage': map['vote_average'],
      'watchedAt': map['watched_at'],
    }).toList();
  }

  // Método para obtener lista de películas ya vistas (solo títulos)
  Future<List<Map<String, dynamic>>> getWatchedMoviesList() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'watched_movies',
      columns: ['id', 'title', 'user_rating'],
      orderBy: 'watched_at DESC',
    );

    return maps.map((map) => {
      'id': map['id'],
      'title': map['title'],
      'userRating': map['user_rating'],
    }).toList();
  }

  // Métodos para preferencias del usuario
  Future<void> saveUserPreferences(UserPreferences preferences) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert(
      'user_preferences',
      {
        'description': preferences.description,
        'favorite_genres': preferences.favoriteGenres.join(','),
        'favorite_actors': preferences.favoriteActors.join(','),
        'favorite_directors': preferences.favoriteDirectors.join(','),
        'is_first_time': preferences.isFirstTime ? 1 : 0,
        'last_recommendation_date': preferences.lastRecommendationDate?.millisecondsSinceEpoch,
        'recommendation_count': preferences.recommendationCount,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserPreferences?> getUserPreferences() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_preferences',
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return UserPreferences(
      description: map['description'],
      favoriteGenres: map['favorite_genres']?.toString().split(',') ?? [],
      favoriteActors: map['favorite_actors']?.toString().split(',') ?? [],
      favoriteDirectors: map['favorite_directors']?.toString().split(',') ?? [],
      isFirstTime: map['is_first_time'] == 1,
      lastRecommendationDate: map['last_recommendation_date'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['last_recommendation_date'])
          : null,
      recommendationCount: map['recommendation_count'] ?? 0,
    );
  }

  Future<void> updateRecommendationCount() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.rawUpdate('''
      UPDATE user_preferences 
      SET recommendation_count = recommendation_count + 1,
          last_recommendation_date = ?,
          updated_at = ?
      WHERE id = (SELECT id FROM user_preferences ORDER BY updated_at DESC LIMIT 1)
    ''', [now, now]);
  }

  Future<void> markFirstTimeCompleted() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.rawUpdate('''
      UPDATE user_preferences 
      SET is_first_time = 0,
          updated_at = ?
      WHERE id = (SELECT id FROM user_preferences ORDER BY updated_at DESC LIMIT 1)
    ''', [now]);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}