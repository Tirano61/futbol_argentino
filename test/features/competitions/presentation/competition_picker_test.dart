import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/competition_logo.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/competition_picker.dart';

import 'package:futbol_argentino/shared/presentation/theme/app_spacing.dart';

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

/// Ids de las competiciones de los logos dentro de [of], en orden.
List<int> logoIds(WidgetTester tester, Finder of) => [
  for (final logo in tester.widgetList<CompetitionLogo>(
    find.descendant(of: of, matching: find.byType(CompetitionLogo)),
  ))
    logo.competition.id,
];

const _ids = [4406, 4616, 5215, 5524, 4500, 4501, 4724];

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
    // El logo a la izquierda del nombre, centrado con él.
    expect(logoIds(tester, picker), [4501]);
    final logo = tester.getRect(
      find.descendant(of: picker, matching: find.byType(CompetitionLogo)),
    );
    final name = tester.getRect(inPicker('Libertadores'));
    expect(logo.right, lessThan(name.left));
    expect(logo.center.dy, moreOrLessEquals(name.center.dy, epsilon: 1));
    expect(find.byTooltip(CompetitionPicker.tooltip), findsOne);
    expect(find.bySemanticsLabel('Competición: Copa Libertadores'), findsOne);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('${width.toInt()} px: al aparecer, el selector carga los '
        'logos de las siete competiciones', (tester) async {
      PaintingBinding.instance.imageCache.clear();
      await pumpPicker(tester, width: width, selections: <int>[]);

      for (final path in CompetitionLogo.assets.values) {
        final key = (await tester.runAsync(
          () => AssetImage(path).obtainKey(ImageConfiguration.empty),
        ))!;
        expect(
          PaintingBinding.instance.imageCache.statusForKey(key).tracked,
          isTrue,
          reason: path,
        );
      }
    });
  }

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
      // Cada una con su logo al principio de la fila.
      expect(logoIds(tester, find.byType(BottomSheet)), _ids);
      expect([
        for (final t in tester.widgetList<ListTile>(find.byType(ListTile)))
          (t.leading! as CompetitionLogo).competition.id,
      ], _ids);
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
        // Cada una con su logo; la tilde, al final.
        expect([
          for (final e in items.evaluate())
            ((e.widget as MenuItemButton).leadingIcon! as CompetitionLogo)
                .competition
                .id,
        ], _ids);
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
        expect(
          tester.getRect(check).left,
          greaterThan(tester.getRect(find.text('Primera Nacional').last).right),
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

    testWidgets('en escritorio (densidad compacta), filas de 48 con los '
        'logos separados', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await pumpPicker(tester, width: 1280, selections: <int>[]);
        await tester.tap(picker);
        await tester.pumpAndSettle();

        final items = find.byType(MenuItemButton);
        for (final e in items.evaluate()) {
          expect(tester.getSize(find.byWidget(e.widget)).height, 48);
        }
        final logos = tester
            .widgetList<CompetitionLogo>(
              find.descendant(
                of: items,
                matching: find.byType(CompetitionLogo),
              ),
            )
            .map((l) => tester.getRect(find.byWidget(l)))
            .toList();
        // Primera Nacional, B Metro y Primera C van seguidas.
        expect(logos[2].top - logos[1].bottom, AppSpacing.md);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

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
        '${l.seasonInBar ? 'en la barra' : 'abajo'}'
        '${l.showLogo ? '' : ', sin logo'}';

    /// Ancho del selector con [name] (logo incluido salvo [logo] falso).
    Future<double> measure(
      WidgetTester tester,
      String name, {
      bool logo = true,
    }) async {
      late double width;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              width = CompetitionPicker.widthFor(context, name, logo: logo);
              return const SizedBox();
            },
          ),
        ),
      );
      return width;
    }

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
        width: 324,
        seasonWidth: 80,
      );
      expect(describe(l), 'corto, temporada en la barra');
    });

    testWidgets('si tampoco: la temporada baja y vuelve el nombre completo '
        'si entra solo', (tester) async {
      final l = await resolve(
        tester,
        competition: CompetitionCatalog.copaLibertadores,
        width: 304,
        seasonWidth: 200,
      );
      expect(describe(l), 'completo, temporada abajo');
    });

    testWidgets('sin lugar ni para el completo solo: el corto, temporada '
        'abajo', (tester) async {
      final l = await resolve(
        tester,
        competition: CompetitionCatalog.primeraBMetropolitana,
        width: 194,
        seasonWidth: 80,
      );
      expect(describe(l), 'corto, temporada abajo');
    });

    testWidgets('sin temporada todavía: solo decide el nombre', (tester) async {
      final l = await resolve(
        tester,
        competition: CompetitionCatalog.copaSudamericana,
        width: 240,
      );
      expect(describe(l), 'corto, temporada en la barra');
    });

    testWidgets('el logo cuenta en el ancho del selector', (tester) async {
      final withLogo = await measure(tester, 'Copa Libertadores');
      final without = await measure(tester, 'Copa Libertadores', logo: false);
      expect(withLogo - without, AppSizes.competitionLogoTile + AppSpacing.sm);
    });

    testWidgets('si ni el corto entra con el logo: el logo se oculta antes '
        'de recortar el nombre', (tester) async {
      final competition = CompetitionCatalog.copaSudamericana;
      final short = await measure(tester, competition.shortName);
      final bare = await measure(tester, competition.shortName, logo: false);

      // El corto entra justo con el logo: lo conserva.
      var l = await resolve(
        tester,
        competition: competition,
        width: short,
        seasonWidth: 80,
      );
      expect(describe(l), 'corto, temporada abajo');

      // Un píxel menos: sin logo, el nombre corto entero.
      l = await resolve(
        tester,
        competition: competition,
        width: short - 1,
        seasonWidth: 80,
      );
      expect(describe(l), 'corto, temporada abajo, sin logo');
      expect(bare, lessThanOrEqualTo(short - 1));

      // Sin lugar ni para el corto solo: sin logo (el nombre se recorta).
      l = await resolve(tester, competition: competition, width: bare - 1);
      expect(describe(l), 'corto, temporada en la barra, sin logo');
    });
  });
}
