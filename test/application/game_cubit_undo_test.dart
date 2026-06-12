import 'package:flutter_test/flutter_test.dart';
import 'package:merge_count/application/game_cubit.dart';
import 'package:merge_count/application/game_state.dart';
import 'package:merge_count/domain/constants.dart';
import 'package:merge_count/domain/engine/daily_seeder.dart';
import 'package:merge_count/domain/engine/game_engine.dart';
import 'package:merge_count/domain/models/board_state.dart';
import 'package:merge_count/domain/models/difficulty.dart';
import 'package:merge_count/domain/models/game_status.dart';
import 'package:merge_count/domain/models/move.dart';
import 'package:merge_count/domain/models/tile.dart';
import 'package:merge_count/infrastructure/storage_service.dart';

/// The replay-relevant shape of a cell: id + tier only. The server verifier
/// (and the `replay` helper below) reconstruct tiers + positions but NOT the
/// cosmetic `golden` flag — golden never affects score or the move log — so
/// invariant checks compare id/tier, not the full (golden-bearing) toJson.
(int, int)? _cellKey(Tile? t) => t == null ? null : (t.id, t.tier);
List<(int, int)?> _cellKeys(BoardState b) => b.cells.map(_cellKey).toList();

/// Replays a final [moveLog] against the regenerated `(date,difficulty)` board
/// the EXACT way the Phase 2 Supabase edge function does (see
/// supabase/functions/_shared/engine.ts `verifyRun`): merge → drop → evaluate,
/// per event. Returns the reconstructed terminal board so a test can assert the
/// persisted moveLog reproduces the persisted board after any undo sequence.
BoardState replay(String date, Difficulty difficulty, List<MoveEvent> log) {
  final seeder = DailySeeder(date, difficulty);
  final start = seeder.generate();
  final dropTiers = start.dropTiers;
  final landing = seeder.landingPrng();
  var board = start.board;

  for (final ev in log) {
    if (ev is MergeEvent) {
      // Mirror the server: must be playing + legal.
      expect(board.status, GameStatus.playing,
          reason: 'replay hit a non-playing merge — moveLog drifted');
      expect(GameEngine.canMerge(board, ev.from, ev.to), isTrue,
          reason: 'replay hit an illegal merge — moveLog drifted');
      board = GameEngine.merge(board, fromIndex: ev.from, toIndex: ev.to);
      if (board.dropIndex < dropTiers.length) {
        board = GameEngine.applyDrop(board, dropTiers[board.dropIndex], landing);
      }
      board = GameEngine.evaluateStatus(board);
    } else if (ev is ContinueEvent) {
      board = board.copyWith(
        movesRemaining: board.movesRemaining + kAdMoveReward,
        adContinuesUsed: board.adContinuesUsed + 1,
        status: GameStatus.playing,
      );
    }
  }
  return board;
}

/// Finds two distinct, mergeable cells whose tier is below the cap.
(int, int) _findMergePair(BoardState b) {
  final byTier = <int, int>{};
  for (var i = 0; i < b.cells.length; i++) {
    final t = b.cells[i];
    if (t == null || t.tier >= kMaxTier) continue;
    if (byTier.containsKey(t.tier)) return (byTier[t.tier]!, i);
    byTier[t.tier] = i;
  }
  throw StateError('seeded board unexpectedly has no merge pair');
}

/// Finds a SECOND, different mergeable pair (disjoint from [avoid]) so the test
/// can "re-merge differently" after an undo.
(int, int)? _findOtherMergePair(BoardState b, (int, int) avoid) {
  final byTier = <int, List<int>>{};
  for (var i = 0; i < b.cells.length; i++) {
    final t = b.cells[i];
    if (t == null || t.tier >= kMaxTier) continue;
    byTier.putIfAbsent(t.tier, () => []).add(i);
  }
  for (final cells in byTier.values) {
    for (var x = 0; x < cells.length; x++) {
      for (var y = x + 1; y < cells.length; y++) {
        final pair = (cells[x], cells[y]);
        if (pair != avoid && (pair.$1, pair.$2) != (avoid.$2, avoid.$1)) {
          return pair;
        }
      }
    }
  }
  return null;
}

void main() {
  late InMemoryStorageService storage;
  GameCubit make(String date) =>
      GameCubit(storage: storage, todayProvider: () => date);
  setUp(() => storage = InMemoryStorageService());

  group('UNDO INVARIANT: run stays replay-consistent', () {
    test('undo rewinds board, dropIndex, and moveLog together', () async {
      const date = '2026-06-07';
      const diff = Difficulty.medium;
      final c = make(date);
      await c.init(difficulty: diff);

      final before = (c.state as GamePlaying).board;
      final pair = _findMergePair(before);
      await c.merge(fromIndex: pair.$1, toIndex: pair.$2);

      final merged = (c.state as GamePlaying).board;
      expect(merged.dropIndex, before.dropIndex + 1);
      expect(merged.moveLog.length, before.moveLog.length + 1);

      await c.undo();
      final restored = (c.state as GamePlaying).board;

      // Board is byte-for-byte the pre-merge board (cells, score, dropIndex,
      // moveLog all rewound together).
      expect(restored.toJson(), before.toJson());
      expect(restored.moveLog, before.moveLog);
      expect(restored.dropIndex, before.dropIndex);
    });

    test(
        'merge → undo → re-merge-differently: final moveLog replays to the '
        'final board (no PRNG desync)', () async {
      const date = '2026-06-09';
      const diff = Difficulty.easy;
      final c = make(date);
      await c.init(difficulty: diff);

      final start = (c.state as GamePlaying).board;
      final firstPair = _findMergePair(start);
      final otherPair = _findOtherMergePair(start, firstPair);
      expect(otherPair, isNotNull,
          reason: 'need a second distinct pair to re-merge differently');

      // Merge one way...
      await c.merge(fromIndex: firstPair.$1, toIndex: firstPair.$2);
      // ...undo it...
      await c.undo();
      expect((c.state as GamePlaying).board.toJson(), start.toJson());
      // ...then merge a DIFFERENT pair.
      await c.merge(fromIndex: otherPair!.$1, toIndex: otherPair.$2);

      final finalBoard = (c.state as GamePlaying).board;

      // THE CRITICAL ASSERTION: the persisted moveLog replays (server-style)
      // to EXACTLY the persisted board. A landing-PRNG desync after undo would
      // place the post-merge drop in a different cell and break this.
      final replayed = replay(date, diff, finalBoard.moveLog);
      expect(_cellKeys(replayed), _cellKeys(finalBoard));
      expect(replayed.score, finalBoard.score);
      expect(replayed.dropIndex, finalBoard.dropIndex);
      expect(replayed.highestTier, finalBoard.highestTier);

      // The move log holds exactly the single (re-)merge — the undone one is
      // gone, so the persisted log equals the real board history.
      expect(finalBoard.moveLog,
          [MergeEvent(from: otherPair.$1, to: otherPair.$2)]);
    });

    test('multiple merges then multiple undos all stay replay-consistent',
        () async {
      const date = '2026-06-10';
      const diff = Difficulty.medium;
      final c = make(date);
      await c.init(difficulty: diff);

      // Make three merges.
      for (var i = 0; i < 3; i++) {
        final b = (c.state as GamePlaying).board;
        final pair = _findMergePair(b);
        await c.merge(fromIndex: pair.$1, toIndex: pair.$2);
      }
      // Undo two of them (depth is bounded at kUndoStackDepth >= 3).
      await c.undoAfterReward();
      await c.undoAfterReward();

      final board = (c.state as GamePlaying).board;
      expect(board.moveLog.length, 1, reason: 'two of three merges undone');

      final replayed = replay(date, diff, board.moveLog);
      expect(_cellKeys(replayed), _cellKeys(board));
      expect(replayed.score, board.score);
      expect(replayed.dropIndex, board.dropIndex);
    });
  });

  group('UNDO gating + bounds', () {
    test('free undo cap: exactly kFreeUndosPerDay free undos, then no-op',
        () async {
      const date = '2026-06-07';
      final c = make(date);
      await c.init(difficulty: Difficulty.medium);

      // Build a stack with several merges so frames exist beyond the free cap.
      for (var i = 0; i < kFreeUndosPerDay + 2; i++) {
        final b = (c.state as GamePlaying).board;
        final pair = _findMergePair(b);
        await c.merge(fromIndex: pair.$1, toIndex: pair.$2);
      }

      var freeUndos = 0;
      while (c.canUndoFree) {
        await c.undo();
        freeUndos++;
      }
      expect(freeUndos, kFreeUndosPerDay);
      // canUndo is still true (frames remain) but no FREE undo is left.
      expect(c.canUndo, isTrue);
      expect(c.canUndoFree, isFalse);

      // A bare undo() past the free cap is a no-op (log unchanged).
      final logBefore = (c.state as GamePlaying).board.moveLog.length;
      await c.undo();
      expect((c.state as GamePlaying).board.moveLog.length, logBefore);
    });

    test('rewarded undo grants exactly one extra past the free cap', () async {
      const date = '2026-06-07';
      final c = make(date);
      await c.init(difficulty: Difficulty.medium);

      for (var i = 0; i < kFreeUndosPerDay + 1; i++) {
        final b = (c.state as GamePlaying).board;
        final pair = _findMergePair(b);
        await c.merge(fromIndex: pair.$1, toIndex: pair.$2);
      }
      // Spend the free undo(s).
      while (c.canUndoFree) {
        await c.undo();
      }
      final logBefore = (c.state as GamePlaying).board.moveLog.length;

      // The rewarded path grants ONE more undo even though the free cap is hit.
      await c.undoAfterReward();
      expect((c.state as GamePlaying).board.moveLog.length, logBefore - 1);
    });

    test('undo is a no-op with an empty stack', () async {
      const date = '2026-06-07';
      final c = make(date);
      await c.init(difficulty: Difficulty.medium);
      expect(c.canUndo, isFalse);
      final before = (c.state as GamePlaying).board.toJson();
      await c.undo();
      await c.undoAfterReward();
      expect((c.state as GamePlaying).board.toJson(), before);
    });

    test('undo stack is bounded at kUndoStackDepth', () async {
      const date = '2026-06-07';
      final c = make(date);
      await c.init(difficulty: Difficulty.medium);

      // Make more merges than the stack depth.
      for (var i = 0; i < kUndoStackDepth + 3; i++) {
        final b = (c.state as GamePlaying).board;
        final pair = _findMergePair(b);
        await c.merge(fromIndex: pair.$1, toIndex: pair.$2);
      }
      // Only kUndoStackDepth frames are rewindable (oldest dropped).
      var undos = 0;
      while (c.canUndo) {
        await c.undoAfterReward();
        undos++;
      }
      expect(undos, kUndoStackDepth);
    });

    test('undo only valid in GamePlaying (not after the run is locked)',
        () async {
      const date = '2026-06-06';
      const diff = Difficulty.medium;
      // Resume a near-complete board (1 move left), merge once to lock the day.
      final start = const DailySeeder(date, diff).generate().board;
      await storage.saveSnapshot(GameSnapshot(
          date: date,
          difficulty: diff,
          board: start.copyWith(movesRemaining: 1),
          completed: false));
      final c = make(date);
      await c.init(difficulty: diff);
      final b = (c.state as GamePlaying).board;
      final pair = _findMergePair(b);
      await c.merge(fromIndex: pair.$1, toIndex: pair.$2);

      expect(c.state, isA<GameOverShowScore>());
      // No undo once locked, even though a merge just happened.
      expect(c.canUndo, isFalse);
      await c.undo();
      await c.undoAfterReward();
      expect(c.state, isA<GameOverShowScore>(),
          reason: 'undo must not revive a locked run');
    });
  });
}
