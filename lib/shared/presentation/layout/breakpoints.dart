import 'package:flutter/widgets.dart';

/// Anchos de ventana de la app (plan §6.2).
///
/// - Compacto (< 600 px): navegación inferior.
/// - Mediano (600–1199 px): riel lateral.
/// - Amplio (≥ 1200 px): riel extendido, buscador en la barra superior,
///   Inicio en 2 columnas y fixture con panel de detalle.
abstract final class Breakpoints {
  /// Desde este ancho se usa el riel lateral.
  static const medium = 600.0;

  /// Desde este ancho se usa el diseño de escritorio.
  static const expanded = 1200.0;

  /// Ancho máximo del contenido en el diseño de escritorio.
  static const maxContentWidth = 1200.0;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < medium;

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expanded;
}
