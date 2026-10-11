import '../entities/match_status.dart';

/// Traduce `strStatus` (+ `strPostponed`) de TheSportsDB a [MatchStatus].
///
/// Observados en datos reales (11/10/2026): `NS`, `1H`, `HT`, `2H`, `FT`,
/// `AET`, `PEN`. El resto sale de la nomenclatura de TheSportsDB y queda
/// pendiente de validar (V4). Un código desconocido se conserva en `raw`.
abstract final class MatchStatusMapper {
  static MatchStatus fromApi(String? status, {String? postponed}) {
    final raw = status?.trim();
    final code = raw?.toUpperCase() ?? '';
    final isPostponed = postponed?.trim().toLowerCase() == 'yes';

    final mapped = _table[code];
    if (mapped == null) {
      if (code.isEmpty) {
        return isPostponed
            ? const MatchStatus(kind: MatchStatusKind.postponed)
            : const MatchStatus.scheduled();
      }
      return MatchStatus(kind: MatchStatusKind.unknown, raw: raw);
    }

    final (kind, decidedBy) = mapped;
    if (isPostponed && kind == MatchStatusKind.scheduled) {
      return MatchStatus(kind: MatchStatusKind.postponed, raw: raw);
    }
    return MatchStatus(kind: kind, decidedBy: decidedBy, raw: raw);
  }

  static const _regular = MatchDecision.regular;

  static const _table = <String, (MatchStatusKind, MatchDecision)>{
    'NS': (MatchStatusKind.scheduled, _regular),
    'NOT STARTED': (MatchStatusKind.scheduled, _regular),
    'TBD': (MatchStatusKind.scheduled, _regular),
    '1H': (MatchStatusKind.live, _regular),
    '2H': (MatchStatusKind.live, _regular),
    'ET': (MatchStatusKind.live, _regular),
    'BT': (MatchStatusKind.live, _regular),
    'P': (MatchStatusKind.live, _regular),
    'LIVE': (MatchStatusKind.live, _regular),
    'HT': (MatchStatusKind.halfTime, _regular),
    'FT': (MatchStatusKind.finished, _regular),
    'MATCH FINISHED': (MatchStatusKind.finished, _regular),
    'AWD': (MatchStatusKind.finished, _regular),
    'WO': (MatchStatusKind.finished, _regular),
    'AET': (MatchStatusKind.finished, MatchDecision.extraTime),
    'PEN': (MatchStatusKind.finished, MatchDecision.penalties),
    'FT_PEN': (MatchStatusKind.finished, MatchDecision.penalties),
    'PST': (MatchStatusKind.postponed, _regular),
    'POSTPONED': (MatchStatusKind.postponed, _regular),
    'CANC': (MatchStatusKind.cancelled, _regular),
    'CANCELLED': (MatchStatusKind.cancelled, _regular),
    'ABD': (MatchStatusKind.abandoned, _regular),
    'ABANDONED': (MatchStatusKind.abandoned, _regular),
    'SUSP': (MatchStatusKind.suspended, _regular),
    'INT': (MatchStatusKind.suspended, _regular),
    'SUSPENDED': (MatchStatusKind.suspended, _regular),
  };
}
