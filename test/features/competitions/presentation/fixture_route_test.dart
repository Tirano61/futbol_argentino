import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/phase.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/services/round_navigator.dart';
import 'package:futbol_argentino/features/competitions/presentation/routing/fixture_route.dart';

/// Fase D3: la URL de cada fase (también las de las copas internacionales).
/// En Web la URL se arma fuera de los widget tests: acá se prueba sola.
void main() {
  test('cada fase tiene un nombre de URL propio y vuelve a leerse', () {
    final names = {for (final p in PhaseKey.values) FixtureRoute.phaseName(p)};
    expect(names, hasLength(PhaseKey.values.length));
    for (final phase in PhaseKey.values) {
      expect(FixtureRoute.parsePhase(FixtureRoute.phaseName(phase)), phase);
    }
    expect(FixtureRoute.parsePhase('x'), isNull);
    expect(FixtureRoute.parsePhase(null), isNull);
  });

  test('copas internacionales: previa, grupos y eliminatorias', () {
    expect(
      [
        for (final p in [
          PhaseKey.qualifying,
          PhaseKey.groups,
          PhaseKey.knockoutStage,
        ])
          FixtureRoute.phaseName(p),
      ],
      ['previa', 'grupos', 'eliminatorias'],
    );
  });

  test('ida y vuelta de cada etapa de la Libertadores 2026', () {
    const libertadores = CompetitionCatalog.copaLibertadores;
    for (final phase in libertadores.phases) {
      for (final stage in RoundNavigator.stagesFor(
        libertadores,
        const Season(2026),
        phase,
      )) {
        final uri = FixtureRoute.uriFor(stage);
        final event = FixtureRoute.parse(
          leagueId: uri.pathSegments.last,
          query: uri.queryParameters,
        );
        expect(
          (event.competitionId, event.season, event.phase, event.apiRound),
          (4501, const Season(2026), phase, stage.apiRound),
          reason: '$uri',
        );
        // Sin `etapa`, la fase y la ronda alcanzan para encontrarla.
        expect(
          event.kind,
          stage.kind == StageKind.knockout ? stage.kind : null,
        );
      }
    }
    expect(
      FixtureRoute.uriFor(
        RoundNavigator.stagesFor(
          libertadores,
          const Season(2026),
          PhaseKey.groups,
        )[2],
      ).toString(),
      '/competiciones/4501?temporada=2026&fase=grupos&ronda=3',
    );
  });

  test('`fase=previa&ronda=1` sin `etapa`: tipo nulo', () {
    final event = FixtureRoute.parse(
      leagueId: '4501',
      query: const {'temporada': '2026', 'fase': 'previa', 'ronda': '1'},
    );

    expect(event.competitionId, 4501);
    expect(event.phase, PhaseKey.qualifying);
    expect(event.apiRound, 1);
    expect(event.kind, isNull);
  });
}
