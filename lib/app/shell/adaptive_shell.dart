import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Contenedor de las 4 secciones principales. Navegación inferior en
/// pantallas angostas y riel lateral en tablets y escritorio.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.navigationShell});

  /// Por debajo de este ancho se usa `NavigationBar`.
  static const compactMaxWidth = 600.0;

  /// Desde este ancho el riel muestra los textos al costado de los íconos.
  static const expandedMinWidth = 1200.0;

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

  final StatefulNavigationShell navigationShell;

  void _onSelected(int index) => navigationShell.goBranch(
    index,
    // Tocar la sección actual vuelve a su pantalla inicial.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width < compactMaxWidth) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
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

    final extended = width >= expandedMinWidth;
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: NavigationRail(
              extended: extended,
              labelType: extended ? null : NavigationRailLabelType.all,
              selectedIndex: navigationShell.currentIndex,
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
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
