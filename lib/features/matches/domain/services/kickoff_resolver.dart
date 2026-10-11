import '../../../../core/time/argentina_time.dart';
import '../../../../core/time/calendar_day.dart';
import '../entities/kickoff.dart';

/// Regla conservadora de horarios (D5).
///
/// - Fuente: `strTimestamp` (UTC sin zona); si falta, `dateEvent` +
///   `strTime` (UTC). `strTimeLocal` nunca es fuente: es inconsistente y
///   solo sirve para corroborar.
/// - `00:00` UTC (= 21:00 ART) puede ser un horario real o un relleno: solo
///   se confirma si `strTimeLocal` dice `21:00`.
/// - Con hora dudosa o sin hora, el día es `dateEventLocal ?? dateEvent`
///   (no se le restan 3 h a una hora que no es confiable).
abstract final class KickoffResolver {
  static Kickoff resolve({
    String? timestamp,
    String? date,
    String? time,
    String? localTime,
    String? localDate,
  }) {
    final fallbackDay =
        CalendarDay.tryParse(localDate) ?? CalendarDay.tryParse(date);

    final fromTimestamp = _parseTimestamp(timestamp);
    final utc = fromTimestamp ?? _combine(date, time);
    if (utc == null) {
      return fallbackDay == null
          ? const Kickoff.unknown()
          : Kickoff(
              utc: null,
              argentinaDay: fallbackDay,
              certainty: KickoffCertainty.unknown,
              evidence: KickoffEvidence.dateOnly,
            );
    }

    if (utc.hour == 0 && utc.minute == 0) {
      if (_clock(localTime) == '21:00') {
        return Kickoff(
          utc: utc,
          argentinaDay: ArgentinaTime.dayOf(utc),
          certainty: KickoffCertainty.confirmed,
          evidence: KickoffEvidence.midnightCorroborated,
        );
      }
      return Kickoff(
        utc: utc,
        argentinaDay: fallbackDay ?? CalendarDay(utc.year, utc.month, utc.day),
        certainty: KickoffCertainty.tentative,
        evidence: KickoffEvidence.midnightUncorroborated,
      );
    }

    return Kickoff(
      utc: utc,
      argentinaDay: ArgentinaTime.dayOf(utc),
      certainty: KickoffCertainty.confirmed,
      evidence: fromTimestamp != null
          ? KickoffEvidence.timestamp
          : KickoffEvidence.dateAndTime,
    );
  }

  static final _offsetSuffix = RegExp(
    r'(Z|[+-]\d{2}:?\d{2})$',
    caseSensitive: false,
  );
  static final _clockPattern = RegExp(r'^(\d{2}):(\d{2})(?::(\d{2}))?');

  /// `2026-10-10T18:30:00` sin zona = UTC. Si trae zona, se respeta.
  static DateTime? _parseTimestamp(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || !text.contains('T')) return null;
    final normalized = _offsetSuffix.hasMatch(text) ? text : '${text}Z';
    return DateTime.tryParse(normalized)?.toUtc();
  }

  static DateTime? _combine(String? date, String? time) {
    final day = CalendarDay.tryParse(date);
    final match = _clockPattern.firstMatch(time?.trim() ?? '');
    if (day == null || match == null) return null;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    if (hour > 23 || minute > 59) return null;
    return DateTime.utc(day.year, day.month, day.day, hour, minute);
  }

  /// `HH:mm` de un texto de hora, o `null`.
  static String? _clock(String? value) {
    final match = _clockPattern.firstMatch(value?.trim() ?? '');
    return match == null ? null : '${match[1]}:${match[2]}';
  }
}
