import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/shared/presentation/widgets/team_badge.dart';

/// Textos dibujados dentro de [scope] (sin las iniciales de un escudo que
/// no cargó, que no son texto de la pantalla).
List<RenderParagraph> paragraphsIn(Finder scope) => [
  for (final element
      in find.descendant(of: scope, matching: find.byType(RichText)).evaluate())
    if (element.findAncestorWidgetOfExactType<TeamBadge>() == null)
      element.renderObject! as RenderParagraph,
];

/// Renglones que ocupa el rango [start]–[end] de [p] (el borde de arriba
/// de cada renglón: con el alto del renglón, no el de la letra, así un ícono
/// de otra fuente en el mismo renglón da lo mismo).
Set<int> linesOf(RenderParagraph p, int start, int end) => {
  for (final box in p.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: end),
    boxHeightStyle: ui.BoxHeightStyle.max,
  ))
    box.top.round(),
};

/// Ningún texto de [scope] se parte a mitad de palabra ni queda recortado:
/// cada palabra en un solo renglón. Solo un nombre de equipo con tope de
/// renglones (dos, o tres a los costados del marcador desde E7) puede
/// terminar en «…» (la regla de §5.1 de `docs/HITO_E.md`: el nombre
/// completo sigue en la semántica y en el detalle).
void expectWholeWords(WidgetTester tester, Finder scope) {
  final paragraphs = paragraphsIn(scope);
  expect(paragraphs, isNotEmpty);
  for (final p in paragraphs) {
    final text = p.text.toPlainText();
    if (p.didExceedMaxLines) {
      expect(p.maxLines, anyOf(2, 3), reason: 'Texto recortado: «$text»');
      continue;
    }
    for (final word in RegExp(r'[^\s￼]+').allMatches(text)) {
      expect(
        linesOf(p, word.start, word.end),
        hasLength(1),
        reason: '«${word[0]}» partida en «$text»',
      );
    }
  }
}
