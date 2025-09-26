import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<String> languages = ['es-ES', 'en-US', 'pt-BR'];
  static const List<String> languageNames = ['Español', 'English', 'Português'];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final safeLanguage = languages.contains(app.languageCode) ? app.languageCode : languages.first;
    final languageIndex = languages.indexOf(safeLanguage);
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Excluir contenido +18'),
            value: app.excludeAdult,
            onChanged: (v) => app.setExcludeAdult(v),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Idioma'),
            subtitle: Text(languageNames[languageIndex]),
            trailing: DropdownButton<String>(
              value: safeLanguage,
              items: languages.asMap().entries
                  .map((entry) => DropdownMenuItem(
                    value: entry.value, 
                    child: Text(languageNames[entry.key])
                  ))
                  .toList(),
              onChanged: (v) {
                if (v != null) app.setLanguage(v);
              },
            ),
          ),
          const Divider(height: 32),
          ListTile(
            title: const Text('Tema'),
            subtitle: Text(app.themeMode == ThemeMode.light ? 'Claro' : 'Oscuro'),
            trailing: DropdownButton<ThemeMode>(
              value: app.themeMode == ThemeMode.system ? ThemeMode.light : app.themeMode,
              items: [
                DropdownMenuItem(value: ThemeMode.light, child: const Text('Claro')),
                DropdownMenuItem(value: ThemeMode.dark, child: const Text('Oscuro')),
              ],
              onChanged: (v) {
                if (v != null) app.setThemeMode(v);
              },
            ),
          ),
        ],
      ),
    );
  }
} 