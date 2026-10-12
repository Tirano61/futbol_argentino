import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../matches/domain/entities/team_ref.dart';
import '../bloc/favorites_bloc.dart';

/// Estrella para agregar o quitar un equipo de favoritos. Usa el
/// `FavoritesBloc` global y avisa con «Deshacer».
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.team});

  final TeamRef team;

  void _toggle(BuildContext context, {required bool wasFavorite}) {
    final bloc = context.read<FavoritesBloc>()..add(FavoriteToggled(team));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            wasFavorite
                ? '${team.name} se quitó de favoritos'
                : '${team.name} se agregó a favoritos',
          ),
          // Con acción, el aviso queda fijo por defecto: se cierra solo.
          persist: false,
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () => bloc.add(FavoriteToggled(team)),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = context.select<FavoritesBloc, bool>(
      (bloc) => bloc.state.contains(team.id),
    );
    final loading = context.select<FavoritesBloc, bool>(
      (bloc) => bloc.state is FavoritesLoading,
    );
    return IconButton(
      tooltip: isFavorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
      isSelected: isFavorite,
      icon: const Icon(Icons.star_outline),
      // Color del tema (primario): el ámbar no llega al contraste mínimo
      // sobre fondo claro.
      selectedIcon: const Icon(Icons.star),
      onPressed: loading
          ? null
          : () => _toggle(context, wasFavorite: isFavorite),
    );
  }
}
