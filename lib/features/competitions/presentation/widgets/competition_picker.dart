import 'package:flutter/material.dart';

import '../../../../shared/presentation/layout/breakpoints.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../domain/catalog/competition_catalog.dart';

/// Selector de competición en el título de la barra superior (Hito E,
/// decisión E-D8): el nombre de la competición con una flecha. En un
/// teléfono abre la hoja con las competiciones agrupadas por categoría;
/// desde 600 px, un menú con las mismas secciones.
///
/// La categoría se deriva de la competición elegida (no es estado propio ni
/// va en la URL): solo agrupa la lista.
class CompetitionPicker extends StatelessWidget {
  const CompetitionPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.shortName = false,
    this.catalog = CompetitionCatalog.all,
  });

  /// Competición mostrada.
  final CompetitionDefinition selected;

  /// Se llama una sola vez por elección, con la competición a cargar (nunca
  /// con la actual).
  final ValueChanged<int> onSelected;

  /// Mostrar el nombre corto («Libertadores»): el completo no entra.
  final bool shortName;

  final List<CompetitionDefinition> catalog;

  static const tooltip = 'Elegir competición';

  /// Escala de texto máxima del título de un `AppBar` (la de Material: el
  /// título no pasa de 1,34 aunque el texto esté más grande).
  static const titleMaxTextScale = 1.34;

  /// Ancho que necesita el selector con [name], con la fuente y la escala
  /// de texto reales: texto, relleno y flecha.
  static double widthFor(BuildContext context, String name) {
    final scaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: titleMaxTextScale);
    final painter = TextPainter(
      text: TextSpan(text: name, style: _style(context)),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width.ceilToDouble();
    painter.dispose();
    return width + 2 * AppSpacing.sm + _arrowSize;
  }

  static const _arrowSize = 24.0;

  static TextStyle _style(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.titleLarge!.copyWith(
      color: theme.colorScheme.onSurface,
    );
  }

  void _select(int id) {
    if (id != selected.id) onSelected(id);
  }

  Future<void> _openSheet(BuildContext context) async {
    final id = await showModalBottomSheet<int>(
      context: context,
      // Sobre la barra de navegación (la de la sección la taparía).
      useRootNavigator: true,
      showDragHandle: true,
      useSafeArea: true,
      // Del alto de su contenido (no 9/16 de la pantalla: en horizontal
      // dejaba las copas fuera de la vista); si no entra, se desplaza.
      isScrollControlled: true,
      builder: (context) => _CompetitionSheet(
        byCategory: CompetitionCatalog.byCategory(catalog),
        selectedId: selected.id,
      ),
    );
    if (id != null) _select(id);
  }

  @override
  Widget build(BuildContext context) {
    // Un nodo propio (en la barra no se mezcla con la temporada), con el
    // nombre completo aunque se vea el corto.
    Widget button(VoidCallback onPressed) => Semantics(
      container: true,
      button: true,
      label: 'Competición: ${selected.name}',
      tooltip: tooltip,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.controlAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      shortName ? selected.shortName : selected.name,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: _style(context),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: _arrowSize),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (Breakpoints.isCompact(context)) {
      return button(() => _openSheet(context));
    }
    return MenuAnchor(
      alignmentOffset: const Offset(0, AppSpacing.xs),
      menuChildren: [
        for (final MapEntry(key: category, value: competitions)
            in CompetitionCatalog.byCategory(catalog).entries) ...[
          _MenuHeader(category.label),
          for (final c in competitions)
            MenuItemButton(
              leadingIcon: c.id == selected.id
                  ? const Icon(Icons.check)
                  : const SizedBox.square(dimension: _arrowSize),
              onPressed: () => _select(c.id),
              child: Semantics(
                selected: c.id == selected.id,
                child: Text(c.name),
              ),
            ),
        ],
      ],
      builder: (context, controller, _) => button(
        () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// Nombre de una categoría en el menú (encabezado, no se elige).
class _MenuHeader extends StatelessWidget {
  const _MenuHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Qué entra en la barra superior: el nombre completo de la competición o
/// el corto, y si la temporada va al lado o baja a los filtros de la vista.
/// Se mide con la fuente y la escala de texto reales sobre el ancho que le
/// queda al título (no el de la pantalla: el riel, la búsqueda y las
/// acciones lo achican).
///
/// Orden: completo y temporada; corto y temporada; completo solo; corto
/// solo (si ni así entra, el nombre corto se recorta con «…»).
class CompetitionTitleLayout {
  const CompetitionTitleLayout({
    required this.shortName,
    required this.seasonInBar,
  });

  final bool shortName;
  final bool seasonInBar;

  /// [seasonWidth]: ancho del selector de temporada en la barra; `null`
  /// mientras no hay temporada.
  static CompetitionTitleLayout resolve(
    BuildContext context, {
    required CompetitionDefinition competition,
    required double width,
    required double? seasonWidth,
  }) {
    final full = CompetitionPicker.widthFor(context, competition.name);
    final short = CompetitionPicker.widthFor(context, competition.shortName);
    final season = seasonWidth ?? 0;
    if (full + season <= width) {
      return const CompetitionTitleLayout(shortName: false, seasonInBar: true);
    }
    if (short + season <= width) {
      return const CompetitionTitleLayout(shortName: true, seasonInBar: true);
    }
    return CompetitionTitleLayout(
      shortName: full > width,
      seasonInBar: seasonWidth == null,
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
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        for (final MapEntry(key: category, value: competitions)
            in byCategory.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
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
