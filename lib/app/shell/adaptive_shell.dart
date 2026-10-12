import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/presentation/layout/breakpoints.dart';

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

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.isCompact(context)) {
      return Scaffold(
        body: _shell,
        bottomNavigationBar: NavigationBar(
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
          const VerticalDivider(width: 1),
          Expanded(child: _shell),
        ],
      ),
    );
  }
}
