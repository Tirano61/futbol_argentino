/// Texto comparable para búsquedas: minúsculas, sin acentos ni signos y con
/// un solo espacio entre palabras.
///
/// Apóstrofos y puntos se quitan sin separar («Newell's» → «newells»,
/// «L.P.» → «lp»); el resto de los signos separa palabras.
abstract final class TextNormalizer {
  static const _plain = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', //
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', //
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', //
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o', //
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', //
    'ñ': 'n', 'ç': 'c',
  };

  static const _removed = {"'", '’', '´', '`', '.'};

  static final _wordChar = RegExp('[a-z0-9]');

  static String normalize(String text) {
    final buffer = StringBuffer();
    var pendingSpace = false;
    for (final rune in text.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      if (_removed.contains(char)) continue;
      final plain = _plain[char] ?? char;
      if (_wordChar.hasMatch(plain)) {
        if (pendingSpace && buffer.isNotEmpty) buffer.write(' ');
        pendingSpace = false;
        buffer.write(plain);
      } else {
        pendingSpace = true;
      }
    }
    return buffer.toString();
  }

  /// Palabras normalizadas de [text].
  static List<String> words(String text) {
    final normalized = normalize(text);
    return normalized.isEmpty ? const [] : normalized.split(' ');
  }
}
