import '../entities/kickoff.dart';
import '../entities/match.dart';
import '../entities/match_status.dart';
import '../entities/team_ref.dart';

/// Calidad de una respuesta de `eventsround` comparada con lo guardado.
enum ResponseQuality {
  /// Se aplican altas, cambios y bajas.
  complete,

  /// Trae menos partidos que antes o que lo esperado: altas y cambios, sin
  /// bajas. Se reintenta pronto.
  partial,

  /// `events: null` habiendo datos guardados: no se toca nada.
  suspectEmpty,

  /// Ronda sin partidos.
  empty,
}

final class RoundMergeResult {
  const RoundMergeResult({
    required this.quality,
    required this.toSave,
    required this.toVerify,
  });

  final ResponseQuality quality;

  /// Partidos a guardar (nuevos, actualizados o marcados `orphaned`).
  final List<Match> toSave;

  /// `idEvent` a verificar con `lookupevent` (baja prioridad).
  final Set<int> toVerify;
}

/// Política de merge de una ronda (§5.3 de DATA_STRATEGY): no pierde datos
/// válidos ni conserva indefinidamente asociaciones obsoletas.
abstract final class RoundMergePolicy {
  /// Un partido que falta en respuestas parciales y no se vio en este
  /// tiempo se verifica con `lookupevent`.
  static const staleAfter = Duration(hours: 24);

  /// Une la respuesta de la ronda [apiRound] con lo guardado.
  ///
  /// [stored]: partidos guardados con ese `apiRound` **más** las versiones
  /// guardadas de los partidos de [incoming] (aunque estén en otra ronda).
  /// [incoming]: la respuesta ya convertida; cada partido trae su propio
  /// `intRound`, que manda sobre la ronda consultada.
  static RoundMergeResult merge({
    required int apiRound,
    required List<Match> stored,
    required List<Match> incoming,
    required int? expectedMinimum,
    required DateTime now,
  }) {
    final storedById = {for (final m in stored) m.id: m};
    final members = [
      for (final m in stored)
        if (m.apiRound == apiRound && m.isVisible) m,
    ];

    if (incoming.isEmpty) {
      return RoundMergeResult(
        quality: members.isEmpty
            ? ResponseQuality.empty
            : ResponseQuality.suspectEmpty,
        toSave: const [],
        toVerify: const {},
      );
    }

    final quality =
        incoming.length < members.length ||
            (expectedMinimum != null && incoming.length < expectedMinimum)
        ? ResponseQuality.partial
        : ResponseQuality.complete;

    final incomingIds = {for (final m in incoming) m.id};
    final toSave = [
      for (final m in incoming) mergeFields(storedById[m.id], m, now),
    ];
    final toVerify = <int>{};

    for (final missing in members.where((m) => !incomingIds.contains(m.id))) {
      if (quality == ResponseQuality.complete) {
        toSave.add(missing.copyWith(membership: MatchMembership.orphaned));
        toVerify.add(missing.id);
      } else if (now.difference(missing.lastSeenAt) > staleAfter) {
        toVerify.add(missing.id);
      }
    }

    return RoundMergeResult(
      quality: quality,
      toSave: toSave,
      toVerify: toVerify,
    );
  }

  /// Resultado de verificar con `lookupevent` un partido guardado.
  /// [found] es `null` si la API ya no lo tiene.
  static Match applyVerification(Match stored, Match? found, DateTime now) {
    if (found == null) {
      return stored.copyWith(membership: MatchMembership.removed);
    }
    final merged = mergeFields(stored, found, now);
    final sameRound = found.apiRound == stored.apiRound;
    if (sameRound && stored.membership == MatchMembership.orphaned) {
      // Existe, pero su ronda ya no lo lista: visible con aviso.
      return merged.copyWith(membership: MatchMembership.unconfirmed);
    }
    return merged;
  }

  /// Combina la versión guardada con la recibida, campo por campo.
  static Match mergeFields(Match? existing, Match incoming, DateTime now) {
    if (existing == null) {
      return incoming.copyWith(
        membership: MatchMembership.active,
        lastSeenAt: now,
      );
    }

    final kickoff = _mergeKickoff(existing.kickoff, incoming.kickoff);
    final rescheduled =
        existing.kickoff.isConfirmed &&
        kickoff.utc != null &&
        kickoff.utc != existing.kickoff.utc;

    return Match(
      id: incoming.id,
      competitionId: incoming.competitionId,
      competitionName: incoming.competitionName,
      season: incoming.season,
      apiRound: incoming.apiRound,
      home: _mergeTeam(existing.home, incoming.home),
      away: _mergeTeam(existing.away, incoming.away),
      kickoff: kickoff,
      status: incoming.status,
      score: incoming.score ?? (_keepsScore(incoming) ? existing.score : null),
      penalties:
          incoming.penalties ??
          (incoming.status.decidedBy == MatchDecision.penalties
              ? existing.penalties
              : null),
      venue: incoming.venue ?? existing.venue,
      thumbUrl: incoming.thumbUrl ?? existing.thumbUrl,
      videoUrl: incoming.videoUrl ?? existing.videoUrl,
      previousKickoffUtc: rescheduled
          ? existing.kickoff.utc
          : existing.previousKickoffUtc,
      previousApiRound: incoming.apiRound != existing.apiRound
          ? existing.apiRound
          : existing.previousApiRound,
      membership: MatchMembership.active,
      lastSeenAt: now,
    );
  }

  /// Un horario confirmado no se degrada a tentativo si es el mismo
  /// instante (p. ej. llega sin `strTimeLocal`).
  static Kickoff _mergeKickoff(Kickoff existing, Kickoff incoming) =>
      existing.isConfirmed &&
          incoming.certainty == KickoffCertainty.tentative &&
          incoming.utc == existing.utc
      ? existing
      : incoming;

  /// Sin resultado en la respuesta: se conserva el guardado salvo que el
  /// partido haya vuelto a no jugado (postergado, cancelado).
  static bool _keepsScore(Match incoming) => switch (incoming.status.kind) {
    MatchStatusKind.scheduled ||
    MatchStatusKind.postponed ||
    MatchStatusKind.cancelled => false,
    _ => true,
  };

  static TeamRef _mergeTeam(TeamRef existing, TeamRef incoming) => TeamRef(
    id: incoming.id,
    name: looksGarbled(incoming.name) && !looksGarbled(existing.name)
        ? existing.name
        : incoming.name,
    badgeUrl: incoming.badgeUrl ?? existing.badgeUrl,
  );

  static final _garbled = RegExp('�|Ã[\u0080-¿]|Â');

  /// Texto con caracteres de reemplazo o UTF-8 mal decodificado.
  static bool looksGarbled(String text) => _garbled.hasMatch(text);
}
