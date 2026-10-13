import '../../../matches/domain/entities/match.dart';

/// Próximo y último partido de un equipo según TheSportsDB (`eventsnext` /
/// `eventslast`, 1 resultado cada uno con la clave gratuita), de cualquier
/// competición: única fuente de las que la app no sigue (D8).
final class TeamPointers {
  const TeamPointers({this.next, this.last});

  final Match? next;
  final Match? last;
}
