import 'package:flutter/material.dart';

/// Roles tipográficos de la app (Hito E, §4.2), sobre los estilos de
/// Material 3. Las cifras (marcador, hora, estadísticas) van tabulares para
/// que no bailen entre filas, aunque en Web caiga otra fuente.
///
/// Los estilos no traen color: lo pone cada widget desde el esquema
/// (`onSurface`, `onSurfaceVariant`, `primary`) o desde `AppPalette`.
extension AppText on TextTheme {
  static const _tabular = [FontFeature.tabularFigures()];

  /// «Hoy», «Próximos 7 días»: 16 / w700.
  TextStyle get sectionTitle =>
      titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w700);

  /// Encabezado de un grupo (competición · fecha, serie): 14 / w600.
  TextStyle get groupTitle =>
      labelLarge!.copyWith(fontSize: 14, fontWeight: FontWeight.w600);

  /// Encabezado de día («Sábado 17/10/2026»): 13 / w600, en `primary`.
  TextStyle get dayHeader =>
      labelLarge!.copyWith(fontSize: 13, fontWeight: FontWeight.w600);

  /// Equipo en una lista: 14 / w400.
  TextStyle get teamName =>
      bodyMedium!.copyWith(fontSize: 14, fontWeight: FontWeight.w400);

  /// Ganador en una lista: 14 / w700.
  TextStyle get teamNameWinner =>
      teamName.copyWith(fontWeight: FontWeight.w700);

  /// Marcador en una lista: 18 / w700, tabular.
  TextStyle get listScore => titleMedium!.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
  );

  /// Marcador del héroe (detalle): 36 / w700, tabular.
  TextStyle get heroScore => displaySmall!.copyWith(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
  );

  /// Equipo en el héroe del detalle: 16 / w400…
  TextStyle get heroTeam =>
      titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w400);

  /// …y el ganador del partido: 16 / w700.
  TextStyle get heroTeamWinner =>
      heroTeam.copyWith(fontWeight: FontWeight.w700);

  /// Nombre en la cabecera de la ficha de un equipo: 24 / w600.
  TextStyle get teamHeaderName =>
      headlineSmall!.copyWith(fontSize: 24, fontWeight: FontWeight.w600);

  /// Hora en una lista: 14 / w600, tabular.
  TextStyle get listTime => titleSmall!.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    fontFeatures: _tabular,
  );

  /// Etiqueta de estado («Final», «En juego»): 11 / w600.
  TextStyle get statusLabel =>
      labelSmall!.copyWith(fontSize: 11, fontWeight: FontWeight.w600);

  /// Estadística de tabla: 14 / w400, tabular.
  TextStyle get tableStat => bodyMedium!.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    fontFeatures: _tabular,
  );

  /// Encabezado de tabla: 11 / w600.
  TextStyle get tableHeader =>
      labelSmall!.copyWith(fontSize: 11, fontWeight: FontWeight.w600);

  /// Secundario y notas (contexto de una fila, pie): 12 / w400.
  TextStyle get secondary =>
      bodySmall!.copyWith(fontSize: 12, fontWeight: FontWeight.w400);

  /// Mensaje de un aviso: 14.
  TextStyle get bannerMessage => bodyMedium!.copyWith(fontSize: 14);
}
