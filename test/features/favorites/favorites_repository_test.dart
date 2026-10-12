import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/favorites/data/models/favorite_record.dart';
import 'package:futbol_argentino/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:futbol_argentino/features/favorites/domain/entities/favorite_team.dart';
import 'package:futbol_argentino/features/favorites/domain/usecases/toggle_favorite.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast_io.dart';

import '../../helpers/fake_teams.dart';
import '../../helpers/favorites.dart';

void main() {
  final addedAt = DateTime.utc(2026, 10, 12, 15);

  test('registro: ida y vuelta sin perder datos', () {
    final boca = FavoriteTeam.fromRef(
      recordedTeam('Boca Juniors'),
      addedAt: addedAt,
    );
    final map = FavoriteRecord.toMap(boca);

    expect(map['v'], FavoriteRecord.schemaVersion);
    expect(FavoriteRecord.fromMap(map), boca);
    expect(boca.badgeUrl, isNotNull);
  });

  test('lista por nombre sin acentos y se actualiza sola', () async {
    final favorites = await memoryFavorites();
    final emitted = <List<String>>[];
    final sub = favorites.watchAll().listen(
      (teams) => emitted.add([for (final t in teams) t.name]),
    );

    for (final name in ['Boca Juniors', 'Atlético Tucumán', 'Banfield']) {
      await favorites.save(
        FavoriteTeam.fromRef(recordedTeam(name), addedAt: addedAt),
      );
    }
    await favorites.remove(recordedTeam('Banfield').id);
    await pumpEventQueue();
    await sub.cancel();

    expect(emitted.first, isEmpty);
    expect(
      emitted,
      anyElement(equals(['Atlético Tucumán', 'Banfield', 'Boca Juniors'])),
    );
    expect(emitted.last, ['Atlético Tucumán', 'Boca Juniors']);
  });

  test('guardar de nuevo actualiza nombre y escudo sin duplicar', () async {
    final favorites = await memoryFavorites();
    final boca = recordedTeam('Boca Juniors');
    await favorites.save(FavoriteTeam.fromRef(boca, addedAt: addedAt));
    await favorites.save(
      FavoriteTeam(teamId: boca.id, name: 'Boca', addedAt: addedAt),
    );

    final stored = await favorites.watchAll().first;
    expect(stored.map((t) => t.name), ['Boca']);
    expect(await favorites.contains(boca.id), isTrue);
  });

  test('ToggleFavorite agrega y después quita', () async {
    final favorites = await memoryFavorites();
    final toggle = ToggleFavorite(favorites);
    final river = recordedTeam('River Plate');

    expect(await toggle(river, now: addedAt), isTrue);
    final stored = await favorites.watchAll().first;
    expect(stored.single.ref, river);
    expect(stored.single.addedAt, addedAt);

    expect(await toggle(river, now: addedAt), isFalse);
    expect(await favorites.contains(river.id), isFalse);
  });

  test('persisten al cerrar y volver a abrir la base (archivo)', () async {
    final dir = await Directory.systemTemp.createTemp('favoritos');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'futbol_argentino.db');
    final boca = recordedTeam('Boca Juniors');

    final first = await databaseFactoryIo.openDatabase(path);
    await ToggleFavorite(FavoritesRepositoryImpl(first))(boca, now: addedAt);
    await first.close();

    final reopened = await databaseFactoryIo.openDatabase(path);
    addTearDown(reopened.close);
    final stored = await FavoritesRepositoryImpl(reopened).watchAll().first;
    expect(stored.single.ref, boca);
  });
}
