import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match_status.dart';
import 'package:futbol_argentino/features/matches/domain/services/match_status_mapper.dart';

import '../../../helpers/fixtures.dart';

MatchStatus map(String? status, [String? postponed]) =>
    MatchStatusMapper.fromApi(status, postponed: postponed);

void main() {
  test('estados observados en datos reales', () {
    expect(map('NS').kind, MatchStatusKind.scheduled);
    expect(map('1H').kind, MatchStatusKind.live);
    expect(map('2H').kind, MatchStatusKind.live);
    expect(map('HT').kind, MatchStatusKind.halfTime);
    expect(
      map('FT'),
      const MatchStatus(kind: MatchStatusKind.finished, raw: 'FT'),
    );
    expect(
      map('AET'),
      const MatchStatus(
        kind: MatchStatusKind.finished,
        decidedBy: MatchDecision.extraTime,
        raw: 'AET',
      ),
    );
    expect(map('PEN').decidedBy, MatchDecision.penalties);
  });

  test('todos los estados de los fixtures reales son conocidos', () {
    final unknown = <String>{};
    for (final name in [
      'eventsround_4406_r0_s2026',
      'eventsround_4406_r12_s2026',
      'eventsround_4616_r33_s2026',
      'eventsround_4500_r64_s2026',
      'eventsround_4500_r125_s2026',
      'eventsround_4500_r150_s2026',
    ]) {
      for (final e in fixtureEvents(name)) {
        final status = map(
          e['strStatus'] as String?,
          e['strPostponed'] as String?,
        );
        if (status.kind == MatchStatusKind.unknown) {
          unknown.add('${e['strStatus']}');
        }
      }
    }
    expect(unknown, isEmpty);
  });

  test('strPostponed "yes" convierte un NS en postergado', () {
    expect(map('NS', 'yes').kind, MatchStatusKind.postponed);
    expect(map(null, 'yes').kind, MatchStatusKind.postponed);
    expect(map('NS', 'no').kind, MatchStatusKind.scheduled);
  });

  test('strPostponed no pisa un partido terminado', () {
    expect(map('FT', 'yes').kind, MatchStatusKind.finished);
  });

  test('estado vacío o nulo es programado', () {
    expect(map(null).kind, MatchStatusKind.scheduled);
    expect(map('  ').kind, MatchStatusKind.scheduled);
  });

  test('variantes de mayúsculas y nombres largos', () {
    expect(map('ft').kind, MatchStatusKind.finished);
    expect(map('Match Finished').kind, MatchStatusKind.finished);
    expect(map('Postponed').kind, MatchStatusKind.postponed);
    expect(map('CANC').kind, MatchStatusKind.cancelled);
    expect(map('ABD').kind, MatchStatusKind.abandoned);
    expect(map('SUSP').kind, MatchStatusKind.suspended);
  });

  test('código desconocido se conserva tal cual', () {
    final status = map('XYZ');

    expect(status.kind, MatchStatusKind.unknown);
    expect(status.raw, 'XYZ');
  });
}
