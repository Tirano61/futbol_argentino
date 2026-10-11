import 'package:sembast/sembast.dart';

import '../../../../core/cache/cache_class.dart';
import '../../../../core/cache/query_metadata_store.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/remote_call.dart';
import '../../../../core/result/data_result.dart';
import '../../../../core/storage/local_database.dart';
import '../../../../core/sync/sync_scheduler.dart';
import '../../../../core/time/clock.dart';
import '../../../matches/data/mappers/event_mapper.dart';
import '../../domain/catalog/competition_catalog.dart';
import '../../domain/entities/competition.dart';
import '../../domain/repositories/competition_repository.dart';
import '../datasources/competition_remote_data_source.dart';
import '../models/competition_record.dart';

class CompetitionRepositoryImpl implements CompetitionRepository {
  CompetitionRepositoryImpl({
    required CompetitionRemoteDataSource remote,
    required Database database,
    required QueryMetadataStore metadata,
    required SyncScheduler scheduler,
    required Clock clock,
  }) : _remote = remote,
       _db = database,
       _metadata = metadata,
       _scheduler = scheduler,
       _clock = clock;

  final CompetitionRemoteDataSource _remote;
  final Database _db;
  final QueryMetadataStore _metadata;
  final SyncScheduler _scheduler;
  final Clock _clock;

  static String leagueKey(int id) => 'league:$id';
  static String pointersKey(int id) => 'pointers:$id';

  @override
  Future<DataResult<Competition>> getCompetition(int competitionId) async {
    final definition = CompetitionCatalog.byId(competitionId);
    if (definition == null) {
      throw NotFoundFailure(
        detail: 'La competición $competitionId no está en el catálogo',
      );
    }
    final key = leagueKey(competitionId);
    final record = AppStores.competitions.record(competitionId);

    return _cached(
      key: key,
      read: () async {
        final map = await record.get(_db);
        return map == null ? null : CompetitionRecord.fromMap(map);
      },
      refresh: () async {
        final dto = await remoteCall(() => _remote.fetchLeague(competitionId));
        if (dto == null) {
          throw NotFoundFailure(
            detail: 'lookupleague no devolvió la liga $competitionId',
          );
        }
        await record.put(
          _db,
          CompetitionRecord.toMap(dto.toEntity(definition)),
        );
        await _metadata.put(
          QueryMetadata(
            key: key,
            fetchedAt: _clock.now(),
            cacheClass: CacheClass.metadata,
          ),
        );
      },
    );
  }

  @override
  Future<DataResult<SchedulePointers>> getSchedulePointers(
    int competitionId, {
    bool forceRefresh = false,
  }) {
    final key = pointersKey(competitionId);
    final record = AppStores.schedulePointers.record(competitionId);

    return _cached(
      key: key,
      forceRefresh: forceRefresh,
      read: () async {
        final map = await record.get(_db);
        return map == null ? null : CompetitionRecord.pointersFromMap(map);
      },
      refresh: () async {
        final now = _clock.now();
        final next = await remoteCall(
          () => _remote.fetchNextEvent(competitionId),
        );
        final last = await remoteCall(
          () => _remote.fetchLastEvent(competitionId),
        );
        final pointers = SchedulePointers(
          next: next == null ? null : EventMapper.toEntity(next, seenAt: now),
          last: last == null ? null : EventMapper.toEntity(last, seenAt: now),
        );
        await record.put(_db, CompetitionRecord.pointersToMap(pointers));
        await _metadata.put(
          QueryMetadata(
            key: key,
            fetchedAt: now,
            cacheClass: CacheClass.pointers,
          ),
        );
      },
    );
  }

  /// Caché con vigencia según `query_meta`: devuelve lo guardado si está
  /// vigente; si no, refresca. Si el refresco falla, devuelve lo guardado
  /// con el error, o lanza el error si no hay nada.
  Future<DataResult<T>> _cached<T>({
    required String key,
    required Future<T?> Function() read,
    required Future<void> Function() refresh,
    bool forceRefresh = false,
  }) async {
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
      await _scheduler.run(key, SyncPriority.visible, refresh);
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
      data: (await read()) as T,
      origin: DataOrigin.remote,
      fetchedAt: updated.fetchedAt,
    );
  }
}
