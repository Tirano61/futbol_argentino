import 'package:flutter/material.dart';

import '../../../core/error/failure.dart';
import '../../../core/time/argentina_time.dart';
import '../formatters/failure_messages.dart';
import '../theme/app_spacing.dart';
import 'info_banner.dart';

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
    final colors = theme.colorScheme;
    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.emptyIcon, color: colors.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
    // Con alto fijo (pantalla vacía) se desplaza si no entra, p. ej. con
    // el texto agrandado; dentro de una lista ya se desplaza la lista.
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: constraints.hasBoundedHeight
            ? SingleChildScrollView(child: content)
            : content,
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
                : FilledButton.tonalIcon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: ExpansionTile(
              title: const Text('Detalle técnico'),
              children: [
                SelectableText(
                  failure.detail,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
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
    final (:title, message: _) = failureMessage(failure);
    final day = ArgentinaTime.formatDay(ArgentinaTime.dayOf(fetchedAt));
    final time = ArgentinaTime.formatTime(fetchedAt);

    return InfoBanner(
      tone: InfoTone.offline,
      text:
          'Mostrando datos guardados (actualizados el $day a las '
          '$time). $title.',
      action: onRetry == null
          ? null
          : TextButton(onPressed: onRetry, child: const Text('Reintentar')),
    );
  }
}
