import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/favorites/presentation/widgets/favorite_button.dart';
import 'package:futbol_argentino/shared/presentation/theme/app_spacing.dart';
import 'package:futbol_argentino/shared/presentation/widgets/team_badge.dart';

import '../helpers/accessibility.dart';
import '../helpers/real_fonts.dart';
import '../helpers/recorded_app.dart';
import '../helpers/text_layout.dart';
import '../visual/visual_helpers.dart' show goTo, useBrightness, useTextScale;

/// Hito E, Fase E6: la cabecera de la ficha de un equipo (§11.1), con la
/// fuente real (Roboto): escudo de 72, el favorito junto al nombre y fuera
/// de la barra (E-D14), estadio · ciudad y las competiciones como chips
/// discretos, sin palabras partidas ni chips recortados al 200 %.
void main() {
  setUpAll(loadRealFonts);

  final favorite = find.byType(FavoriteButton);
  final header = find
      .ancestor(of: favorite, matching: find.byType(LayoutBuilder))
      .first;

  Future<void> openBoca(WidgetTester tester, double width) async {
    await pumpApp(tester, Size(width, 900), now: continentalRecordingTime);
    await goTo(tester, '/equipos/135156', wait: const Duration(minutes: 5));
  }

  for (final width in [360.0, 411.0, 800.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('${width.toInt()} px · ${(scale * 100).toInt()} %', (
        tester,
      ) async {
        if (scale != 1) useTextScale(tester, scale);
        await openBoca(tester, width);

        // El favorito, en la cabecera y no en la barra.
        expect(favorite, findsOne);
        expect(
          find.descendant(of: find.byType(AppBar), matching: favorite),
          findsNothing,
        );
        expect(find.byTooltip('Agregar a favoritos'), findsOne);
        expect(find.byTooltip('Actualizar'), findsOne);

        // Escudo de 72 y el nombre con la estrella al lado.
        expect(
          find.descendant(
            of: header,
            matching: find.byWidgetPredicate(
              (w) => w is TeamBadge && w.size == AppSizes.badgeHero,
            ),
          ),
          findsOne,
        );
        final name = tester.getRect(
          find.descendant(of: header, matching: find.text('Boca Juniors')),
        );
        final star = tester.getRect(favorite);
        expect(star.left - name.right, lessThanOrEqualTo(AppSpacing.sm));
        expect(star.left, greaterThanOrEqualTo(name.right - 0.5));
        expect(star.center.dy, inInclusiveRange(name.top, name.bottom));

        // Estadio · ciudad y los chips de las competiciones, enteros.
        expect(
          find.text('Estadio Alberto José Armando · La Boca, Buenos Aires'),
          findsOne,
        );
        final chips = find.descendant(of: header, matching: find.byType(Chip));
        expect(chips, findsNWidgets(3));
        for (final chip in chips.evaluate()) {
          expect(
            tester.getRect(find.byWidget(chip.widget)).right,
            lessThanOrEqualTo(width),
          );
        }
        expectWholeWords(tester, header);
      });
    }
  }

  testWidgets('palabra larga al 200 % en un teléfono: el escudo y la '
      'estrella arriba, el nombre entero debajo', (tester) async {
    useTextScale(tester, 2);
    await pumpApp(tester, const Size(360, 900));
    await goTo(tester, '/competiciones/4406?temporada=2026&fase=clausura');
    await goTo(tester, '/equipos/137777', wait: const Duration(minutes: 5));

    final name = tester.getRect(
      find.descendant(
        of: header,
        matching: find.text('Independiente Rivadavia'),
      ),
    );
    final badge = tester.getRect(
      find.descendant(of: header, matching: find.byType(TeamBadge)),
    );
    final star = tester.getRect(favorite);
    expect(badge.bottom, lessThanOrEqualTo(name.top));
    expect(star.bottom, lessThanOrEqualTo(name.top));
    expect(star.right, lessThanOrEqualTo(360));
    expectWholeWords(tester, header);
  });

  testWidgets('la estrella de la cabecera agrega y quita', (tester) async {
    await openBoca(tester, 360);
    await tester.tap(find.byTooltip('Agregar a favoritos'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Quitar de favoritos'), findsOne);
    await tester.tap(find.byTooltip('Quitar de favoritos'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Agregar a favoritos'), findsOne);
  });

  group('pautas de accesibilidad', () {
    for (final brightness in Brightness.values) {
      final theme = brightness == Brightness.light ? 'claro' : 'oscuro';
      for (final width in [360.0, 1280.0]) {
        testWidgets('${width.toInt()} px · $theme', (tester) async {
          final semantics = tester.ensureSemantics();
          useBrightness(tester, brightness);
          await openBoca(tester, width);
          await expectGuidelines(tester);
          semantics.dispose();
        });
      }
    }
  });
}
