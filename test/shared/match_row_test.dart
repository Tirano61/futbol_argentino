import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/app/theme/app_theme.dart';
import 'package:futbol_argentino/core/time/argentina_time.dart';
import 'package:futbol_argentino/features/competitions/domain/usecases/watch_stage_matches.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/series_list.dart';
import 'package:futbol_argentino/features/matches/domain/entities/kickoff.dart';
import 'package:futbol_argentino/features/matches/domain/entities/knockout_tie.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match_status.dart';
import 'package:futbol_argentino/features/matches/domain/entities/score.dart';
import 'package:futbol_argentino/features/matches/domain/entities/team_ref.dart';
import 'package:futbol_argentino/features/matches/domain/services/tie_outcome.dart';
import 'package:futbol_argentino/shared/presentation/theme/app_palette.dart';
import 'package:futbol_argentino/shared/presentation/widgets/badge_image_resolver.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_group.dart';

import '../helpers/accessibility.dart';
import '../helpers/real_fonts.dart';

/// Fila de partido del Hito E (§5.2 y §5.4 de `docs/HITO_E.md`): cada
/// estado y cada caso obligatorio a 360 y 1280 px, al 100 y al 200 %, en
/// claro y oscuro. Los partidos se arman en el test (las grabaciones no
/// tienen postergados, suspendidos ni cancelados); los nombres son de
/// equipos reales, los más largos del catálogo.
void main() {
  setUpAll(loadRealFonts);

  final now = DateTime.utc(2026, 10, 17, 20);

  const gimnasia = TeamRef(id: 1, name: 'Gimnasia y Esgrima de La Plata');
  const central = TeamRef(
    id: 2,
    name: 'Central Córdoba de Santiago del Estero',
  );
  const river = TeamRef(id: 3, name: 'River Plate');
  const boca = TeamRef(id: 4, name: 'Boca Juniors');
  const independiente = TeamRef(id: 5, name: 'Independiente');
  const racing = TeamRef(id: 6, name: 'Racing Club');
  const fluminense = TeamRef(id: 7, name: 'Fluminense');
  const palmeiras = TeamRef(id: 8, name: 'Palmeiras');
  const ldu = TeamRef(id: 9, name: 'LDU Quito');
  const lanus = TeamRef(id: 10, name: 'Lanús');
  const mineiro = TeamRef(id: 11, name: 'Atlético Mineiro');
  const velez = TeamRef(id: 12, name: 'Vélez Sarsfield');
  const sinEscudo = TeamRef(
    id: 13,
    name: 'Deportivo Riestra',
    badgeUrl: 'https://r2.thesportsdb.com/images/media/team/badge/x.png',
  );

  Kickoff at(DateTime utc) => Kickoff(
    utc: utc,
    argentinaDay: ArgentinaTime.dayOf(utc),
    certainty: KickoffCertainty.confirmed,
    evidence: KickoffEvidence.timestamp,
  );

  var nextId = 100;
  Match game(
    TeamRef home,
    TeamRef away, {
    MatchStatus status = const MatchStatus.scheduled(),
    Score? score,
    Score? penalties,
    Kickoff? kickoff,
    DateTime? previousKickoffUtc,
    MatchMembership membership = MatchMembership.active,
  }) => Match(
    id: nextId++,
    competitionId: 4501,
    competitionName: 'Copa Libertadores',
    season: '2026',
    apiRound: 16,
    home: home,
    away: away,
    kickoff: kickoff ?? at(DateTime.utc(2026, 10, 18, 20)),
    status: status,
    score: score,
    penalties: penalties,
    lastSeenAt: now,
    previousKickoffUtc: previousKickoffUtc,
    membership: membership,
  );

  MatchStatus finished([MatchDecision by = MatchDecision.regular]) =>
      MatchStatus(kind: MatchStatusKind.finished, decidedBy: by);
  MatchStatus kind(MatchStatusKind k, {String? raw}) =>
      MatchStatus(kind: k, raw: raw);

  /// Cada estado de §5.2: el partido, el texto visible y el ícono.
  final states = <(Match, String, IconData?)>[
    (game(river, boca), '17:00', null),
    (
      game(
        river,
        boca,
        kickoff: Kickoff(
          utc: DateTime.utc(2026, 10, 19),
          argentinaDay: ArgentinaTime.dayOf(DateTime.utc(2026, 10, 19)),
          certainty: KickoffCertainty.tentative,
          evidence: KickoffEvidence.midnightUncorroborated,
        ),
      ),
      'Horario por confirmar',
      null,
    ),
    (
      game(river, boca, kickoff: at(DateTime.utc(2026, 10, 17, 14))),
      'Resultado pendiente',
      Icons.hourglass_empty,
    ),
    (
      game(
        independiente,
        racing,
        status: kind(MatchStatusKind.live),
        score: const Score(home: 1, away: 0),
      ),
      'En juego',
      null,
    ),
    (
      game(
        independiente,
        racing,
        status: kind(MatchStatusKind.halfTime),
        score: const Score(home: 0, away: 0),
      ),
      'Entretiempo',
      null,
    ),
    (
      game(
        river,
        boca,
        status: finished(),
        score: const Score(home: 2, away: 1),
      ),
      'Final',
      null,
    ),
    (
      game(
        river,
        boca,
        status: finished(MatchDecision.extraTime),
        score: const Score(home: 1, away: 2),
      ),
      'Final (alargue)',
      null,
    ),
    (
      game(
        gimnasia,
        central,
        status: finished(MatchDecision.penalties),
        score: const Score(home: 1, away: 1),
        penalties: const Score(home: 4, away: 3),
      ),
      'Final (penales)',
      Icons.check_circle_outline,
    ),
    (
      game(river, boca, status: kind(MatchStatusKind.postponed)),
      'Postergado',
      Icons.event_busy,
    ),
    (
      game(
        river,
        boca,
        status: kind(MatchStatusKind.abandoned),
        score: const Score(home: 1, away: 0),
      ),
      'Suspendido',
      Icons.pause_circle_outline,
    ),
    (
      game(river, boca, status: kind(MatchStatusKind.suspended)),
      'Interrumpido',
      Icons.pause_circle_outline,
    ),
    (
      game(river, boca, status: kind(MatchStatusKind.cancelled)),
      'Cancelado',
      Icons.block,
    ),
    (
      game(river, boca, status: kind(MatchStatusKind.unknown, raw: 'ZZZ')),
      'ZZZ',
      null,
    ),
  ];

  // Notas, nombres largos, escudos, selección y fila no tocable.
  final longNames = game(
    gimnasia,
    central,
    status: finished(),
    score: const Score(home: 0, away: 1),
  );
  final notes = game(
    velez,
    lanus,
    kickoff: Kickoff(
      utc: null,
      argentinaDay: ArgentinaTime.dayOf(DateTime.utc(2026, 10, 18, 20)),
      certainty: KickoffCertainty.unknown,
      evidence: KickoffEvidence.dateOnly,
    ),
    previousKickoffUtc: DateTime.utc(2026, 10, 11, 20),
    membership: MatchMembership.unconfirmed,
  );
  final badgeFails = game(
    sinEscudo,
    lanus,
    status: finished(),
    score: const Score(home: 1, away: 0),
  );
  final selected = game(
    river,
    boca,
    status: finished(),
    score: const Score(home: 1, away: 0),
  );
  final notTappable = game(
    racing,
    independiente,
    status: finished(),
    score: const Score(home: 3, away: 3),
  );

  /// Las series de §5.3 en orden: global parcial, global, tanda, sin dato
  /// de la definición y pierna faltante.
  StageSeries series(List<Match> legs) {
    final tie = KnockoutTie(legs: legs, expectedLegs: 2);
    return StageSeries(tie: tie, outcome: TieOutcome.ofTie(tie));
  }

  final allSeries = [
    series([
      game(
        fluminense,
        palmeiras,
        status: finished(),
        score: const Score(home: 0, away: 1),
        kickoff: at(DateTime.utc(2026, 10, 14, 23)),
      ),
      game(palmeiras, fluminense, kickoff: at(DateTime.utc(2026, 10, 22))),
    ]),
    series([
      game(
        river,
        boca,
        status: finished(),
        score: const Score(home: 2, away: 0),
        kickoff: at(DateTime.utc(2026, 9, 9, 23)),
      ),
      game(
        boca,
        river,
        status: finished(),
        score: const Score(home: 1, away: 1),
        kickoff: at(DateTime.utc(2026, 9, 16, 23)),
      ),
    ]),
    series([
      game(
        palmeiras,
        ldu,
        status: finished(),
        score: const Score(home: 1, away: 0),
        kickoff: at(DateTime.utc(2026, 9, 9, 23)),
      ),
      game(
        ldu,
        palmeiras,
        status: finished(MatchDecision.penalties),
        score: const Score(home: 1, away: 0),
        penalties: const Score(home: 3, away: 4),
        kickoff: at(DateTime.utc(2026, 9, 16, 23)),
      ),
    ]),
    series([
      game(
        lanus,
        mineiro,
        status: finished(),
        score: const Score(home: 0, away: 0),
        kickoff: at(DateTime.utc(2025, 11, 15, 20)),
      ),
      game(
        mineiro,
        lanus,
        status: finished(),
        score: const Score(home: 1, away: 1),
        kickoff: at(DateTime.utc(2025, 11, 22, 20)),
      ),
    ]),
    series([
      game(
        gimnasia,
        central,
        status: finished(),
        score: const Score(home: 2, away: 2),
        kickoff: at(DateTime.utc(2026, 10, 1, 23)),
      ),
    ]),
  ];

  var tapped = 0;
  List<Widget> rowsScene() => [
    MatchGroup(
      children: [
        for (final (m, _, _) in states)
          MatchCard(key: ValueKey(m.id), match: m, now: now, onTap: () {}),
      ],
    ),
    const SizedBox(height: 12),
    MatchGroup(
      children: [
        MatchCard(
          key: ValueKey(longNames.id),
          match: longNames,
          now: now,
          subtitle: 'Copa Libertadores · Octavos de final',
          onTap: () {},
        ),
        MatchCard(
          key: ValueKey(notes.id),
          match: notes,
          now: now,
          onTap: () {},
        ),
        MatchCard(
          key: ValueKey(badgeFails.id),
          match: badgeFails,
          now: now,
          onTap: () {},
        ),
        MatchCard(
          key: ValueKey(selected.id),
          match: selected,
          now: now,
          selected: true,
          onTap: () => tapped++,
        ),
        // Otras competiciones (ficha de equipo): sin detalle.
        MatchCard(key: ValueKey(notTappable.id), match: notTappable, now: now),
      ],
    ),
  ];

  List<Widget> seriesScene() => seriesItems(
    series: allSeries,
    unpaired: const [],
    now: now,
    onTap: (_) {},
  );

  Future<void> pumpScene(
    WidgetTester tester,
    List<Widget> children, {
    double width = 360,
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view
      ..physicalSize = Size(width, 6000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        home: BadgeImages(
          resolver: const _FailingBadges(),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const teamNames = {
    'Gimnasia y Esgrima de La Plata',
    'Central Córdoba de Santiago del Estero',
    'River Plate',
    'Boca Juniors',
    'Independiente',
    'Racing Club',
    'Fluminense',
    'Palmeiras',
    'LDU Quito',
    'Lanús',
    'Atlético Mineiro',
    'Vélez Sarsfield',
    'Deportivo Riestra',
  };

  /// Ningún texto de la fila se recorta ni se sale de ella: solo el nombre
  /// de un equipo puede cortarse (desde el cuarto renglón a los costados
  /// del marcador y el tercero con los equipos apilados; E7).
  void expectNothingCut(WidgetTester tester) {
    for (final card in find.byType(MatchCard).evaluate()) {
      final box = card.renderObject! as RenderBox;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      expect(rect.height, greaterThanOrEqualTo(48), reason: 'área táctil');
      void visit(RenderObject node) {
        if (node is RenderParagraph) {
          final text = node.text.toPlainText();
          if (!teamNames.contains(text)) {
            expect(node.didExceedMaxLines, isFalse, reason: text);
          }
          final paragraph = node.localToGlobal(Offset.zero) & node.size;
          expect(
            rect.inflate(0.5).contains(paragraph.topLeft) &&
                rect.inflate(0.5).contains(paragraph.bottomRight),
            isTrue,
            reason: '«$text» se sale de la fila',
          );
        }
        node.visitChildren(visit);
      }

      visit(box);
    }
  }

  for (final width in [360.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        final config =
            '${width.toInt()} px · ${(scale * 100).toInt()} % · '
            '${brightness == Brightness.light ? 'claro' : 'oscuro'}';

        testWidgets('estados (§5.2) y casos de fila (§5.4) · $config', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          await pumpScene(
            tester,
            rowsScene(),
            width: width,
            scale: scale,
            brightness: brightness,
          );

          for (final (m, label, icon) in states) {
            final row = find.byKey(ValueKey(m.id));
            expect(
              find.descendant(of: row, matching: find.text(label)),
              findsOne,
              reason: label,
            );
            if (icon != null) {
              expect(
                find.descendant(of: row, matching: find.byIcon(icon)),
                findsOne,
                reason: '$label: ícono',
              );
            }
          }
          // Sin marcador: «—» en postergado, interrumpido y cancelado.
          expect(find.text('—'), findsNWidgets(3));
          expect(find.text('(4-3 pen.)'), findsOne);
          expect(
            find.text('Avanza Gimnasia y Esgrima de La Plata (4-3 en penales)'),
            findsOne,
          );
          expect(find.text('Reprogramado'), findsOne);
          expect(find.byIcon(Icons.update), findsOne);
          expect(find.text('La API ya no lo lista en esta fecha'), findsOne);
          expect(find.byIcon(Icons.help_outline), findsOne);
          // El escudo que no carga y el que no existe: iniciales.
          expect(find.text('DR'), findsOne);
          expect(find.text('GE'), findsNWidgets(2));
          expect(find.text('Copa Libertadores · Octavos de final'), findsOne);

          expectNothingCut(tester);
          await expectGuidelines(tester);
          semantics.dispose();
        });

        testWidgets('series de ida y vuelta (§5.3) · $config', (tester) async {
          final semantics = tester.ensureSemantics();
          await pumpScene(
            tester,
            seriesScene(),
            width: width,
            scale: scale,
            brightness: brightness,
          );

          expect(find.byType(MatchGroup), findsNWidgets(5));
          expect(
            find.text('Global parcial Fluminense 0-1 Palmeiras'),
            findsOne,
          );
          expect(find.text('Global River Plate 3-1 Boca Juniors'), findsOne);
          expect(
            find.text('Clasificó River Plate por resultado global (3-1)'),
            findsOne,
          );
          expect(find.text('Global Palmeiras 1-1 LDU Quito'), findsOne);
          expect(find.text('Clasificó Palmeiras por penales (4-3)'), findsOne);
          expect(find.text('Global Lanús 1-1 Atlético Mineiro'), findsOne);
          expect(find.text('Sin dato de la definición'), findsOne);
          expect(find.text('Vuelta: sin datos en TheSportsDB'), findsOne);
          expect(find.byIcon(Icons.check_circle_outline), findsNWidgets(2));
          expect(find.byIcon(Icons.help_outline), findsOne);
          // Dentro de la serie, la fila no repite quién pasa (ni la
          // vuelta que ganó LDU dice «Avanza LDU»).
          expect(find.textContaining('Avanza'), findsNothing);
          expect(find.textContaining('Ida · '), findsNWidgets(5));
          expect(find.textContaining('Vuelta · '), findsNWidgets(4));

          expectNothingCut(tester);
          await expectGuidelines(tester);
          semantics.dispose();
        });
      }
    }
  }

  group('fila', () {
    FontWeight? weightOf(WidgetTester tester, Match m, String name) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(ValueKey(m.id)),
            matching: find.text(name),
          ),
        )
        .style
        ?.fontWeight;

    testWidgets('ganador en negrita solo con evidencia (TieOutcome)', (
      tester,
    ) async {
      await pumpScene(tester, rowsScene(), width: 1280);

      // Final 2-1: River.
      final (win, _, _) = states[5];
      expect(weightOf(tester, win, 'River Plate'), FontWeight.w700);
      expect(weightOf(tester, win, 'Boca Juniors'), FontWeight.w400);
      // Penales 1-1 (4-3): Gimnasia.
      final (pen, _, _) = states[7];
      expect(
        weightOf(tester, pen, 'Gimnasia y Esgrima de La Plata'),
        FontWeight.w700,
      );
      expect(
        weightOf(tester, pen, 'Central Córdoba de Santiago del Estero'),
        FontWeight.w400,
      );
      // En juego 1-0 o empate final sin tanda: nadie.
      final (live, _, _) = states[3];
      expect(weightOf(tester, live, 'Independiente'), FontWeight.w400);
      expect(weightOf(tester, notTappable, 'Racing Club'), FontWeight.w400);
      expect(weightOf(tester, notTappable, 'Independiente'), FontWeight.w400);
      // Suspendido 1-0: el parcial no da ganador.
      final (abandoned, _, _) = states[9];
      expect(weightOf(tester, abandoned, 'River Plate'), FontWeight.w400);
    });

    testWidgets('en vivo: marcador y punto en el color de en vivo', (
      tester,
    ) async {
      await pumpScene(tester, rowsScene(), width: 1280);
      final (live, _, _) = states[3];

      final score = tester.widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey(live.id)),
          matching: find.text('1 – 0'),
        ),
      );
      expect(score.style?.color, AppPalette.light.live);
    });

    testWidgets('a los costados con lugar; apilada con texto grande en un '
        'teléfono', (tester) async {
      final (win, _, _) = states[5];
      final row = find.byKey(ValueKey(win.id));

      await pumpScene(tester, rowsScene());
      expect(find.descendant(of: row, matching: find.text('2 – 1')), findsOne);

      await pumpScene(tester, rowsScene(), scale: 2);
      expect(
        find.descendant(of: row, matching: find.text('2 – 1')),
        findsNothing,
      );
      expect(find.descendant(of: row, matching: find.text('2')), findsOne);
      expect(find.descendant(of: row, matching: find.text('1')), findsOne);
      // El local arriba, el visitante abajo.
      expect(
        tester
            .getTopLeft(
              find.descendant(of: row, matching: find.text('River Plate')),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.descendant(of: row, matching: find.text('Boca Juniors')),
              )
              .dy,
        ),
      );

      await pumpScene(tester, rowsScene(), width: 1280, scale: 2);
      expect(find.descendant(of: row, matching: find.text('2 – 1')), findsOne);
    });

    testWidgets('a 360 px los nombres de una palabra no se parten', (
      tester,
    ) async {
      final (live, _, _) = states[3];
      await pumpScene(tester, rowsScene());

      final name = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(ValueKey(live.id)),
          matching: find.text('Independiente'),
        ),
      );
      final painter = TextPainter(
        text: name.text,
        textDirection: TextDirection.ltr,
        textScaler: name.textScaler,
      )..layout(maxWidth: name.constraints.maxWidth);
      expect(painter.computeLineMetrics(), hasLength(1));
      painter.dispose();
    });

    testWidgets('elegida: fondo de marca y barra; no tocable: sin acción', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpScene(tester, rowsScene(), width: 1280);

      final chosen = find.byKey(ValueKey(selected.id));
      final material = tester.widget<Material>(
        find.descendant(of: chosen, matching: find.byType(Material)).first,
      );
      expect(material.color, AppTheme.light.colorScheme.primaryContainer);
      expect(
        tester.getSemantics(chosen),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          isSelected: true,
          hasSelectedState: true,
          label: 'River Plate 1, Boca Juniors 0. Final',
        ),
      );
      await tester.tap(chosen);
      expect(tapped, 1);

      final plain = find.byKey(ValueKey(notTappable.id));
      expect(tester.widget<MatchCard>(plain).onTap, isNull);
      expect(
        tester.getSemantics(plain),
        matchesSemantics(
          hasSelectedState: true,
          label: 'Racing Club 3, Independiente 3. Final',
        ),
      );
      semantics.dispose();
    });

    testWidgets('suspendido: el parcial también en la semántica', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpScene(tester, rowsScene(), width: 1280);
      final (abandoned, _, _) = states[9];

      expect(
        find.descendant(
          of: find.byKey(ValueKey(abandoned.id)),
          matching: find.text('1 – 0'),
        ),
        findsOne,
      );
      expect(
        find.bySemanticsLabel('River Plate 1, Boca Juniors 0. Suspendido'),
        findsOne,
      );
      semantics.dispose();
    });
  });
}

/// Escudos que nunca cargan (sin red): la fila muestra las iniciales.
class _FailingBadges implements BadgeImageResolver {
  const _FailingBadges();

  @override
  ImageProvider imageFor(String url) => const _FailingImage();
}

class _FailingImage extends ImageProvider<_FailingImage> {
  const _FailingImage();

  @override
  Future<_FailingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _FailingImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    Future<ImageInfo>.error(StateError('sin red')),
  );
}
