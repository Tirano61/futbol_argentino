import 'package:flutter/material.dart';
import 'package:futbol_argentino/app/shell/top_bar_team_search.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/shared/presentation/layout/breakpoints.dart';

/// Prototipo de E1 (decisión E-D8 del Hito E): la cabecera de Competiciones
/// en tres niveles, con el selector de competición en el título de la
/// AppBar. **Solo para evaluar** (vive en `test/visual/prototypes/`): no
/// carga datos, no navega por URL ni cambia nada de la app.
///
/// - Nivel 1: competición (título, abre la hoja < 600 o un menú ≥ 600) y
///   temporada; si no entran juntas, primero el nombre corto y después la
///   temporada baja al nivel 3.
/// - Nivel 2: pestañas de vista con subrayado (miden la etiqueta más ancha;
///   si no entran, se desplazan).
/// - Nivel 3: filtros de la vista (fase + ronda), en una fila si entran.
class CompetitionHeaderPrototype extends StatefulWidget {
  const CompetitionHeaderPrototype({
    super.key,
    this.initial = CompetitionCatalog.copaLibertadores,
    this.detailPanel = false,
  });

  final CompetitionDefinition initial;

  /// Simula el panel de detalle de 440 px del escritorio (≥ 1200).
  final bool detailPanel;

  static const selectorKey = ValueKey('competition-selector');
  static const headerKey = ValueKey('prototype-header');
  static const seasonKey = ValueKey('prototype-season');
  static const contentKey = ValueKey('prototype-content');

  @override
  State<CompetitionHeaderPrototype> createState() =>
      _CompetitionHeaderPrototypeState();
}

class _CompetitionHeaderPrototypeState
    extends State<CompetitionHeaderPrototype> {
  late CompetitionDefinition _competition = widget.initial;
  String _season = '2026';
  int _view = 0;
  int? _phase;

  static const _views = [
    (label: 'Fixture', icon: Icons.format_list_bulleted),
    (label: 'Tabla', icon: Icons.leaderboard_outlined),
    (label: 'Calendario', icon: Icons.calendar_month_outlined),
    (label: 'Llaves', icon: Icons.account_tree_outlined),
  ];

  /// Fases reales de la competición (catálogo); chips solo si hay más de
  /// una, como hoy.
  List<String> get _phases => [
    if (_competition.phases.length > 1)
      for (final p in _competition.phases) p.label,
  ];

  @override
  Widget build(BuildContext context) {
    final expanded = Breakpoints.isExpanded(context);
    final page = LayoutBuilder(
      builder: (context, constraints) {
        final layout = _TitleLayout.resolve(
          context,
          competition: _competition,
          season: _season,
          // Ancho de la barra: el de la columna de contenido.
          width: constraints.maxWidth,
          searchField: expanded,
        );
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 8,
            title: _CompetitionTitle(
              key: CompetitionHeaderPrototype.selectorKey,
              text: layout.useShortName
                  ? _competition.shortName
                  : _competition.name,
              onSelected: (c) => setState(() {
                _competition = c;
                _phase = null;
              }),
              selected: _competition,
            ),
            actions: [
              if (layout.seasonInBar)
                _SeasonButton(
                  key: CompetitionHeaderPrototype.seasonKey,
                  season: _season,
                  compact: Breakpoints.isCompact(context),
                  onChanged: (s) => setState(() => _season = s),
                ),
              const TopBarTeamSearch(),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: () {},
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: Column(
            key: CompetitionHeaderPrototype.headerKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ViewTabs(
                views: _views,
                selected: _view,
                onSelected: (i) => setState(() => _view = i),
              ),
              _LevelThree(
                season: layout.seasonInBar
                    ? null
                    : _SeasonButton(
                        key: CompetitionHeaderPrototype.seasonKey,
                        season: _season,
                        compact: false,
                        onChanged: (s) => setState(() => _season = s),
                      ),
                phases: _phases,
                phase: _phase ?? _phases.length - 1,
                onPhase: (i) => setState(() => _phase = i),
                round:
                    _competition.category ==
                            CompetitionCategory.firstDivision ||
                        _competition.category == CompetitionCategory.promotion
                    ? 'Fecha 12'
                    : 'Semifinales',
              ),
              const Expanded(
                child: _ContentPlaceholder(
                  key: CompetitionHeaderPrototype.contentKey,
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!(widget.detailPanel && expanded)) return page;
    return Row(
      children: [
        Expanded(child: page),
        const VerticalDivider(width: 1),
        const SizedBox(width: 440, child: _PanelPlaceholder()),
      ],
    );
  }
}

/// Qué entra en la barra: nombre completo o corto, y si la temporada va en
/// la barra o baja al nivel 3. Se mide con la escala de texto real.
class _TitleLayout {
  const _TitleLayout({required this.useShortName, required this.seasonInBar});

  final bool useShortName;
  final bool seasonInBar;

  static _TitleLayout resolve(
    BuildContext context, {
    required CompetitionDefinition competition,
    required String season,
    required double width,
    required bool searchField,
  }) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      return painter.width;
    }

    // Título: texto + flecha (24) + relleno del botón (8 + 8) + titleSpacing.
    double title(String name) =>
        measure(name, theme.textTheme.titleLarge) + 24 + 16 + 8;
    // Temporada compacta en la barra («2026 ▾»): texto + flecha + relleno.
    final seasonWidth = measure(season, theme.textTheme.labelLarge) + 24 + 24;
    // Acciones fijas: Actualizar (48) + buscador (296 en escritorio) + margen.
    final actions = 48.0 + (searchField ? 296 : 0) + 8;

    bool fits(String name, {required bool withSeason}) =>
        title(name) + actions + (withSeason ? seasonWidth : 0) <= width;

    if (fits(competition.name, withSeason: true)) {
      return const _TitleLayout(useShortName: false, seasonInBar: true);
    }
    if (fits(competition.shortName, withSeason: true)) {
      return const _TitleLayout(useShortName: true, seasonInBar: true);
    }
    return _TitleLayout(
      useShortName: !fits(competition.name, withSeason: false),
      seasonInBar: false,
    );
  }
}

/// El nombre de la competición como botón: abre la hoja (< 600) o un menú
/// agrupado por categoría (≥ 600). Mismo tooltip que el selector actual.
class _CompetitionTitle extends StatelessWidget {
  const _CompetitionTitle({
    super.key,
    required this.text,
    required this.selected,
    required this.onSelected,
  });

  final String text;
  final CompetitionDefinition selected;
  final ValueChanged<CompetitionDefinition> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget button(VoidCallback onPressed) => Tooltip(
      message: 'Elegir competición',
      child: Semantics(
        button: true,
        label: 'Competición: ${selected.name}. Elegir competición',
        excludeSemantics: true,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
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
      alignmentOffset: const Offset(0, 4),
      menuChildren: [
        for (final MapEntry(key: category, value: competitions)
            in CompetitionCatalog.byCategory().entries) ...[
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                category.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          for (final c in competitions)
            MenuItemButton(
              leadingIcon: Icon(
                Icons.check,
                color: c.id == selected.id ? null : const Color(0x00000000),
              ),
              onPressed: () => onSelected(c),
              child: Text(c.name),
            ),
        ],
      ],
      builder: (context, controller, _) => button(
        () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final chosen = await showModalBottomSheet<CompetitionDefinition>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            for (final MapEntry(key: category, value: competitions)
                in CompetitionCatalog.byCategory().entries) ...[
              Semantics(
                header: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                  trailing: c.id == selected.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.of(context).pop(c),
                ),
            ],
          ],
        );
      },
    );
    if (chosen != null) onSelected(chosen);
  }
}

class _SeasonButton extends StatelessWidget {
  const _SeasonButton({
    super.key,
    required this.season,
    required this.compact,
    required this.onChanged,
  });

  final String season;

  /// «2026» en la barra de un teléfono; «Temporada 2026» en el resto.
  final bool compact;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: season,
          borderRadius: BorderRadius.circular(8),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          items: [
            for (final s in ['2026', '2025'])
              DropdownMenuItem(
                value: s,
                child: Text(compact ? s : 'Temporada $s'),
              ),
          ],
          onChanged: (s) => onChanged(s!),
        ),
      ),
    );
  }
}

/// Pestañas de vista con subrayado. Cada pestaña mide su etiqueta (más 12
/// de cada lado) y, si sobra lugar, se reparte; íconos solo desde 600 px y
/// si entran. Si no entran, se desplazan: nunca se parte una etiqueta.
class _ViewTabs extends StatelessWidget {
  const _ViewTabs({
    required this.views,
    required this.selected,
    required this.onSelected,
  });

  final List<({String label, IconData icon})> views;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final style = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final labels = [
      for (final v in views)
        (TextPainter(
          text: TextSpan(text: v.label, style: style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout()).width.ceilToDouble(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = 12.0;
        const iconExtra = 18.0 + 8;
        final available = constraints.maxWidth - 16;
        double total(bool icons) => labels.fold(
          0.0,
          (sum, w) => sum + w + 2 * padding + (icons ? iconExtra : 0),
        );
        final withIcons =
            !Breakpoints.isCompact(context) && total(true) <= available;
        final needed = total(withIcons);
        final fits = needed <= available;
        // En un teléfono ocupan todo el ancho; desde 600, su ancho natural
        // alineadas a la izquierda.
        final extra = fits && Breakpoints.isCompact(context)
            ? (available - needed) / views.length
            : 0.0;

        final row = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, v) in views.indexed)
              _Tab(
                width:
                    labels[i] +
                    2 * padding +
                    (withIcons ? iconExtra : 0) +
                    extra,
                label: v.label,
                icon: withIcons ? v.icon : null,
                selected: i == selected,
                onTap: () => onSelected(i),
              ),
          ],
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: fits
                ? Align(alignment: Alignment.centerLeft, child: row)
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: row,
                  ),
          ),
        );
      },
    );
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
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 0,
                    height: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ),
                  ),
                // Alto mínimo del segmento (el Stack toma el de sus hijos
                // no posicionados).
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Filtros de la vista Fixture de una copa: temporada (si bajó de la
/// barra) y fases en una fila desplazable, y el navegador de ronda. Desde
/// 600 px, todo en una fila si entra.
class _LevelThree extends StatefulWidget {
  const _LevelThree({
    required this.season,
    required this.phases,
    required this.phase,
    required this.onPhase,
    required this.round,
  });

  final Widget? season;
  final List<String> phases;
  final int phase;
  final ValueChanged<int> onPhase;

  /// Texto del navegador de ronda (ilustrativo: el prototipo no carga
  /// rondas).
  final String round;

  @override
  State<_LevelThree> createState() => _LevelThreeState();
}

class _LevelThreeState extends State<_LevelThree> {
  // La fase elegida queda a la vista aunque la fila se desplace (hoy, a
  // 360 px, «Eliminatorias» queda cortada contra el borde).
  final _selectedChip = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chip = _selectedChip.currentContext;
      if (chip != null) Scrollable.ensureVisible(chip, alignment: 1);
    });
  }

  Widget? get season => widget.season;
  List<String> get phases => widget.phases;
  int get phase => widget.phase;
  ValueChanged<int> get onPhase => widget.onPhase;
  String get round => widget.round;

  @override
  Widget build(BuildContext context) {
    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        spacing: 8,
        children: [
          ?season,
          for (final (i, p) in phases.indexed)
            ChoiceChip(
              key: i == phase ? _selectedChip : null,
              label: Text(p),
              selected: i == phase,
              onSelected: (_) => onPhase(i),
            ),
        ],
      ),
    );
    final navigator = _RoundNavigator(round: round);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Una fila si entran los chips y un navegador de al menos 320.
        final scaler = MediaQuery.textScalerOf(context);
        final chipsWidth =
            phases
                .map(
                  (p) =>
                      (TextPainter(
                        text: TextSpan(
                          text: p,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        textDirection: TextDirection.ltr,
                        textScaler: scaler,
                      )..layout()).width +
                      32 +
                      8,
                )
                .fold(0.0, (a, b) => a + b) +
            (season == null ? 0 : 180) +
            32;
        final oneRow =
            !Breakpoints.isCompact(context) &&
            chipsWidth + 320 <= constraints.maxWidth;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: oneRow
              ? Row(
                  children: [
                    Flexible(child: chips),
                    const SizedBox(width: 8),
                    SizedBox(width: 320, child: navigator),
                    const SizedBox(width: 8),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    chips,
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: navigator,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _RoundNavigator extends StatelessWidget {
  const _RoundNavigator({required this.round});

  final String round;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: 'Anterior',
          onPressed: () {},
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: round,
              isExpanded: true,
              alignment: Alignment.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              items: [
                for (final s in {round})
                  DropdownMenuItem(
                    value: s,
                    alignment: Alignment.center,
                    child: Text(
                      s,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
        IconButton(
          tooltip: 'Siguiente',
          onPressed: () {},
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// El contenido de la vista no es parte del prototipo: un recuadro rotulado,
/// sin partidos inventados.
class _ContentPlaceholder extends StatelessWidget {
  const _ContentPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Contenido de la vista\n(fuera del prototipo)',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelPlaceholder extends StatelessWidget {
  const _PanelPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Text('Partido', style: theme.textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Cerrar detalle',
                onPressed: () {},
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Center(
            child: Text(
              'Panel de detalle\n(fuera del prototipo)',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}
