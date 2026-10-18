import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:share_plus/share_plus.dart';

import 'badge_probe_section.dart';
import '../../../../core/platform/file_download.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';

/// Prueba de paquetes (T11.4): compartir, agregar al calendario y escudos
/// guardados en disco. Solo datos de prueba, rotulados como tales.
class PackageProbeSection extends StatefulWidget {
  const PackageProbeSection({super.key});

  @override
  State<PackageProbeSection> createState() => _PackageProbeSectionState();
}

class _PackageProbeSectionState extends State<PackageProbeSection> {
  static const _text = 'Prueba de compartir de Fútbol Argentino (T11.4)';
  static const _badge = '${BadgeProbeSection.badgeUrl}/tiny';

  final _log = <String>[];

  void _add(String line) {
    debugPrint('Paquetes: $line');
    setState(() => _log.insert(0, line));
  }

  Future<void> _share() async {
    try {
      final result = await SharePlus.instance.share(ShareParams(text: _text));
      _add('Compartir: ${result.status.name} (${result.raw})');
    } catch (e) {
      _add('Compartir ERROR ${e.runtimeType}: $e');
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(const ClipboardData(text: _text));
    _add('Copiado al portapapeles');
  }

  Future<void> _calendar() async {
    final start = DateTime.now().add(const Duration(hours: 1));
    if (kIsWeb) {
      final ok = downloadTextFile(
        fileName: 'prueba-futbol-argentino.ics',
        mimeType: 'text/calendar',
        content: _ics(start),
      );
      _add('Calendario Web (.ics): ${ok ? 'descargado' : 'no disponible'}');
      return;
    }
    try {
      final ok = await Add2Calendar.addEvent2Cal(
        Event(
          title: 'Prueba Fútbol Argentino (T11.4)',
          description: 'Evento de prueba del diagnóstico',
          startDate: start,
          endDate: start.add(const Duration(hours: 2)),
          timeZone: 'America/Argentina/Buenos_Aires',
        ),
      );
      _add('Calendario Android: ${ok ? 'abrió el calendario' : 'falló'}');
    } catch (e) {
      _add('Calendario ERROR ${e.runtimeType}: $e');
    }
  }

  /// Evento mínimo en UTC (RFC 5545).
  static String _ics(DateTime start) {
    String utc(DateTime d) =>
        '${d.toUtc().toIso8601String().replaceAll(RegExp('[-:]'), '').split('.').first}Z';
    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//futbol_argentino//diagnostico//ES',
      'BEGIN:VEVENT',
      'UID:prueba-t11-4@futbol-argentino',
      'DTSTAMP:${utc(DateTime.now())}',
      'DTSTART:${utc(start)}',
      'DTEND:${utc(start.add(const Duration(hours: 2)))}',
      'SUMMARY:Prueba Fútbol Argentino (T11.4)',
      'END:VEVENT',
      'END:VCALENDAR',
      '',
    ].join('\r\n');
  }

  Future<void> _cacheStatus() async {
    if (kIsWeb) {
      _add('Caché en disco: no aplica en Web');
      return;
    }
    final file = await DefaultCacheManager().getFileFromCache(_badge);
    _add(
      file == null
          ? 'Escudo NO está en disco'
          : 'Escudo en disco: ${file.file.path} (${await file.file.length()} bytes)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prueba de paquetes (T11.4)', style: textTheme.titleMedium),
            Text(
              'Plataforma: ${kIsWeb ? 'Web' : defaultTargetPlatform.name}',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.tonal(
                  onPressed: _share,
                  child: const Text('Compartir'),
                ),
                FilledButton.tonal(
                  onPressed: _copy,
                  child: const Text('Copiar'),
                ),
                FilledButton.tonal(
                  onPressed: _calendar,
                  child: const Text('Agregar al calendario'),
                ),
                FilledButton.tonal(
                  onPressed: _cacheStatus,
                  child: const Text('¿Escudo en disco?'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Escudo con CachedNetworkImage', style: textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            SizedBox.square(
              dimension: AppSizes.badgeHero,
              child: CachedNetworkImage(
                imageUrl: _badge,
                errorWidget: (context, url, error) {
                  debugPrint('Paquetes: CachedNetworkImage ERROR $error');
                  return const Icon(Icons.broken_image);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final line in _log)
              SelectableText(line, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
