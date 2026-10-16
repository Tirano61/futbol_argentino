import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/competition_picker.dart';

import '../../../helpers/real_fonts.dart';

/// Selector de la Fase D2 solo, con la competición elegida en un estado
/// propio. [selections] guarda cada elección (una por toque).
Future<void> pumpPicker(
  WidgetTester tester, {
  required double width,
  double height = 900,
  int initialId = 4406,
  required List<int> selections,
}) async {
  tester.view
    ..physicalSize = Size(width, height)
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
  // Si los chips entran en una línea depende del ancho real del texto.
  setUpAll(loadRealFonts);

  group('teléfono (< 600 px): botón y hoja inferior', () {
    testWidgets('la hoja agrupa por categoría y marca la actual', (
      tester,
    ) async {
      final selections = <int>[];
      // Alto suficiente para que la hoja (9/16 de la pantalla) muestre las
      // siete competiciones sin desplazarse.
      await pumpPicker(
        tester,
        width: 360,
        height: 1200,
        selections: selections,
      );

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
        [
          'Primera División',
          'Ascenso',
          'Copas nacionales',
          'Copas internacionales',
        ],
      );
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
        ('Copa Libertadores', false),
        ('Copa Sudamericana', false),
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
      expect(
        top(find.widgetWithText(ListTile, 'Copa Argentina')),
        lessThan(top(find.text('Copas internacionales'))),
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
        find.widgetWithText(ListTile, 'Copa Sudamericana'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.widgetWithText(ListTile, 'Copa Sudamericana'), findsOne);
    });
  });

  group('desde 600 px: chips de categoría y de competición', () {
    testWidgets('categoría con una sola competición: sin segunda fila', (
      tester,
    ) async {
      await pumpPicker(tester, width: 768, selections: <int>[]);

      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(ChoiceChip), findsNWidgets(4));
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

  testWidgets('Fase D3: «Copas internacionales» elige la Libertadores', (
    tester,
  ) async {
    final selections = <int>[];
    await pumpPicker(tester, width: 768, selections: selections);

    await tester.ensureVisible(chip('Copas internacionales'));
    await tester.tap(chip('Copas internacionales'));
    await tester.pumpAndSettle();

    expect(selections, [4501]);
    expect(isSelected(tester, 'Libertadores'), isTrue);
    expect(chip('Sudamericana'), findsOne);
  });

  group('las categorías no entran en una línea: botón y hoja', () {
    // La columna del fixture junto al panel de detalle (1280 px en
    // horizontal) mide unos 550 px: el selector se pone en `width`.
    testWidgets('550 px: botón en lugar de chips cortados', (tester) async {
      final selections = <int>[];
      await pumpPicker(
        tester,
        width: 582,
        height: 1200,
        selections: selections,
      );

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Primera División'), findsOne);
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Copa Sudamericana'));
      await tester.pumpAndSettle();

      expect(selections, [4724]);
      expect(
        find.widgetWithText(
          OutlinedButton,
          'Copas internacionales · Sudamericana',
        ),
        findsOne,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });

    testWidgets(
      'al ensancharse vuelven los chips (y al angostarse, el botón)',
      (tester) async {
        await pumpPicker(tester, width: 582, selections: <int>[]);
        expect(find.byType(OutlinedButton), findsOne);

        tester.view.physicalSize = const Size(800, 900);
        await tester.pumpAndSettle();
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.byType(ChoiceChip), findsNWidgets(4));
        // Las cuatro categorías enteras dentro del selector.
        final picker = tester.getRect(find.byType(CompetitionPicker));
        for (final label in [
          'Primera División',
          'Ascenso',
          'Copas nacionales',
          'Copas internacionales',
        ]) {
          expect(
            tester.getRect(chip(label)).right,
            lessThanOrEqualTo(picker.right),
          );
        }

        tester.view.physicalSize = const Size(582, 900);
        await tester.pumpAndSettle();
        expect(find.byType(ChoiceChip), findsNothing);
        expect(find.byType(OutlinedButton), findsOne);
      },
    );

    testWidgets('768 px con texto al 200 %: botón, sin desbordes', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPicker(tester, width: 768, selections: <int>[]);

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(OutlinedButton), findsOne);
      expect(tester.takeException(), isNull);
    });
  });

  group('la hoja, del alto de su contenido', () {
    testWidgets(
      '1280×800 (horizontal): todas las competiciones sin desplazar',
      (tester) async {
        await pumpPicker(
          tester,
          width: 582,
          height: 800,
          initialId: 4501,
          selections: <int>[],
        );
        await tester.tap(find.byType(OutlinedButton));
        await tester.pumpAndSettle();

        final screen = tester.view.physicalSize.height;
        for (final name in ['Primera División', 'Copa Sudamericana']) {
          final tile = find.widgetWithText(ListTile, name);
          expect(tile, findsOne, reason: name);
          expect(tester.getRect(tile).bottom, lessThanOrEqualTo(screen));
        }
      },
    );

    testWidgets('texto al 200 %: se desplaza y abre con la actual a la vista', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPicker(
        tester,
        width: 360,
        height: 780,
        initialId: 4724,
        selections: <int>[],
      );
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      final current = find.widgetWithText(ListTile, 'Copa Sudamericana');
      expect(current, findsOne);
      final rect = tester.getRect(current);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(780));
      expect(tester.widget<ListTile>(current).selected, isTrue);
    });
  });
}
