import 'package:flutter_test/flutter_test.dart';
import 'package:merge_loop/domain/constants.dart';
import 'package:merge_loop/domain/models/board_state.dart';
import 'package:merge_loop/domain/models/game_status.dart';
import 'package:merge_loop/domain/models/tile.dart';
import 'package:merge_loop/infrastructure/storage_service.dart';

BoardState sampleBoard() => BoardState(
      cells: List<Tile?>.filled(kCellCount, null),
      movesRemaining: 30,
      score: 0,
      nextTileId: 0,
      dropIndex: 0,
      adContinuesUsed: 0,
      movesMade: 0,
      status: GameStatus.playing,
    );

void main() {
  test('snapshot round-trips through the in-memory fake', () async {
    final s = InMemoryStorageService();
    await s.init();
    expect(s.loadSnapshot(), isNull);

    final snap = GameSnapshot(date: '2026-06-06', board: sampleBoard(), completed: false);
    await s.saveSnapshot(snap);

    final loaded = s.loadSnapshot()!;
    expect(loaded.date, '2026-06-06');
    expect(loaded.completed, isFalse);
    expect(loaded.board.toJson(), snap.board.toJson());
  });

  test('stats default to zero and persist', () async {
    final s = InMemoryStorageService();
    await s.init();
    expect(s.loadStats().bestScore, 0);

    await s.saveStats(const LifetimeStats(
        streak: 3, lastCompletedDate: '2026-06-06', bestScore: 999, bestTier: 7));
    expect(s.loadStats().streak, 3);
    expect(s.loadStats().bestScore, 999);
  });

  test('GameSnapshot and LifetimeStats round-trip through json', () {
    final snap = GameSnapshot(date: '2026-06-06', board: sampleBoard(), completed: true);
    expect(GameSnapshot.fromJson(snap.toJson()).toJson(), snap.toJson());

    const stats = LifetimeStats(streak: 2, lastCompletedDate: '2026-06-05', bestScore: 50, bestTier: 4);
    expect(LifetimeStats.fromJson(stats.toJson()).toJson(), stats.toJson());
  });
}
