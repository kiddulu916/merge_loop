import 'difficulty.dart';

/// An immutable summary of one completed `(date, difficulty)` run, persisted to
/// the append-only history log so the stats calendar can render past days
/// Wordle-style.
///
/// Pure data — no plugin dependencies — so it stays testable. The [date] is the
/// canonical UTC `YYYY-MM-DD` string (same form the seeder/storage use
/// everywhere), kept as a string to avoid local/UTC drift.
class DayResult {
  /// Canonical UTC date string (`YYYY-MM-DD`) the run belongs to.
  final String date;

  /// Which tier the run was played on.
  final Difficulty difficulty;

  /// Final board score of the run.
  final int score;

  /// Highest tile tier reached during the run.
  final int highestTier;

  /// Whether the run was a "win" — i.e. it ran the full move budget out rather
  /// than dead-ending early (out of moves, not deadlocked).
  final bool win;

  const DayResult({
    required this.date,
    required this.difficulty,
    required this.score,
    required this.highestTier,
    required this.win,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'difficulty': difficulty.name,
        'score': score,
        'highestTier': highestTier,
        'win': win,
      };

  static DayResult fromJson(Map<String, dynamic> j) => DayResult(
        date: j['date'] as String,
        difficulty: Difficulty.values.byName(j['difficulty'] as String),
        score: j['score'] as int,
        highestTier: j['highestTier'] as int,
        win: j['win'] as bool,
      );

  @override
  bool operator ==(Object other) =>
      other is DayResult &&
      other.date == date &&
      other.difficulty == difficulty &&
      other.score == score &&
      other.highestTier == highestTier &&
      other.win == win;

  @override
  int get hashCode => Object.hash(date, difficulty, score, highestTier, win);

  @override
  String toString() =>
      'DayResult(date: $date, difficulty: ${difficulty.name}, '
      'score: $score, highestTier: $highestTier, win: $win)';
}
