import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/teams/domain/services/team_index.dart';

import '../../../helpers/fake_teams.dart';

void main() {
  final index = TeamIndex(recordedTeamSummaries());
  List<String> names(String query) => [
    for (final t in index.search(query)) t.team.name,
  ];

  test('«river» encuentra River Plate (y no Independiente Rivadavia)', () {
    expect(names('river'), ['River Plate']);
    expect(names('RIVER'), ['River Plate']);
  });

  test('«gimnasia» encuentra todas las Gimnasias, en orden alfabético', () {
    expect(names('gimnasia'), [
      'Gimnasia y Esgrima de Chivilcoy',
      'Gimnasia y Esgrima de Jujuy',
      'Gimnasia y Esgrima de La Plata',
      'Gimnasia y Esgrima de Mendoza',
      'Gimnasia y Tiro',
    ]);
  });

  test('cada palabra debe aparecer, en cualquier orden', () {
    expect(names('gimnasia plata'), ['Gimnasia y Esgrima de La Plata']);
    expect(names('plata gimnasia'), ['Gimnasia y Esgrima de La Plata']);
  });

  test('sin acentos ni apóstrofos', () {
    expect(names('velez'), ['Vélez Sarsfield']);
    expect(names('union'), ['Unión']);
    expect(names('newells'), ["Newell's Old Boys"]);
    expect(names('GÜEMES'), ['Güemes']);
  });

  test('primero los que empiezan con la búsqueda, después por palabra', () {
    final found = names('san');
    // «San …» primero; «Ciudad de …» no contiene «san».
    expect(found.take(6).every((n) => n.startsWith('San ')), isTrue);
    expect(found, isNot(contains('Ciudad de Bolívar')));

    // «Racing Club» empieza con «racing»; «Racing de Córdoba» también.
    expect(names('racing'), ['Racing Club', 'Racing de Córdoba']);
    // «Central Córdoba…» empieza con «central»; «Rosario Central» tiene
    // una palabra que empieza con «central».
    expect(names('central').first, startsWith('Central'));
    expect(names('central').last, 'Rosario Central');
  });

  test('búsqueda vacía o solo signos: sin resultados', () {
    expect(index.search(''), isEmpty);
    expect(index.search(' - '), isEmpty);
  });

  test('búsqueda en línea solo desde 3 letras', () {
    expect(TeamIndex.allowsOnlineSearch('bo'), isFalse);
    expect(TeamIndex.allowsOnlineSearch(' b o '), isFalse);
    expect(TeamIndex.allowsOnlineSearch('bo c'), isTrue);
    expect(TeamIndex.allowsOnlineSearch('boca'), isTrue);
  });
}
