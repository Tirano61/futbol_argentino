import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/competition_picker.dart';

import '../../../helpers/real_fonts.dart';

/// Selector de competición en el título de la barra (Hito E, E-D8), solo,
/// con la competición elegida en un estado propio. [selections] guarda cada
/// elección (una por toque).
Future<void> pumpPicker(
  WidgetTester tester, {
  required double width,
  double height = 900,
  int initialId = 4406,
  bool shortName = false,
  required List<int> selections,
}) async {
  tester.view
    ..physicalSize = Size(width, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  var selected = initialId;
  await tester.pumpWidget(
    MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          appBar: AppBar(
            title: CompetitionPicker(
              selected: CompetitionCatalog.byId(selected)!,
              shortName: shortName,
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

final picker = find.byType(CompetitionPicker);

Finder inPicker(String text) =>
    find.descendant(of: picker, matching: find.text(text));

/// Textos de los encabezados (semánticos) visibles, en orden.
List<String?> headers(WidgetTester tester) => [
  for (final e
      in find
          .byWidgetPredicate(
            (w) => w is Semantics && (w.properties.header ?? false),
          )
          .evaluate())
    switch ((e.widget as Semantics).child) {
      final Text text => text.data,
      final Padding padding when padding.child is Text =>
        (padding.child! as Text).data,
      _ => null,
    },
].nonNulls.toList();

const _categories = [
  'Primera División',
  'Ascenso',
  'Copas nacionales',
  'Copas internacionales',
];

const _names = [
  'Primera División',
  'Primera Nacional',
  'Primera B Metropolitana',
  'Primera C',
  'Copa Argentina',
  'Copa Libertadores',
  'Copa Sudamericana',
];

void main() {
  // Lo que entra en la barra depende del ancho real del texto.
  setUpAll(loadRealFonts);

  testWidgets('el nombre de la competición con la flecha, el tooltip y la '
      'semántica con el nombre completo', (tester) async {
    await pumpPicker(
      tester,
      width: 360,
      initialId: 4501,
      shortName: true,
      selections: <int>[],
    );

    expect(inPicker('Libertadores'), findsOne);
    expect(
      find.descendant(of: picker, matching: find.byIcon(Icons.arrow_drop_down)),
      findsOne,
    );
    expect(find.byTooltip(CompetitionPicker.tooltip), findsOne);
    expect(find.bySemanticsLabel('Competición: Copa Libertadores'), findsOne);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  group('teléfono (< 600 px): hoja inferior', () {
    testWidgets('la hoja agrupa por categoría y marca la actual', (
      tester,
    ) async {
      // Alto suficiente para que la hoja muestre las siete competiciones
      // sin desplazarse.
      await pumpPicker(tester, width: 360, height: 1200, selections: <int>[]);

      expect(inPicker('Primera División'), findsOne);
      await tester.tap(picker);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOne);
      expect(find.byType(MenuItemButton), findsNothing);
      expect(headers(tester), _categories);
      final tiles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => ((t.title! as Text).data, t.selected))
          .toList();
      expect(tiles, [for (final n in _names) (n, n == 'Primera División')]);
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

    testWidgets('elegir en la hoja: una sola elección, se cierra y el título '
        'cambia', (tester) async {
      final selections = <int>[];
      await pumpPicker(tester, width: 360, selections: selections);

      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(ListTile, 'Primera B Metropolitana'),
      );
      await tester.pumpAndSettle();

      expect(selections, [5215]);
      expect(find.byType(BottomSheet), findsNothing);
      expect(inPicker('Primera B Metropolitana'), findsOne);

      // La actual no vuelve a cargarse.
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(ListTile, 'Primera B Metropolitana'),
      );
      await tester.pumpAndSettle();
      expect(selections, [5215]);
    });

    testWidgets('texto al 200 %: se desplaza y abre con la actual a la '
        'vista', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPicker(
        tester,
        width: 360,
        height: 780,
        initialId: 4724,
        shortName: true,
        selections: <int>[],
      );
      await tester.tap(picker);
      await tester.pumpAndSettle();

      final current = find.widgetWithText(ListTile, 'Copa Sudamericana');
      expect(current, findsOne);
      final rect = tester.getRect(current);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(780));
      expect(tester.widget<ListTile>(current).selected, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('desde 600 px: menú agrupado por categoría', () {
    for (final width in [768.0, 1280.0]) {
      testWidgets('${width.toInt()} px: las cuatro categorías y las siete '
          'competiciones, con la actual marcada', (tester) async {
        await pumpPicker(
          tester,
          width: width,
          initialId: 4616,
          selections: <int>[],
        );

        await tester.tap(picker);
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsNothing);
        expect(headers(tester), _categories);
        final items = find.byType(MenuItemButton);
        expect([
          for (final e in items.evaluate())
            ((e.widget as MenuItemButton).child! as Semantics).child is Text
                ? (((e.widget as MenuItemButton).child! as Semantics).child!
                          as Text)
                      .data
                : null,
        ], _names);
        // Solo la actual lleva la tilde (y la semántica de elegida).
        final check = find.descendant(
          of: items,
          matching: find.byIcon(Icons.check),
        );
        expect(check, findsOne);
        expect(
          find.ancestor(
            of: check,
            matching: find.widgetWithText(MenuItemButton, 'Primera Nacional'),
          ),
          findsOne,
        );
        // Cada categoría antes de sus competiciones.
        double top(Finder f) => tester.getTopLeft(f).dy;
        expect(
          top(find.text('Ascenso')),
          lessThan(
            top(find.widgetWithText(MenuItemButton, 'Primera Nacional')),
          ),
        );
        expect(
          top(find.widgetWithText(MenuItemButton, 'Copa Argentina')),
          lessThan(top(find.text('Copas internacionales'))),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });
    }

    testWidgets('elegir en el menú: una sola elección, se cierra y el '
        'título cambia', (tester) async {
      final selections = <int>[];
      await pumpPicker(tester, width: 800, selections: selections);

      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(MenuItemButton, 'Copa Sudamericana'),
      );
      await tester.pumpAndSettle();

      expect(selections, [4724]);
      expect(find.byType(MenuItemButton), findsNothing);
      expect(inPicker('Copa Sudamericana'), findsOne);

      // La actual no vuelve a cargarse.
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(MenuItemButton, 'Copa Sudamericana'),
      );
      await tester.pumpAndSettle();
      expect(selections, [4724]);

      // Tocar el título con el menú abierto lo cierra sin elegir.
      await tester.tap(picker);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNWidgets(7));
      await tester.tap(picker);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(selections, [4724]);
    });

    testWidgets('768 px con texto al 200 %: sin desbordes, se llega a la '
        'última', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final selections = <int>[];
      await pumpPicker(
        tester,
        width: 768,
        height: 1024,
        selections: selections,
      );

      await tester.tap(picker);
      await tester.pumpAndSettle();
      final last = find.widgetWithText(MenuItemButton, 'Copa Sudamericana');
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(selections, [4724]);
      expect(tester.takeException(), isNull);
    });
  });

  group('qué entra en la barra (CompetitionTitleLayout)', () {
    Future<CompetitionTitleLayout> resolve(
      WidgetTester tester, {
      required CompetitionDefinition competition,
      required double width,
      double? seasonWidth,
      double textScale = 1,
    }) async {
      if (textScale != 1) {
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      }
      late CompetitionTitleLayout layout;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              layout = CompetitionTitleLayout.resolve(
                context,
                competition: competition,
                width: width,
                seasonWidth: seasonWidth,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      return layout;
    }

    String describe(CompetitionTitleLayout l) =>
        '${l.shortName ? 'corto' : 'completo'}, temporada '
        '${l.seasonInBar ? 'en la barra' : 'abajo'}';

    testWidgets('con lugar: el nombre completo y la temporada', (tester) async {
      final l = await resolve(
        tester,
        competition: CompetitionCatalog.copaLibertadores,
        width: 600,
        seasonWidth: 80,
      );
      expect(describe(l), 'completo, temporada en la barra');
    });

    testWidgets('si no entran juntos: primero el nombre corto', (tester) async {
      final full = await resolve(
        tester,
        competition: CompetitionCatalog.copaLibertadores,
        width: 10000,
      );
      expect(full.shortName, isFalse);
      // Un ancho donde entra el corto con la temporada, pero no el completo.
      final l = await resolve(
        tester,
        competition: CompetitionCatalog.copaLibertadores,
        width: 280,
        seasonWidth: 80,
      );
      expect(describe(l), 'corto, temporada en la barra');
    });

    testWidgets('si tampoco: la temporada baja y vuelve el nombre completo '
        'si entra solo', (tester) async {
      final l = await resolve(
        tester,
        competition: CompetitionCatalog.copaLibertadores,
        width: 260,
        seasonWidth: 200,
      );
      expect(describe(l), 'completo, temporada abajo');
    });

    testWidgets('sin lugar ni para el completo solo: el corto, temporada '
        'abajo', (tester) async {
      final l = await resolve(
        tester,
        competition: CompetitionCatalog.primeraBMetropolitana,
        width: 150,
        seasonWidth: 80,
      );
      expect(describe(l), 'corto, temporada abajo');
    });

    testWidgets('sin temporada todavía: solo decide el nombre', (tester) async {
      final l = await resolve(
        tester,
        competition: CompetitionCatalog.copaSudamericana,
        width: 150,
      );
      expect(describe(l), 'corto, temporada en la barra');
    });
  });
}
