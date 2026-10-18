import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/competition.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/competition_logo.dart';
import 'package:futbol_argentino/shared/presentation/theme/app_palette.dart';
import 'package:futbol_argentino/shared/presentation/theme/app_spacing.dart';

/// `strBadge` de cada asset (`docs/COMPETITION_LOGOS.md`): el archivo es la
/// variante `/small` de esa imagen, sin cambios. Si una grabación nueva trae
/// otro `strBadge`, la liga cambió su logo: bajar el nuevo y actualizar el
/// asset, esta lista y el documento.
const _sources = {
  4406:
      'https://r2.thesportsdb.com/images/media/league/badge/rk9xhx1768238251.png',
  4616:
      'https://r2.thesportsdb.com/images/media/league/badge/u5tbaw1762466392.png',
  4500:
      'https://r2.thesportsdb.com/images/media/league/badge/welbig1655924428.png',
  5215:
      'https://r2.thesportsdb.com/images/media/league/badge/5vbn1s1784161051.png',
  5524:
      'https://r2.thesportsdb.com/images/media/league/badge/6j0rlo1734111674.png',
  4501:
      'https://r2.thesportsdb.com/images/media/league/badge/9shr931685425181.png',
  4724:
      'https://r2.thesportsdb.com/images/media/league/badge/9yynq01685425243.png',
};

/// `strBadge` grabado de [id]: su `lookupleague` o, para la Nacional (sin
/// esa grabación), la búsqueda de ligas de Argentina.
String? _recordedBadge(int id) {
  final lookup = File('test/fixtures/api/lookupleague_$id.json');
  final (file, key) = lookup.existsSync()
      ? (lookup, 'leagues')
      : (
          File('test/fixtures/api/search_all_leagues_Argentina.json'),
          'countries',
        );
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final leagues = (json[key] as List).cast<Map<String, dynamic>>();
  return leagues.singleWhere((l) => l['idLeague'] == '$id')['strBadge']
      as String?;
}

/// Competición fuera del mapa de logos (una nueva en el catálogo).
const _withoutLogo = CompetitionDefinition(
  id: 1,
  name: 'Copa de prueba',
  shortName: 'Prueba',
  category: CompetitionCategory.nationalCup,
  format: CompetitionFormat.cup,
  rules: KnockoutCupRules(rounds: []),
);

/// Bundle donde ningún asset carga.
class _FailingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      Future.error(FlutterError('Sin el asset $key'));
}

Future<void> _pumpLogo(
  WidgetTester tester,
  CompetitionDefinition competition, {
  Brightness brightness = Brightness.light,
  AssetBundle? bundle,
}) async {
  Widget logo = Center(child: CompetitionLogo(competition: competition));
  if (bundle != null) logo = DefaultAssetBundle(bundle: bundle, child: logo);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        extensions: [AppPalette.forBrightness(brightness)],
      ),
      home: Scaffold(body: logo),
    ),
  );
}

void main() {
  group('assets', () {
    test('cada competición del catálogo tiene su logo', () {
      expect(CompetitionLogo.assets.keys.toSet(), {
        for (final c in CompetitionCatalog.all) c.id,
      });
      expect(_sources.keys.toSet(), CompetitionLogo.assets.keys.toSet());
    });

    for (final c in CompetitionCatalog.all) {
      test('${c.shortName}: PNG de 200 × 200 con transparencia, registrado '
          'en pubspec', () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        final path = CompetitionLogo.assets[c.id]!;
        expect(path, 'assets/competitions/${c.id}.png');
        // Se carga del bundle de la app: está declarado en pubspec.yaml.
        final bytes = (await rootBundle.load(path)).buffer.asUint8List();
        expect(bytes.sublist(1, 4), ascii.encode('PNG'));
        // Cabecera IHDR: ancho, alto, profundidad y tipo de color (6 = RGBA).
        final header = ByteData.sublistView(bytes, 16, 26);
        expect(header.getUint32(0), 200);
        expect(header.getUint32(4), 200);
        expect(header.getUint8(9), 6);
      });

      test('${c.shortName}: es el strBadge de su liga en las grabaciones', () {
        expect(_recordedBadge(c.id), _sources[c.id]);
      });
    }
  });

  group('CompetitionLogo', () {
    for (final brightness in Brightness.values) {
      testWidgets('recuadro de 36 y logo de 28 con BoxFit.contain, el mismo '
          'fondo oscuro en ${brightness.name}', (tester) async {
        await _pumpLogo(
          tester,
          CompetitionCatalog.copaLibertadores,
          brightness: brightness,
        );

        final tile = find.byType(CompetitionLogo);
        expect(tester.getSize(tile), const Size.square(36));
        final box = tester.widget<Container>(
          find.descendant(of: tile, matching: find.byType(Container)),
        );
        expect(
          (box.decoration! as BoxDecoration).color,
          AppPalette.light.logoBackdrop,
        );
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.fit, BoxFit.contain);
        expect(image.width, AppSizes.competitionLogo);
        expect(image.height, AppSizes.competitionLogo);
        expect(
          (image.image as AssetImage).assetName,
          'assets/competitions/4501.png',
        );
        expect(tester.getSize(find.byType(Image)), const Size.square(28));
      });
    }

    testWidgets('los siete logos se decodifican y se dibujan', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: [
                for (final c in CompetitionCatalog.all)
                  CompetitionLogo(competition: c),
              ],
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(Wrap));
      await tester.runAsync(() async {
        for (final path in CompetitionLogo.assets.values) {
          await precacheImage(AssetImage(path), context);
        }
      });
      await tester.pumpAndSettle();

      final painted = tester.widgetList<RawImage>(find.byType(RawImage));
      expect(painted, hasLength(7));
      expect(painted.every((r) => r.image != null), isTrue);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('es decorativo: sin nodo semántico propio', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpLogo(tester, CompetitionCatalog.primeraDivision);
      expect(tester.getSemantics(find.byType(CompetitionLogo)).label, isEmpty);
      expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
      handle.dispose();
    });

    testWidgets('sin logo en el mapa: el recuadro con el ícono de su '
        'categoría', (tester) async {
      await _pumpLogo(tester, _withoutLogo);
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.emoji_events_outlined), findsOne);
      expect(
        tester.getSize(find.byType(CompetitionLogo)),
        const Size.square(36),
      );
    });

    for (final (competition, icon) in [
      (CompetitionCatalog.primeraDivision, Icons.sports_soccer),
      (CompetitionCatalog.primeraC, Icons.sports_soccer),
      (CompetitionCatalog.copaArgentina, Icons.emoji_events_outlined),
      (CompetitionCatalog.copaSudamericana, Icons.emoji_events_outlined),
    ]) {
      testWidgets('si el asset no carga (${competition.shortName}): el ícono '
          'de la categoría', (tester) async {
        await _pumpLogo(tester, competition, bundle: _FailingBundle());
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();

        expect(find.byIcon(icon), findsOne);
        final drawn = tester.widget<Icon>(find.byIcon(icon));
        expect(drawn.color, AppPalette.light.onLogoBackdrop);
        expect(drawn.size, AppSizes.competitionLogo);
        expect(
          tester.getSize(find.byType(CompetitionLogo)),
          const Size.square(36),
        );
      });
    }
  });
}
