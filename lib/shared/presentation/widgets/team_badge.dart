import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'badge_image_resolver.dart';

/// Escudo de un equipo. Si no hay URL o la imagen no carga (sin red, sin
/// caché), muestra las iniciales.
///
/// La imagen sale del [BadgeImageResolver] de la app: en Android, con caché
/// en disco; en Web, de la red con `WebHtmlElementStrategy.fallback`
/// (`r2.thesportsdb.com` no envía CORS, validado en T0.2).
class TeamBadge extends StatelessWidget {
  const TeamBadge({
    super.key,
    required this.name,
    required this.url,
    this.size = AppSizes.badgeHeader,
  });

  final String name;
  final String? url;
  final double size;

  /// Iniciales de las dos primeras palabras significativas.
  static String initialsOf(String name) {
    const ignored = {'de', 'del', 'la', 'las', 'los', 'y', 'el'};
    final words = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !ignored.contains(w.toLowerCase()))
        .toList();
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final source = url;
    final placeholder = _Initials(text: initialsOf(name), size: size);
    if (source == null) return placeholder;

    // /tiny = 50 px, /small = 250 px.
    final variant = size <= 50 ? '$source/tiny' : '$source/small';
    return SizedBox.square(
      dimension: size,
      child: Image(
        image: BadgeImages.of(context).imageFor(variant),
        // En Web, con el `<img>` del modo fallback, cambiar la URL de una
        // imagen ya montada no cambia lo que se ve (una tabla que se reordena
        // dejaba cada escudo en su fila): otra URL, otra imagen.
        key: ValueKey(variant),
        width: size,
        height: size,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) => placeholder,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
            wasSynchronouslyLoaded || frame != null ? child : placeholder,
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.text, required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: colors.onPrimaryContainer,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
