import 'package:sembast/sembast.dart';

import '../../../../core/cache/cache_class.dart';
import '../../../../core/cache/query_metadata_store.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/remote_call.dart';
import '../../../../core/result/data_result.dart';
import '../../../../core/storage/local_database.dart';
import '../../../../core/sync/sync_scheduler.dart';
import '../../../../core/time/clock.dart';
import '../../../matches/data/datasources/match_local_data_source.dart';
import '../../../matches/data/models/match_record.dart';
import '../../../matches/domain/entities/team_ref.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/team_summary.dart';
import '../../domain/repositories/team_repository.dart';
import '../datasources/team_remote_data_source.dart';
import '../models/team_record.dart';

class TeamRepositoryImpl implements TeamRepository {
  TeamRepositoryImpl({
    required TeamRemoteDataSource remote,
    required MatchLocalDataSource matches,
    required Database database,
    required QueryMetadataStore metadata,
    required SyncScheduler scheduler,
    required Clock clock,
  }) : _remote = remote,
       _matches = matches,
       _db = database,
       _metadata = metadata,
       _scheduler = scheduler,
       _clock = clock;

  final TeamRemoteDataSource _remote;
  final MatchLocalDataSource _matches;
  final Database _db;
  final QueryMetadataStore _metadata;
  final SyncScheduler _scheduler;
  final Clock _clock;

  static String teamKey(int id) => 'team:$id';

  @override
  Future<List<TeamSummary>> storedTeams() async {
    final byTeam = <int, _Sightings>{};
    for (final s in await _matches.teamSightings()) {
      (byTeam[s.team.id] ??= _Sightings(s)).add(s);
    }
    return [for (final s in byTeam.values) s.summary];
  }

  @override
  Future<List<Team>> searchOnline(String query) async {
    final name = query.trim();
    var found = const <Team>[];
    await _scheduler.run(
      'search:${name.toLowerCase()}',
      SyncPriority.visible,
      () async {
        final dtos = await remoteCall(() => _remote.search(name));
        found = [
          for (final dto in dtos)
            if (dto.isArgentineFootball) ?dto.toEntity(),
        ];
      },
    );
    return found;
  }

  @override
  Future<DataResult<Team>> getTeam(
    int teamId, {
    bool forceRefresh = false,
  }) async {
    final key = teamKey(teamId);
    final record = AppStores.teams.record(teamId);
    Future<Team?> read() async {
      final map = await record.get(_db);
      return map == null ? null : TeamRecord.fromMap(map);
    }

    final meta = await _metadata.get(key);
    final stored = meta == null ? null : await read();
    if (meta != null &&
        stored != null &&
        !meta.needsRefresh(_clock.now(), force: forceRefresh)) {
      return DataResult(
        data: stored,
        origin: DataOrigin.cache,
        fetchedAt: meta.fetchedAt,
      );
    }

    try {
      await _scheduler.run(key, SyncPriority.visible, () async {
        final dto = await remoteCall(() => _remote.fetchTeam(teamId));
        if (dto == null) {
          throw NotFoundFailure(
            detail: 'lookupteam no devolvió el equipo $teamId',
          );
        }
        final team = dto.toEntity();
        if (team == null) {
          throw FormatFailure(
            detail: 'El equipo $teamId no trae idTeam o strTeam',
          );
        }
        await record.put(_db, TeamRecord.toMap(team));
        await _metadata.put(
          QueryMetadata(
            key: key,
            fetchedAt: _clock.now(),
            cacheClass: CacheClass.metadata,
          ),
        );
      });
    } on Failure catch (failure) {
      if (meta == null || stored == null) rethrow;
      return DataResult(
        data: stored,
        origin: DataOrigin.cache,
        fetchedAt: meta.fetchedAt,
        refreshError: failure,
      );
    }

    final updated = (await _metadata.get(key))!;
    return DataResult(
      data: (await read())!,
      origin: DataOrigin.remote,
      fetchedAt: updated.fetchedAt,
    );
  }
}

/// Lo que se sabe de un equipo por los partidos guardados: nombre y escudo
/// del partido visto más recientemente; competiciones de la temporada más
/// reciente.
final class _Sightings {
  _Sightings(TeamSighting first) : _latest = first, _season = first.season;

  TeamSighting _latest;

  /// Algún escudo, por si el partido más reciente no lo trae.
  String? _anyBadgeUrl;
  String _season;
  final _competitionIds = <int>{};

  void add(TeamSighting s) {
    if (s.seenAt.isAfter(_latest.seenAt)) _latest = s;
    _anyBadgeUrl ??= s.team.badgeUrl;
    // Temporadas `YYYY`: el orden de texto es el cronológico.
    final order = s.season.compareTo(_season);
    if (order > 0) {
      _season = s.season;
      _competitionIds.clear();
    }
    if (order >= 0) _competitionIds.add(s.competitionId);
  }

  TeamSummary get summary => TeamSummary(
    team: TeamRef(
      id: _latest.team.id,
      name: _latest.team.name,
      badgeUrl: _latest.team.badgeUrl ?? _anyBadgeUrl,
    ),
    competitionIds: _competitionIds.toList()..sort(),
  );
}
