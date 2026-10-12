import 'package:sembast/sembast.dart';

import '../../../../core/storage/local_database.dart';
import '../../domain/entities/match.dart';
import '../../domain/repositories/match_repository.dart';
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

  /// Todos los partidos guardados de una temporada, con cualquier
  /// membresía.
  Future<List<Match>> season({
    required int competitionId,
    required String season,
  }) async {
    final records = await _store.find(
      _db,
      finder: Finder(filter: _seasonFilter(competitionId, season)),
    );
    return [for (final r in records) MatchRecord.fromMap(r.value)];
  }

  /// Cantidad de partidos por competición y temporada (sin reconstruir
  /// cada partido).
  Future<List<StoredSeasonSummary>> seasonSummaries() async {
    final byKey = <(int, String), _SeasonCount>{};
    for (final r in await _store.find(_db)) {
      final map = r.value;
      final competitionId = map['competitionId']! as int;
      final season = map['season']! as String;
      (byKey[(competitionId, season)] ??= _SeasonCount(
        competitionId,
        map['competitionName']! as String,
        season,
      )).add(map['membership']! as String);
    }
    return [for (final c in byKey.values) c.summary];
  }

  /// Borra los partidos de una temporada y devuelve sus `idEvent`.
  Future<List<int>> deleteSeason({
    required int competitionId,
    required String season,
  }) => _db.transaction((txn) async {
    final finder = Finder(filter: _seasonFilter(competitionId, season));
    final keys = await _store.findKeys(txn, finder: finder);
    await _store.delete(txn, finder: finder);
    return keys;
  });

  static Filter _seasonFilter(int competitionId, String season) => Filter.and([
    Filter.equals('competitionId', competitionId),
    Filter.equals('season', season),
  ]);

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

  /// Partidos de esos equipos; emite enseguida y cada vez que se guardan
  /// partidos.
  Stream<List<Match>> watchByTeams(Set<int> teamIds) => _store
      .query(
        finder: Finder(
          filter: Filter.or([
            for (final id in teamIds)
              Filter.equals('teamIds', id, anyInList: true),
          ]),
        ),
      )
      .onSnapshots(_db)
      .map(
        (records) => [for (final r in records) MatchRecord.fromMap(r.value)],
      );

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

class _SeasonCount {
  _SeasonCount(this.competitionId, this.competitionName, this.season);

  final int competitionId;
  final String competitionName;
  final String season;
  var _total = 0;
  var _orphaned = 0;
  var _removed = 0;

  void add(String membership) {
    _total++;
    if (membership == MatchMembership.orphaned.name) _orphaned++;
    if (membership == MatchMembership.removed.name) _removed++;
  }

  StoredSeasonSummary get summary => StoredSeasonSummary(
    competitionId: competitionId,
    competitionName: competitionName,
    season: season,
    matchCount: _total,
    orphanedCount: _orphaned,
    removedCount: _removed,
  );
}
