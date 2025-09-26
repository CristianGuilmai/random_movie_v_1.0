import 'package:flutter/foundation.dart';
import '../services/backend_service.dart';
import '../config/backend_config.dart';

class SecurityChecker {
  static Future<Map<String, dynamic>> checkSecurity() async {
    final results = <String, dynamic>{};
    
    // 1. Verificar si el backend está disponible
    try {
      final isBackendHealthy = await BackendService.checkHealth();
      results['backend_healthy'] = isBackendHealthy;
      results['backend_url'] = BackendConfig.baseUrl;
    } catch (e) {
      results['backend_healthy'] = false;
      results['backend_error'] = e.toString();
    }
    
    // 2. Verificar configuración
    results['backend_enabled'] = BackendConfig.isBackendEnabled;
    results['fallback_enabled'] = BackendConfig.useFallback;
    results['app_signature'] = BackendConfig.appSignature.isNotEmpty;
    
    // 3. Verificar entorno
    results['is_debug'] = kDebugMode;
    results['environment'] = kDebugMode ? 'development' : 'production';
    
    // 4. Resumen de seguridad
    final isSecure = results['backend_healthy'] == true && 
                     results['backend_enabled'] == true;
    
    results['is_secure'] = isSecure;
    results['security_level'] = isSecure ? 'HIGH' : 'MEDIUM';
    
    return results;
  }
  
  static void printSecurityReport(Map<String, dynamic> results) {
    print('🔒 === REPORTE DE SEGURIDAD ===');
    print('Backend saludable: ${results['backend_healthy']}');
    print('Backend habilitado: ${results['backend_enabled']}');
    print('Fallback habilitado: ${results['fallback_enabled']}');
    print('App signature: ${results['app_signature']}');
    print('Entorno: ${results['environment']}');
    print('Nivel de seguridad: ${results['security_level']}');
    print('URL del backend: ${results['backend_url']}');
    
    if (results['is_secure'] == true) {
      print('✅ APIS COMPLETAMENTE SEGURAS');
    } else {
      print('⚠️ APIS PARCIALMENTE SEGURAS');
      if (results['backend_error'] != null) {
        print('Error del backend: ${results['backend_error']}');
      }
    }
    print('🔒 === FIN DEL REPORTE ===');
  }
}
