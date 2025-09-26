import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = app.history;
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de búsqueda')),
      body: items.isEmpty
          ? const Center(child: Text('Aún no hay historial'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final m = items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: m.posterUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                              imageUrl: m.posterUrl!,
                              width: 40,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.history),
                    title: Text(m.title),
                    subtitle: Text(m.releaseYear ?? ''),
                    onTap: () => context.pushNamed('detail', extra: m),
                  ),
                );
              },
            ),
    );
  }
} 