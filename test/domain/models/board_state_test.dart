import 'package:flutter_test/flutter_test.dart';
import 'package:merge_loop/domain/constants.dart';
import 'package:merge_loop/domain/models/board_state.dart';
import 'package:merge_loop/domain/models/game_status.dart';
import 'package:merge_loop/domain/models/tile.dart';

BoardState boardWith(Map<int, Tile> tiles) {
  final cells = List<Tile?>.filled(kCellCount, null);
  tiles.forEach((i, t) => cells[i] = t);
  return BoardState(
    cells: cells,
    movesRemaining: kMovesPerDay,
    score: 0,
    nextTileId: 100,
    dropIndex: 0,
    adContinuesUsed: 0,
    movesMade: 0,
    status: GameStatus.playing,
  );
}

void main() {
  test('emptyIndices and filledCount reflect occupancy', () {
    final b = boardWith({0: const Tile(id: 1, tier: 1), 3: const Tile(id: 2, tier: 2)});
    expect(b.filledCount, 2);
    expect(b.emptyIndices.length, kCellCount - 2);
    expect(b.emptyIndices.contains(0), isFalse);
    expect(b.emptyIndices.contains(1), isTrue);
  });

  test('highestTier finds the max live tier', () {
    final b = boardWith({0: const Tile(id: 1, tier: 1), 3: const Tile(id: 2, tier: 7)});
    expect(b.highestTier, 7);
  });

  test('round-trips through json', () {
    final b = boardWith({0: const Tile(id: 1, tier: 1), 24: const Tile(id: 2, tier: 5)})
        .copyWith(score: 42, dropIndex: 3, movesMade: 4);
    expect(BoardState.fromJson(b.toJson()).toJson(), b.toJson());
  });
}
