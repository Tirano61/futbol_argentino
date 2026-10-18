import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Título de una sección de una lista («Hoy», «Próximos 7 días»…), con un
/// detalle opcional al lado («Domingo 11/10/2026»). Si no entra en el
/// renglón, el detalle baja.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.xl,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(
              title,
              style: theme.textTheme.sectionTitle.copyWith(
                color: colors.onSurface,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: theme.textTheme.secondary.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
