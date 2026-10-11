import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/data/models/league_dto.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/competition.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';

import '../../../helpers/fixtures.dart';

LeagueDto leagueFixture(String name) => LeagueDto.fromJson(
  (fixtureJson(name)['leagues'] as List).single as Map<String, dynamic>,
);

void main() {
  test('Primera División real: escudo y temporada actual', () {
    final dto = leagueFixture('lookupleague_4406');

    final competition = dto.toEntity(CompetitionCatalog.primeraDivision);

    expect(dto.idLeague, 4406);
    expect(dto.strLeague, 'Argentinian Primera Division');
    expect(competition.name, 'Primera División');
    expect(competition.currentSeason, const Season(2026));
    expect(competition.badgeUrl, startsWith('https://r2.thesportsdb.com/'));
  });

  test('Copa Argentina real: formato copa desde el catálogo', () {
    final competition = leagueFixture(
      'lookupleague_4500',
    ).toEntity(CompetitionCatalog.copaArgentina);

    expect(competition.format, CompetitionFormat.cup);
    expect(competition.currentSeason, const Season(2026));
  });

  test('temporada con otro formato o vacía: null', () {
    final dto = LeagueDto.fromJson({
      'idLeague': '4616',
      'strCurrentSeason': '2021-2022',
      'strBadge': '',
    });

    final competition = dto.toEntity(CompetitionCatalog.primeraNacional);

    expect(competition.currentSeason, isNull);
    expect(competition.badgeUrl, isNull);
  });
}
