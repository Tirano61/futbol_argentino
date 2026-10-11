import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/result/data_result.dart';
import '../../../../core/time/argentina_time.dart';
import '../bloc/cache_probe_bloc.dart';

/// Prueba de caché (Fase 3): cada toque muestra qué devolvió el repositorio
/// y de dónde. Las peticiones reales aparecen como `GET …` en el log.
class CacheProbeSection extends StatelessWidget {
  const CacheProbeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocBuilder<CacheProbeBloc, CacheProbeState>(
          builder: (context, state) {
            final bloc = context.read<CacheProbeBloc>();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prueba de caché', style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Primera División · fecha 12 · temporada 2026 · '
                  'repositorio con caché local',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: state.running
                          ? null
                          : () => bloc.add(const CacheProbeRequested()),
                      icon: const Icon(Icons.storage),
                      label: const Text('Consultar con caché'),
                    ),
                    OutlinedButton.icon(
                      onPressed: state.running
                          ? null
                          : () => bloc.add(
                              const CacheProbeRequested(forceRefresh: true),
                            ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Forzar actualización'),
                    ),
                  ],
                ),
                if (state.running) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 8),
                for (final entry in state.entries) _EntryRow(entry: entry),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final CacheProbeEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    String hour(DateTime utc) {
      final local = ArgentinaTime.wallClock(utc);
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
    }

    final origin = switch (entry.origin) {
      DataOrigin.cache => 'CACHÉ',
      DataOrigin.remote => 'RED',
      null => 'SIN DATOS',
    };
    final parts = [
      '#${entry.run}${entry.forced ? ' (forzada)' : ''}',
      hour(entry.receivedAt),
      origin,
      if (entry.count != null) '${entry.count} partidos',
      if (entry.fetchedAt != null) 'obtenido ${hour(entry.fetchedAt!)} ART',
    ];
    final error = entry.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(parts.join(' · ')),
          if (error != null)
            SelectableText(
              'Error de actualización: ${error.runtimeType}: ${error.detail}',
              style: TextStyle(color: colors.error, fontSize: 12),
              maxLines: 3,
            ),
        ],
      ),
    );
  }
}
