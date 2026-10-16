import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/bracket_panel.dart';

import '../../../helpers/recorded_app.dart';

/// Abre la vista «Llaves» y deja pasar el tiempo que necesita el cupo P2
/// (10 rondas por minuto) para sus rondas.
Future<void> openBracket(WidgetTester tester) async {
  await openView(tester, 'Llaves');
  await tester.pump(const Duration(minutes: 1));
  await tester.pumpAndSettle();
}

/// Vista «Llaves» en la app completa con respuestas grabadas (domingo
/// 11/10/2026).
void main() {
  const laptop = Size(1280, 800);

  testWidgets('Primera: el cuadro del Apertura, con el campeón; el Clausura '
      'todavía sin eliminatorias', (tester) async {
    await pumpApp(tester, laptop);
    await openSection(tester, 'Competiciones');
    await openBracket(tester);

    expect(find.text('Campeón: Belgrano'), findsOne);
    expect(find.text('Octavos de final'), findsOne);
    expect(find.text('Semifinales'), findsOne);
    expect(
      find.bySemanticsLabel(
        RegExp(
          '^Octavos de final\\. River Plate 1, San Lorenzo 1\\. Final '
          '\\(penales\\)\\. Penales: River Plate 4, San Lorenzo 3\\..*'
          'Avanza River Plate \\(4-3 en penales\\)\$',
        ),
      ),
      findsOne,
    );

    await tester.tap(find.text('Clausura'));
    await tester.pumpAndSettle();
    expect(find.text('Sin eliminatorias'), findsOne);
    expect(
      find.textContaining(
        'Todavía no hay partidos de eliminación del '
        'Clausura 2026',
      ),
      findsOne,
    );
  });

  testWidgets('tocar una llave abre el partido, con la tanda y quién avanza', (
    tester,
  ) async {
    await pumpApp(tester, laptop);
    await openSection(tester, 'Competiciones');
    await openBracket(tester);

    final tie = find.bySemanticsLabel(
      RegExp(r'^Semifinales\. Argentinos Juniors 1'),
    );
    await tester.ensureVisible(tie);
    await tester.pumpAndSettle();
    await tester.tap(tie);
    await tester.pumpAndSettle();
    expect(find.text('Penales: 3-4'), findsOne);
    expect(find.text('Avanza Belgrano (3-4 en penales)'), findsOne);
    expect(find.textContaining('no informa el resultado'), findsNothing);
  });

  testWidgets('Copa: desde octavos, la final a definir; se puede ver desde '
      '32avos', (tester) async {
    await pumpApp(tester, laptop);
    await openSection(tester, 'Competiciones');
    await selectCompetition(tester, 'Copa Argentina');
    await openBracket(tester);

    expect(find.text('Campeón'), findsNothing);
    expect(find.text('Desde'), findsOne);
    // El encabezado de la columna y el chip «Octavos de final».
    expect(find.text('Octavos de final'), findsNWidgets(2));
    expect(find.text('A definir'), findsNWidgets(2));
    expect(
      find.bySemanticsLabel(
        RegExp(
          '^Semifinales\\. Banfield contra '
          'Boca Juniors',
        ),
      ),
      findsOne,
    );

    await tester.tap(find.widgetWithText(ChoiceChip, '32avos de final'));
    await tester.pumpAndSettle();
    // Los 32avos por penales sin la tanda: avanza el que juega 16avos.
    expect(
      find.bySemanticsLabel(
        RegExp(
          '^32avos de final\\. Barracas Central 2, Temperley 2\\..*'
          'Avanza Barracas Central\$',
        ),
      ),
      findsOne,
    );
  });

  testWidgets('el partido de 32avos sin la tanda muestra quién avanzó según '
      'la ronda siguiente guardada', (tester) async {
    await pumpApp(tester, laptop);
    await openSection(tester, 'Competiciones');
    await selectCompetition(tester, 'Copa Argentina');
    await openBracket(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '32avos de final'));
    await tester.pumpAndSettle();

    final tie = find.bySemanticsLabel(
      RegExp('^32avos de final\\. Barracas Central 2'),
    );
    await tester.ensureVisible(tie);
    await tester.pumpAndSettle();
    await tester.tap(tie);
    await tester.pumpAndSettle();
    expect(find.text('Avanza Barracas Central'), findsOne);
    // El rótulo y la nota van en un mismo texto («Llave · …»).
    expect(
      find.textContaining(
        'Según los partidos guardados de la ronda '
        'siguiente.',
      ),
      findsOne,
    );
    expect(
      find.textContaining(
        'TheSportsDB no informa el resultado de los '
        'penales.',
      ),
      findsOne,
    );
  });

  testWidgets('Nacional: sin cuadro verificado, sin segmento «Llaves»; con '
      'las llaves abiertas vuelve al Fixture', (tester) async {
    await pumpApp(tester, laptop);
    await openSection(tester, 'Competiciones');
    await openView(tester, 'Llaves');
    expect(find.byType(BracketPanel), findsOne);

    await selectCompetition(tester, 'Nacional');
    expect(find.text('Llaves'), findsNothing);
    expect(find.text('Tabla'), findsOne);
    expect(find.byType(BracketPanel), findsNothing);
    expect(find.text('Sin cuadro de llaves'), findsNothing);
  });
}
