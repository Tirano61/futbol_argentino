import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// De dónde sale la imagen de un escudo (`TeamBadge`).
abstract interface class BadgeImageResolver {
  /// Android: caché en disco (los escudos se ven sin conexión después de
  /// verlos una vez). Web: la red con el `<img>` del navegador.
  factory BadgeImageResolver.forPlatform() =>
      kIsWeb ? const NetworkBadgeImages() : DiskBadgeImages();

  ImageProvider imageFor(String url);
}

/// Red, con la caché en memoria de Flutter (y la del navegador en Web).
///
/// `WebHtmlElementStrategy.fallback`: `r2.thesportsdb.com` no envía CORS y en
/// Web la carga normal falla (validado en T0.2). En `cached_network_image`
/// falla por lo mismo, así que Web usa siempre esta.
class NetworkBadgeImages implements BadgeImageResolver {
  const NetworkBadgeImages();

  @override
  ImageProvider imageFor(String url) => NetworkImage(
    url,
    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
  );
}

/// Caché en disco de `cached_network_image` (solo Android).
class DiskBadgeImages implements BadgeImageResolver {
  DiskBadgeImages({BaseCacheManager? cacheManager})
    : _cacheManager = cacheManager;

  /// Unos 150 equipos en el catálogo, con escudo chico y grande: lugar de
  /// sobra. Un escudo que no se usa en 60 días se borra. Se crea con el
  /// primer escudo (abre su índice en disco).
  static final _badges = CacheManager(
    Config(
      'team_badges',
      stalePeriod: const Duration(days: 60),
      maxNrOfCacheObjects: 600,
    ),
  );

  final BaseCacheManager? _cacheManager;

  @override
  ImageProvider imageFor(String url) =>
      CachedNetworkImageProvider(url, cacheManager: _cacheManager ?? _badges);
}

/// Pone un [BadgeImageResolver] al alcance de los escudos de toda la app.
/// Sin uno arriba (tests de un widget suelto), los escudos usan la red.
class BadgeImages extends InheritedWidget {
  const BadgeImages({super.key, required this.resolver, required super.child});

  final BadgeImageResolver resolver;

  static BadgeImageResolver of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BadgeImages>()?.resolver ??
      const NetworkBadgeImages();

  @override
  bool updateShouldNotify(BadgeImages oldWidget) =>
      resolver != oldWidget.resolver;
}
