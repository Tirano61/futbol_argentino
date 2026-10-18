import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../shared/presentation/theme/app_palette.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text.dart';
import '../../../competitions/domain/catalog/competition_catalog.dart';
import '../../../competitions/presentation/routing/fixture_route.dart';

/// Acceso al buscador de equipos en pantallas sin buscador en la barra
/// (< 1200 px): con forma de campo, abre Equipos.
class TeamSearchShortcut extends StatelessWidget {
  const TeamSearchShortcut({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const shape = StadiumBorder();
    return Semantics(
      button: true,
      child: Material(
        color: AppPalette.of(context).group,
        shape: shape.copyWith(side: BorderSide(color: colors.outlineVariant)),
        child: InkWell(
          customBorder: shape,
          onTap: () => context.go(AppRoutes.teams),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: colors.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Buscar equipo',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Accesos al fixture de cada competición, por categoría y en el orden del
/// catálogo.
///
/// Con [singleRow] (teléfonos), una sola fila que se desplaza de costado y
/// llega hasta los bordes de la pantalla ([gutter] es el margen lateral):
/// el chip cortado contra el borde indica que hay más. Si no, cada
/// categoría (etiqueta + chips) se acomoda junto a la anterior si entra, y
/// solo se parte en renglones si no entra sola.
class CompetitionShortcuts extends StatelessWidget {
  const CompetitionShortcuts({
    super.key,
    required this.singleRow,
    this.gutter = 0,
  });

  final bool singleRow;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final categories = CompetitionCatalog.byCategory().entries.toList();

    List<Widget> category(
      CompetitionCategory category,
      List<CompetitionDefinition> competitions,
    ) => [
      _CategoryLabel(category.label),
      for (final competition in competitions)
        ActionChip(
          label: Text(competition.name),
          tooltip: 'Fixture de ${competition.name}',
          onPressed: () =>
              context.go('${FixtureRoute.basePath}/${competition.id}'),
        ),
    ];

    if (!singleRow) {
      return Wrap(
        spacing: AppSpacing.xl,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final MapEntry(key: c, value: competitions) in categories)
            Wrap(
              spacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: category(c, competitions),
            ),
        ],
      );
    }

    return ScrollConfiguration(
      // En Web con mouse también se arrastra (por defecto, solo táctil).
      behavior: ScrollConfiguration.of(
        context,
      ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: gutter),
        child: Row(
          spacing: AppSpacing.sm,
          children: [
            for (final (i, MapEntry(key: c, value: competitions))
                in categories.indexed) ...[
              if (i > 0)
                const SizedBox(
                  height: AppSpacing.xl,
                  child: VerticalDivider(
                    width: AppSpacing.lg + AppSizes.divider,
                  ),
                ),
              ...category(c, competitions),
            ],
          ],
        ),
      ),
    );
  }
}

/// Nombre de la categoría («Ascenso»): se anuncia como encabezado.
class _CategoryLabel extends StatelessWidget {
  const _CategoryLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Text(
        text,
        style: theme.textTheme.secondary.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
