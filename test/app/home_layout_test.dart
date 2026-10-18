import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:futbol_argentino/features/favorites/domain/entities/favorite_team.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_group.dart';
import 'package:sembast/sembast.dart' show Database;

import '../helpers/accessibility.dart';
import '../helpers/fake_teams.dart';
import '../helpers/real_fonts.dart';
import '../helpers/recorded_app.dart';

/// Inicio del Hito E (Fase E3, `docs/HITO_E.md` §6): lo que entra en la
/// primera pantalla de un teléfono y cómo se acomodan los accesos según el
/// ancho. Con Roboto: lo que entra en un renglón depende de la fuente.
void main() {
  setUpAll(loadRealFonts);

  const phone = Size(360, 640);

  Future<void> saveBoca(Database db) => FavoritesRepositoryImpl(db).save(
    FavoriteTeam.fromRef(
      recordedTeam('Boca Juniors'),
      addedAt: DateTime.utc(2026, 10, 1),
    ),
  );

  /// Borde inferior de lo visible: la barra de navegación.
  double fold(WidgetTester tester) =>
      tester.getRect(find.byType(NavigationBar)).top;

  final chips = find.byType(ActionChip);
  Iterable<Rect> chipRects(WidgetTester tester) => [
    for (var i = 0; i < chips.evaluate().length; i++)
      tester.getRect(chips.at(i)),
  ];

  group('360 × 640', () {
    testWidgets('sin favoritos, «Hoy» y su primer partido entran en la '
        'primera pantalla', (tester) async {
      await pumpApp(tester, phone);

      expect(tester.getRect(find.text('Hoy')).bottom, lessThan(fold(tester)));
      // Sin favoritos, la primera fila es la primera de Hoy.
      expect(
        tester.getRect(find.byType(MatchCard).first).top,
        lessThan(fold(tester)),
      );
    });

    testWidgets('con un favorito, «Hoy» sigue a su bloque compacto en la '
        'primera pantalla', (tester) async {
      await pumpApp(tester, phone, seed: saveBoca);

      final boca = find.widgetWithText(ListTile, 'Boca Juniors');
      final block = find.ancestor(of: boca, matching: find.byType(MatchGroup));
      // Próximo y último, cada uno en una fila del bloque.
      expect(
        find.descendant(of: block, matching: find.byType(MatchCard)),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: block, matching: find.textContaining('Próximo · ')),
        findsOne,
      );
      expect(
        find.descendant(of: block, matching: find.textContaining('Último · ')),
        findsOne,
      );
      final hoy = tester.getRect(find.text('Hoy'));
      expect(hoy.top, greaterThan(tester.getRect(block).bottom));
      expect(hoy.bottom, lessThan(fold(tester)));
    });
  });

  group('teléfono', () {
    testWidgets('un solo acceso al buscador, con forma de campo, que abre '
        'Equipos', (tester) async {
      await pumpApp(tester, phone);

      // Sin el ícono duplicado en la barra.
      expect(find.byTooltip('Buscar equipo'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      final field = find.ancestor(
        of: find.text('Buscar equipo'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(field).height, greaterThanOrEqualTo(48));

      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(find.text('Buscá un equipo'), findsOne);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 2);
    });

    testWidgets('los accesos van en una fila que llega a los bordes y se '
        'desplaza de costado sin mover la lista', (tester) async {
      await pumpApp(tester, const Size(360, 780));

      expect(chips, findsNWidgets(CompetitionCatalog.all.length));
      // Una sola fila, con las cuatro categorías.
      expect({
        for (final r in chipRects(tester)) r.center.dy.round(),
      }, hasLength(1));
      final row = find
          .ancestor(of: chips.first, matching: find.byType(Scrollable))
          .first;
      final rowState = tester.state<ScrollableState>(row);
      expect(rowState.position.axis, Axis.horizontal);
      // Llega a los bordes de la pantalla: lo que sigue queda cortado
      // contra el borde y se nota que hay más.
      expect(tester.getRect(row).left, 0);
      expect(tester.getRect(row).right, 360);
      expect(rowState.position.maxScrollExtent, greaterThan(0));
      final sudamericana = find.widgetWithText(ActionChip, 'Copa Sudamericana');
      expect(tester.getRect(sudamericana).left, greaterThan(360));

      final hoy = tester.getTopLeft(find.text('Hoy'));
      await tester.drag(row, const Offset(-2000, 0));
      await tester.pumpAndSettle();
      expect(tester.getRect(sudamericana).right, lessThanOrEqualTo(360));
      // La lista no se movió.
      expect(tester.getTopLeft(find.text('Hoy')), hoy);

      // Arrastrar hacia arriba sobre la fila desplaza la lista.
      await tester.drag(sudamericana, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Hoy')).dy, lessThan(hoy.dy));
      expect(rowState.position.pixels, rowState.position.maxScrollExtent);
    });

    testWidgets('un acceso desplazado lleva a su fixture', (tester) async {
      await pumpApp(tester, const Size(360, 780));
      final row = find
          .ancestor(of: chips.first, matching: find.byType(Scrollable))
          .first;
      await tester.drag(row, const Offset(-2000, 0));
      await tester.pumpAndSettle();

      // El último, que al principio quedaba fuera de la pantalla.
      await tester.tap(find.widgetWithText(ActionChip, 'Copa Sudamericana'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Copa Sudamericana'),
        ),
        findsOne,
      );
    });

    testWidgets('al 200 % la fila sigue siendo una y «Hoy» queda en la '
        'primera pantalla de 780 px', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, const Size(360, 780));

      expect({
        for (final r in chipRects(tester)) r.center.dy.round(),
      }, hasLength(1));
      expect(tester.getRect(find.text('Hoy')).bottom, lessThan(fold(tester)));
      // Los desbordes de layout fallan el test por sí solos.
    });
  });

  group('pautas de accesibilidad con un favorito', () {
    for (final size in [const Size(360, 780), const Size(1280, 800)]) {
      for (final brightness in Brightness.values) {
        testWidgets('${size.width.toInt()} px · ${brightness.name}', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          await pumpApp(tester, size, seed: saveBoca);
          expect(find.widgetWithText(ListTile, 'Boca Juniors'), findsOne);
          await expectGuidelines(tester);
          semantics.dispose();
        });
      }
    }
  });

  group('tablet y escritorio: los accesos se acomodan al ancho', () {
    for (final (size, rows) in [
      (const Size(768, 1024), 4),
      (const Size(1100, 800), 2),
      (const Size(1280, 800), 6),
      (const Size(1920, 1080), 6),
    ]) {
      testWidgets('${size.width.toInt()} px: $rows renglones, sin '
          'desplazamiento ni salirse del contenido', (tester) async {
        await pumpApp(tester, size);

        expect(chips, findsNWidgets(CompetitionCatalog.all.length));
        expect(
          find.ancestor(of: chips.first, matching: find.byType(Scrollable)),
          findsOne, // solo la lista de Inicio
        );
        final content = tester.getRect(find.byType(ListView));
        final rects = chipRects(tester);
        for (final r in rects) {
          expect(r.left, greaterThanOrEqualTo(content.left));
          expect(r.right, lessThanOrEqualTo(content.right));
        }
        expect({for (final r in rects) r.center.dy.round()}, hasLength(rows));
        // Ninguna categoría queda sola en su renglón: va con su primer
        // chip.
        for (final MapEntry(key: category, value: competitions)
            in CompetitionCatalog.byCategory().entries) {
          expect(
            tester.getCenter(find.text(category.label).first).dy,
            moreOrLessEquals(
              tester
                  .getCenter(
                    find.widgetWithText(ActionChip, competitions.first.name),
                  )
                  .dy,
              epsilon: 1,
            ),
          );
        }
      });
    }
  });
}
