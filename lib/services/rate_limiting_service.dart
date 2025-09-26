import 'package:shared_preferences/shared_preferences.dart';

class RateLimitingService {
  static const String _dailyQueriesKey = 'daily_queries_count';
  static const String _lastResetDateKey = 'last_reset_date';
  static const int _maxQueriesPerDay = 10;
  
  // Singleton pattern
  static final RateLimitingService _instance = RateLimitingService._internal();
  factory RateLimitingService() => _instance;
  RateLimitingService._internal();

  /// Verifica si el usuario puede hacer una consulta
  Future<bool> canMakeQuery() async {
    await _resetCounterIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_dailyQueriesKey) ?? 0;
    return currentCount < _maxQueriesPerDay;
  }

  /// Registra una consulta realizada
  Future<void> recordQuery() async {
    await _resetCounterIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_dailyQueriesKey) ?? 0;
    await prefs.setInt(_dailyQueriesKey, currentCount + 1);
  }

  /// Obtiene el número de consultas restantes
  Future<int> getRemainingQueries() async {
    await _resetCounterIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_dailyQueriesKey) ?? 0;
    return _maxQueriesPerDay - currentCount;
  }

  /// Obtiene el número total de consultas realizadas hoy
  Future<int> getTodayQueriesCount() async {
    await _resetCounterIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailyQueriesKey) ?? 0;
  }

  /// Obtiene el tiempo restante hasta el próximo reset (en horas)
  Future<int> getHoursUntilReset() async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final difference = tomorrow.difference(now);
    return difference.inHours;
  }

  /// Obtiene el tiempo restante hasta el próximo reset (en minutos)
  Future<int> getMinutesUntilReset() async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final difference = tomorrow.difference(now);
    return difference.inMinutes % 60;
  }

  /// Resetea el contador si es un nuevo día
  Future<void> _resetCounterIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetDate = prefs.getString(_lastResetDateKey);
    final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD

    if (lastResetDate != today) {
      await prefs.setInt(_dailyQueriesKey, 0);
      await prefs.setString(_lastResetDateKey, today);
    }
  }

  /// Fuerza el reset del contador (útil para testing)
  Future<void> forceReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyQueriesKey, 0);
    await prefs.setString(_lastResetDateKey, DateTime.now().toIso8601String().split('T')[0]);
  }

  /// Obtiene información completa del estado actual
  Future<RateLimitInfo> getRateLimitInfo() async {
    await _resetCounterIfNeeded();
    final used = await getTodayQueriesCount();
    final remaining = await getRemainingQueries();
    final hoursUntilReset = await getHoursUntilReset();
    final minutesUntilReset = await getMinutesUntilReset();
    
    return RateLimitInfo(
      used: used,
      remaining: remaining,
      maxPerDay: _maxQueriesPerDay,
      hoursUntilReset: hoursUntilReset,
      minutesUntilReset: minutesUntilReset,
    );
  }
}

class RateLimitInfo {
  final int used;
  final int remaining;
  final int maxPerDay;
  final int hoursUntilReset;
  final int minutesUntilReset;

  RateLimitInfo({
    required this.used,
    required this.remaining,
    required this.maxPerDay,
    required this.hoursUntilReset,
    required this.minutesUntilReset,
  });

  bool get isLimitReached => remaining <= 0;
  
  String get timeUntilReset {
    if (hoursUntilReset > 0) {
      return '${hoursUntilReset}h ${minutesUntilReset}m';
    } else {
      return '${minutesUntilReset}m';
    }
  }
}
