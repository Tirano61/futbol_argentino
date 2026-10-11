import '../../../matches/data/models/match_record.dart';
import '../../domain/entities/competition.dart';
import '../../domain/entities/season.dart';
import '../../domain/repositories/competition_repository.dart';

/// Forma en que se guardan competiciones y punteros en la base local.
abstract final class CompetitionRecord {
  static Map<String, Object?> toMap(Competition c) => {
    'id': c.id,
    'name': c.name,
    'shortName': c.shortName,
    'format': c.format.name,
    'badgeUrl': c.badgeUrl,
    'currentSeason': c.currentSeason?.apiValue,
  };

  static Competition fromMap(Map<String, Object?> map) => Competition(
    id: map['id']! as int,
    name: map['name']! as String,
    shortName: map['shortName']! as String,
    format: CompetitionFormat.values.byName(map['format']! as String),
    badgeUrl: map['badgeUrl'] as String?,
    currentSeason: Season.tryParse(map['currentSeason'] as String?),
  );

  static Map<String, Object?> pointersToMap(SchedulePointers p) => {
    'next': p.next == null ? null : MatchRecord.toMap(p.next!),
    'last': p.last == null ? null : MatchRecord.toMap(p.last!),
  };

  static SchedulePointers pointersFromMap(Map<String, Object?> map) {
    final next = map['next'] as Map<String, Object?>?;
    final last = map['last'] as Map<String, Object?>?;
    return SchedulePointers(
      next: next == null ? null : MatchRecord.fromMap(next),
      last: last == null ? null : MatchRecord.fromMap(last),
    );
  }
}
