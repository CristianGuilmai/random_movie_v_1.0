import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'router/app_router.dart';
import 'state/app_state.dart';
import 'services/ad_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar AdMob
  await AdService.initialize();

  // Iniciales según requerimiento: es-ES, excluir +18, tema oscuro
  final appState = AppState(
    initialExcludeAdult: false,
    initialLanguage: 'es-ES',
    initialThemeMode: ThemeMode.dark,
  );
  await appState.loadFromPrefs();

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return MaterialApp.router(
      title: 'Random Movies',
      debugShowCheckedModeBanner: false,
      themeMode: app.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      routerConfig: appRouter,
    );
  }
}