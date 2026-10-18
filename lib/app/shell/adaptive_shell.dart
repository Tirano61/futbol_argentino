import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/presentation/layout/breakpoints.dart';
import '../../shared/presentation/theme/app_spacing.dart';

/// Contenedor de las 4 secciones principales. Navegación inferior en
/// pantallas angostas y riel lateral en tablets y escritorio.
class AdaptiveShell extends StatefulWidget {
  const AdaptiveShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends State<AdaptiveShell> {
  static const _destinations = [
    (label: 'Inicio', icon: Icons.home_outlined, selected: Icons.home),
    (
      label: 'Competiciones',
      icon: Icons.emoji_events_outlined,
      selected: Icons.emoji_events,
    ),
    (label: 'Equipos', icon: Icons.shield_outlined, selected: Icons.shield),
    (label: 'Favoritos', icon: Icons.star_outline, selected: Icons.star),
  ];

  StatefulNavigationShell get _shell => widget.navigationShell;

  @override
  void didUpdateWidget(AdaptiveShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Un aviso («se agregó a favoritos») es de la sección donde se dio: no
    // sigue en la siguiente, se llegue por el menú o por un enlace.
    // Se quita al terminar el frame: durante el build no se puede.
    if (oldWidget.navigationShell.currentIndex != _shell.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
      });
    }
  }

  void _onSelected(int index) => _shell.goBranch(
    index,
    // Tocar la sección actual vuelve a su pantalla inicial.
    initialLocation: index == _shell.currentIndex,
  );

  /// Escala máxima de las etiquetas de la barra inferior para que ninguna
  /// se parta: la barra ya las limita a 1,3×, pero a 360 px «Competiciones»
  /// no entra en un renglón desde ~1,1× («Competicio / nes» al 200 %; E7).
  /// Nunca baja de 1× (la letra no se achica respecto del tamaño normal).
  static double _labelScaleThatFits(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium!;
    final widest = _destinations
        .map((d) {
          final painter = TextPainter(
            text: TextSpan(text: d.label, style: style),
            textDirection: Directionality.of(context),
            maxLines: 1,
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width;
        })
        .reduce(math.max);
    final perDestination =
        MediaQuery.sizeOf(context).width / _destinations.length;
    // Un margen chico: el ancho no crece exactamente en proporción.
    return math.max(1, (perDestination - AppSpacing.xs) / widest);
  }

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.isCompact(context)) {
      return Scaffold(
        body: _shell,
        bottomNavigationBar: MediaQuery.withClampedTextScaling(
          maxScaleFactor: _labelScaleThatFits(context),
          child: NavigationBar(
            selectedIndex: _shell.currentIndex,
            onDestinationSelected: _onSelected,
            destinations: [
              for (final d in _destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selected),
                  label: d.label,
                ),
            ],
          ),
        ),
      );
    }

    final extended = Breakpoints.isExpanded(context);
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: NavigationRail(
              extended: extended,
              labelType: extended ? null : NavigationRailLabelType.all,
              selectedIndex: _shell.currentIndex,
              onDestinationSelected: _onSelected,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: AppSizes.divider),
          Expanded(child: _shell),
        ],
      ),
    );
  }
}
