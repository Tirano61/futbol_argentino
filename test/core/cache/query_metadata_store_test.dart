import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/cache/cache_class.dart';
import 'package:futbol_argentino/core/cache/query_metadata_store.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  final fetchedAt = DateTime.utc(2026, 10, 11, 20);

  test('guarda y lee metadatos de una consulta', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('test.db');
    final store = QueryMetadataStore(db);

    await store.put(
      QueryMetadata(
        key: 'round:4406:2026:12',
        fetchedAt: fetchedAt,
        cacheClass: CacheClass.today,
        quality: 'complete',
      ),
    );
    final read = await store.get('round:4406:2026:12');

    expect(read!.fetchedAt, fetchedAt);
    expect(read.cacheClass, CacheClass.today);
    expect(read.quality, 'complete');
    expect(await store.get('round:4406:2026:13'), isNull);
    await db.close();
  });

  group('vigencia', () {
    final meta = QueryMetadata(
      key: 'k',
      fetchedAt: fetchedAt,
      cacheClass: CacheClass.today,
    );

    test('fresca antes del TTL, vencida después', () {
      expect(meta.isFresh(fetchedAt.add(const Duration(minutes: 9))), isTrue);
      expect(meta.isFresh(fetchedAt.add(const Duration(minutes: 10))), isFalse);
    });

    test('refresco manual: no antes de 30 s', () {
      final at10s = fetchedAt.add(const Duration(seconds: 10));
      final at31s = fetchedAt.add(const Duration(seconds: 31));

      expect(meta.needsRefresh(at10s, force: true), isFalse);
      expect(meta.needsRefresh(at31s, force: true), isTrue);
      expect(meta.needsRefresh(at31s, force: false), isFalse);
    });
  });
}
