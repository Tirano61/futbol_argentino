import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/app/theme/app_theme.dart';
import 'package:futbol_argentino/core/time/calendar_day.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/standings/regular_season_matches.dart';
import 'package:futbol_argentino/features/competitions/domain/standings/standings_table.dart';
import 'package:futbol_argentino/features/competitions/domain/standings/table_builders.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/standings_panel.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/standings_table_view.dart';
import 'package:futbol_argentino/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:futbol_argentino/features/favorites/domain/entities/favorite_team.dart';
import 'package:futbol_argentino/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/shared/presentation/widgets/team_badge.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sembast/sembast.dart' show Database;

import '../helpers/accessibility.dart';
import '../helpers/fake_teams.dart';
import '../helpers/favorites.dart';
import '../helpers/fixture_matches.dart';
import '../helpers/real_fonts.dart';
import '../helpers/recorded_app.dart';
import '../visual/visual_helpers.dart' show goTo, useBrightness, useTextScale;

/// Hito E, Fase E5: la tabla de posiciones rediseñada, con la fuente real
/// (Roboto). Columnas según el **ancho disponible** y la escala de texto,
/// nombres que nunca se parten a mitad de palabra (al 200 % tampoco),
/// favoritos (E-D11), marcadores de los grupos CONMEBOL (E-D10) y
/// cobertura y notas a la vista.
void main() {
  setUpAll(loadRealFonts);

  /// Orden en que entran las columnas (§8 de `docs/HITO_E.md`).
  const priority = ['Pts', 'PJ', 'DG', 'PG', 'PE', 'PP', 'GF', 'GC'];

  final table = find.byType(StandingsTableView);

  /// Columnas a la vista (los encabezados), en orden de prioridad.
  /// (Las iniciales de un escudo que no cargó, como «GC» de Godoy Cruz,
  /// no son encabezados.)
  List<String> columns() => [
    for (final c in priority)
      if (find
          .descendant(of: table, matching: find.text(c))
          .evaluate()
          .any((e) => e.findAncestorWidgetOfExactType<TeamBadge>() == null))
        c,
  ];

  /// Ningún texto de la tabla se parte a mitad de palabra ni queda
  /// recortado: cada palabra en un solo renglón. (Las iniciales de un
  /// escudo que no cargó no son texto de la tabla.)
  void expectWholeWords(WidgetTester tester) {
    final paragraphs = [
      for (final element
          in find
              .descendant(of: table, matching: find.byType(RichText))
              .evaluate())
        if (element.findAncestorWidgetOfExactType<TeamBadge>() == null)
          element.renderObject! as RenderParagraph,
    ];
    expect(paragraphs, isNotEmpty);
    for (final p in paragraphs) {
      final text = p.text.toPlainText();
      expect(p.didExceedMaxLines, isFalse, reason: text);
      for (final word in RegExp(r'[^\s￼]+').allMatches(text)) {
        final lines = {
          for (final box in p.getBoxesForSelection(
            TextSelection(baseOffset: word.start, extentOffset: word.end),
          ))
            box.top.round(),
        };
        expect(lines, hasLength(1), reason: '«${word[0]}» en «$text»');
      }
    }
  }

  /// La etiqueta accesible de la fila del equipo.
  String rowLabel(WidgetTester tester, String team) => tester
      .getSemantics(find.bySemanticsLabel(RegExp('^Posición \\d+.*: $team\\.')))
      .label;

  group('columnas según el ancho disponible', () {
    for (final (width, expected) in [
      (360.0, 3),
      (411.0, null),
      (768.0, 8),
      (800.0, 8),
      (1280.0, 8),
      (1920.0, 8),
    ]) {
      testWidgets('${width.toInt()} px: Tabla Anual', (tester) async {
        await pumpApp(tester, Size(width, 900));
        await goTo(
          tester,
          '/competiciones/4406?temporada=2026&vista=tabla&tabla=anual',
          wait: const Duration(minutes: 2),
        );

        final visible = columns();
        // Siempre Pts, PJ y DG; las demás, en orden de prioridad.
        expect(visible, priority.take(visible.length), reason: '$visible');
        expect(visible.length, expected ?? greaterThanOrEqualTo(3));
        expectWholeWords(tester);
      });
    }

    testWidgets('el ancho de la tabla, no el de la pantalla: el mismo ancho '
        'da las mismas columnas en un teléfono y en un monitor', (
      tester,
    ) async {
      final group = _groupTable(CompetitionCatalog.copaLibertadores, 2026, 'A');
      final results = <(double, double), List<String>>{};
      for (final screen in [360.0, 1920.0]) {
        // 336: la tabla en un teléfono de 360 (márgenes de 12); 760: la
        // columna junto a un panel de 440 en escritorio.
        for (final box in [336.0, 760.0]) {
          await _pumpTableAlone(tester, screen: screen, box: box, table: group);
          results[(screen, box)] = columns();
        }
      }
      expect(results[(360.0, 336.0)], ['Pts', 'PJ', 'DG']);
      expect(results[(1920.0, 336.0)], results[(360.0, 336.0)]);
      expect(results[(1920.0, 760.0)], priority);
      expect(results[(360.0, 760.0)], results[(1920.0, 760.0)]);
    });
  });

  group('texto al 200 %', () {
    for (final (name, location, continental) in [
      ('Tabla Anual', '/competiciones/4406?temporada=2026&vista=tabla', false),
      (
        'Clausura · Zona A',
        '/competiciones/4406?temporada=2026&vista=tabla&tabla=clausura-a',
        false,
      ),
      (
        'Nacional · Zona A',
        '/competiciones/4616?temporada=2026&vista=tabla&tabla=zona-a',
        false,
      ),
      (
        'Libertadores · Grupo A',
        '/competiciones/4501?temporada=2026&vista=tabla&tabla=grupo-a',
        true,
      ),
      (
        'Sudamericana · Grupo C',
        '/competiciones/4724?temporada=2026&vista=tabla&tabla=grupo-c',
        true,
      ),
    ]) {
      for (final width in [360.0, 411.0, 800.0]) {
        testWidgets('$name a ${width.toInt()} px: los nombres se parten '
            'entre palabras; Pts, PJ y DG a la vista', (tester) async {
          useTextScale(tester, 2);
          await pumpApp(
            tester,
            Size(width, 900),
            now: continental ? continentalRecordingTime : null,
            seed: _saveBoca,
          );
          await goTo(tester, location, wait: const Duration(minutes: 4));

          expectWholeWords(tester);
          final visible = columns();
          expect(visible, priority.take(visible.length));
          expect(visible, contains('Pts'));
          if (!visible.contains('PJ')) {
            // PJ y DG debajo del nombre, en cada fila.
            final inline = find.descendant(
              of: table,
              matching: find.textContaining(RegExp(r'^PJ \d+ · DG [+-]?\d+$')),
            );
            expect(
              inline.evaluate().length,
              find
                  .descendant(of: table, matching: find.byType(InkWell))
                  .evaluate()
                  .length,
            );
          }
          // La semántica dice siempre PJ, DG y Pts.
          final first = tester
              .getSemantics(find.bySemanticsLabel(RegExp('^Posición 1')).first)
              .label;
          expect(first, contains('puntos '));
          expect(first, contains('diferencia de gol '));
          expect(first, contains('partidos jugados '));
        });
      }
    }

    testWidgets('360 px: con solo Pts, el nombre más largo entra entero', (
      tester,
    ) async {
      useTextScale(tester, 2);
      await pumpApp(tester, const Size(360, 900));
      await goTo(
        tester,
        '/competiciones/4406?temporada=2026&vista=tabla&tabla=anual',
        wait: const Duration(minutes: 2),
      );
      expect(columns(), ['Pts']);
      // «Independiente Rivadavia», «Gimnasia y Esgrima de La Plata»…
      expect(
        find.descendant(
          of: table,
          matching: find.text('Gimnasia y Esgrima de La Plata'),
        ),
        findsOne,
      );
      expectWholeWords(tester);
    });
  });

  group('favoritos (E-D11)', () {
    for (final width in [360.0, 1280.0]) {
      testWidgets('${width.toInt()} px: fila resaltada y estrella junto al '
          'nombre, sin consultas', (tester) async {
        final requests = <Uri>[];
        await pumpApp(
          tester,
          Size(width, 900),
          requests: requests,
          seed: _saveBoca,
        );
        await goTo(
          tester,
          '/competiciones/4406?temporada=2026&vista=tabla&tabla=apertura-a',
          wait: const Duration(minutes: 2),
        );

        expect(
          rowLabel(tester, 'Boca Juniors'),
          matches(RegExp(r'^Posición 2: Boca Juniors\..* Favorito\.$')),
        );
        final star = find.descendant(
          of: table,
          matching: find.byIcon(Icons.star),
        );
        expect(star, findsOne);
        final boca = find.ancestor(
          of: find.textContaining('Boca Juniors'),
          matching: find.byType(InkWell),
        );
        expect(find.descendant(of: boca, matching: star), findsOne);
        // Fondo tenue: solo la fila del favorito tiene color propio.
        Color? rowColor(String team) => tester
            .widget<Material>(
              find
                  .ancestor(
                    of: find.ancestor(
                      of: find.textContaining(team),
                      matching: find.byType(InkWell),
                    ),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color;
        expect(rowColor('Boca Juniors'), isNot(Colors.transparent));
        expect(rowColor('Boca Juniors'), isNot(_groupColor(tester)));
        final rowColors = [
          for (final row
              in find
                  .descendant(of: table, matching: find.byType(InkWell))
                  .evaluate())
            row.findAncestorWidgetOfExactType<Material>()!.color,
        ];
        expect(rowColors.where((c) => c != Colors.transparent), hasLength(1));
        // El nombre entero, sin partirse por la estrella.
        expectWholeWords(tester);

        // Quitar el favorito no consulta nada: la estrella se va.
        requests.clear();
        final repository = tester
            .element(find.byType(StandingsPanel))
            .read<FavoritesRepository>();
        await outsideFakeAsync(tester, () => repository.remove(135156));
        await tester.pumpAndSettle();
        expect(star, findsNothing);
        expect(rowLabel(tester, 'Boca Juniors'), isNot(contains('Favorito')));
        expect(requests, isEmpty);
      });
    }

    testWidgets('agregar un favorito con la tabla abierta la actualiza, sin '
        'consultas', (tester) async {
      final requests = <Uri>[];
      await pumpApp(tester, const Size(360, 900), requests: requests);
      await goTo(
        tester,
        '/competiciones/4406?temporada=2026&vista=tabla&tabla=apertura-a',
        wait: const Duration(minutes: 2),
      );
      expect(
        find.descendant(of: table, matching: find.byIcon(Icons.star)),
        findsNothing,
      );

      requests.clear();
      final repository = tester
          .element(find.byType(StandingsPanel))
          .read<FavoritesRepository>();
      await outsideFakeAsync(
        tester,
        () => repository.save(
          FavoriteTeam.fromRef(
            recordedTeam('Boca Juniors'),
            addedAt: DateTime.utc(2026, 10, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(rowLabel(tester, 'Boca Juniors'), endsWith('Favorito.'));
      expect(
        find.descendant(of: table, matching: find.byIcon(Icons.star)),
        findsOne,
      );
      expect(requests, isEmpty);
    });
  });

  group('marcadores de clasificación (E-D10)', () {
    String note(CompetitionDefinition cup) =>
        (cup.standingsFor(const Season(2026)) as GroupStage).qualificationNote;

    for (final (cup, group, places) in [
      (CompetitionCatalog.copaLibertadores, 'G', 3),
      (CompetitionCatalog.copaSudamericana, 'A', 2),
    ]) {
      testWidgets('${cup.shortName} 2026, Grupo $group: los $places '
          'primeros siguen en competencia; leyenda con la nota del '
          'catálogo', (tester) async {
        await pumpApp(
          tester,
          const Size(360, 900),
          now: continentalRecordingTime,
        );
        await goTo(
          tester,
          '/competiciones/${cup.id}?temporada=2026&vista=tabla'
          '&tabla=grupo-${group.toLowerCase()}',
          wait: const Duration(minutes: 1),
        );

        for (var position = 1; position <= 4; position++) {
          final label = tester
              .getSemantics(
                find.bySemanticsLabel(RegExp('^Posición $position[:,]')),
              )
              .label;
          expect(
            label.endsWith('Sigue en competencia.'),
            position <= places,
            reason: label,
          );
        }
        // Una barra por puesto marcado.
        expect(
          find.descendant(
            of: table,
            matching: find.byWidgetPredicate(
              (w) => w is Positioned && w.left == 0 && w.width == 3,
            ),
          ),
          findsNWidgets(places),
        );
        // La nota del catálogo, una sola vez (en la leyenda, no en el pie).
        expect(find.textContaining(note(cup)), findsOne);
        expect(
          find.textContaining(
            'Sigue en competencia. ${note(cup)} Posiciones actuales, no '
            'definitivas.',
          ),
          findsOne,
        );
      });
    }

    for (final (name, location) in [
      ('Tabla Anual', '/competiciones/4406?temporada=2026&vista=tabla'),
      (
        'Clausura · Zona A',
        '/competiciones/4406?temporada=2026&vista=tabla&tabla=clausura-a',
      ),
      (
        'Nacional · Zona A',
        '/competiciones/4616?temporada=2026&vista=tabla&tabla=zona-a',
      ),
    ]) {
      testWidgets('$name: sin marcadores ni leyenda (sin cupos en el '
          'catálogo)', (tester) async {
        await pumpApp(tester, const Size(360, 900));
        await goTo(tester, location, wait: const Duration(minutes: 4));
        expect(table, findsOne);
        expect(find.textContaining('Sigue en competencia'), findsNothing);
        expect(
          find.bySemanticsLabel(RegExp('Sigue en competencia')),
          findsNothing,
        );
      });
    }

    test('una posición compartida que cruza el corte no se marca '
        '(Libertadores 2025 al 02/04, datos grabados)', () {
      final b = _groupTable(
        CompetitionCatalog.copaLibertadores,
        2025,
        'B',
        until: const CalendarDay(2025, 4, 2),
      );
      expect(_order(b), [
        '1 River Plate',
        '2 Barcelona SC',
        '3* Independiente del Valle',
        '3* Universitario',
      ]);
      expect(_names(b, StandingsTableView.advancingTeams(b.rows, 3)), {
        'River Plate',
        'Barcelona SC',
      });

      // Compartida pero adentro del corte: sí se marca.
      final d = _groupTable(
        CompetitionCatalog.copaLibertadores,
        2025,
        'D',
        until: const CalendarDay(2025, 4, 2),
      );
      expect(_order(d), [
        '1* Club Libertad',
        '1* São Paulo',
        '3* Alianza Lima',
        '3* Talleres de Córdoba',
      ]);
      expect(_names(d, StandingsTableView.advancingTeams(d.rows, 3)), {
        'Club Libertad',
        'São Paulo',
      });
      // Con 2 cupos (Sudamericana), el 1.° compartido entre dos también.
      expect(StandingsTableView.advancingTeams(d.rows, 2), hasLength(2));
      expect(StandingsTableView.advancingTeams(d.rows, 1), isEmpty);
      // Sin cupos en el catálogo, nadie.
      expect(StandingsTableView.advancingTeams(d.rows, null), isEmpty);
    });

    testWidgets('la tabla compartida: «3*» y la semántica, sin marcador en '
        'los que cruzan el corte', (tester) async {
      final b = _groupTable(
        CompetitionCatalog.copaLibertadores,
        2025,
        'B',
        until: const CalendarDay(2025, 4, 2),
      );
      await _pumpTableAlone(
        tester,
        screen: 360,
        box: 336,
        table: b,
        advancing: StandingsTableView.advancingTeams(b.rows, 3),
      );
      expect(find.text('3*'), findsNWidgets(2));
      expect(
        rowLabel(tester, 'Universitario'),
        allOf(
          startsWith('Posición 3, compartida: Universitario.'),
          isNot(contains('Sigue en competencia')),
        ),
      );
      expect(
        rowLabel(tester, 'Barcelona SC'),
        endsWith('Sigue en competencia.'),
      );
    });
  });

  group('cobertura y notas', () {
    testWidgets('Tabla Anual: parcial, partidos sin sumar por motivo y la '
        'aclaración de tabla no oficial a la vista', (tester) async {
      await pumpApp(tester, const Size(360, 900));
      await goTo(
        tester,
        '/competiciones/4406?temporada=2026&vista=tabla&tabla=anual',
        wait: const Duration(minutes: 2),
      );

      expect(
        // El ícono va dentro del mismo texto.
        find.textContaining(
          'Tabla parcial · Fechas guardadas 16 de 16 · 413 de 480 '
          'partidos sumados',
        ),
        findsOne,
      );
      // El pie, debajo de los 30 equipos.
      final list = find.descendant(
        of: find.byType(StandingsPanel),
        matching: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      final unofficial = find.textContaining('no es la tabla oficial');
      await tester.scrollUntilVisible(unofficial, 300, scrollable: list);
      await tester.pumpAndSettle();
      expect(unofficial, findsOne);
      expect(
        find.descendant(
          of: find.ancestor(of: unofficial, matching: find.byType(Row)).first,
          matching: find.byIcon(Icons.info_outline),
        ),
        findsOne,
      );

      final uncounted = find.text('Partidos sin sumar (67)');
      await tester.scrollUntilVisible(uncounted, -300, scrollable: list);
      await tester.pumpAndSettle();
      await tester.tap(uncounted);
      await tester.pumpAndSettle();
      // Por motivo; los motivos suman los 67.
      var total = 0;
      for (final t in tester.widgetList<Text>(
        find.textContaining(
          RegExp(
            r'^(Por jugar|En juego|Postergados|Suspendidos|Cancelados|'
            r'Terminados sin resultado|Excluidos: sin torneo determinado) '
            r'\(\d+\)$',
          ),
        ),
      )) {
        total += int.parse(RegExp(r'\((\d+)\)$').firstMatch(t.data!)![1]!);
      }
      expect(total, 67);
      expect(find.textContaining(RegExp(r'^Por jugar \(\d+\)$')), findsOne);
    });

    testWidgets('grupo terminado: tabla completa, sin partidos sin sumar', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const Size(360, 900),
        now: continentalRecordingTime,
      );
      await goTo(
        tester,
        '/competiciones/4501?temporada=2026&vista=tabla&tabla=grupo-a',
        wait: const Duration(minutes: 1),
      );
      expect(
        find.textContaining(
          'Tabla completa · Fechas guardadas 6 de 6 · 12 de 12 partidos '
          'sumados',
        ),
        findsOne,
      );
      expect(find.textContaining('Partidos sin sumar'), findsNothing);
      expect(find.textContaining('no es la tabla oficial'), findsOne);
    });
  });

  group('accesibilidad', () {
    for (final brightness in Brightness.values) {
      for (final width in [360.0, 1280.0]) {
        testWidgets('${width.toInt()} px, ${brightness.name}: favorito y '
            'marcadores cumplen las pautas', (tester) async {
          final semantics = tester.ensureSemantics();
          useBrightness(tester, brightness);
          await pumpApp(
            tester,
            Size(width, 900),
            now: continentalRecordingTime,
            seed: (db) => _saveTeam(db, 'Estudiantes de La Plata'),
          );
          // Libertadores 2026, Grupo A: Estudiantes es 2.° (favorito y
          // marcado a la vez).
          await goTo(
            tester,
            '/competiciones/4501?temporada=2026&vista=tabla&tabla=grupo-a',
            wait: const Duration(minutes: 1),
          );
          expect(
            rowLabel(tester, 'Estudiantes de La Plata'),
            endsWith('Sigue en competencia. Favorito.'),
          );
          await expectGuidelines(tester);
          semantics.dispose();
        });
      }
    }
  });
}

Future<void> _saveBoca(Database db) => _saveTeam(db, 'Boca Juniors');

Future<void> _saveTeam(Database db, String name) =>
    FavoritesRepositoryImpl(db).save(
      FavoriteTeam.fromRef(recordedTeam(name), addedAt: DateTime.utc(2026, 10)),
    );

Color _groupColor(WidgetTester tester) => tester
    .widget<Material>(
      find
          .ancestor(
            of: find.byType(StandingsTableView),
            matching: find.byType(Material),
          )
          .first,
    )
    .color!;

/// Tabla de un grupo con las rondas 1–6 grabadas (hasta el día argentino
/// [until], inclusive).
StandingsTable _groupTable(
  CompetitionDefinition cup,
  int year,
  String group, {
  CalendarDay? until,
}) {
  final format = cup.standingsFor(Season(year)) as GroupStage;
  bool played(Match m) =>
      until == null ||
      switch (m.kickoff.argentinaDay) {
        final day? => day.compareTo(until) <= 0,
        null => false,
      };
  final matches = <Match>[
    for (var r = 1; r <= 6; r++)
      for (final m in fixtureMatches('eventsround_${cup.id}_r${r}_s$year'))
        if (played(m)) m,
  ];
  return GroupTableBuilder.build(
    format: format,
    season: Season(year),
    group: group,
    matches: RegularSeasonMatches.classify(
      definition: cup,
      season: Season(year),
      matches: matches,
      rounds: format.regularRounds,
      tournaments: format.tournaments,
    ),
    roundsQueried: format.regularRounds.length,
  );
}

List<String> _order(StandingsTable table) => [
  for (final r in table.rows)
    '${r.position}${r.isShared ? '*' : ''} ${r.stats.team.name}',
];

Set<String> _names(StandingsTable table, Set<int> ids) => {
  for (final r in table.rows)
    if (ids.contains(r.stats.team.id)) r.stats.team.name,
};

/// Solo la tabla, en una caja de [box] px dentro de una pantalla de
/// [screen] px, con el tema de la app.
Future<void> _pumpTableAlone(
  WidgetTester tester, {
  required double screen,
  required double box,
  required StandingsTable table,
  Set<int> advancing = const {},
}) async {
  tester.view
    ..physicalSize = Size(screen, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        // La caja puede ser más ancha que la pantalla.
        body: OverflowBox(
          alignment: Alignment.topLeft,
          maxWidth: box,
          minWidth: box,
          child: SingleChildScrollView(
            child: StandingsTableView(table: table, advancing: advancing),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
