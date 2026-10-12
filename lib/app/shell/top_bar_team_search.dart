import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../../shared/presentation/layout/breakpoints.dart';

/// Buscador de equipos de la barra superior. En escritorio (≥ 1200 px) es
/// un campo: al confirmar abre Equipos con lo escrito. En pantallas más
/// angostas es un botón (con [showButtonWhenNarrow]) o nada.
class TopBarTeamSearch extends StatefulWidget {
  const TopBarTeamSearch({super.key, this.showButtonWhenNarrow = false});

  final bool showButtonWhenNarrow;

  @override
  State<TopBarTeamSearch> createState() => _TopBarTeamSearchState();
}

class _TopBarTeamSearchState extends State<TopBarTeamSearch> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String text) {
    final query = text.trim();
    _controller.clear();
    context.go(
      Uri(
        path: AppRoutes.teams,
        queryParameters: query.isEmpty ? null : {'q': query},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Breakpoints.isExpanded(context)) {
      return widget.showButtonWhenNarrow
          ? IconButton(
              tooltip: 'Buscar equipo',
              onPressed: () => context.go(AppRoutes.teams),
              icon: const Icon(Icons.search),
            )
          : const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: 280,
        child: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          decoration: const InputDecoration(
            hintText: 'Buscar equipo',
            prefixIcon: Icon(Icons.search),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
          ),
        ),
      ),
    );
  }
}
