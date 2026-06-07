import '../domain/models/board_state.dart';

/// A persisted in-progress (or finished) day.
class GameSnapshot {
  final String date; // YYYY-MM-DD this snapshot belongs to
  final BoardState board;
  final bool completed; // true once the day is locked

  const GameSnapshot({
    required this.date,
    required this.board,
    required this.completed,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'board': board.toJson(),
        'completed': completed,
      };

  static GameSnapshot fromJson(Map<String, dynamic> j) => GameSnapshot(
        date: j['date'] as String,
        board: BoardState.fromJson(Map<String, dynamic>.from(j['board'] as Map)),
        completed: j['completed'] as bool,
      );
}

/// Lifetime, cross-day stats for the offline result screen.
class LifetimeStats {
  final int streak;
  final String? lastCompletedDate;
  final int bestScore;
  final int bestTier;

  const LifetimeStats({
    required this.streak,
    required this.lastCompletedDate,
    required this.bestScore,
    required this.bestTier,
  });

  static const empty = LifetimeStats(
      streak: 0, lastCompletedDate: null, bestScore: 0, bestTier: 0);

  LifetimeStats copyWith({
    int? streak,
    String? lastCompletedDate,
    int? bestScore,
    int? bestTier,
  }) =>
      LifetimeStats(
        streak: streak ?? this.streak,
        lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
        bestScore: bestScore ?? this.bestScore,
        bestTier: bestTier ?? this.bestTier,
      );

  Map<String, dynamic> toJson() => {
        'streak': streak,
        'lastCompletedDate': lastCompletedDate,
        'bestScore': bestScore,
        'bestTier': bestTier,
      };

  static LifetimeStats fromJson(Map<String, dynamic> j) => LifetimeStats(
        streak: j['streak'] as int,
        lastCompletedDate: j['lastCompletedDate'] as String?,
        bestScore: j['bestScore'] as int,
        bestTier: j['bestTier'] as int,
      );
}

/// Local persistence boundary. The Hive implementation lives in
/// hive_storage_service.dart; this in-memory fake is used by tests.
abstract class StorageService {
  Future<void> init();
  GameSnapshot? loadSnapshot();
  Future<void> saveSnapshot(GameSnapshot snapshot);
  LifetimeStats loadStats();
  Future<void> saveStats(LifetimeStats stats);
}

class InMemoryStorageService implements StorageService {
  GameSnapshot? _snapshot;
  LifetimeStats _stats = LifetimeStats.empty;

  @override
  Future<void> init() async {}

  @override
  GameSnapshot? loadSnapshot() => _snapshot;

  @override
  Future<void> saveSnapshot(GameSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  LifetimeStats loadStats() => _stats;

  @override
  Future<void> saveStats(LifetimeStats stats) async {
    _stats = stats;
  }
}
