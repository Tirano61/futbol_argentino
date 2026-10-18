import 'package:flutter/material.dart';

import '../../../../shared/presentation/layout/breakpoints.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../domain/catalog/competition_catalog.dart';
import 'competition_logo.dart';

/// Selector de competición en el título de la barra superior (Hito E,
/// decisión E-D8): el nombre de la competición con una flecha. En un
/// teléfono abre la hoja con las competiciones agrupadas por categoría;
/// desde 600 px, un menú con las mismas secciones.
///
/// La categoría se deriva de la competición elegida (no es estado propio ni
/// va en la URL): solo agrupa la lista.
///
/// Cada competición lleva su logo (`CompetitionLogo`) en el título, la hoja
/// y el menú; en el título se oculta solo si ni el nombre corto entra con él
/// ([CompetitionTitleLayout]).
class CompetitionPicker extends StatelessWidget {
  const CompetitionPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.shortName = false,
    this.showLogo = true,
    this.catalog = CompetitionCatalog.all,
  });

  /// Competición mostrada.
  final CompetitionDefinition selected;

  /// Se llama una sola vez por elección, con la competición a cargar (nunca
  /// con la actual).
  final ValueChanged<int> onSelected;

  /// Mostrar el nombre corto («Libertadores»): el completo no entra.
  final bool shortName;

  /// Logo al lado del nombre en el título.
  final bool showLogo;

  final List<CompetitionDefinition> catalog;

  static const tooltip = 'Elegir competición';

  /// Escala de texto máxima del título de un `AppBar` (la de Material: el
  /// título no pasa de 1,34 aunque el texto esté más grande).
  static const titleMaxTextScale = 1.34;

  /// Ancho que necesita el selector con [name], con la fuente y la escala
  /// de texto reales: logo (si va), texto, relleno y flecha.
  static double widthFor(
    BuildContext context,
    String name, {
    bool logo = true,
  }) {
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
    return (logo ? CompetitionLogo.size + AppSpacing.sm : 0) +
        width +
        2 * AppSpacing.sm +
        _arrowSize;
  }

  static const _arrowSize = 24.0;

  static final _menuItemStyle = MenuItemButton.styleFrom(
    visualDensity: VisualDensity.standard,
  );

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
                  if (showLogo) ...[
                    CompetitionLogo(competition: selected),
                    const SizedBox(width: AppSpacing.sm),
                  ],
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
      return _PrecacheLogos(child: button(() => _openSheet(context)));
    }
    return _PrecacheLogos(
      child: MenuAnchor(
        alignmentOffset: const Offset(0, AppSpacing.xs),
        menuChildren: [
          for (final MapEntry(key: category, value: competitions)
              in CompetitionCatalog.byCategory(catalog).entries) ...[
            _MenuHeader(category.label),
            for (final c in competitions)
              MenuItemButton(
                // Filas de 48 también con el ratón (la densidad compacta del
                // escritorio las deja en 40 y los recuadros de los logos
                // quedan casi pegados).
                style: _menuItemStyle,
                leadingIcon: CompetitionLogo(competition: c),
                trailingIcon: c.id == selected.id
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
      ),
    );
  }
}

/// Carga los logos de todas las competiciones cuando aparece el selector
/// (`CompetitionLogo.precacheAll`), una sola vez.
class _PrecacheLogos extends StatefulWidget {
  const _PrecacheLogos({required this.child});

  final Widget child;

  @override
  State<_PrecacheLogos> createState() => _PrecacheLogosState();
}

class _PrecacheLogosState extends State<_PrecacheLogos> {
  var _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_done) return;
    _done = true;
    CompetitionLogo.precacheAll(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
/// el corto, si la temporada va al lado o baja a los filtros de la vista y
/// si va el logo. Se mide con la fuente y la escala de texto reales sobre el
/// ancho que le queda al título (no el de la pantalla: el riel, la búsqueda
/// y las acciones lo achican).
///
/// Orden, siempre con el logo: completo y temporada; corto y temporada;
/// completo solo; corto solo. Si ni el corto entra con el logo, el logo se
/// oculta antes de recortar el nombre con «…».
class CompetitionTitleLayout {
  const CompetitionTitleLayout({
    required this.shortName,
    required this.seasonInBar,
    this.showLogo = true,
  });

  final bool shortName;
  final bool seasonInBar;
  final bool showLogo;

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
    final seasonInBar = seasonWidth == null;
    if (short <= width) {
      return CompetitionTitleLayout(
        shortName: full > width,
        seasonInBar: seasonInBar,
      );
    }
    return CompetitionTitleLayout(
      shortName: true,
      seasonInBar: seasonInBar,
      showLogo: false,
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
              leading: CompetitionLogo(competition: c),
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
