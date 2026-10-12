import '../../../../core/text/text_normalizer.dart';
import '../entities/team_summary.dart';

/// Búsqueda local de equipos por nombre, sin acentos ni mayúsculas: cada
/// palabra buscada tiene que aparecer en el nombre («river» → River Plate;
/// «gimnasia plata» → Gimnasia y Esgrima de La Plata).
final class TeamIndex {
  TeamIndex(Iterable<TeamSummary> teams)
    : _entries = [
        for (final t in teams)
          (team: t, name: TextNormalizer.normalize(t.team.name)),
      ];

  /// Letras mínimas para buscar en línea cuando no hay resultados locales.
  static const minOnlineQueryLength = 3;

  final List<({TeamSummary team, String name})> _entries;

  bool get isEmpty => _entries.isEmpty;
  int get length => _entries.length;

  /// Sin resultados locales, la consulta alcanza para buscar en línea.
  static bool allowsOnlineSearch(String query) =>
      TextNormalizer.normalize(query).replaceAll(' ', '').length >=
      minOnlineQueryLength;

  /// Coincidencias ordenadas: primero los nombres que empiezan con la
  /// búsqueda, después los que tienen una palabra que empieza con ella, y
  /// el resto; dentro de cada grupo, alfabético.
  List<TeamSummary> search(String query) {
    final words = TextNormalizer.words(query);
    if (words.isEmpty) return const [];
    final normalized = words.join(' ');

    int rank(String name) {
      if (name.startsWith(normalized)) return 0;
      if (name.split(' ').any((w) => w.startsWith(words.first))) return 1;
      return 2;
    }

    final found = [
      for (final e in _entries)
        if (words.every(e.name.contains)) (entry: e, rank: rank(e.name)),
    ];
    found.sort(
      (a, b) => a.rank != b.rank
          ? a.rank - b.rank
          : a.entry.name.compareTo(b.entry.name),
    );
    return [for (final f in found) f.entry.team];
  }
}
