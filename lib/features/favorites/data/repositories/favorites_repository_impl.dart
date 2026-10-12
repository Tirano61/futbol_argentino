import 'package:sembast/sembast.dart';

import '../../../../core/storage/local_database.dart';
import '../../../../core/text/text_normalizer.dart';
import '../../domain/entities/favorite_team.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../models/favorite_record.dart';

/// Favoritos en la base local (store `favorites`, clave `idTeam`): archivo
/// en Android, IndexedDB en Web.
class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl(this._db);

  final Database _db;
  final _store = AppStores.favorites;

  @override
  Stream<List<FavoriteTeam>> watchAll() => _store
      .query()
      .onSnapshots(_db)
      .map(
        (records) =>
            [for (final r in records) FavoriteRecord.fromMap(r.value)]
              ..sort((a, b) => _byName(a).compareTo(_byName(b))),
      );

  /// Sin acentos: «Atlético Tucumán» va antes que «Banfield».
  static String _byName(FavoriteTeam f) => TextNormalizer.normalize(f.name);

  @override
  Future<bool> contains(int teamId) async =>
      await _store.record(teamId).exists(_db);

  @override
  Future<void> save(FavoriteTeam team) =>
      _store.record(team.teamId).put(_db, FavoriteRecord.toMap(team));

  @override
  Future<void> remove(int teamId) => _store.record(teamId).delete(_db);
}
