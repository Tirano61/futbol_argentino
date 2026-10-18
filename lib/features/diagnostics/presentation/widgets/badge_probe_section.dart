import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../shared/presentation/theme/app_palette.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';

/// Prueba de carga de escudos (T0.2). `r2.thesportsdb.com` no envía
/// `Access-Control-Allow-Origin`, así que en Flutter Web la carga normal
/// puede fallar; se compara con la estrategia de elemento `<img>`.
class BadgeProbeSection extends StatelessWidget {
  const BadgeProbeSection({super.key});

  // Escudo real de Boca Juniors (lookupteam.php?id=135156).
  static const badgeUrl =
      'https://r2.thesportsdb.com/images/media/team/badge/bm7krb1775741582.png';

  static const _variants = [
    ('original', ''),
    ('/tiny', '/tiny'),
    ('/small', '/small'),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prueba de escudos', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Plataforma: ${kIsWeb ? 'Web' : defaultTargetPlatform.name}',
              style: textTheme.bodySmall,
            ),
            SelectableText(badgeUrl, style: textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            for (final strategy in const [
              WebHtmlElementStrategy.never,
              WebHtmlElementStrategy.fallback,
            ]) ...[
              Text(
                'webHtmlElementStrategy.${strategy.name}',
                style: textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final (label, suffix) in _variants)
                _BadgeProbe(
                  label: label,
                  url: '$badgeUrl$suffix',
                  strategy: strategy,
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgeProbe extends StatelessWidget {
  const _BadgeProbe({
    required this.label,
    required this.url,
    required this.strategy,
  });

  final String label;
  final String url;
  final WebHtmlElementStrategy strategy;

  /// Tamaño de la muestra: ni el de una fila ni el del héroe, para ver la
  /// imagen original sin escalar demasiado (pantalla de desarrollo).
  static const _imageSize = 56.0;

  String get _id => '[${strategy.name} $label]';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Image.network(
        url,
        width: _imageSize,
        height: _imageSize,
        webHtmlElementStrategy: strategy,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          final loaded = frame != null || wasSynchronouslyLoaded;
          if (loaded) debugPrint('Escudo $_id OK');
          return _row(
            context,
            image: child,
            status: loaded ? 'OK: imagen mostrada' : 'Cargando…',
            color: loaded ? AppPalette.of(context).success : null,
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Escudo $_id ERROR ${error.runtimeType}: $error');
          return _row(
            context,
            image: const Icon(Icons.broken_image, size: _imageSize),
            status: 'ERROR ${error.runtimeType}: $error',
            color: Theme.of(context).colorScheme.error,
          );
        },
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required Widget image,
    required String status,
    Color? color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(dimension: _imageSize, child: image),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              SelectableText(
                status,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: color),
                maxLines: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
