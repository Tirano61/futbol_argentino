import 'package:flutter/material.dart';

import '../../../../shared/presentation/layout/breakpoints.dart';
import '../../domain/catalog/competition_catalog.dart';

/// Selector de competición en dos niveles: categoría → competición.
///
/// La categoría se deriva de la competición elegida (no es estado propio ni
/// va en la URL). En un teléfono es un botón que abre una hoja con las
/// competiciones agrupadas; desde 600 px, una fila de categorías y otra con
/// las competiciones de la categoría (oculta si tiene una sola); desde
/// 1200 px, las dos en la misma línea si entran.
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
    if (Breakpoints.isCompact(context)) {
      return _SheetButton(
        byCategory: byCategory,
        selected: selected,
        onSelected: _select,
      );
    }

    final category = selected?.category;
    final competitions = byCategory[category] ?? const [];
    final categoryChips = _ChipRow([
      for (final MapEntry(key: c, value: list) in byCategory.entries)
        ChoiceChip(
          label: Text(c.label),
          showCheckmark: false,
          selected: c == category,
          onSelected: (_) {
            if (c != category) _selectCategory(c, list);
          },
        ),
    ]);
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
class _CompetitionSheet extends StatelessWidget {
  const _CompetitionSheet({required this.byCategory, required this.selectedId});

  final Map<CompetitionCategory, List<CompetitionDefinition>> byCategory;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
