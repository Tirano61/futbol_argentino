import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/matches/data/mappers/event_mapper.dart';
import 'package:futbol_argentino/features/matches/data/models/event_dto.dart';
import 'package:futbol_argentino/features/matches/domain/entities/kickoff.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match_status.dart';
import 'package:futbol_argentino/features/matches/domain/entities/score.dart';

import '../../../helpers/fixtures.dart';

final seenAt = DateTime.utc(2026, 10, 11, 21);

void main() {
  test('todos los eventos de los 52 fixtures reales se convierten', () {
    final files = Directory('test/fixtures/api')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.startsWith('events') || n.startsWith('lookupevent'))
        .map((n) => n.replaceAll('.json', ''));
    var total = 0;
    for (final name in files) {
      for (final e in fixtureEvents(name)) {
        final match = EventMapper.toEntity(
          EventDto.fromJson(e),
          seenAt: seenAt,
        );
        expect(match, isNotNull, reason: '$name ${e['idEvent']}');
        total++;
      }
    }
    expect(total, greaterThan(1100));
  });

  test('partido terminado con todos sus datos', () {
    // Defensa y Justicia 2 – 0 Unión (Apertura 2026, fecha 12).
    final match = EventMapper.toEntity(
      EventDto.fromJson(fixtureEvent('eventsround_4406_r12_s2026', '2397881')),
      seenAt: seenAt,
    )!;

    expect(match.id, 2397881);
    expect(match.competitionId, 4406);
    expect(match.season, '2026');
    expect(match.apiRound, 12);
    expect(match.home.name, 'Defensa y Justicia');
    expect(match.home.badgeUrl, startsWith('https://r2.thesportsdb.com/'));
    expect(match.away.name, 'Unión');
    expect(match.score, const Score(home: 2, away: 0));
    expect(match.status.kind, MatchStatusKind.finished);
    expect(match.kickoff.certainty, KickoffCertainty.confirmed);
    expect(match.lastSeenAt, seenAt);
  });

  test('partido no jugado: sin resultado; strTimeLocal null no rompe', () {
    final match = EventMapper.toEntity(
      EventDto.fromJson(fixtureEvent('eventsround_4616_r34_s2026', '2405155')),
      seenAt: seenAt,
    )!;

    expect(match.score, isNull);
    expect(match.status.kind, MatchStatusKind.scheduled);
    expect(match.kickoff.certainty, KickoffCertainty.tentative);
  });

  test('definido por penales y por alargue (eliminatorias reales)', () {
    final decisions = {
      for (final e in fixtureEvents('eventsround_4406_r0_s2026'))
        EventMapper.toEntity(
          EventDto.fromJson(e),
          seenAt: seenAt,
        )!.status.decidedBy,
    };

    expect(
      decisions,
      containsAll([MatchDecision.extraTime, MatchDecision.penalties]),
    );
  });

  group('parsing tolerante', () {
    Map<String, dynamic> base() =>
        Map.of(fixtureEvent('eventsround_4406_r12_s2026', '2397881'));

    test('números como número y textos con espacios', () {
      final json = base()
        ..['idEvent'] = 2397881
        ..['intRound'] = 12.0
        ..['intHomeScore'] = ' 2 '
        ..['strVenue'] = '   ';

      final match = EventMapper.toEntity(
        EventDto.fromJson(json),
        seenAt: seenAt,
      )!;

      expect(match.id, 2397881);
      expect(match.apiRound, 12);
      expect(match.score!.home, 2);
      expect(match.venue, isNull);
    });

    test('campos vacíos son null', () {
      final json = base()
        ..['strThumb'] = ''
        ..['strVideo'] = null
        ..['strHomeTeamBadge'] = '';

      final match = EventMapper.toEntity(
        EventDto.fromJson(json),
        seenAt: seenAt,
      )!;

      expect(match.thumbUrl, isNull);
      expect(match.videoUrl, isNull);
      expect(match.home.badgeUrl, isNull);
    });

    test('sin un solo resultado no hay marcador', () {
      final json = base()..['intAwayScore'] = null;

      expect(
        EventMapper.toEntity(EventDto.fromJson(json), seenAt: seenAt)!.score,
        isNull,
      );
    });

    test('sin idEvent o sin idTeam se descarta', () {
      expect(
        EventMapper.toEntity(
          EventDto.fromJson(base()..remove('idEvent')),
          seenAt: seenAt,
        ),
        isNull,
      );
      expect(
        EventMapper.toEntity(
          EventDto.fromJson(base()..['idAwayTeam'] = ''),
          seenAt: seenAt,
        ),
        isNull,
      );
    });

    test('temporada y ronda de la consulta si el evento no las trae', () {
      final json = base()
        ..remove('strSeason')
        ..remove('intRound');

      final match = EventMapper.toEntity(
        EventDto.fromJson(json),
        seenAt: seenAt,
        season: '2026',
        apiRound: 12,
      )!;

      expect(match.season, '2026');
      expect(match.apiRound, 12);
    });

    test('nombre ausente usa un texto neutro', () {
      final json = base()..['strHomeTeam'] = null;

      expect(
        EventMapper.toEntity(
          EventDto.fromJson(json),
          seenAt: seenAt,
        )!.home.name,
        'Equipo sin nombre',
      );
    });
  });
}
