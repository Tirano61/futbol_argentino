import 'package:flutter/foundation.dart';

import '../../../../core/cache/query_metadata_store.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/remote_call.dart';
import '../../../../core/result/data_result.dart';
import '../../../../core/sync/sync_scheduler.dart';
import '../../../../core/time/clock.dart';
import '../../domain/entities/match.dart';
import '../../domain/repositories/match_repository.dart';
import '../../domain/services/round_merge_policy.dart';
import '../cache/round_cache_policy.dart';
import '../datasources/match_local_data_source.dart';
import '../datasources/match_remote_data_source.dart';
import '../mappers/event_mapper.dart';

/// Repositorio offline-first de partidos: caché inmediata, refresco cuando
/// vence (stale-while-revalidate) y merge con [RoundMergePolicy].
class MatchRepositoryImpl implements MatchRepository {
  MatchRepositoryImpl({
    required MatchRemoteDataSource remote,
    required MatchLocalDataSource local,
    required QueryMetadataStore metadata,
    required SyncScheduler scheduler,
    required Clock clock,
  }) : _remote = remote,
       _local = local,
       _metadata = metadata,
       _scheduler = scheduler,
       _clock = clock;

  final MatchRemoteDataSource _remote;
  final MatchLocalDataSource _local;
  final QueryMetadataStore _metadata;

  /// Comparte refrescos simultáneos de la misma clave y los ordena por
  /// prioridad.
  final SyncScheduler _scheduler;
  final Clock _clock;

  static String roundKey(RoundQuery q) =>
      'round:${q.competitionId}:${q.season}:${q.apiRound}';

  static String eventKey(int id) => 'event:$id';

  @override
  Stream<DataResult<List<Match>>> watchRound(
    RoundQuery query, {
    bool forceRefresh = false,
  }) async* {
    final key = roundKey(query);
    final meta = await _metadata.get(key);
    List<Match>? cached;

    if (meta != null) {
      cached = await _visibleRound(query);
      yield DataResult(
        data: cached,
        origin: DataOrigin.cache,
        fetchedAt: meta.fetchedAt,
      );
      if (!meta.needsRefresh(_clock.now(), force: forceRefresh)) return;
    }

    try {
      await _scheduler.run(
        key,
        SyncPriority.visible,
        () => _refreshRound(query, key),
      );
    } on Failure catch (failure) {
      if (meta == null) rethrow;
      yield DataResult(
        data: cached!,
        origin: DataOrigin.cache,
        fetchedAt: meta.fetchedAt,
        refreshError: failure,
      );
      return;
    }

    final updated = (await _metadata.get(key))!;
    yield DataResult(
      data: await _visibleRound(query),
      origin: DataOrigin.remote,
      fetchedAt: updated.fetchedAt,
    );
  }

  @override
  Future<void> prefetchRound(RoundQuery query) async {
    final key = roundKey(query);
    final meta = await _metadata.get(key);
    if (meta != null && meta.isFresh(_clock.now())) return;
    try {
      await _scheduler.run(
        key,
        SyncPriority.context,
        () => _refreshRound(query, key),
      );
    } on Failure catch (failure) {
      debugPrint('$key: prefetch falló: $failure');
    }
  }

  @override
  Future<DataResult<Match>> getMatch(
    int matchId, {
    bool forceRefresh = false,
  }) async {
    final key = eventKey(matchId);
    final stored = await _local.byId(matchId);
    final now = _clock.now();

    if (stored != null) {
      final meta = await _metadata.get(key);
      // Lo más reciente entre una consulta directa y la última ronda.
      final fetchedAt =
          meta != null && meta.fetchedAt.isAfter(stored.lastSeenAt)
          ? meta.fetchedAt
          : stored.lastSeenAt;
      final effective = QueryMetadata(
        key: key,
        fetchedAt: fetchedAt,
        cacheClass: RoundCachePolicy.classify(
          matches: [stored],
          quality: ResponseQuality.complete,
          now: now,
        ),
      );
      if (!effective.needsRefresh(now, force: forceRefresh)) {
        return DataResult(
          data: stored,
          origin: DataOrigin.cache,
          fetchedAt: fetchedAt,
        );
      }
    }

    try {
      await _scheduler.run(
        key,
        SyncPriority.visible,
        () => _refreshEvent(matchId, stored),
      );
    } on Failure catch (failure) {
      if (stored == null) rethrow;
      return DataResult(
        data: stored,
        origin: DataOrigin.cache,
        fetchedAt: stored.lastSeenAt,
        refreshError: failure,
      );
    }

    final updated = (await _local.byId(matchId))!;
    return DataResult(
      data: updated,
      origin: DataOrigin.remote,
      fetchedAt: updated.lastSeenAt,
    );
  }

  Future<void> _refreshRound(RoundQuery query, String key) async {
    final now = _clock.now();
    final dtos = await remoteCall(
      () => _remote.fetchRound(
        competitionId: query.competitionId,
        season: query.season,
        apiRound: query.apiRound,
      ),
    );

    final incoming = [
      for (final dto in dtos)
        ?EventMapper.toEntity(
          dto,
          seenAt: now,
          season: query.season,
          apiRound: query.apiRound,
        ),
    ];
    if (incoming.length < dtos.length) {
      debugPrint(
        '$key: ${dtos.length - incoming.length} eventos descartados '
        '(sin idEvent, idLeague o idTeam)',
      );
    }

    final inRound = await _localRound(query);
    final known = await _local.byIds(incoming.map((m) => m.id));
    final stored = {
      for (final m in [...inRound, ...known]) m.id: m,
    };

    final result = RoundMergePolicy.merge(
      apiRound: query.apiRound,
      stored: stored.values.toList(),
      incoming: incoming,
      expectedMinimum: query.expectedMinimum,
      now: now,
    );
    await _local.saveAll(result.toSave);
    if (result.quality != ResponseQuality.complete) {
      debugPrint('$key: respuesta ${result.quality.name}');
    }
    if (result.toVerify.isNotEmpty) {
      // La verificación con lookupevent es sincronización P3 (post-MVP).
      debugPrint('$key: pendientes de verificar ${result.toVerify}');
    }

    await _metadata.put(
      QueryMetadata(
        key: key,
        fetchedAt: now,
        cacheClass: RoundCachePolicy.classify(
          matches: await _visibleRound(query),
          quality: result.quality,
          now: now,
        ),
        quality: result.quality.name,
      ),
    );
  }

  Future<void> _refreshEvent(int matchId, Match? stored) async {
    final now = _clock.now();
    final dto = await remoteCall(() => _remote.fetchEvent(matchId));
    if (dto == null) {
      throw NotFoundFailure(
        detail: 'lookupevent no devolvió el evento $matchId',
      );
    }
    final incoming = EventMapper.toEntity(dto, seenAt: now);
    if (incoming == null) {
      throw FormatFailure(
        detail: 'El evento $matchId no trae idEvent, idLeague o idTeam',
      );
    }
    final merged = RoundMergePolicy.mergeFields(stored, incoming, now);
    await _local.saveAll([merged]);
    await _metadata.put(
      QueryMetadata(
        key: eventKey(matchId),
        fetchedAt: now,
        cacheClass: RoundCachePolicy.classify(
          matches: [merged],
          quality: ResponseQuality.complete,
          now: now,
        ),
      ),
    );
  }

  Future<List<Match>> _localRound(RoundQuery q) => _local.round(
    competitionId: q.competitionId,
    season: q.season,
    apiRound: q.apiRound,
  );

  Future<List<Match>> _visibleRound(RoundQuery q) async => [
    for (final m in await _localRound(q))
      if (m.isVisible) m,
  ];
}
