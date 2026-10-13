import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';
import 'package:futbol_argentino/core/time/calendar_day.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/repositories/competition_repository.dart';
import 'package:futbol_argentino/features/home/domain/entities/home_feed.dart';
import 'package:futbol_argentino/features/home/domain/usecases/get_home_feed.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixture_matches.dart';
import '../../helpers/recorded_home.dart';

Match matchById(String fixture, int id) =>
    fixtureMatches(fixture).singleWhere((m) => m.id == id);

void main() {
  // Domingo 11/10/2026, 17:00 en Argentina (fecha 12 de Primera en curso).
  final now = DateTime.utc(2026, 10, 11, 20);
  const primera = CompetitionCatalog.primeraDivision;
  const nacional = CompetitionCatalog.primeraNacional;
  const copa = CompetitionCatalog.copaArgentina;

  late FakeMatchRepository matches;
  late FakeCompetitionRepository competitions;

  FakeCompetitionRepository pointersRepo({
    Map<int, Failure> failures = const {},
  }) => FakeCompetitionRepository(
    pointersById: {
      for (final d in homeCompetitions) d.id: recordedPointers(d.id),
    },
    failuresById: failures,
  );

  GetHomeFeed useCase() =>
      GetHomeFeed(competitions: competitions, matches: matches);

  setUp(() {
    matches = FakeMatchRepository(recordedRounds());
    competitions = pointersRepo();
  });

  group('GetHomeFeed.roundsFor', () {
    List<int> rounds(CompetitionDefinition d, {Match? next, Match? last}) => [
      for (final q in GetHomeFeed.roundsFor(
        d,
        SchedulePointers(next: next, last: last),
      ))
        q.apiRound,
    ];

    final r12 = fixtureMatches('eventsround_4406_r12_s2026');
    final octoberR12 = r12.firstWhere(
      (m) => m.kickoff.argentinaDay == const CalendarDay(2026, 10, 11),
    );
    final octoberR13 = fixtureMatches(
      'eventsround_4406_r13_s2026',
    ).firstWhere((m) => m.kickoff.argentinaDay!.month == 10);
    // Reprogramado de la fecha 11: 14/10/2026.
    final rescheduledR11 = matchById('eventsround_4406_r11_s2026', 2398113);

    test(
      'fecha en curso (próximo y último en la misma): esa y la siguiente',
      () {
        final p = recordedPointers(4406);
        expect(p.next!.apiRound, 12);
        expect(p.last!.apiRound, 12);
        expect(rounds(primera, next: p.next, last: p.last), [12, 13]);
      },
    );

    test('cambio de fecha (el próximo ya en la siguiente)', () {
      expect(rounds(primera, next: octoberR13, last: octoberR12), [12, 13]);
    });

    test(
      'próximo reprogramado de una fecha anterior: no desplaza la siguiente',
      () {
        expect(rounds(primera, next: rescheduledR11, last: octoberR12), [
          12,
          13,
        ]);
      },
    );

    test('Copa: códigos no consecutivos (Cuartos → Semifinales)', () {
      final p = recordedPointers(4500);
      expect(rounds(copa, next: p.next, last: p.last), [125, 150]);
    });

    test('solo próximo partido: su ronda y la siguiente', () {
      expect(rounds(nacional, next: recordedPointers(4616).next), [33, 34]);
    });

    test('sin punteros: ninguna ronda', () {
      expect(rounds(primera), isEmpty);
    });

    test('las consultas llevan la cantidad mínima esperada', () {
      final p = recordedPointers(4406);
      final queries = GetHomeFeed.roundsFor(primera, p);
      expect(
        queries.first,
        const RoundQuery(competitionId: 4406, season: '2026', apiRound: 12),
      );
      expect(queries.map((q) => q.expectedMinimum), [15, 15]);
    });
  });

  group('GetHomeFeed', () {
    test('secciones con datos reales del 11/10/2026', () async {
      final feed = await useCase()(now: now).last;

      expect(feed.isLoading, isFalse);
      expect(feed.today, const CalendarDay(2026, 10, 11));
      // Primera 5 + Nacional 12.
      expect(feed.todayMatches, hasLength(17));
      // Primera 2 (fecha 12) + 15 (fecha 13) · Nacional 2 + 18.
      expect(feed.upcoming, hasLength(37));
      // Primera 4 + Nacional 4, del sábado 10.
      expect(feed.recent, hasLength(8));
      expect(
        feed.recent.every(
          (m) =>
              m.match.kickoff.argentinaDay == const CalendarDay(2026, 10, 10),
        ),
        isTrue,
      );
      // Copa: semifinales el 25/10 y cuartos a fin de septiembre.
      final copaFeed = feed.competitions.singleWhere(
        (c) => c.competition.id == copa.id,
      );
      expect(copaFeed.matches, isEmpty);
      expect(copaFeed.hasData, isTrue);
    });

    test('no repite partidos y respeta el orden por día y hora', () async {
      final feed = await useCase()(now: now).last;
      final upcoming = feed.upcoming.map((m) => m.match).toList();

      expect(upcoming.map((m) => m.id).toSet(), hasLength(upcoming.length));
      for (var i = 1; i < upcoming.length; i++) {
        final a = upcoming[i - 1].kickoff.argentinaDay!;
        final b = upcoming[i].kickoff.argentinaDay!;
        expect(a.isAfter(b), isFalse);
      }
      expect(
        upcoming.last.kickoff.argentinaDay!.isAfter(
          const CalendarDay(2026, 10, 18),
        ),
        isFalse,
      );
    });

    test(
      'consulta 2 rondas por competición con prioridad de contexto',
      () async {
        await useCase()(now: now).last;

        expect(
          {for (final q in matches.queries) '${q.competitionId}:${q.apiRound}'},
          {'4406:12', '4406:13', '4616:33', '4616:34', '4500:125', '4500:150'},
        );
        expect(matches.calls.every((c) => !c.force), isTrue);
        expect(
          matches.calls.every((c) => c.priority == SyncPriority.context),
          isTrue,
        );
        expect(competitions.pointerCalls.map((c) => c.priority).toSet(), {
          SyncPriority.context,
        });
      },
    );

    test('refresco manual: ignora la vigencia y va con prioridad P0', () async {
      await useCase()(now: now, forceRefresh: true).last;

      expect(matches.calls.every((c) => c.force), isTrue);
      expect(
        matches.calls.every((c) => c.priority == SyncPriority.visible),
        isTrue,
      );
      expect(competitions.pointerCalls.every((c) => c.force), isTrue);
      expect(competitions.pointerCalls.map((c) => c.priority).toSet(), {
        SyncPriority.visible,
      });
    });

    test('cada partido trae competición, fase y etapa', () async {
      final feed = await useCase()(now: now).last;

      final fromPrimera = feed.todayMatches.firstWhere(
        (m) => m.match.competitionId == primera.id,
      );
      expect(fromPrimera.competitionName, 'Primera División');
      expect(fromPrimera.phaseLabel, 'Clausura');
      expect(fromPrimera.stageLabel, 'Fecha 12');

      final fromNacional = feed.todayMatches.firstWhere(
        (m) => m.match.competitionId == nacional.id,
      );
      expect(fromNacional.competitionName, 'Primera Nacional');
      expect(fromNacional.phaseLabel, isNull);
      expect(fromNacional.stageLabel, 'Fecha 33');
    });

    test(
      'un partido de los punteros fuera de las rondas cargadas se muestra',
      () async {
        final rescheduled = matchById('eventsround_4406_r11_s2026', 2398113);
        competitions = FakeCompetitionRepository(
          pointersById: {
            primera.id: SchedulePointers(
              next: rescheduled,
              last: recordedPointers(4406).last,
            ),
            nacional.id: recordedPointers(4616),
            copa.id: recordedPointers(4500),
          },
        );

        final feed = await useCase()(now: now).last;

        final shown = feed.upcoming.singleWhere((m) => m.match.id == 2398113);
        expect(shown.stageLabel, 'Fecha 11');
        expect(shown.phaseLabel, 'Clausura');
        expect(matches.queries.where((q) => q.apiRound == 11), isEmpty);
      },
    );

    test('emite enseguida y se completa por competición', () async {
      final feeds = await useCase()(now: now).toList();

      expect(feeds.first.isLoading, isTrue);
      expect(feeds.first.hasData, isFalse);
      expect(feeds.last.isLoading, isFalse);
      expect(feeds.last.competitions.every((c) => !c.isLoading), isTrue);
    });

    test('una competición sin red ni datos no afecta a las demás', () async {
      const offline = NetworkFailure(
        issue: NetworkIssue.connection,
        detail: 'Failed host lookup',
      );
      competitions = pointersRepo(failures: {copa.id: offline});

      final feed = await useCase()(now: now).last;

      expect(feed.failedCompetitions, [copa]);
      expect(feed.failure, offline);
      expect(feed.todayMatches, hasLength(17));
      expect(feed.refreshError, isNull);
    });

    test('ronda sin red ni datos: quedan los punteros y el error', () async {
      const offline = NetworkFailure(
        issue: NetworkIssue.connection,
        detail: 'Failed host lookup',
      );
      matches = FakeMatchRepository(const {}, failure: offline);

      final feed = await useCase()(now: now).last;

      // Próximo (19:15) y último (17:00) de Primera y de Nacional, hoy.
      expect(feed.todayMatches, hasLength(4));
      expect(feed.failedCompetitions, isEmpty);
      expect(feed.refreshError, offline);
    });

    test('datos guardados con error de actualización', () async {
      const offline = NetworkFailure(
        issue: NetworkIssue.connection,
        detail: 'Failed host lookup',
      );
      matches = FakeMatchRepository(recordedRounds(), refreshError: offline);

      final feed = await useCase()(now: now).last;

      expect(feed.todayMatches, hasLength(17));
      expect(feed.refreshError, offline);
      expect(feed.fetchedAt, fakeFetchedAt);
    });
  });

  group('HomeFeed.carryOver', () {
    late HomeFeed previous;
    late CompetitionFeed previousPrimera;

    setUp(() async {
      previous = await useCase()(now: now).last;
      previousPrimera = previous.competitions.firstWhere(
        (c) => c.competition.id == primera.id,
      );
    });

    HomeFeed withPrimera(CompetitionFeed feed) => HomeFeed(
      today: previous.today,
      competitions: [
        for (final c in previous.competitions)
          c.competition.id == primera.id ? feed : c,
      ],
    );

    test('sin datos nuevos todavía: conserva lo anterior, cargando', () {
      final shown = withPrimera(
        const CompetitionFeed(competition: primera),
      ).carryOver(previous);

      final p = shown.competitions.firstWhere(
        (c) => c.competition.id == primera.id,
      );
      expect(p.isLoading, isTrue);
      expect(p.matches, hasLength(previousPrimera.matches.length));
      expect(shown.isLoading, isTrue);
    });

    test('con datos parciales (solo punteros): no se achica', () {
      final pointerOnly = previousPrimera.matches
          .where((m) => {2398124, 2398126}.contains(m.match.id))
          .toList();
      final shown = withPrimera(
        CompetitionFeed(
          competition: primera,
          matches: pointerOnly,
          fetchedAt: now,
        ),
      ).carryOver(previous);

      expect(shown.todayMatches, hasLength(previous.todayMatches.length));
      expect(shown.upcoming, hasLength(previous.upcoming.length));
    });

    test('terminada la carga: solo lo nuevo', () {
      final shown = withPrimera(
        CompetitionFeed(competition: primera, isLoading: false, fetchedAt: now),
      ).carryOver(previous);

      expect(
        shown.competitions
            .firstWhere((c) => c.competition.id == primera.id)
            .matches,
        isEmpty,
      );
    });
  });
}
