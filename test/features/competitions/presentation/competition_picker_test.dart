import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/competition_picker.dart';

/// Selector de la Fase D2 solo, con la competición elegida en un estado
/// propio. [selections] guarda cada elección (una por toque).
Future<void> pumpPicker(
  WidgetTester tester, {
  required double width,
  int initialId = 4406,
  required List<int> selections,
}) async {
  tester.view
    ..physicalSize = Size(width, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  var selected = initialId;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: const EdgeInsets.all(16),
            child: CompetitionPicker(
              selectedId: selected,
              onSelected: (id) {
                selections.add(id);
                setState(() => selected = id);
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

bool isSelected(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(chip(label)).selected;

void main() {
  group('teléfono (< 600 px): botón y hoja inferior', () {
    testWidgets('la hoja agrupa por categoría y marca la actual', (
      tester,
    ) async {
      final selections = <int>[];
      await pumpPicker(tester, width: 360, selections: selections);

      expect(find.byType(ChoiceChip), findsNothing);
      // Una categoría con una sola competición se nombra por ella.
      expect(find.widgetWithText(OutlinedButton, 'Primera División'), findsOne);

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      final headers = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.header ?? false),
      );
      expect(
        [
          for (final e in headers.evaluate())
            (e.widget as Semantics).child is Text
                ? ((e.widget as Semantics).child! as Text).data
                : null,
        ].nonNulls,
        ['Primera División', 'Ascenso', 'Copas nacionales'],
      );
      // La categoría internacional está vacía hasta la Fase D3.
      expect(find.text('Copas internacionales'), findsNothing);
      final tiles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => ((t.title! as Text).data, t.selected))
          .toList();
      expect(tiles, [
        ('Primera División', true),
        ('Primera Nacional', false),
        ('Primera B Metropolitana', false),
        ('Primera C', false),
        ('Copa Argentina', false),
      ]);
      // Encabezados en orden, cada uno antes de sus competiciones.
      double top(Finder f) => tester.getTopLeft(f).dy;
      expect(
        top(find.text('Ascenso')),
        lessThan(top(find.widgetWithText(ListTile, 'Primera Nacional'))),
      );
      expect(
        top(find.widgetWithText(ListTile, 'Primera C')),
        lessThan(top(find.text('Copas nacionales'))),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('elegir en la hoja: una sola elección y se cierra', (
      tester,
    ) async {
      final selections = <int>[];
      await pumpPicker(tester, width: 360, selections: selections);

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(ListTile, 'Primera B Metropolitana'),
      );
      await tester.pumpAndSettle();

      expect(selections, [5215]);
      expect(find.byType(ListTile), findsNothing);
      expect(
        find.widgetWithText(OutlinedButton, 'Ascenso · B Metro'),
        findsOne,
      );

      // La actual no vuelve a cargarse.
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(ListTile, 'Primera B Metropolitana'),
      );
      await tester.pumpAndSettle();
      expect(selections, [5215]);
    });

    testWidgets('texto al 200 %: el botón no desborda', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPicker(
        tester,
        width: 360,
        initialId: 5215,
        selections: <int>[],
      );

      expect(find.byType(OutlinedButton), findsOne);
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      // La hoja se desplaza hasta la última competición.
      await tester.scrollUntilVisible(
        find.widgetWithText(ListTile, 'Copa Argentina'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.widgetWithText(ListTile, 'Copa Argentina'), findsOne);
    });
  });

  group('desde 600 px: chips de categoría y de competición', () {
    testWidgets('categoría con una sola competición: sin segunda fila', (
      tester,
    ) async {
      await pumpPicker(tester, width: 768, selections: <int>[]);

      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      expect(isSelected(tester, 'Primera División'), isTrue);
      expect(chip('Nacional'), findsNothing);
    });

    testWidgets('tocar la categoría elige su primera competición con una '
        'sola elección; luego, la última vista', (tester) async {
      final selections = <int>[];
      await pumpPicker(tester, width: 768, selections: selections);

      await tester.tap(chip('Ascenso'));
      await tester.pumpAndSettle();
      expect(selections, [4616]);
      expect(isSelected(tester, 'Ascenso'), isTrue);
      expect(isSelected(tester, 'Nacional'), isTrue);
      expect(chip('B Metro'), findsOne);
      expect(chip('Primera C'), findsOne);

      await tester.tap(chip('Primera C'));
      await tester.pumpAndSettle();
      await tester.tap(chip('Copas nacionales'));
      await tester.pumpAndSettle();
      expect(chip('Primera C'), findsNothing);

      // Vuelve a la Primera C, no a la Nacional.
      await tester.tap(chip('Ascenso'));
      await tester.pumpAndSettle();
      expect(selections, [4616, 5524, 4500, 5524]);
      expect(isSelected(tester, 'Primera C'), isTrue);

      // La categoría actual no vuelve a cargar.
      await tester.tap(chip('Ascenso'));
      await tester.pumpAndSettle();
      expect(selections, [4616, 5524, 4500, 5524]);
    });

    testWidgets('768 px: dos filas', (tester) async {
      await pumpPicker(
        tester,
        width: 768,
        initialId: 4616,
        selections: <int>[],
      );

      expect(
        tester.getTopLeft(chip('Nacional')).dy,
        greaterThan(tester.getBottomLeft(chip('Ascenso')).dy),
      );
    });

    testWidgets('1280 px: categorías y competiciones en la misma línea', (
      tester,
    ) async {
      await pumpPicker(
        tester,
        width: 1280,
        initialId: 4616,
        selections: <int>[],
      );

      expect(
        tester.getCenter(chip('Nacional')).dy,
        tester.getCenter(chip('Ascenso')).dy,
      );
      expect(
        tester.getTopLeft(chip('Nacional')).dx,
        greaterThan(tester.getTopRight(chip('Copas nacionales')).dx),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  });
}
