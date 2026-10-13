import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/shared/presentation/widgets/badge_image_resolver.dart';
import 'package:futbol_argentino/shared/presentation/widgets/team_badge.dart';

/// URL real de un escudo (Boca Juniors, `lookupteam_135156.json`).
const badge =
    'https://r2.thesportsdb.com/images/media/team/badge/bm7krb1775741582.png';

/// Caché que no toca el disco (el real necesita `path_provider`).
class _UnusedCacheManager implements BaseCacheManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Anota cada URL que pide [TeamBadge].
class _RecordingResolver implements BadgeImageResolver {
  final urls = <String>[];

  @override
  ImageProvider imageFor(String url) {
    urls.add(url);
    return const NetworkBadgeImages().imageFor(url);
  }
}

void main() {
  test('red: el `<img>` del navegador en Web (r2 no envía CORS)', () {
    final image = const NetworkBadgeImages().imageFor(badge);

    expect(
      image,
      isA<NetworkImage>()
          .having((i) => i.url, 'url', badge)
          .having(
            (i) => i.webHtmlElementStrategy,
            'estrategia Web',
            WebHtmlElementStrategy.fallback,
          ),
    );
  });

  test('disco: cached_network_image con la caché de escudos', () {
    final cache = _UnusedCacheManager();
    final image = DiskBadgeImages(cacheManager: cache).imageFor(badge);

    expect(
      image,
      isA<CachedNetworkImageProvider>()
          .having((i) => i.url, 'url', badge)
          .having((i) => i.cacheManager, 'caché', same(cache)),
    );
  });

  test('fuera de Web (Android) la app usa la caché en disco', () {
    // Los tests corren fuera de Web.
    expect(BadgeImageResolver.forPlatform(), isA<DiskBadgeImages>());
  });

  testWidgets('TeamBadge pide la imagen al resolver de la app', (tester) async {
    final resolver = _RecordingResolver();
    await tester.pumpWidget(
      BadgeImages(
        resolver: resolver,
        child: const MaterialApp(
          home: Column(
            children: [
              TeamBadge(name: 'Boca Juniors', url: badge, size: 24),
              TeamBadge(name: 'Boca Juniors', url: badge, size: 96),
            ],
          ),
        ),
      ),
    );

    expect(resolver.urls, ['$badge/tiny', '$badge/small']);
  });

  testWidgets('sin resolver arriba, TeamBadge usa la red', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TeamBadge(name: 'Boca Juniors', url: badge, size: 24),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
  });
}
