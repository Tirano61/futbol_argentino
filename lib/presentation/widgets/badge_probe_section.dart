import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prueba de escudos', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Plataforma: ${kIsWeb ? 'Web' : defaultTargetPlatform.name}',
              style: textTheme.bodySmall,
            ),
            SelectableText(badgeUrl, style: textTheme.bodySmall),
            const SizedBox(height: 12),
            for (final strategy in const [
              WebHtmlElementStrategy.never,
              WebHtmlElementStrategy.fallback,
            ]) ...[
              Text(
                'webHtmlElementStrategy.${strategy.name}',
                style: textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              for (final (label, suffix) in _variants)
                _BadgeProbe(
                  label: label,
                  url: '$badgeUrl$suffix',
                  strategy: strategy,
                ),
              const SizedBox(height: 8),
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

  String get _id => '[${strategy.name} $label]';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Image.network(
        url,
        width: 56,
        height: 56,
        webHtmlElementStrategy: strategy,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          final loaded = frame != null || wasSynchronouslyLoaded;
          if (loaded) debugPrint('Escudo $_id OK');
          return _row(
            image: child,
            status: loaded ? 'OK: imagen mostrada' : 'Cargando…',
            color: loaded ? Colors.green : null,
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Escudo $_id ERROR ${error.runtimeType}: $error');
          return _row(
            image: const Icon(Icons.broken_image, size: 56),
            status: 'ERROR ${error.runtimeType}: $error',
            color: Colors.red,
          );
        },
      ),
    );
  }

  Widget _row({required Widget image, required String status, Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 56, height: 56, child: image),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              SelectableText(
                status,
                style: TextStyle(color: color, fontSize: 12),
                maxLines: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
