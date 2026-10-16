import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../shared/presentation/layout/breakpoints.dart';
import '../../domain/catalog/competition_catalog.dart';

/// Selector de competición en dos niveles: categoría → competición.
///
/// La categoría se deriva de la competición elegida (no es estado propio ni
/// va en la URL). En un teléfono es un botón que abre una hoja con las
/// competiciones agrupadas; desde 600 px, una fila de categorías y otra con
/// las competiciones de la categoría (oculta si tiene una sola); desde
/// 1200 px, las dos en la misma línea si entran. Si las categorías no entran
/// en una línea (la columna del fixture junto al panel de detalle, o texto
/// grande), vuelve al botón con la hoja: un solo renglón, sin chips
/// cortados ni áreas táctiles más chicas.
class CompetitionPicker extends StatefulWidget {
  const CompetitionPicker({
    super.key,
    required this.selectedId,
    required this.onSelected,
    this.catalog = CompetitionCatalog.all,
  });

  /// Competición mostrada; `null` mientras carga.
  final int? selectedId;

  /// Se llama una sola vez por elección, con la competición a cargar.
  final ValueChanged<int> onSelected;

  final List<CompetitionDefinition> catalog;

  @override
  State<CompetitionPicker> createState() => _CompetitionPickerState();
}

class _CompetitionPickerState extends State<CompetitionPicker> {
  /// Última competición vista de cada categoría, mientras la pantalla vive:
  /// tocar la categoría vuelve a ella.
  final _lastByCategory = <CompetitionCategory, int>{};

  /// Ancho que necesitan los chips de categoría en una línea, medido con
  /// [_measuredScaler] (cambia con la escala de texto).
  double? _categoriesWidth;
  TextScaler? _measuredScaler;

  @override
  void initState() {
    super.initState();
    _remember();
  }

  @override
  void didUpdateWidget(CompetitionPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _remember();
  }

  CompetitionDefinition? get _selected {
    for (final c in widget.catalog) {
      if (c.id == widget.selectedId) return c;
    }
    return null;
  }

  void _remember() {
    final selected = _selected;
    if (selected != null) _lastByCategory[selected.category] = selected.id;
  }

  void _select(int id) {
    if (id != widget.selectedId) widget.onSelected(id);
  }

  /// La medición llega durante el layout: el cambio se aplica en el cuadro
  /// siguiente (mientras tanto la fila no se pinta).
  void _onCategoriesMeasured(double width, TextScaler scaler) {
    final known = _categoriesWidth;
    if (scaler == _measuredScaler &&
        known != null &&
        (known - width).abs() < 0.5) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _categoriesWidth = width;
        _measuredScaler = scaler;
      });
    });
  }

  void _selectCategory(
    CompetitionCategory category,
    List<CompetitionDefinition> competitions,
  ) {
    final last = _lastByCategory[category];
    _select(
      competitions.any((c) => c.id == last) ? last! : competitions.first.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final byCategory = CompetitionCatalog.byCategory(widget.catalog);
    final selected = _selected;
    final sheetButton = _SheetButton(
      byCategory: byCategory,
      selected: selected,
      onSelected: _select,
    );
    if (Breakpoints.isCompact(context)) return sheetButton;

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final needed = scaler == _measuredScaler ? _categoriesWidth : null;
        if (needed != null && needed > constraints.maxWidth) {
          return sheetButton;
        }
        return _chips(
          context,
          byCategory,
          selected,
          (width) => _onCategoriesMeasured(width, scaler),
        );
      },
    );
  }

  Widget _chips(
    BuildContext context,
    Map<CompetitionCategory, List<CompetitionDefinition>> byCategory,
    CompetitionDefinition? selected,
    ValueChanged<double> onCategoriesMeasured,
  ) {
    final category = selected?.category;
    final competitions = byCategory[category] ?? const [];
    final categoryChips = _MeasuredRow(
      onMeasured: onCategoriesMeasured,
      children: [
        for (final MapEntry(key: c, value: list) in byCategory.entries)
          ChoiceChip(
            label: Text(c.label),
            showCheckmark: false,
            selected: c == category,
            onSelected: (_) {
              if (c != category) _selectCategory(c, list);
            },
          ),
      ],
    );
    final competitionChips = competitions.length < 2
        ? null
        : _ChipRow([
            for (final c in competitions)
              ChoiceChip(
                label: Text(c.shortName),
                tooltip: c.name,
                showCheckmark: false,
                selected: c.id == selected?.id,
                onSelected: (_) => _select(c.id),
              ),
          ]);

    if (Breakpoints.isExpanded(context)) {
      return Wrap(
        spacing: 24,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [categoryChips, ?competitionChips],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [categoryChips, ?competitionChips],
    );
  }
}

/// Fila de chips que informa el ancho que necesita para entrar en una línea.
/// Si no entra no se pinta: el selector pasa al botón en el cuadro
/// siguiente.
class _MeasuredRow extends SingleChildRenderObjectWidget {
  _MeasuredRow({required this.onMeasured, required List<Widget> children})
    : super(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: children,
        ),
      );

  final ValueChanged<double> onMeasured;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasuredRow(onMeasured);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasuredRow renderObject,
  ) {
    renderObject.onMeasured = onMeasured;
  }
}

class _RenderMeasuredRow extends RenderProxyBox {
  _RenderMeasuredRow(this.onMeasured);

  ValueChanged<double> onMeasured;
  var _fits = true;

  @override
  void performLayout() {
    final child = this.child!;
    final needed = child.getMaxIntrinsicWidth(double.infinity);
    onMeasured(needed);
    _fits = needed <= constraints.maxWidth;
    // Sin entrar, se dispone sin límite de ancho (no desborda) y no se pinta.
    child.layout(
      _fits ? constraints.loosen() : const BoxConstraints(),
      parentUsesSize: true,
    );
    size = constraints.constrain(child.size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_fits) super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      _fits && super.hitTest(result, position: position);
}

/// Chips en una fila con desplazamiento: con texto grande no entran, y
/// bajar de renglón le quita alto al fixture.
class _ChipRow extends StatelessWidget {
  const _ChipRow(this.chips);

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(spacing: 8, children: chips),
    );
  }
}

/// «Ascenso · Nacional ▾»: abre la hoja con todas las competiciones.
class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.byCategory,
    required this.selected,
    required this.onSelected,
  });

  final Map<CompetitionCategory, List<CompetitionDefinition>> byCategory;
  final CompetitionDefinition? selected;
  final ValueChanged<int> onSelected;

  /// Una categoría con una sola competición se nombra por la competición.
  String get _label {
    final c = selected;
    if (c == null) return 'Competición';
    if ((byCategory[c.category]?.length ?? 0) < 2) return c.name;
    return '${c.category.label} · ${c.shortName}';
  }

  Future<void> _open(BuildContext context) async {
    final id = await showModalBottomSheet<int>(
      context: context,
      // Sobre la barra de navegación (la de la sección la taparía).
      useRootNavigator: true,
      showDragHandle: true,
      useSafeArea: true,
      // Del alto de su contenido (no 9/16 de la pantalla: en horizontal
      // dejaba las copas fuera de la vista); si no entra, se desplaza.
      isScrollControlled: true,
      builder: (context) =>
          _CompetitionSheet(byCategory: byCategory, selectedId: selected?.id),
    );
    if (id != null) onSelected(id);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Tooltip(
        message: 'Elegir competición',
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () => _open(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(_label, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}

/// Competiciones agrupadas por categoría, con la actual marcada.
/// Se abre con la competición actual a la vista.
class _CompetitionSheet extends StatefulWidget {
  const _CompetitionSheet({required this.byCategory, required this.selectedId});

  final Map<CompetitionCategory, List<CompetitionDefinition>> byCategory;
  final int? selectedId;

  @override
  State<_CompetitionSheet> createState() => _CompetitionSheetState();
}

class _CompetitionSheetState extends State<_CompetitionSheet> {
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selected = _selectedKey.currentContext;
      if (selected != null && selected.mounted) {
        Scrollable.ensureVisible(selected, alignment: 0.5);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byCategory = widget.byCategory;
    final selectedId = widget.selectedId;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final MapEntry(key: category, value: competitions)
            in byCategory.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Semantics(
              header: true,
              child: Text(
                category.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          for (final c in competitions)
            ListTile(
              key: c.id == selectedId ? _selectedKey : null,
              title: Text(c.name),
              selected: c.id == selectedId,
              trailing: c.id == selectedId ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, c.id),
            ),
        ],
      ],
    );
  }
}
