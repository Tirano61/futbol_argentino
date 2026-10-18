import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../shared/presentation/theme/app_palette.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text.dart';
import '../../../../shared/presentation/widgets/team_badge.dart';
import '../../domain/standings/standings_table.dart';
import '../../domain/standings/tie_breaker.dart';

enum _Column {
  played('PJ', 'partidos jugados'),
  won('PG', 'ganados'),
  drawn('PE', 'empatados'),
  lost('PP', 'perdidos'),
  goalsFor('GF', 'goles a favor'),
  goalsAgainst('GC', 'goles en contra'),
  goalDifference('DG', 'diferencia de gol'),
  points('Pts', 'puntos');

  const _Column(this.short, this.spoken);

  final String short;
  final String spoken;

  /// Orden en que entran según el ancho (§8 de `docs/HITO_E.md`): Pts
  /// siempre; después PJ y DG (juntas), y el resto de a una.
  static const optional = [won, drawn, lost, goalsFor, goalsAgainst];

  /// Siempre a la vista: si no entran como columnas, van debajo del nombre.
  static const essential = [played, goalDifference];

  String valueOf(StandingsRow row) {
    final s = row.stats;
    return switch (this) {
      played => '${s.played}',
      won => '${s.won}',
      drawn => '${s.drawn}',
      lost => '${s.lost}',
      goalsFor => '${s.goalsFor}',
      goalsAgainst => '${s.goalsAgainst}',
      goalDifference =>
        s.goalDifference > 0 ? '+${s.goalDifference}' : '${s.goalDifference}',
      points => '${s.points}',
    };
  }
}

/// La tabla (Hito E, §8): filas separadas por divisores sobre la
/// superficie de grupo, posición y Pts en negrita, cifras tabulares a la
/// derecha. Tocar un equipo abre su ficha.
///
/// Las columnas salen del **ancho disponible** (no del de la pantalla) y de
/// la escala de texto: el nombre nunca baja de su palabra más larga, así no
/// se parte a mitad de palabra. Si PJ y DG no entran como columnas, van
/// debajo del nombre.
class StandingsTableView extends StatelessWidget {
  const StandingsTableView({
    super.key,
    required this.table,
    this.favorites = const {},
    this.advancing = const {},
  });

  final StandingsTable table;

  /// `idTeam` de los favoritos: fila resaltada y estrella (E-D11).
  final Set<int> favorites;

  /// `idTeam` de los que hoy siguen en competencia (E-D10, ver
  /// [advancingTeams]): barra junto a la posición.
  final Set<int> advancing;

  /// Equipos en los [places] primeros puestos de [rows] (los grupos
  /// CONMEBOL, con `GroupStage.advancingPlaces`). Una posición compartida
  /// que cruza el corte no se marca: no se sabe quién queda adentro.
  static Set<int> advancingTeams(List<StandingsRow> rows, int? places) {
    if (places == null) return const {};
    final sharing = <int, int>{};
    for (final r in rows) {
      sharing.update(r.position, (n) => n + 1, ifAbsent: () => 1);
    }
    return {
      for (final r in rows)
        if (r.position + sharing[r.position]! - 1 <= places) r.stats.team.id,
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _TableLayout.resolve(
          context,
          width: constraints.maxWidth,
          rows: table.rows,
        );
        return Material(
          color: AppPalette.of(context).group,
          borderRadius: AppRadius.groupAll,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Las filas ya dicen todo con su etiqueta accesible.
              ExcludeSemantics(child: _HeaderRow(layout: layout)),
              for (final row in table.rows) ...[
                const Divider(),
                _TeamRow(
                  row: row,
                  layout: layout,
                  isFavorite: favorites.contains(row.stats.team.id),
                  isAdvancing: advancing.contains(row.stats.team.id),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Qué se ve de la tabla en un ancho y una escala de texto dados.
final class _TableLayout {
  const _TableLayout({
    required this.position,
    required this.showBadge,
    required this.columns,
    required this.widths,
    required this.inline,
  });

  /// Ancho de la columna «#».
  final double position;

  /// Si falta lugar hasta para la palabra más larga con solo Pts, se quita
  /// el escudo antes que partirla.
  final bool showBadge;

  /// Columnas a la vista, en el orden de la tabla (PJ … DG, Pts).
  final List<_Column> columns;
  final Map<_Column, double> widths;

  /// PJ y DG cuando no entran como columnas: debajo del nombre.
  final List<_Column> inline;

  /// Barra de «sigue en competencia» (se reserva siempre: alinea las
  /// posiciones).
  static const marker = AppSizes.selectionBar;

  /// Entre el escudo y el nombre, y entre el nombre y las cifras.
  static const badgeGap = AppSpacing.sm;
  static const nameGap = AppSpacing.xs;

  /// Después de la última columna (la sombra de Pts llega al borde).
  static const trailing = 0.0;

  /// Lo que se suma al texto más ancho de cada columna (y lo de Pts, que
  /// lleva el fondo sombreado).
  static const cellPadding = AppSpacing.md;
  static const pointsPadding = AppSpacing.lg;

  /// El nombre no se achica por debajo de esto (a escala 1) para sumar una
  /// columna secundaria: a 360 px quedan PJ, DG y Pts, como antes.
  static const comfortableName = 160.0;

  /// Ancho de cada cifra cuando sobra lugar: si al nombre le siguen
  /// quedando [roomyName] (a escala 1).
  static const roomyCell = 44.0;
  static const roomyName = 320.0;

  static List<_Column> _inTableOrder(Iterable<_Column> columns) =>
      _Column.values.where(columns.contains).toList();

  static _TableLayout resolve(
    BuildContext context, {
    required double width,
    required List<StandingsRow> rows,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final text = Theme.of(context).textTheme;
    final styles = _Styles.of(text);

    double measure(String value, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w.ceilToDouble();
    }

    double columnWidth(_Column c) {
      final isPoints = c == _Column.points;
      var widest = measure(c.short, styles.header);
      for (final r in rows) {
        widest = math.max(
          widest,
          measure(c.valueOf(r), isPoints ? styles.points : styles.stat),
        );
      }
      return widest + (isPoints ? pointsPadding : cellPadding);
    }

    var position = measure('#', styles.header);
    for (final r in rows) {
      position = math.max(
        position,
        measure('${r.position}${r.isShared ? '*' : ''}', styles.position),
      );
    }
    position += cellPadding;

    // La palabra más larga de los nombres: menos que eso, se partiría.
    var longestWord = 0.0;
    for (final r in rows) {
      for (final word in r.stats.team.name.split(RegExp(r'\s+'))) {
        longestWord = math.max(longestWord, measure(word, styles.name));
      }
    }
    final comfortable = math.max(longestWord, scaler.scale(comfortableName));

    final widths = <_Column, double>{
      _Column.points: columnWidth(_Column.points),
    };
    var name =
        width -
        marker -
        position -
        AppSizes.badgeTable -
        badgeGap -
        nameGap -
        trailing -
        widths[_Column.points]!;

    final essential = {for (final c in _Column.essential) c: columnWidth(c)};
    final essentialWidth = essential.values.fold(0.0, (a, b) => a + b);
    if (name - essentialWidth >= comfortable) {
      widths.addAll(essential);
      name -= essentialWidth;
      for (final c in _Column.optional) {
        final w = columnWidth(c);
        if (name - w < comfortable) break;
        widths[c] = w;
        name -= w;
      }
    }
    // Con lugar de sobra (tablet horizontal, escritorio), las cifras se
    // separan un poco más en vez de dejar todo el aire al nombre.
    final roomy = {
      for (final c in widths.keys)
        c: math.max(
          widths[c]!,
          scaler.scale(roomyCell) +
              (c == _Column.points ? pointsPadding - cellPadding : 0),
        ),
    };
    final extra = [
      for (final c in widths.keys) roomy[c]! - widths[c]!,
    ].fold(0.0, (a, b) => a + b);
    if (name - extra >= scaler.scale(roomyName)) {
      widths.addAll(roomy);
      name -= extra;
    }
    final showBadge = name >= longestWord;

    return _TableLayout(
      position: position,
      showBadge: showBadge,
      columns: _inTableOrder(widths.keys),
      widths: widths,
      inline: [
        for (final c in _Column.essential)
          if (!widths.containsKey(c)) c,
      ],
    );
  }

  /// Lo que dice la fila: las columnas a la vista y las de debajo del
  /// nombre, de Pts hacia la izquierda (como antes).
  String spoken(StandingsRow row) {
    final said = _inTableOrder([...columns, ...inline]).reversed;
    return [for (final c in said) '${c.spoken} ${c.valueOf(row)}'].join(', ');
  }
}

/// Estilos de la tabla (§4.2): cifras tabulares 14, Pts y posición en
/// negrita, encabezado 11 / w600.
final class _Styles {
  const _Styles({
    required this.header,
    required this.stat,
    required this.points,
    required this.position,
    required this.name,
    required this.inline,
  });

  final TextStyle header;
  final TextStyle stat;
  final TextStyle points;
  final TextStyle position;
  final TextStyle name;
  final TextStyle inline;

  factory _Styles.of(TextTheme text) => _Styles(
    header: text.tableHeader,
    stat: text.tableStat,
    points: text.tableStat.copyWith(fontWeight: FontWeight.w700),
    position: text.tableStat.copyWith(fontWeight: FontWeight.w700),
    name: text.teamName,
    inline: text.secondary.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.layout});

  final _TableLayout layout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _Styles.of(
      theme.textTheme,
    ).header.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(
        left: _TableLayout.marker,
        right: _TableLayout.trailing,
        top: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: layout.position,
            child: Text('#', style: style, textAlign: TextAlign.center),
          ),
          Expanded(child: Text('Equipo', style: style)),
          const SizedBox(width: _TableLayout.nameGap),
          for (final c in layout.columns)
            _Cell(
              width: layout.widths[c]!,
              padding: c == _Column.points
                  ? _TableLayout.pointsPadding
                  : _TableLayout.cellPadding,
              child: Text(c.short, style: style, maxLines: 1),
            ),
        ],
      ),
    );
  }
}

/// Celda numérica alineada a la derecha.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.width,
    required this.padding,
    required this.child,
  });

  final double width;
  final double padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Padding(
      padding: EdgeInsets.only(right: padding / 2),
      child: Align(alignment: Alignment.centerRight, child: child),
    ),
  );
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({
    required this.row,
    required this.layout,
    required this.isFavorite,
    required this.isAdvancing,
  });

  final StandingsRow row;
  final _TableLayout layout;
  final bool isFavorite;
  final bool isAdvancing;

  /// Fondo tenue del favorito: el contenedor de marca sobre la superficie
  /// de grupo (maqueta de E1).
  static const _favoriteTint = 0.6;

  /// Sombra de la columna Pts.
  static const _pointsShade = 0.55;

  String get _label {
    final position = row.isShared
        ? 'Posición ${row.position}, compartida'
        : 'Posición ${row.position}';
    return [
      '$position: ${row.stats.team.name}. ${layout.spoken(row)}.',
      if (isAdvancing) 'Sigue en competencia.',
      if (isFavorite) 'Favorito.',
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = AppPalette.of(context);
    final styles = _Styles.of(theme.textTheme);
    final team = row.stats.team;

    final name = Text.rich(
      TextSpan(
        text: team.name,
        children: [
          if (isFavorite) ...[
            const TextSpan(text: ' '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(
                Icons.star,
                // Dentro del texto, Flutter ya lo escala con la letra.
                size: AppSizes.statusIcon,
                color: colors.primary,
              ),
            ),
          ],
        ],
      ),
      style: styles.name.copyWith(color: colors.onSurface),
    );

    final content = Row(
      children: [
        SizedBox(
          width: layout.position,
          child: Text(
            '${row.position}${row.isShared ? '*' : ''}',
            style: styles.position.copyWith(color: colors.onSurface),
            textAlign: TextAlign.center,
          ),
        ),
        if (layout.showBadge) ...[
          TeamBadge(
            name: team.name,
            url: team.badgeUrl,
            size: AppSizes.badgeTable,
          ),
          const SizedBox(width: _TableLayout.badgeGap),
        ],
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: layout.inline.isEmpty
                ? name
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      name,
                      Text(
                        [
                          for (final c in layout.inline)
                            '${c.short} ${c.valueOf(row)}',
                        ].join(' · '),
                        style: styles.inline.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(width: _TableLayout.nameGap),
        for (final c in layout.columns)
          _Cell(
            width: layout.widths[c]!,
            padding: c == _Column.points
                ? _TableLayout.pointsPadding
                : _TableLayout.cellPadding,
            child: Text(
              c.valueOf(row),
              maxLines: 1,
              style: (c == _Column.points ? styles.points : styles.stat)
                  .copyWith(color: colors.onSurface),
            ),
          ),
      ],
    );

    return Material(
      color: isFavorite
          ? Color.alphaBlend(
              colors.primaryContainer.withValues(alpha: _favoriteTint),
              palette.group,
            )
          : Colors.transparent,
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: _label,
        child: InkWell(
          onTap: () => context.go(AppRoutes.teamDetail(team.id)),
          child: Stack(
            children: [
              // La columna Pts, apenas sombreada, de arriba abajo.
              Positioned(
                top: 0,
                bottom: 0,
                right: _TableLayout.trailing,
                width: layout.widths[_Column.points],
                child: ColoredBox(
                  color: colors.surfaceContainerHigh.withValues(
                    alpha: _pointsShade,
                  ),
                ),
              ),
              if (isAdvancing)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: _TableLayout.marker,
                  child: ColoredBox(color: palette.success),
                ),
              Padding(
                padding: const EdgeInsets.only(
                  left: _TableLayout.marker,
                  right: _TableLayout.trailing,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSizes.tapTarget,
                  ),
                  child: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Leyenda del marcador de los grupos CONMEBOL: un solo nivel, con el
/// destino de cada puesto tal como lo dice el catálogo.
class QualificationLegend extends StatelessWidget {
  const QualificationLegend({super.key, required this.note});

  /// `GroupStage.qualificationNote`, literal.
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // En el color del texto principal (no el gris de las notas): explica
    // el marcador y es lo que más importa debajo de la tabla.
    final style = theme.textTheme.secondary.copyWith(color: colors.onSurface);
    final lineHeight = MediaQuery.textScalerOf(
      context,
    ).scale(style.fontSize! * (style.height ?? 1.4));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _TableLayout.marker,
          height: lineHeight,
          decoration: BoxDecoration(
            color: AppPalette.of(context).success,
            borderRadius: AppRadius.controlAll,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Sigue en competencia. ',
                  style: style.copyWith(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: '$note Posiciones actuales, no definitivas.'),
              ],
            ),
            style: style,
          ),
        ),
      ],
    );
  }
}
