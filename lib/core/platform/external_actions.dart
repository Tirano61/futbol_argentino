import 'package:add_2_calendar/add_2_calendar.dart' as a2c;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../calendar/calendar_event.dart';
import '../calendar/ics_builder.dart';
import '../time/argentina_time.dart';
import '../time/clock.dart';
import 'file_download.dart';

/// Resultado de compartir un texto.
enum ShareOutcome {
  /// Se abrió la hoja de compartir del sistema (o del navegador).
  shared,

  /// El usuario la cerró sin elegir nada.
  dismissed,

  /// No se podía compartir: el texto quedó en el portapapeles.
  copied,

  /// No se pudo compartir ni copiar.
  failed,
}

/// Resultado de agregar un evento al calendario.
enum CalendarOutcome {
  /// Android: se abrió el calendario con el evento precargado.
  opened,

  /// Web: se descargó el `.ics`.
  downloaded,

  failed,
}

/// Acciones que salen de la app: compartir, agregar al calendario y abrir
/// un enlace. Las pantallas la reciben por `RepositoryProvider` (en los
/// tests, una falsa).
abstract interface class ExternalActions {
  Future<ShareOutcome> share(String text, {String? subject});

  /// Abre [uri] en el navegador (en Web, en otra pestaña). `false` si no se
  /// pudo.
  Future<bool> openLink(Uri uri);

  /// [fileName]: nombre del `.ics` en Web.
  Future<CalendarOutcome> addToCalendar(
    CalendarEvent event, {
    required String fileName,
  });
}

/// `share_plus` (Android y Web Share API) con el portapapeles como
/// alternativa, y `add_2_calendar` en Android o un `.ics` en Web (V11).
class PlatformExternalActions implements ExternalActions {
  const PlatformExternalActions({this.clock = const SystemClock()});

  final Clock clock;

  static const argentinaTimeZone = 'America/Argentina/Buenos_Aires';

  @override
  Future<ShareOutcome> share(String text, {String? subject}) async {
    try {
      final result = await SharePlus.instance.share(
        // Sin la alternativa de `mailto:` de la versión Web: si el
        // navegador no puede compartir, se copia.
        ShareParams(text: text, subject: subject, mailToFallbackEnabled: false),
      );
      return result.status == ShareResultStatus.dismissed
          ? ShareOutcome.dismissed
          : ShareOutcome.shared;
    } catch (e) {
      debugPrint('Compartir: $e; se copia al portapapeles');
    }
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return ShareOutcome.copied;
    } catch (e) {
      debugPrint('Copiar: $e');
      return ShareOutcome.failed;
    }
  }

  @override
  Future<bool> openLink(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Abrir enlace: $e');
      return false;
    }
  }

  @override
  Future<CalendarOutcome> addToCalendar(
    CalendarEvent event, {
    required String fileName,
  }) async {
    if (kIsWeb) {
      final ok = downloadTextFile(
        fileName: fileName,
        mimeType: IcsBuilder.mimeType,
        content: IcsBuilder.build(event, stampUtc: clock.now()),
      );
      return ok ? CalendarOutcome.downloaded : CalendarOutcome.failed;
    }
    try {
      final ok = await a2c.Add2Calendar.addEvent2Cal(androidEvent(event));
      return ok ? CalendarOutcome.opened : CalendarOutcome.failed;
    } catch (e) {
      debugPrint('Calendario: $e');
      return CalendarOutcome.failed;
    }
  }

  /// Evento para el calendario de Android (`add_2_calendar`).
  @visibleForTesting
  static a2c.Event androidEvent(CalendarEvent event) => switch (event.time) {
    TimedEvent(:final startUtc, :final endUtc) => a2c.Event(
      title: event.title,
      description: event.description,
      location: event.location,
      startDate: startUtc,
      endDate: endUtc,
      timeZone: argentinaTimeZone,
    ),
    // Google Calendar toma el día completo de medianoche a medianoche
    // (fin exclusivo) en la zona del evento: el día argentino del partido
    // (validado en la tablet).
    AllDayEvent(:final day) => a2c.Event(
      title: event.title,
      description: event.description,
      location: event.location,
      startDate: ArgentinaTime.startOf(day),
      endDate: ArgentinaTime.startOf(day.addDays(1)),
      timeZone: argentinaTimeZone,
      allDay: true,
    ),
  };
}
