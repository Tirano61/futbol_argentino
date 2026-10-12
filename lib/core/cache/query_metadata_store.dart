import 'package:sembast/sembast.dart';

import '../storage/local_database.dart';
import 'cache_class.dart';

/// Cuándo y con qué resultado se hizo una consulta a la API.
final class QueryMetadata {
  const QueryMetadata({
    required this.key,
    required this.fetchedAt,
    required this.cacheClass,
    this.quality,
  });

  factory QueryMetadata.fromMap(String key, Map<String, Object?> map) =>
      QueryMetadata(
        key: key,
        fetchedAt: DateTime.parse(map['fetchedAt']! as String),
        cacheClass: CacheClass.values.byName(map['cacheClass']! as String),
        quality: map['quality'] as String?,
      );

  final String key;

  /// UTC.
  final DateTime fetchedAt;
  final CacheClass cacheClass;

  /// Calidad de la respuesta (`complete`, `partial`…), si aplica.
  final String? quality;

  bool isFresh(DateTime now) => now.difference(fetchedAt) < cacheClass.ttl;

  /// Un refresco manual solo se hace si pasó el intervalo mínimo.
  bool allowsManualRefresh(DateTime now) =>
      now.difference(fetchedAt) >= CacheClass.manualRefreshInterval;

  /// Hay que pedir a la red: vencida, o refresco manual permitido.
  bool needsRefresh(DateTime now, {required bool force}) =>
      !isFresh(now) || (force && allowsManualRefresh(now));

  Map<String, Object?> toMap() => {
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'cacheClass': cacheClass.name,
    'quality': quality,
  };
}

class QueryMetadataStore {
  QueryMetadataStore(this._db);

  final Database _db;

  Future<QueryMetadata?> get(String key) async {
    final map = await AppStores.queryMeta.record(key).get(_db);
    return map == null ? null : QueryMetadata.fromMap(key, map);
  }

  Future<void> put(QueryMetadata metadata) =>
      AppStores.queryMeta.record(metadata.key).put(_db, metadata.toMap());

  /// Borra las consultas cuya clave empieza con [prefix] (p. ej.
  /// `round:4406:2025:`) y las de [keys].
  Future<void> delete({String? prefix, Iterable<String> keys = const []}) =>
      _db.transaction((txn) async {
        if (prefix != null) {
          await AppStores.queryMeta.delete(
            txn,
            finder: Finder(
              filter: Filter.custom(
                (r) => (r.key! as String).startsWith(prefix),
              ),
            ),
          );
        }
        await AppStores.queryMeta.records(keys).delete(txn);
      });
}
