import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../../shared/presentation/layout/breakpoints.dart';
import '../../shared/presentation/theme/app_spacing.dart';

/// Buscador de equipos de la barra superior. En escritorio (≥ 1200 px) es
/// un campo: al confirmar abre Equipos con lo escrito. En pantallas más
/// angostas no se muestra (el Inicio tiene su acceso arriba del contenido).
class TopBarTeamSearch extends StatefulWidget {
  const TopBarTeamSearch({super.key});

  static const _fieldWidth = 280.0;

  /// Ancho que ocupa en la barra (en escritorio; si no, nada).
  static const barWidth = _fieldWidth + 2 * AppSpacing.sm;

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
    if (!Breakpoints.isExpanded(context)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: SizedBox(
        width: TopBarTeamSearch._fieldWidth,
        child: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          decoration: const InputDecoration(
            hintText: 'Buscar equipo',
            prefixIcon: Icon(Icons.search),
            isDense: true,
            border: OutlineInputBorder(borderRadius: AppRadius.pillAll),
          ),
        ),
      ),
    );
  }
}
