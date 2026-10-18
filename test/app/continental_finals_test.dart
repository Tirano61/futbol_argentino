import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/recorded_app.dart';

/// Fase D7: cuadros y finales de las copas internacionales en la app
/// completa, con las temporadas 2025 completas y las etapas 2026 ya jugadas
/// (respuestas grabadas el 14/10/2026, D1). La final 2026 todavía no está en
/// TheSportsDB: se muestra pendiente, sin «Avanza» ni campeón.
void main() {
  const laptop = Size(1280, 800);

  Future<void> openCup(WidgetTester tester, String cup) async {
    await pumpApp(tester, laptop, now: continentalRecordingTime);
    await openSection(tester, 'Competiciones');
    await selectCompetition(tester, cup);
  }

  Future<void> chooseSeason2025(WidgetTester tester) async {
    await tester.tap(find.text('Temporada 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temporada 2025').last);
    await tester.pumpAndSettle();
  }

  Future<void> openBracket(WidgetTester tester) async {
    await openView(tester, 'Llaves');
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
  }

  /// Las llaves del cuadro (una etiqueta por serie o partido único).
  Finder ties(String round) =>
      find.bySemanticsLabel(RegExp('^${RegExp.escape(round)}\\. '));

  /// Quién pasa: «Avanza X» en un partido único y «Clasificó X por…» en
  /// una serie de ida y vuelta (Fase E7).
  Finder advancing() => find.bySemanticsLabel(RegExp('Avanza |Clasificó '));

  group('2025 completo', () {
    testWidgets('Libertadores: 15 llaves con ganador y la final Palmeiras 0-1 '
        'Flamengo con el campeón', (tester) async {
      await openCup(tester, 'Libertadores');
      await chooseSeason2025(tester);
      await openBracket(tester);

      expect(ties('Octavos de final'), findsNWidgets(8));
      expect(ties('Cuartos de final'), findsNWidgets(4));
      expect(ties('Semifinales'), findsNWidgets(2));
      expect(advancing(), findsNWidgets(15));
      expect(
        find.bySemanticsLabel(
          RegExp(
            '^Final\\. Palmeiras 0, Flamengo 1\\. Final\\. Avanza Flamengo\$',
          ),
        ),
        findsOne,
      );
      expect(find.text('Campeón: Flamengo'), findsOne);
    });

    testWidgets('Libertadores: el detalle de la final dice quién gana', (
      tester,
    ) async {
      await openCup(tester, 'Libertadores');
      await chooseSeason2025(tester);
      // El Fixture 2025 abre en la final.
      await tester.tap(find.text('Palmeiras').first);
      await tester.pumpAndSettle();

      expect(find.text('Eliminatorias · Final'), findsOne);
      expect(find.text('Sábado 29/11/2025'), findsWidgets);
      expect(find.text('Avanza Flamengo'), findsOne);
    });

    testWidgets('Sudamericana: cuadro completo, Lanús y Atlético Mineiro en '
        'la final 0-0 sin dato de la definición ni campeón', (tester) async {
      await openCup(tester, 'Sudamericana');
      await chooseSeason2025(tester);
      await openBracket(tester);

      expect(ties('Octavos de final'), findsNWidgets(8));
      expect(ties('Cuartos de final'), findsNWidgets(4));
      expect(
        find.bySemanticsLabel(
          RegExp(
            '^Semifinales\\. Universidad de Chile contra Lanús.*'
            'Clasificó Lanús por resultado global \\(3-2\\)\$',
          ),
        ),
        findsOne,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(
            '^Semifinales\\. Independiente del Valle contra Atlético Mineiro.*'
            'Clasificó Atlético Mineiro por resultado global \\(4-2\\)\$',
          ),
        ),
        findsOne,
      );
      // 8 + 4 + 2 con ganador; la final, no.
      expect(
        find.bySemanticsLabel(
          RegExp(
            '^(Octavos de final|Cuartos de final|Semifinales)\\..*Clasificó ',
          ),
        ),
        findsNWidgets(14),
      );
      expect(
        find.bySemanticsLabel(
          RegExp(
            '^Final\\. Lanús 0, Atlético Mineiro 0\\. Final\\. '
            'Sin dato de la definición\$',
          ),
        ),
        findsOne,
      );
      expect(find.textContaining('Campeón'), findsNothing);
    });

    testWidgets('Sudamericana: el detalle de la final no inventa ganador', (
      tester,
    ) async {
      await openCup(tester, 'Sudamericana');
      await chooseSeason2025(tester);
      await tester.tap(find.text('Lanús').first);
      await tester.pumpAndSettle();

      expect(find.text('Eliminatorias · Final'), findsOne);
      expect(find.text('Sin dato de la definición'), findsOne);
      expect(find.textContaining(RegExp('Avanza|Clasificó')), findsNothing);
    });
  });

  group('2026: etapas jugadas y la final pendiente', () {
    for (final (cup, semis) in [
      (
        'Libertadores',
        [
          'Semifinales\\. Fluminense contra Palmeiras.*'
              'Global parcial Fluminense 0-0 Palmeiras',
          'Semifinales\\. Estudiantes de La Plata contra Flamengo.*'
              'Vuelta: Flamengo contra Estudiantes de La Plata\\. '
              'Jueves 22/10/2026, 21:30',
        ],
      ),
      (
        'Sudamericana',
        [
          'Semifinales\\. Boca Juniors contra Vasco da Gama.*'
              'Global parcial Boca Juniors 0-1 Vasco da Gama',
          'Semifinales\\. Atlético Mineiro contra Montevideo City Torque.*'
              'Global parcial Atlético Mineiro 3-0 Montevideo City Torque',
        ],
      ),
    ]) {
      testWidgets('$cup: octavos y cuartos con ganador; semifinales sin '
          '«Avanza»; la final a definir, sin campeón', (tester) async {
        await openCup(tester, cup);
        await openBracket(tester);

        expect(advancing(), findsNWidgets(8 + 4));
        for (final s in semis) {
          expect(find.bySemanticsLabel(RegExp('^$s\$')), findsOne);
        }
        expect(
          find.bySemanticsLabel(RegExp('^Final\\. A definir\$')),
          findsOne,
        );
        expect(find.textContaining('Campeón'), findsNothing);
      });

      testWidgets('$cup: la final en el Fixture, sin partidos y sin datos '
          'inventados', (tester) async {
        await openCup(tester, cup);
        // El Fixture abre en las semifinales; la siguiente etapa es la final.
        await tester.tap(find.byTooltip('Siguiente'));
        await tester.pumpAndSettle();

        expect(find.text('Sin partidos'), findsOne);
        expect(
          find.text(
            'Final: TheSportsDB todavía no tiene los partidos cargados.',
          ),
          findsOne,
        );
        expect(find.textContaining(RegExp('Avanza|Clasificó')), findsNothing);
      });
    }
  });
}
