import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../constants.dart';
import '../models/board_state.dart';
import '../models/game_status.dart';
import '../models/tile.dart';
import 'prng.dart';

/// Everything the day needs, derived deterministically from the date.
class DailyStart {
  final BoardState board;
  final List<int> dropTiers; // length kMaxDrops; dropTiers[n] = tier of drop n
  const DailyStart(this.board, this.dropTiers);
}

/// Turns a `YYYY-MM-DD` string into the day's board and drop schedule.
///
/// Two independent PRNG streams keep concerns decoupled:
///  - stream A (seedA): initial board placement + drop tiers (the global item
///    sequence — identical for every player).
///  - stream B (seedB): landing-cell selection at drop time (mapped onto each
///    player's own empty cells, so position adapts locally).
class DailySeeder {
  final String date;
  const DailySeeder(this.date);

  static int seedForDate(String date) {
    final bytes = sha256.convert(utf8.encode(date)).bytes;
    return (bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24)) &
        0xFFFFFFFF;
  }

  int get _seedA => seedForDate(date);
  int get _seedB => seedForDate(date) ^ 0x9E3779B9;

  DailyStart generate() {
    final a = Prng(_seedA);

    // Initial board: kStartingFill tiles of tier 1-2 in deterministic cells.
    final cells = List<Tile?>.filled(kCellCount, null);
    var nextId = 0;
    var placed = 0;
    while (placed < kStartingFill) {
      final idx = a.nextInt(kCellCount);
      if (cells[idx] != null) continue; // rejection sampling; deterministic
      cells[idx] = Tile(id: nextId++, tier: 1 + a.nextInt(2));
      placed++;
    }

    // Drop schedule: tiers only. Band widens by drop index n.
    final tiers = <int>[];
    for (var n = 0; n < kMaxDrops; n++) {
      tiers.add(1 + a.nextInt(dropCap(n)));
    }

    final board = BoardState(
      cells: cells,
      movesRemaining: kMovesPerDay,
      score: 0,
      nextTileId: nextId,
      dropIndex: 0,
      adContinuesUsed: 0,
      movesMade: 0,
      status: GameStatus.playing,
    );
    return DailyStart(board, tiers);
  }

  /// Fresh landing stream (stream B). Advance it `board.dropIndex` times when
  /// resuming a saved game to reach the correct position.
  Prng landingPrng() => Prng(_seedB);
}
