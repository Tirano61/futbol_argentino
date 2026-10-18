import 'package:flutter/material.dart';

import '../../../../shared/presentation/layout/breakpoints.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/scroll_row.dart';
import '../routing/fixture_route.dart';

/// «Fixture · Tabla · Calendario · Llaves» como pestañas con subrayado
/// (Hito E, E-D9), solo las que ofrece la competición.
///
/// Cada pestaña mide su etiqueta: en un teléfono ocupan todo el ancho
/// (se reparte lo que sobra) y desde 600 px van con su ancho natural, con
/// íconos si entran. Si no entran (texto grande) se desplazan, con el borde
/// esfumado del lado que sigue: nunca se parte una etiqueta.
class ViewTabs extends StatelessWidget {
  const ViewTabs({
    super.key,
    required this.view,
    required this.views,
    required this.onChanged,
  });

  final CompetitionsView view;
  final List<CompetitionsView> views;
  final ValueChanged<CompetitionsView> onChanged;

  static const _tabs = [
    (CompetitionsView.fixture, 'Fixture', Icons.format_list_bulleted),
    (CompetitionsView.table, 'Tabla', Icons.leaderboard_outlined),
    (CompetitionsView.calendar, 'Calendario', Icons.calendar_month_outlined),
    (CompetitionsView.bracket, 'Llaves', Icons.account_tree_outlined),
  ];

  /// Relleno a cada lado de la etiqueta.
  static const _padding = AppSpacing.md;

  /// Ícono (18) y su separación.
  static const _iconSize = 18.0;
  static const _iconExtra = _iconSize + AppSpacing.sm;

  static TextStyle labelStyle(BuildContext context) => Theme.of(
    context,
  ).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600);

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final tab in _tabs)
        if (views.contains(tab.$1)) tab,
    ];
    final style = labelStyle(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final labels = [
      for (final (_, label, _) in shown)
        _measure(label, style, scaler, direction),
    ];
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth;
          double total(bool icons) => labels.fold(
            0.0,
            (sum, w) => sum + w + 2 * _padding + (icons ? _iconExtra : 0),
          );
          final compact = Breakpoints.isCompact(context);
          final icons = !compact && total(true) <= available;
          final needed = total(icons);
          final fits = needed <= available;
          // En un teléfono ocupan todo el ancho; desde 600, su ancho natural.
          // Entero hacia abajo: la suma nunca pasa el ancho por redondeo.
          final extra = fits && compact
              ? ((available - needed) / shown.length).floorToDouble()
              : 0.0;
          final tabs = [
            for (final (i, (value, label, icon)) in shown.indexed)
              _Tab(
                width:
                    labels[i] + 2 * _padding + (icons ? _iconExtra : 0) + extra,
                label: label,
                icon: icons ? icon : null,
                selected: value == view,
                onTap: () {
                  if (value != view) onChanged(value);
                },
              ),
          ];
          if (fits) return Row(children: tabs);
          return ScrollRow(
            spacing: 0,
            visible: shown.indexWhere((t) => t.$1 == view),
            children: tabs,
          );
        },
      ),
    );
  }

  static double _measure(
    String text,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width.ceilToDouble();
    painter.dispose();
    return width;
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.width,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.primary : colors.onSurfaceVariant;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: ViewTabs._iconSize, color: color),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: ViewTabs.labelStyle(
                          context,
                        ).copyWith(color: color),
                      ),
                    ],
                  ),
                ),
                // La elegida no se marca solo con el color: lleva subrayado.
                if (selected)
                  PositionedDirectional(
                    start: ViewTabs._padding,
                    end: ViewTabs._padding,
                    bottom: 0,
                    height: AppSizes.tabIndicator,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppSizes.tabIndicator),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
