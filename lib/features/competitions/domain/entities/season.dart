import 'package:equatable/equatable.dart';

/// Temporada con formato `YYYY` (el que usan las ligas argentinas desde
/// 2022 en TheSportsDB).
final class Season extends Equatable implements Comparable<Season> {
  const Season(this.year);

  static Season? tryParse(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\d{4}$').hasMatch(text)) return null;
    return Season(int.parse(text));
  }

  final int year;

  /// Valor del parámetro `s` de la API.
  String get apiValue => '$year';

  Season get previous => Season(year - 1);

  @override
  int compareTo(Season other) => year - other.year;

  @override
  List<Object?> get props => [year];

  @override
  String toString() => apiValue;
}
