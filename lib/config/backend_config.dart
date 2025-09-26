class BackendConfig {
  // URLs del backend - Cambiar por tu URL real
  static const String _productionUrl = 'https://web-production-e93e.up.railway.app';
  
  // Obtener URL según el entorno
  static String get baseUrl {
    // Siempre usar la URL de producción para Railway
    return _productionUrl;
  }
  
  // Signature de la app
  static const String appSignature = 'randomovie_2024_secure_signature';
  
  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Rate limiting
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // Headers comunes
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'x-app-signature': appSignature,
    'User-Agent': 'Randomovie/1.0.0',
  };
  
  // Verificar si el backend está disponible
  static bool get isBackendEnabled => true; // SIEMPRE usar backend
  
  // Configuración de fallback
  static bool get useFallback => false; // NO usar APIs directas - solo backend seguro
}
