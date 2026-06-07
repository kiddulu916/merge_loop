import 'package:flutter_test/flutter_test.dart';
import 'package:merge_loop/domain/constants.dart';
import 'package:merge_loop/domain/engine/game_engine.dart';
import 'package:merge_loop/domain/engine/prng.dart';
import 'package:merge_loop/domain/models/board_state.dart';
import 'package:merge_loop/domain/models/game_status.dart';
import 'package:merge_loop/domain/models/tile.dart';

BoardState boardWith(Map<int, Tile> tiles, {int moves = kMovesPerDay}) {
  final cells = List<Tile?>.filled(kCellCount, null);
  tiles.forEach((i, t) => cells[i] = t);
  return BoardState(
    cells: cells,
    movesRemaining: moves,
    score: 0,
    nextTileId: 100,
    dropIndex: 0,
    adContinuesUsed: 0,
    movesMade: 0,
    status: GameStatus.playing,
  );
}

void main() {
  test('canMerge: same tier, distinct cells, below max tier', () {
    final b = boardWith({
      0: const Tile(id: 1, tier: 3),
      1: const Tile(id: 2, tier: 3),
      2: const Tile(id: 3, tier: 4),
      3: const Tile(id: 4, tier: kMaxTier),
      4: const Tile(id: 5, tier: kMaxTier),
    });
    expect(GameEngine.canMerge(b, 0, 1), isTrue);
    expect(GameEngine.canMerge(b, 0, 2), isFalse); // different tier
    expect(GameEngine.canMerge(b, 0, 0), isFalse); // same cell
    expect(GameEngine.canMerge(b, 3, 4), isFalse); // at max tier
  });

  test('merge: destination becomes tier+1, source empties, scores 2^newTier, spends a move', () {
    final b = boardWith({
      0: const Tile(id: 1, tier: 3),
      1: const Tile(id: 2, tier: 3),
    });
    final r = GameEngine.merge(b, fromIndex: 0, toIndex: 1);
    expect(r.cells[0], isNull);
    expect(r.cells[1]!.tier, 4);
    expect(r.cells[1]!.id, 2); // destination id preserved for animation
    expect(r.score, 1 << 4); // 16
    expect(r.movesRemaining, kMovesPerDay - 1);
    expect(r.movesMade, 1);
  });

  test('applyDrop: places dropped tier at a deterministic empty cell, advances dropIndex', () {
    final b = boardWith({0: const Tile(id: 1, tier: 1)});
    final landing = Prng(42);
    final r = GameEngine.applyDrop(b, 2, landing);
    expect(r.filledCount, 2);
    expect(r.dropIndex, 1);
    final dropped = r.cells.firstWhere((c) => c != null && c.id == 100);
    expect(dropped!.tier, 2);
  });

  test('hasMergeAvailable: false when all tiers unique => deadlock', () {
    final dead = boardWith({
      0: const Tile(id: 1, tier: 1),
      1: const Tile(id: 2, tier: 2),
      2: const Tile(id: 3, tier: 3),
    });
    expect(GameEngine.hasMergeAvailable(dead), isFalse);
    expect(GameEngine.evaluateStatus(dead).status, GameStatus.deadlocked);
  });

  test('evaluateStatus: zero moves => outOfMoves even if a merge exists', () {
    final b = boardWith({
      0: const Tile(id: 1, tier: 1),
      1: const Tile(id: 2, tier: 1),
    }, moves: 0);
    expect(GameEngine.evaluateStatus(b).status, GameStatus.outOfMoves);
  });
}
