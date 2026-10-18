import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/platform/external_actions.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/presentation/layout/breakpoints.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/content_app_bar.dart';
import '../../../../shared/presentation/widgets/info_banner.dart';
import '../../../../shared/presentation/widgets/match_group.dart';
import '../../../../shared/presentation/widgets/section_header.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/stored_season.dart';
import '../../domain/usecases/stored_seasons.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/stored_data_bloc.dart';

/// Ajustes: el tema, los «Datos guardados» (temporadas guardadas en el
/// dispositivo y su limpieza manual) y la fuente de los datos. Cada sección
/// va en una superficie de grupo con divisores, como el resto de la app
/// (Fase E7).
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
        appBar: ContentAppBar(
          maxWidth: Breakpoints.maxNarrowWidth,
          bar: AppBar(
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
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Breakpoints.maxNarrowWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: const [
                _ThemeSection(),
                _StoredDataSection(),
                _SourceSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tema de la app; lo lee y lo guarda el `SettingsBloc` global.
class _ThemeSection extends StatelessWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context) {
    final theme = context.select<SettingsBloc, ThemePreference>(
      (bloc) => bloc.state.settings.theme,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Tema'),
        RadioGroup<ThemePreference>(
          groupValue: theme,
          onChanged: (value) {
            if (value == null) return;
            context.read<SettingsBloc>().add(ThemePreferenceChanged(value));
          },
          child: const MatchGroup(
            children: [
              RadioListTile(
                value: ThemePreference.system,
                title: Text('Según el sistema'),
                subtitle: Text('Claro u oscuro, como el dispositivo'),
              ),
              RadioListTile(value: ThemePreference.light, title: Text('Claro')),
              RadioListTile(value: ThemePreference.dark, title: Text('Oscuro')),
            ],
          ),
        ),
      ],
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
    final secondary = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return BlocBuilder<StoredDataBloc, StoredDataState>(
      builder: (context, state) {
        final bloc = context.read<StoredDataBloc>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Datos guardados'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text(
                'Los partidos se guardan en este dispositivo para ver la '
                'app sin conexión y no volver a pedirlos. Podés borrar '
                'temporadas anteriores: si las volvés a abrir, se descargan '
                'de nuevo. La temporada actual no se puede borrar y tus '
                'favoritos no se tocan.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...switch (state) {
              StoredDataLoading() => [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Semantics(
                      label: 'Cargando datos guardados',
                      child: const CircularProgressIndicator(),
                    ),
                  ),
                ),
              ],
              StoredDataUnavailable() => [
                InfoBanner(
                  tone: InfoTone.error,
                  text: 'No se pudieron leer los datos guardados.',
                  action: TextButton(
                    onPressed: () => bloc.add(const StoredDataStarted()),
                    child: const Text('Reintentar'),
                  ),
                ),
              ],
              StoredDataLoaded(seasons: final seasons) when seasons.isEmpty => [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text(
                    'Todavía no hay partidos guardados.',
                    style: secondary,
                  ),
                ),
              ],
              final StoredDataLoaded loaded => [
                ..._seasonGroups(context, loaded),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.tonalIcon(
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
                  const SizedBox(height: AppSpacing.sm),
                  Semantics(
                    label: 'Borrando datos guardados',
                    child: const LinearProgressIndicator(),
                  ),
                ],
              ],
            },
          ],
        );
      },
    );
  }

  /// Un grupo por competición: su nombre como encabezado y una fila por
  /// temporada (con casilla si se puede borrar).
  static List<Widget> _seasonGroups(
    BuildContext context,
    StoredDataLoaded state,
  ) {
    final bloc = context.read<StoredDataBloc>();
    final byCompetition = <int, List<StoredSeason>>{};
    for (final s in state.seasons) {
      byCompetition.putIfAbsent(s.competitionId, () => []).add(s);
    }
    Widget tile(StoredSeason s) {
      final count = _matches(s.matchCount);
      return s.canDelete
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
            );
    }

    return [
      for (final (i, seasons) in byCompetition.values.indexed)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.md),
          child: MatchGroup(
            header: MatchGroupHeader(title: seasons.first.competitionName),
            children: [for (final s in seasons) tile(s)],
          ),
        ),
    ];
  }
}

/// De dónde salen los datos y las imágenes (condiciones de TheSportsDB:
/// mencionar la fuente con un enlace; `docs/COMPETITION_LOGOS.md`).
class _SourceSection extends StatelessWidget {
  const _SourceSection();

  static final site = Uri.parse('https://www.thesportsdb.com/');

  Future<void> _open(BuildContext context) async {
    final opened = await context.read<ExternalActions>().openLink(site);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el enlace: www.thesportsdb.com'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Fuente'),
        MatchGroup(
          children: [
            ListTile(
              title: const Text('Datos e imágenes: TheSportsDB'),
              subtitle: const Text('www.thesportsdb.com'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _open(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            'Los logos de las competiciones y los escudos de los equipos '
            'pertenecen a sus dueños.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
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
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  '• ${s.competitionName} ${s.season}: '
                  '${_matches(s.matchCount)}',
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
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
