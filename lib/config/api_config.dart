import 'package:flutter/foundation.dart';

class ApiConfig {
  // API Keys - SOLO para fallback si el backend falla
  static const String _groqApiKey = 'FALLBACK_KEY_ONLY';
  static const String _tmdbApiKey = 'FALLBACK_KEY_ONLY';
  
  // AdMob IDs - Tus IDs reales
  static const String _admobAppId = 'ca-app-pub-2605832983846978~4432926061';
  static const String _admobBannerId = 'ca-app-pub-2605832983846978/4432926061';
  static const String _admobInterstitialId = 'ca-app-pub-2605832983846978/4432926061';
  static const String _admobRewardedId = 'ca-app-pub-2605832983846978/4432926061';
  
  // Getters seguros
  static String get groqApiKey {
    if (kDebugMode) {
      return _groqApiKey;
    }
    // En producción, usar variables de entorno
    return const String.fromEnvironment('GROQ_API_KEY', defaultValue: _groqApiKey);
  }
  
  static String get tmdbApiKey {
    if (kDebugMode) {
      return _tmdbApiKey;
    }
    // En producción, usar variables de entorno
    return const String.fromEnvironment('TMDB_API_KEY', defaultValue: _tmdbApiKey);
  }
  
  static String get admobAppId {
    if (kDebugMode) {
      return _admobAppId;
    }
    return const String.fromEnvironment('ADMOB_APP_ID', defaultValue: _admobAppId);
  }
  
  static String get admobBannerId {
    if (kDebugMode) {
      return _admobBannerId;
    }
    return const String.fromEnvironment('ADMOB_BANNER_ID', defaultValue: _admobBannerId);
  }
  
  static String get admobInterstitialId {
    if (kDebugMode) {
      return _admobInterstitialId;
    }
    return const String.fromEnvironment('ADMOB_INTERSTITIAL_ID', defaultValue: _admobInterstitialId);
  }
  
  static String get admobRewardedId {
    if (kDebugMode) {
      return _admobRewardedId;
    }
    return const String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: _admobRewardedId);
  }
  
  // Validación de configuración
  static bool get isConfigured => 
    groqApiKey.isNotEmpty && 
    tmdbApiKey.isNotEmpty && 
    admobAppId.isNotEmpty;
}
