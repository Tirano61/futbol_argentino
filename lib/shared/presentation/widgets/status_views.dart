import 'package:flutter/material.dart';

import '../../../core/error/failure.dart';
import '../../../core/time/argentina_time.dart';
import '../formatters/failure_messages.dart';

/// Pantalla vacía informativa.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Error sin datos para mostrar, con reintento y detalle técnico.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.failure, this.onRetry});

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final (:title, :message) = failureMessage(failure);
    return SingleChildScrollView(
      child: Column(
        children: [
          EmptyView(
            icon: Icons.cloud_off,
            title: title,
            message: message,
            action: onRetry == null
                ? null
                : FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ExpansionTile(
              title: const Text('Detalle técnico'),
              children: [
                SelectableText(
                  failure.detail,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de datos guardados cuando la actualización falló.
class StaleDataBanner extends StatelessWidget {
  const StaleDataBanner({
    super.key,
    required this.fetchedAt,
    required this.failure,
    this.onRetry,
  });

  final DateTime fetchedAt;
  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (:title, message: _) = failureMessage(failure);
    final day = ArgentinaTime.formatDay(ArgentinaTime.dayOf(fetchedAt));
    final time = ArgentinaTime.formatTime(fetchedAt);

    return Semantics(
      liveRegion: true,
      child: Material(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: colors.onTertiaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Mostrando datos guardados (actualizados el $day a las '
                  '$time). $title.',
                  style: TextStyle(color: colors.onTertiaryContainer),
                ),
              ),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      ),
    );
  }
}
