import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Mide textos con la escala de texto del sistema, como los dibuja `Text`,
/// para que un componente elija su disposición con el ancho disponible
/// (Hito E): una columna que no parte una palabra, un marcador que no se
/// corta, el alto de una tarjeta con el texto agrandado.
final class TextMeasure {
  const TextMeasure(this.scaler);

  TextMeasure.of(BuildContext context)
    : scaler = MediaQuery.textScalerOf(context);

  final TextScaler scaler;

  /// Tamaño de [text] en [maxWidth] (en los renglones que haga falta, o
  /// hasta [maxLines]), redondeado hacia arriba.
  Size size(
    String text,
    TextStyle style, {
    double maxWidth = double.infinity,
    int? maxLines,
  }) => spanSize(
    TextSpan(text: text, style: style),
    maxWidth: maxWidth,
    maxLines: maxLines,
  );

  /// Como [size], para un texto con partes de distinto estilo.
  Size spanSize(
    InlineSpan span, {
    double maxWidth = double.infinity,
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);
    final size = Size(
      painter.width.ceilToDouble(),
      painter.height.ceilToDouble(),
    );
    painter.dispose();
    return size;
  }

  /// Ancho de [text] en un renglón.
  double width(String text, TextStyle style) => size(text, style).width;

  /// Alto de [text] en [maxWidth].
  double height(
    String text,
    TextStyle style,
    double maxWidth, {
    int? maxLines,
  }) => size(text, style, maxWidth: maxWidth, maxLines: maxLines).height;

  /// Ancho de la palabra más ancha de [texts]: lo mínimo para que ninguna
  /// se parta. Los espacios duros (`\u00A0`) unen palabras.
  double widestWord(Iterable<String> texts, TextStyle style) {
    var widest = 0.0;
    for (final text in texts) {
      for (final word in text.split(RegExp(r'[ \n\t]+'))) {
        if (word.isNotEmpty) widest = math.max(widest, width(word, style));
      }
    }
    return widest;
  }
}
