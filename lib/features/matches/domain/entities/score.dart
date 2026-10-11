import 'package:equatable/equatable.dart';

final class Score extends Equatable {
  const Score({required this.home, required this.away});

  final int home;
  final int away;

  @override
  List<Object?> get props => [home, away];

  @override
  String toString() => '$home - $away';
}
