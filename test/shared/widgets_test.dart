import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/time/calendar_day.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match_status.dart';
import 'package:futbol_argentino/features/matches/domain/entities/team_ref.dart';
import 'package:futbol_argentino/shared/presentation/formatters/failure_messages.dart';
import 'package:futbol_argentino/shared/presentation/formatters/match_labels.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_day_list.dart';
import 'package:futbol_argentino/shared/presentation/widgets/status_views.dart';
import 'package:futbol_argentino/shared/presentation/widgets/team_badge.dart';

import '../helpers/fixture_matches.dart';
import '../helpers/fixtures.dart';

final recordedAt = DateTime.utc(2026, 10, 11, 20, 35);

Match event(String fixture, String id) =>
    matchFromEvent(fixtureEvent(fixture, id));

Future<void> pumpCard(WidgetTester tester, Match match, {DateTime? now}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchCard(match: match, now: now ?? recordedAt),
        ),
      ),
    );

void main() {
  group('MatchCard', () {
    testWidgets('terminado: marcador y «Final»', (tester) async {
      // Defensa y Justicia 2 – 0 Unión.
      await pumpCard(tester, event('eventsround_4406_r12_s2026', '2397881'));

      expect(find.text('2 – 0'), findsOneWidget);
      expect(find.text('Final'), findsOneWidget);
      expect(find.text('Defensa y Justicia'), findsOneWidget);
      expect(find.text('Unión'), findsOneWidget);
    });

    testWidgets('en juego: marcador y «En juego»', (tester) async {
      final live = fixtureMatches(
        'eventsround_4616_r33_s2026',
      ).firstWhere((m) => m.status.kind == MatchStatusKind.live);

      await pumpCard(tester, live);

      expect(find.text('En juego'), findsOneWidget);
      expect(
        find.text('${live.score!.home} – ${live.score!.away}'),
        findsOneWidget,
      );
    });

    testWidgets('programado con hora confirmada: hora argentina', (
      tester,
    ) async {
      // Gimnasia y Esgrima de Mendoza – Newell's: 2026-10-12T21:30 UTC.
      await pumpCard(tester, event('eventsround_4406_r12_s2026', '2398120'));

      expect(find.text('18:30'), findsOneWidget);
      expect(find.text('Final'), findsNothing);
    });

    testWidgets('00:00 UTC sin corroborar: «Horario por confirmar»', (
      tester,
    ) async {
      final tentative = event('eventsround_4616_r34_s2026', '2405155');

      await pumpCard(tester, tentative);

      expect(find.text(MatchLabels.unconfirmedTime), findsOneWidget);
      expect(find.text('21:00'), findsNothing);
    });

    testWidgets('definido por penales', (tester) async {
      final pen = fixtureMatches(
        'eventsround_4406_r0_s2026',
      ).firstWhere((m) => m.status.decidedBy == MatchDecision.penalties);

      await pumpCard(tester, pen);

      expect(find.text('Final (penales)'), findsOneWidget);
    });

    testWidgets('no comenzado 3 h después: «Resultado pendiente»', (
      tester,
    ) async {
      final scheduled = event('eventsround_4406_r12_s2026', '2398120');

      await pumpCard(
        tester,
        scheduled,
        now: scheduled.kickoff.utc!.add(const Duration(hours: 4)),
      );

      expect(find.text('Resultado pendiente'), findsOneWidget);
    });

    testWidgets('reprogramado', (tester) async {
      final original = event('eventsround_4406_r12_s2026', '2398120');
      final moved = rebuild(original);
      final rescheduled = Match(
        id: moved.id,
        competitionId: moved.competitionId,
        competitionName: moved.competitionName,
        season: moved.season,
        apiRound: moved.apiRound,
        home: moved.home,
        away: moved.away,
        kickoff: moved.kickoff,
        status: moved.status,
        lastSeenAt: moved.lastSeenAt,
        previousKickoffUtc: DateTime.utc(2026, 10, 12, 18),
      );

      await pumpCard(tester, rescheduled);

      expect(find.text('Reprogramado'), findsOneWidget);
    });

    testWidgets('descripción accesible', (tester) async {
      await pumpCard(tester, event('eventsround_4406_r12_s2026', '2397881'));

      expect(
        find.bySemanticsLabel('Defensa y Justicia 2, Unión 0. Final'),
        findsOneWidget,
      );
    });
  });

  group('TeamBadge', () {
    test('iniciales', () {
      expect(TeamBadge.initialsOf('Boca Juniors'), 'BJ');
      expect(TeamBadge.initialsOf('Gimnasia y Esgrima de La Plata'), 'GE');
      expect(TeamBadge.initialsOf('Unión'), 'U');
      expect(TeamBadge.initialsOf(''), '?');
    });

    testWidgets('sin URL muestra iniciales', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TeamBadge(name: 'River Plate', url: null)),
        ),
      );

      expect(find.text('RP'), findsOneWidget);
    });
  });

  group('lista por día', () {
    testWidgets('fecha 12 del Clausura: encabezados en español y 15 tarjetas', (
      tester,
    ) async {
      final clausura = fixtureMatches(
        'eventsround_4406_r12_s2026',
      ).where((m) => m.kickoff.argentinaDay!.month == 10).toList();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: matchDayItems(matches: clausura, now: recordedAt),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Viernes 09/10/2026'), findsOneWidget);
      expect(find.byType(MatchCard, skipOffstage: false), findsNWidgets(15));
    });

    test('día sin fecha', () {
      expect(MatchLabels.day(null), 'Fecha por confirmar');
      expect(
        MatchLabels.day(const CalendarDay(2026, 10, 11)),
        'Domingo 11/10/2026',
      );
    });
  });

  test('cada error tiene su mensaje para el usuario', () {
    String title(Failure f) => failureMessage(f).title;

    expect(
      title(const NetworkFailure(issue: NetworkIssue.connection, detail: '')),
      'Sin conexión',
    );
    // En Web, CORS y falta de red no se distinguen: se informa como red.
    expect(
      title(const NetworkFailure(issue: NetworkIssue.possibleCors, detail: '')),
      'Sin conexión',
    );
    expect(
      title(const NetworkFailure(issue: NetworkIssue.timeout, detail: '')),
      'La consulta tardó demasiado',
    );
    expect(title(const RateLimitFailure(detail: '')), 'Demasiadas consultas');
    expect(
      title(const ServerFailure(detail: '', statusCode: 503)),
      'TheSportsDB no respondió bien',
    );
    expect(
      failureMessage(const ServerFailure(detail: '', statusCode: 503)).message,
      contains('HTTP 503'),
    );
    expect(title(const FormatFailure(detail: '')), 'Datos inesperados');
    expect(title(const NotFoundFailure(detail: '')), 'No se encontraron datos');
  });

  group('vistas de estado', () {
    testWidgets('ErrorView: mensaje para el usuario y reintento', (
      tester,
    ) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              failure: const NetworkFailure(
                issue: NetworkIssue.connection,
                detail: 'SocketException: Failed host lookup',
              ),
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Sin conexión'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      expect(retried, isTrue);
    });

    testWidgets('StaleDataBanner: fecha y hora argentinas del dato', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaleDataBanner(
              fetchedAt: DateTime.utc(2026, 10, 11, 21, 19),
              failure: const RateLimitFailure(detail: '429'),
            ),
          ),
        ),
      );

      expect(
        find.textContaining('actualizados el 11/10/2026 a las 18:19'),
        findsOneWidget,
      );
      expect(find.textContaining('Demasiadas consultas'), findsOneWidget);
    });
  });

  test('TeamRef sin escudo no rompe la tarjeta', () {
    const team = TeamRef(id: 1, name: 'Equipo sin nombre');
    expect(team.badgeUrl, isNull);
  });
}
