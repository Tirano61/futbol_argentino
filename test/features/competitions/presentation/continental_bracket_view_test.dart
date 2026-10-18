import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/bracket_panel.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_group.dart';

import '../../../helpers/recorded_app.dart';

/// Fase D5: series de ida y vuelta en las Llaves, el Fixture y el detalle
/// de las copas internacionales, en la app completa con las respuestas
/// grabadas el 14/10/2026 (D1).
void main() {
  const laptop = Size(1280, 800);

  Future<void> openCup(WidgetTester tester, String cup, {Size? size}) async {
    await pumpApp(tester, size ?? laptop, now: continentalRecordingTime);
    await openSection(tester, 'Competiciones');
    await selectCompetition(tester, cup);
  }

  Future<void> chooseSeason2025(WidgetTester tester) async {
    await tester.tap(find.text('Temporada 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temporada 2025').last);
    await tester.pumpAndSettle();
  }

  /// Desplaza la lista del panel (no el cuadro, que va a lo ancho).
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find
          .descendant(
            of: find.byType(BracketPanel),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openBracket(WidgetTester tester) async {
    await openView(tester, 'Llaves');
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('Libertadores 2025: árbol de octavos a la final, campeón '
      'Flamengo, series con el global', (tester) async {
    await openCup(tester, 'Libertadores');
    await chooseSeason2025(tester);
    await openBracket(tester);

    expect(find.text('Campeón: Flamengo'), findsOne);
    // Un solo cuadro: sin chips de fase.
    expect(find.widgetWithText(ChoiceChip, 'Eliminatorias'), findsNothing);
    expect(
      find.bySemanticsLabel(
        RegExp(
          '^Octavos de final\\. Peñarol contra Racing Club, ida y vuelta\\. '
          'Ida: Peñarol 1, Racing Club 0\\. Final\\. '
          'Vuelta: Racing Club 3, Peñarol 1\\. Final\\. '
          'Global Peñarol 2-3 Racing Club\\. '
          'Avanza Racing Club \\(global 3-2\\)\$',
        ),
      ),
      findsOne,
    );
    // Global empatado sin penales (2025): el que juega la ronda siguiente.
    expect(
      find.bySemanticsLabel(
        RegExp(
          '^Octavos de final\\. Club Libertad contra River Plate.*'
          'Avanza River Plate \\(juega la ronda siguiente\\)\$',
        ),
      ),
      findsOne,
    );
    final footer = find.textContaining('las gana quien hace más goles');
    await scrollTo(tester, footer);
    expect(footer, findsOne);
  });

  testWidgets('tocar una serie abre su vuelta, con la serie y quién avanza', (
    tester,
  ) async {
    await openCup(tester, 'Libertadores');
    await chooseSeason2025(tester);
    await openBracket(tester);

    final tie = find.bySemanticsLabel(
      RegExp('^Octavos de final\\. Peñarol contra Racing Club'),
    );
    await tester.ensureVisible(tie);
    await tester.pumpAndSettle();
    await tester.tap(tie);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Ida: Peñarol 1-0 Racing Club\n'
        'Vuelta: Racing Club 3-1 Peñarol\n'
        'Global Peñarol 2-3 Racing Club',
      ),
      findsOne,
    );
    expect(find.text('Avanza Racing Club (global 3-2)'), findsOne);
  });

  testWidgets('Sudamericana 2025: Playoffs como lista y la final sin dato de '
      'la definición', (tester) async {
    await openCup(tester, 'Sudamericana');
    await chooseSeason2025(tester);
    await openBracket(tester);

    expect(find.textContaining('Campeón'), findsNothing);
    expect(
      find.bySemanticsLabel(
        RegExp(
          '^Final\\. Lanús 0, Atlético Mineiro 0\\. Final\\. '
          'Sin dato de la definición\$',
        ),
      ),
      findsOne,
    );
    await scrollTo(tester, find.text('Playoffs de octavos'));
    expect(find.text('Sus ganadores juegan los octavos de final.'), findsOne);
    expect(
      find.bySemanticsLabel(
        RegExp(
          '^Playoffs de octavos\\. Atlético Bucaramanga contra Atlético '
          'Mineiro, ida y vuelta.*Avanza Atlético Mineiro \\(juega la ronda '
          'siguiente\\)\$',
        ),
      ),
      findsOne,
    );
  });

  testWidgets('Libertadores 2026: semifinales en juego y la final a definir', (
    tester,
  ) async {
    await openCup(tester, 'Libertadores');
    await openBracket(tester);

    expect(find.textContaining('Campeón'), findsNothing);
    expect(
      find.bySemanticsLabel(
        RegExp(
          '^Semifinales\\. Fluminense contra Palmeiras, ida y vuelta\\. '
          'Ida: Fluminense 0, Palmeiras 0\\. En juego\\. '
          'Vuelta: Palmeiras contra Fluminense\\..*'
          'Global parcial Fluminense 0-0 Palmeiras\$',
        ),
      ),
      findsOne,
    );
    expect(find.text('Ida en juego'), findsOne);
    expect(find.text('A definir'), findsNWidgets(2));
  });

  testWidgets('Fixture: los octavos agrupados por serie, con ida, vuelta, '
      'global y la tanda', (tester) async {
    // Vista alta: todas las tarjetas de la etapa se construyen.
    await openCup(tester, 'Libertadores', size: const Size(800, 6000));
    // Abre en las semifinales: dos atrás, los octavos.
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('Anterior'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Octavos de final'), findsWidgets);
    expect(find.byType(MatchCard), findsNWidgets(16));
    expect(find.textContaining('Ida · '), findsNWidgets(8));
    expect(find.textContaining('Vuelta · '), findsNWidgets(8));
    // Un grupo por serie: los equipos y el global en el encabezado, quién
    // avanza al pie.
    final series = find.ancestor(
      of: find.text('Fluminense – Independiente Rivadavia'),
      matching: find.byType(MatchGroup),
    );
    expect(series, findsOne);
    expect(
      find.descendant(
        of: series,
        matching: find.text('Global Fluminense 1-1 Independiente Rivadavia'),
      ),
      findsOne,
    );
    expect(
      find.descendant(
        of: series,
        matching: find.text('Avanza Fluminense (5-4 en penales)'),
      ),
      findsOne,
    );
    expect(
      find.descendant(of: series, matching: find.byType(MatchCard)),
      findsNWidgets(2),
    );
    // Dentro de la serie, la tarjeta no repite «Avanza».
    expect(find.textContaining('Avanza Fluminense (4-5'), findsNothing);
  });
}
