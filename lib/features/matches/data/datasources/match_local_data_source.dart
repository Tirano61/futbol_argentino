import 'package:sembast/sembast.dart';

import '../../../../core/storage/local_database.dart';
import '../../domain/entities/match.dart';
import '../models/match_record.dart';

/// Partidos guardados (store `events`, clave `idEvent`).
class MatchLocalDataSource {
  MatchLocalDataSource(this._db);

  final Database _db;
  final _store = AppStores.events;

  /// Todos los partidos guardados de una ronda, con cualquier membresía.
  Future<List<Match>> round({
    required int competitionId,
    required String season,
    required int apiRound,
  }) async {
    final records = await _store.find(
      _db,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('competitionId', competitionId),
          Filter.equals('season', season),
          Filter.equals('apiRound', apiRound),
        ]),
      ),
    );
    return [for (final r in records) MatchRecord.fromMap(r.value)];
  }

  Future<Match?> byId(int id) async {
    final map = await _store.record(id).get(_db);
    return map == null ? null : MatchRecord.fromMap(map);
  }

  Future<List<Match>> byIds(Iterable<int> ids) async {
    final maps = await _store.records(ids).get(_db);
    return [
      for (final map in maps)
        if (map != null) MatchRecord.fromMap(map),
    ];
  }

  /// Partidos de un equipo, de todas las competiciones guardadas.
  Future<List<Match>> byTeam(int teamId) async {
    final records = await _store.find(
      _db,
      finder: Finder(filter: Filter.equals('teamIds', teamId, anyInList: true)),
    );
    return [for (final r in records) MatchRecord.fromMap(r.value)];
  }

  /// Equipos de todos los partidos guardados (para el índice de búsqueda).
  Future<List<TeamSighting>> teamSightings() async => [
    for (final r in await _store.find(_db))
      ...MatchRecord.sightingsFromMap(r.value),
  ];

  Future<void> saveAll(List<Match> matches) async {
    if (matches.isEmpty) return;
    await _db.transaction((txn) async {
      for (final m in matches) {
        await _store.record(m.id).put(txn, MatchRecord.toMap(m));
      }
    });
  }
}
