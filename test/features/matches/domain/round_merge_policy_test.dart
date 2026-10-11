import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/time/calendar_day.dart';
import 'package:futbol_argentino/features/matches/domain/entities/kickoff.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match_status.dart';
import 'package:futbol_argentino/features/matches/domain/entities/team_ref.dart';
import 'package:futbol_argentino/features/matches/domain/services/round_merge_policy.dart';

import '../../../helpers/fixture_matches.dart';

final now = DateTime.utc(2026, 10, 11, 21);
final earlier = DateTime.utc(2026, 10, 11, 20);
final twoDaysAgo = DateTime.utc(2026, 10, 9, 20);

Kickoff confirmedAt(DateTime utc) => Kickoff(
  utc: utc,
  argentinaDay: CalendarDay(utc.year, utc.month, utc.day),
  certainty: KickoffCertainty.confirmed,
  evidence: KickoffEvidence.timestamp,
);

RoundMergeResult merge(
  List<Match> stored,
  List<Match> incoming, {
  int? expected = 15,
}) => RoundMergePolicy.merge(
  apiRound: 12,
  stored: stored,
  incoming: incoming,
  expectedMinimum: expected,
  now: now,
);

void main() {
  late List<Match> round12;
  late List<Match> stored;

  setUp(() {
    round12 = fixtureMatches('eventsround_4406_r12_s2026', seenAt: now);
    stored = fixtureMatches('eventsround_4406_r12_s2026', seenAt: earlier);
  });

  group('calidad de la respuesta', () {
    test('primera carga: completa, todo activo y visto ahora', () {
      final result = merge(const [], round12);

      expect(result.quality, ResponseQuality.complete);
      expect(result.toSave, hasLength(30));
      expect(
        result.toSave.every(
          (m) => m.membership == MatchMembership.active && m.lastSeenAt == now,
        ),
        isTrue,
      );
      expect(result.toVerify, isEmpty);
    });

    test('misma respuesta otra vez: completa, sin bajas', () {
      final result = merge(stored, round12);

      expect(result.quality, ResponseQuality.complete);
      expect(result.toSave, hasLength(30));
      expect(result.toVerify, isEmpty);
    });

    test(
      'respuesta truncada reciente: parcial, sin bajas ni verificaciones',
      () {
        final result = merge(stored, round12.take(15).toList());

        expect(result.quality, ResponseQuality.partial);
        expect(result.toSave, hasLength(15));
        expect(
          result.toSave.any((m) => m.membership != MatchMembership.active),
          isFalse,
        );
        expect(result.toVerify, isEmpty);
      },
    );

    test('truncada y faltantes sin ver hace más de 24 h: se verifican', () {
      final old = [for (final m in stored) rebuild(m, lastSeenAt: twoDaysAgo)];

      final result = merge(old, round12.take(15).toList());

      expect(result.quality, ResponseQuality.partial);
      expect(result.toVerify, hasLength(15));
      expect(result.toSave, hasLength(15), reason: 'los faltantes no se tocan');
    });

    test('completa sin un partido: queda orphaned y se verifica', () {
      final missing = round12.first;
      // Falta un partido pero llega otro nuevo: la cantidad se mantiene y
      // la respuesta es completa.
      final incoming = [
        ...round12.skip(1),
        Match(
          id: 1,
          competitionId: 4406,
          competitionName: missing.competitionName,
          season: '2026',
          apiRound: 12,
          home: missing.home,
          away: missing.away,
          kickoff: missing.kickoff,
          status: const MatchStatus.scheduled(),
          lastSeenAt: now,
        ),
      ];

      final result = merge(stored, incoming);

      expect(result.quality, ResponseQuality.complete);
      final orphan = result.toSave.singleWhere((m) => m.id == missing.id);
      expect(orphan.membership, MatchMembership.orphaned);
      expect(orphan.isVisible, isFalse);
      expect(result.toVerify, {missing.id});
    });

    test('events null con datos guardados: sospechosa, no se toca nada', () {
      final result = merge(stored, const []);

      expect(result.quality, ResponseQuality.suspectEmpty);
      expect(result.toSave, isEmpty);
      expect(result.toVerify, isEmpty);
    });

    test('events null sin datos guardados: ronda vacía', () {
      expect(merge(const [], const []).quality, ResponseQuality.empty);
    });

    test('primera carga con menos de lo esperado: parcial', () {
      final nacional = fixtureMatches('eventsround_4616_r33_s2026');

      final result = RoundMergePolicy.merge(
        apiRound: 33,
        stored: const [],
        incoming: nacional.take(10).toList(),
        expectedMinimum: 18,
        now: now,
      );

      expect(result.quality, ResponseQuality.partial);
    });

    test('un orphaned que reaparece vuelve a estar activo', () {
      final orphan = rebuild(
        stored.first,
        membership: MatchMembership.orphaned,
      );

      final result = merge([orphan, ...stored.skip(1)], round12);

      expect(
        result.toSave.singleWhere((m) => m.id == orphan.id).membership,
        MatchMembership.active,
      );
    });
  });

  group('merge por campo', () {
    test('partido movido de ronda: guarda la ronda anterior', () {
      final incoming = rebuild(round12.first, apiRound: 13);

      final merged = RoundMergePolicy.mergeFields(stored.first, incoming, now);

      expect(merged.apiRound, 13);
      expect(merged.previousApiRound, 12);
    });

    test('reprogramado: guarda el horario confirmado anterior', () {
      final original = rebuild(
        stored.first,
        kickoff: confirmedAt(DateTime.utc(2026, 10, 12, 20)),
      );
      final incoming = rebuild(
        round12.first,
        kickoff: confirmedAt(DateTime.utc(2026, 10, 13, 22)),
      );

      final merged = RoundMergePolicy.mergeFields(original, incoming, now);

      expect(merged.previousKickoffUtc, DateTime.utc(2026, 10, 12, 20));
      expect(merged.wasRescheduled, isTrue);
    });

    test('tentativo que se confirma no cuenta como reprogramación', () {
      // 2397877: 00:00 UTC sin corroborar (tentativo).
      final tentative = stored.singleWhere((m) => m.id == 2397877);
      expect(tentative.kickoff.certainty, KickoffCertainty.tentative);
      final incoming = rebuild(
        tentative,
        kickoff: confirmedAt(DateTime.utc(2026, 3, 21, 0, 30)),
      );

      final merged = RoundMergePolicy.mergeFields(tentative, incoming, now);

      expect(merged.kickoff.isConfirmed, isTrue);
      expect(merged.previousKickoffUtc, isNull);
    });

    test('un confirmado no se degrada a tentativo del mismo instante', () {
      final utc = DateTime.utc(2025, 3, 15);
      final confirmed = rebuild(
        stored.first,
        kickoff: Kickoff(
          utc: utc,
          argentinaDay: const CalendarDay(2025, 3, 14),
          certainty: KickoffCertainty.confirmed,
          evidence: KickoffEvidence.midnightCorroborated,
        ),
      );
      final incoming = rebuild(
        round12.first,
        kickoff: Kickoff(
          utc: utc,
          argentinaDay: const CalendarDay(2025, 3, 15),
          certainty: KickoffCertainty.tentative,
          evidence: KickoffEvidence.midnightUncorroborated,
        ),
      );

      final merged = RoundMergePolicy.mergeFields(confirmed, incoming, now);

      expect(merged.kickoff, confirmed.kickoff);
    });

    test('resultado no se pierde si llega vacío con el partido terminado', () {
      final finished = stored.firstWhere((m) => m.score != null);
      final incoming = rebuild(finished, clearScore: true);

      final merged = RoundMergePolicy.mergeFields(finished, incoming, now);

      expect(merged.score, finished.score);
    });

    test('resultado se borra si el partido pasa a postergado', () {
      final finished = stored.firstWhere((m) => m.score != null);
      final incoming = rebuild(
        finished,
        clearScore: true,
        status: const MatchStatus(kind: MatchStatusKind.postponed, raw: 'PST'),
      );

      final merged = RoundMergePolicy.mergeFields(finished, incoming, now);

      expect(merged.score, isNull);
      expect(merged.status.kind, MatchStatusKind.postponed);
    });

    test('nombre con mojibake no pisa el correcto; escudo vacío tampoco', () {
      final good = stored.first;
      final incoming = rebuild(
        round12.first,
        home: TeamRef(id: good.home.id, name: 'Atl�tico Tucum�n'),
      );

      final merged = RoundMergePolicy.mergeFields(good, incoming, now);

      expect(merged.home.name, good.home.name);
      expect(merged.home.badgeUrl, good.home.badgeUrl);
    });

    test('looksGarbled', () {
      expect(RoundMergePolicy.looksGarbled('Río Cuarto'), isFalse);
      expect(RoundMergePolicy.looksGarbled('R�o Cuarto'), isTrue);
      expect(RoundMergePolicy.looksGarbled('RÃ­o Cuarto'), isTrue);
    });
  });

  group('verificación con lookupevent', () {
    test('ya no existe: removed', () {
      final orphan = rebuild(
        stored.first,
        membership: MatchMembership.orphaned,
      );

      final result = RoundMergePolicy.applyVerification(orphan, null, now);

      expect(result.membership, MatchMembership.removed);
      expect(result.isVisible, isFalse);
    });

    test('existe en la misma ronda: unconfirmed (visible con aviso)', () {
      final orphan = rebuild(
        stored.first,
        membership: MatchMembership.orphaned,
      );

      final result = RoundMergePolicy.applyVerification(
        orphan,
        round12.first,
        now,
      );

      expect(result.membership, MatchMembership.unconfirmed);
      expect(result.isVisible, isTrue);
    });

    test('existe en otra ronda: activo en la nueva ronda', () {
      final orphan = rebuild(
        stored.first,
        membership: MatchMembership.orphaned,
      );

      final result = RoundMergePolicy.applyVerification(
        orphan,
        rebuild(round12.first, apiRound: 14),
        now,
      );

      expect(result.membership, MatchMembership.active);
      expect(result.apiRound, 14);
      expect(result.previousApiRound, 12);
    });
  });
}
