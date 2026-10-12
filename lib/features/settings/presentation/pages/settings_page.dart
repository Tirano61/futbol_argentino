import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/presentation/widgets/section_header.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../../domain/entities/stored_season.dart';
import '../../domain/usecases/stored_seasons.dart';
import '../bloc/stored_data_bloc.dart';

/// Ajustes. Por ahora, «Datos guardados»: temporadas guardadas en el
/// dispositivo y su limpieza manual.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final matches = context.read<MatchRepository>();
    return BlocProvider(
      create: (context) => StoredDataBloc(
        getStoredSeasons: GetStoredSeasons(matches),
        deleteStoredSeasons: DeleteStoredSeasons(matches),
        clock: context.read<Clock>(),
      )..add(const StoredDataStarted()),
      child: Scaffold(
        appBar: AppBar(
          // Por enlace directo no hay a dónde volver: se ofrece el inicio.
          leading: Navigator.canPop(context)
              ? null
              : IconButton(
                  tooltip: 'Ir al inicio',
                  onPressed: () => context.go(AppRoutes.home),
                  icon: const Icon(Icons.home_outlined),
                ),
          title: const Text('Ajustes'),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: const [_StoredDataSection()],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoredDataSection extends StatelessWidget {
  const _StoredDataSection();

  static Future<void> _confirmAndDelete(
    BuildContext context,
    List<StoredSeason> selection,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDeleteDialog(selection: selection),
    );
    if (confirmed != true || !context.mounted) return;

    final bloc = context.read<StoredDataBloc>()
      ..add(const StoredDataDeleteRequested());
    final after = await bloc.stream.firstWhere(
      (s) => s is! StoredDataLoaded || !s.isDeleting,
    );
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (after) {
          StoredDataLoaded(lastDeleted: final n?) =>
            n == 1 ? 'Se borró 1 partido.' : 'Se borraron $n partidos.',
          _ => 'No se pudieron borrar los datos guardados.',
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<StoredDataBloc, StoredDataState>(
      builder: (context, state) {
        final bloc = context.read<StoredDataBloc>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Datos guardados'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Los partidos se guardan en este dispositivo para ver la '
                'app sin conexión y no volver a pedirlos. Podés borrar '
                'temporadas anteriores: si las volvés a abrir, se descargan '
                'de nuevo. La temporada actual no se puede borrar y tus '
                'favoritos no se tocan.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 8),
            ...switch (state) {
              StoredDataLoading() => const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              StoredDataUnavailable() => [
                _Message(
                  text: 'No se pudieron leer los datos guardados.',
                  action: TextButton(
                    onPressed: () => bloc.add(const StoredDataStarted()),
                    child: const Text('Reintentar'),
                  ),
                ),
              ],
              StoredDataLoaded(seasons: final seasons) when seasons.isEmpty =>
                const [_Message(text: 'Todavía no hay partidos guardados.')],
              final StoredDataLoaded loaded => [
                ..._seasonTiles(context, loaded),
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.icon(
                    onPressed: loaded.selection.isEmpty || loaded.isDeleting
                        ? null
                        : () => _confirmAndDelete(context, loaded.selection),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(
                      loaded.selection.isEmpty
                          ? 'Borrar seleccionadas'
                          : 'Borrar seleccionadas (${loaded.selection.length})',
                    ),
                  ),
                ),
                if (loaded.isDeleting) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
              ],
            },
          ],
        );
      },
    );
  }

  static List<Widget> _seasonTiles(
    BuildContext context,
    StoredDataLoaded state,
  ) {
    final theme = Theme.of(context);
    final bloc = context.read<StoredDataBloc>();
    final tiles = <Widget>[];
    int? competition;
    for (final s in state.seasons) {
      if (s.competitionId != competition) {
        competition = s.competitionId;
        tiles.add(
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
              child: Text(
                s.competitionName,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
        );
      }
      final count = _matches(s.matchCount);
      tiles.add(
        s.canDelete
            ? CheckboxListTile(
                value: state.selected.contains(s.key),
                onChanged: state.isDeleting
                    ? null
                    : (_) => bloc.add(StoredDataToggled(s.key)),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('Temporada ${s.season}'),
                subtitle: Text(count),
              )
            : ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text('Temporada ${s.season}'),
                subtitle: Text('$count · temporada actual, no se puede borrar'),
              ),
      );
    }
    return tiles;
  }
}

String _matches(int n) => n == 1 ? '1 partido' : '$n partidos';

class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog({required this.selection});

  final List<StoredSeason> selection;

  @override
  Widget build(BuildContext context) {
    final total = selection.fold(0, (sum, s) => sum + s.matchCount);
    return AlertDialog(
      title: const Text('¿Borrar datos guardados?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in selection)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${s.competitionName} ${s.season}: '
                  '${_matches(s.matchCount)}',
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Se borran ${_matches(total)} de este dispositivo. Tus '
              'favoritos no se tocan. Si volvés a abrir esas temporadas, se '
              'descargan de nuevo.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Borrar'),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(text), ?action],
    ),
  );
}
