import 'package:flutter/widgets.dart';

/// Escala de espaciado (Hito E, §4.3): 4 · 8 · 12 · 16 · 24 · 32. Ningún
/// otro valor sin una razón escrita.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Radios: 12 las superficies de grupo; 8 chips, píldoras, avisos y celdas.
abstract final class AppRadius {
  static const double group = 12;
  static const double control = 8;

  static const groupAll = BorderRadius.all(Radius.circular(group));
  static const controlAll = BorderRadius.all(Radius.circular(control));

  /// Píldora («● En juego»): extremos redondos a cualquier escala de texto.
  static const pillAll = BorderRadius.all(Radius.circular(999));

  /// Codo de un conector de llaves.
  static const double connector = 6;
}

/// Medidas fijas de los componentes (Hito E, §4.3).
abstract final class AppSizes {
  /// Área táctil mínima, aunque el dibujo sea más compacto.
  static const double tapTarget = 48;

  /// Alto mínimo de una fila de partido: crece con el contenido.
  static const double matchRowMinHeight = 56;

  /// Alto mínimo del encabezado de un grupo.
  static const double groupHeaderMinHeight = 40;

  /// Barra de la fila seleccionada (la señal no es solo el color).
  static const double selectionBar = 3;

  static const double divider = 1;

  /// Escudos: llaves, tabla, filas de partido, encabezados, héroe.
  static const double badgeBracket = 20;
  static const double badgeTable = 24;
  static const double badgeRow = 28;
  static const double badgeHeader = 32;
  static const double badgeHero = 72;

  /// Logo de una competición (`CompetitionLogo`) y su recuadro: el mismo
  /// tamaño en la barra, la hoja y el menú; no crece con el texto.
  static const double competitionLogo = 28;
  static const double competitionLogoTile = 36;

  /// Punto fijo de «en vivo» (sin animación: trabaría `pumpAndSettle`).
  static const double liveDot = 6;

  /// Ícono de una etiqueta de estado o de una nota de fila, a escala 1.
  static const double statusIcon = 14;

  /// Ícono de un aviso (`InfoBanner`).
  static const double bannerIcon = 20;

  /// Ícono de una vista vacía o de error.
  static const double emptyIcon = 40;

  /// Indicador de carga dentro de un renglón de texto («Buscando en las
  /// copas internacionales…»): del tamaño del ícono de un aviso.
  static const double inlineProgress = bannerIcon;
  static const double inlineProgressStroke = 2;

  /// Borde esfumado de una fila que se desplaza (hay más contenido).
  static const double scrollFade = 24;

  /// Subrayado de la pestaña elegida (`ViewTabs`).
  static const double tabIndicator = 3;

  /// Conectores de llaves: un cruce definido va lleno y más grueso; uno
  /// pendiente, punteado (la diferencia no es solo el color).
  static const double connectorDefined = 2;
  static const double connectorPending = 1.5;
  static const double connectorDash = 4;
}
