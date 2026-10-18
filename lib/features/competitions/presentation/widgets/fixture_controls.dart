import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/scroll_row.dart';
import '../../domain/entities/phase.dart';
import '../../domain/entities/season.dart';
import '../../domain/entities/stage.dart';
import '../bloc/competition_fixture_bloc.dart';

/// Filtros de la vista Fixture (nivel 3 de la cabecera, Hito E §7): las
/// fases y el navegador de ronda («‹ Fecha 12 ›»), y el acceso a los
/// partidos sin fase determinada.
///
/// Las fases van en una fila que se desplaza (la elegida queda a la
/// vista). Desde 600 px, fases y ronda van en la misma línea si entran.
class FixtureSelectors extends StatelessWidget {
  const FixtureSelectors({super.key, required this.state});

  final CompetitionFixtureState state;

  /// Selector de competición (para los tests).
  static const competitionSelectorKey = ValueKey('competition-selector');

  /// Selector de temporada, en la barra o en los filtros (para los tests).
  static const seasonSelectorKey = ValueKey('season-selector');

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CompetitionFixtureBloc>();
    final phase = state.phase;
    final phases = state.phases.length > 1 ? state.phases : const <PhaseKey>[];
    final chips = [
      for (final p in phases)
        ChoiceChip(
          label: Text(p.label),
          selected: p == phase,
          onSelected: (_) {
            if (p != phase) bloc.add(FixturePhaseChanged(p));
          },
        ),
    ];
    final selectedPhase = phases.indexOf(phase ?? PhaseKey.undetermined);
    final chipRow = chips.isEmpty
        ? null
        : ScrollRow(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            visible: selectedPhase < 0 ? null : selectedPhase,
            children: chips,
          );
    final navigator = state.stage == null
        ? null
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: StageNavigator(state: state),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chipRow != null && navigator != null)
            FilterLine(
              leading: chipRow,
              trailing: navigator,
              trailingMinWidth: StageNavigator.minWidth,
            )
          else
            ?chipRow ?? navigator,
          if (state.undeterminedInRound > 0 && phase != PhaseKey.undetermined)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => bloc.add(
                    const FixturePhaseChanged(PhaseKey.undetermined),
                  ),
                  icon: const Icon(Icons.help_outline),
                  label: Text(
                    state.undeterminedInRound == 1
                        ? '1 partido de esta ronda sin fase determinada'
                        : '${state.undeterminedInRound} partidos de esta ronda '
                              'sin fase determinada',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Temporada elegida, como menú desplegable sin subrayado. [compact]: solo
/// el año («2026 ▾», en la barra de un teléfono); si no, «Temporada 2026».
class SeasonSelector extends StatelessWidget {
  const SeasonSelector({
    super.key,
    required this.season,
    required this.seasons,
    required this.onChanged,
    this.compact = false,
  });

  final Season season;
  final List<Season> seasons;
  final ValueChanged<Season> onChanged;
  final bool compact;

  static String labelFor(Season season, {required bool compact}) =>
      compact ? season.apiValue : 'Temporada ${season.apiValue}';

  static TextStyle _style(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.labelLarge!.copyWith(
      color: theme.colorScheme.onSurface,
    );
  }

  /// Ancho que ocupa en la barra (con la separación del título), con la
  /// fuente y la escala de texto reales.
  static double widthFor(
    BuildContext context,
    List<Season> seasons, {
    required bool compact,
  }) {
    var widest = 0.0;
    for (final s in seasons) {
      final painter = TextPainter(
        text: TextSpan(
          text: labelFor(s, compact: compact),
          style: _style(context),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest.ceilToDouble() + _arrowSize + 2 * AppSpacing.xs;
  }

  static const _arrowSize = 24.0;

  @override
  Widget build(BuildContext context) {
    // Un nodo propio: en la barra no se mezcla con el selector de
    // competición.
    return Semantics(
      container: true,
      child: Tooltip(
        message: 'Elegir temporada',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          // Su ancho natural, sin pasar el disponible (con texto grande se
          // recorta en lugar de desbordar).
          child: IntrinsicWidth(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Season>(
                key: FixtureSelectors.seasonSelectorKey,
                value: season,
                isExpanded: true,
                iconSize: _arrowSize,
                borderRadius: AppRadius.controlAll,
                style: _style(context),
                items: [
                  for (final s in seasons)
                    DropdownMenuItem(
                      value: s,
                      child: Text(
                        labelFor(s, compact: compact),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (s) {
                  if (s != null && s != season) onChanged(s);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fecha o ronda actual, con anterior y siguiente.
class StageNavigator extends StatelessWidget {
  const StageNavigator({super.key, required this.state});

  final CompetitionFixtureState state;

  /// Ancho mínimo para ir al lado de las fases (desde 600 px).
  static const minWidth = 320.0;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CompetitionFixtureBloc>();
    final stage = state.stage;
    if (stage == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Row(
      children: [
        IconButton(
          tooltip: 'Anterior',
          onPressed: state.hasPrevious
              ? () => bloc.add(const FixturePreviousStageRequested())
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Stage>(
              value: stage,
              isExpanded: true,
              alignment: Alignment.center,
              borderRadius: AppRadius.controlAll,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              items: [
                for (final s in state.stages)
                  DropdownMenuItem(
                    value: s,
                    alignment: Alignment.center,
                    child: Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (s) {
                if (s != null && s != stage) bloc.add(FixtureStageChanged(s));
              },
            ),
          ),
        ),
        IconButton(
          tooltip: 'Siguiente',
          onPressed: state.hasNext
              ? () => bloc.add(const FixtureNextStageRequested())
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// Dos controles del mismo nivel: en una línea si [leading] entra entero
/// junto a [trailing] (con al menos [trailingMinWidth]); si no, uno debajo
/// del otro. Mide el ancho real de [leading] (fuente y escala de texto) y
/// el disponible, no el de la pantalla (p. ej. junto al panel de detalle).
class FilterLine extends MultiChildRenderObjectWidget {
  FilterLine({
    super.key,
    required Widget leading,
    required Widget trailing,
    required this.trailingMinWidth,
  }) : super(children: [leading, trailing]);

  final double trailingMinWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFilterLine(trailingMinWidth);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderFilterLine).trailingMinWidth = trailingMinWidth;
  }
}

class _FilterLineParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderFilterLine extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FilterLineParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FilterLineParentData> {
  _RenderFilterLine(this._trailingMinWidth);

  double _trailingMinWidth;
  set trailingMinWidth(double value) {
    if (value == _trailingMinWidth) return;
    _trailingMinWidth = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FilterLineParentData) {
      child.parentData = _FilterLineParentData();
    }
  }

  RenderBox get _leading => firstChild!;
  RenderBox get _trailing => lastChild!;

  bool _oneLine(double maxWidth) =>
      _leading.getMaxIntrinsicWidth(double.infinity) + _trailingMinWidth <=
      maxWidth;

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final leading = _leading.parentData! as _FilterLineParentData;
    final trailing = _trailing.parentData! as _FilterLineParentData;
    if (width.isFinite && _oneLine(width)) {
      _trailing.layout(
        BoxConstraints.tightFor(width: _trailingMinWidth),
        parentUsesSize: true,
      );
      _leading.layout(
        BoxConstraints(maxWidth: width - _trailingMinWidth),
        parentUsesSize: true,
      );
      final height = _leading.size.height > _trailing.size.height
          ? _leading.size.height
          : _trailing.size.height;
      leading.offset = Offset(0, (height - _leading.size.height) / 2);
      trailing.offset = Offset(
        width - _trailingMinWidth,
        (height - _trailing.size.height) / 2,
      );
      size = constraints.constrain(Size(width, height));
      return;
    }
    final child = BoxConstraints(maxWidth: width);
    _leading.layout(child, parentUsesSize: true);
    _trailing.layout(child.tighten(width: width), parentUsesSize: true);
    leading.offset = Offset.zero;
    trailing.offset = Offset(0, _leading.size.height);
    size = constraints.constrain(
      Size(width, _leading.size.height + _trailing.size.height),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) {
    final a = _leading.getMaxIntrinsicHeight(width);
    final b = _trailing.getMaxIntrinsicHeight(width);
    if (width.isFinite && _oneLine(width)) return a > b ? a : b;
    return a + b;
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
