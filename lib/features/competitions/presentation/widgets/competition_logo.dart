import 'package:flutter/material.dart';

import '../../../../shared/presentation/theme/app_palette.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../domain/catalog/competition_catalog.dart';

/// Logo de una competición en un recuadro oscuro neutro, igual en los dos
/// temas (los logos tienen partes blancas y no se pueden modificar).
///
/// Los logos son assets locales (`assets/competitions/<idLeague>.png`): el
/// `strBadge` de TheSportsDB tal cual, en su variante `/small`. Se ven sin
/// conexión y no piden nada a la red. Procedencia y condiciones de uso en
/// `docs/COMPETITION_LOGOS.md`.
///
/// Sin logo (una competición nueva en el catálogo) o si el asset no carga,
/// el mismo recuadro con un ícono de su categoría. Es decorativo: el nombre
/// va al lado y en la semántica.
class CompetitionLogo extends StatelessWidget {
  const CompetitionLogo({super.key, required this.competition});

  final CompetitionDefinition competition;

  /// Asset de cada competición por `idLeague`.
  static const assets = <int, String>{
    4406: 'assets/competitions/4406.png',
    4616: 'assets/competitions/4616.png',
    4500: 'assets/competitions/4500.png',
    5215: 'assets/competitions/5215.png',
    5524: 'assets/competitions/5524.png',
    4501: 'assets/competitions/4501.png',
    4724: 'assets/competitions/4724.png',
  };

  /// Ancho que ocupa en una fila, sin el espacio que lo separa del nombre.
  static const double size = AppSizes.competitionLogoTile;

  /// Carga los siete logos en la caché de imágenes. En Web los assets se
  /// piden al servidor de la app la primera vez que se muestran: cargados
  /// con el título, la hoja y el menú los muestran aunque después se corte
  /// la conexión. Si alguno falla, queda el ícono de reemplazo.
  static void precacheAll(BuildContext context) {
    for (final path in assets.values) {
      precacheImage(AssetImage(path), context, onError: (_, _) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final fallback = Icon(
      switch (competition.category) {
        CompetitionCategory.nationalCup ||
        CompetitionCategory.internationalCup => Icons.emoji_events_outlined,
        CompetitionCategory.firstDivision ||
        CompetitionCategory.promotion => Icons.sports_soccer,
      },
      size: AppSizes.competitionLogo,
      color: palette.onLogoBackdrop,
    );
    final asset = assets[competition.id];
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.logoBackdrop,
          borderRadius: AppRadius.controlAll,
        ),
        child: asset == null
            ? fallback
            : Image.asset(
                asset,
                width: AppSizes.competitionLogo,
                height: AppSizes.competitionLogo,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
      ),
    );
  }
}
