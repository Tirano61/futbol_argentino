import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/calendar/calendar_event.dart';
import 'package:futbol_argentino/core/platform/external_actions.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/match_detail/presentation/pages/match_detail_page.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';

import '../../helpers/fake_external_actions.dart';
import '../../helpers/fakes.dart';
import '../../helpers/fixture_matches.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    int id,
    FakeExternalActions actions, {
    Size size = const Size(800, 2400),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          // Partidos reales: Primera 2026 fecha 11, Nacional fecha 34.
          RepositoryProvider<MatchRepository>.value(
            value: FakeMatchRepository({
              11: fixtureMatches('eventsround_4406_r11_s2026'),
              34: fixtureMatches('eventsround_4616_r34_s2026'),
            }),
          ),
          RepositoryProvider<Clock>.value(
            value: FixedClock(DateTime.utc(2026, 10, 11, 21)),
          ),
          RepositoryProvider<ExternalActions>.value(value: actions),
        ],
        child: MaterialApp(home: MatchDetailPage(matchId: id)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('programado: comparte el texto y agenda con hora', (
    tester,
  ) async {
    final actions = FakeExternalActions();
    await pumpPage(tester, 2398113, actions); // Sarmiento – River, 14/10

    await tap(tester, 'Compartir');
    expect(actions.shared.single.subject, 'Sarmiento vs. River Plate');
    expect(
      actions.shared.single.text,
      contains('Miércoles 14/10/2026 · 19:00'),
    );
    expect(find.byType(SnackBar), findsNothing);

    await tap(tester, 'Agregar al calendario');
    final added = actions.events.single;
    expect(added.fileName, 'partido-2398113.ics');
    expect(
      (added.event.time as TimedEvent).startUtc,
      DateTime.utc(2026, 10, 14, 22),
    );
  });

  testWidgets('sin poder compartir: avisa que se copió', (tester) async {
    await pumpPage(
      tester,
      2398113,
      FakeExternalActions(shareOutcome: ShareOutcome.copied),
    );

    await tap(tester, 'Compartir');

    expect(find.text('Copiado al portapapeles.'), findsOneWidget);
  });

  testWidgets('Web: avisa la descarga del .ics', (tester) async {
    await pumpPage(
      tester,
      2398113,
      FakeExternalActions(calendarOutcome: CalendarOutcome.downloaded),
    );

    await tap(tester, 'Agregar al calendario');

    expect(
      find.text(
        'Se descargó partido-2398113.ics: abrilo para agregarlo a tu '
        'calendario.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('hora sin confirmar: evento de todo el día', (tester) async {
    final actions = FakeExternalActions();
    await pumpPage(tester, 2405155, actions); // Rafaela – Quilmes, 00:00 UTC

    await tap(tester, 'Agregar al calendario (todo el día)');

    expect(actions.events.single.event.time, isA<AllDayEvent>());
  });

  testWidgets('terminado: se comparte, pero no se agenda', (tester) async {
    await pumpPage(tester, 2398104, FakeExternalActions()); // Boca – Unión

    expect(find.text('Compartir'), findsOneWidget);
    expect(find.textContaining('Agregar al calendario'), findsNothing);
  });

  testWidgets('texto al 200 % en 360 px: los botones no desbordan', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpPage(
      tester,
      2405155,
      FakeExternalActions(),
      size: const Size(360, 4000),
    );

    expect(find.text('Compartir'), findsOneWidget);
    expect(find.text('Agregar al calendario (todo el día)'), findsOneWidget);
    // Un desborde falla el test por sí solo.
  });
}
