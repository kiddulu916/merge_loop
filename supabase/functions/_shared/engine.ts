// TS port of lib/domain/engine/game_engine.dart + the replay verifier.
//
// `verifyRun(date, difficulty, moveLog)` regenerates the `(date,difficulty)`
// board and drop schedule, applies each move event in order (validating
// legality), applies the deterministic drop after each merge, and returns the
// authoritative score + highest tier, or rejects. The ordering mirrors
// GameCubit.merge / GameCubit.grantAdReward exactly.

import { Prng } from "./prng.ts";
import { DailySeeder } from "./seeder.ts";
import {
  type Difficulty,
  isDifficulty,
  kAdMoveReward,
  kMaxAdContinuesPerDay,
  kMaxTier,
} from "./constants.ts";

export interface Tile {
  id: number;
  tier: number;
}

export type GameStatus = "playing" | "outOfMoves" | "deadlocked";

export interface BoardState {
  cells: (Tile | null)[];
  movesRemaining: number;
  score: number;
  nextTileId: number;
  dropIndex: number;
  adContinuesUsed: number;
  movesMade: number;
  status: GameStatus;
}

// Move events (mirror lib/domain/models/move.dart). Accept both the spec's
// short form ({t:"merge"}) and Dart's toJson form ({type:"merge"}).
export interface MergeEvent {
  type: "merge";
  from: number;
  to: number;
}
export interface ContinueEvent {
  type: "continue";
}
export type MoveEvent = MergeEvent | ContinueEvent;

export interface VerifyResult {
  valid: boolean;
  score: number;
  highestTier: number;
  reason?: string;
}

// ---- pure rules (port of GameEngine) ----

export function canMerge(s: BoardState, fromIndex: number, toIndex: number): boolean {
  if (fromIndex === toIndex) return false;
  if (fromIndex < 0 || fromIndex >= s.cells.length) return false;
  if (toIndex < 0 || toIndex >= s.cells.length) return false;
  const from = s.cells[fromIndex];
  const to = s.cells[toIndex];
  if (from === null || to === null) return false;
  return from.tier === to.tier && from.tier < kMaxTier;
}

export function merge(s: BoardState, fromIndex: number, toIndex: number): BoardState {
  const to = s.cells[toIndex]!;
  const newTier = to.tier + 1;
  const cells = s.cells.slice();
  cells[toIndex] = { id: to.id, tier: newTier };
  cells[fromIndex] = null;
  return {
    ...s,
    cells,
    score: s.score + (1 << newTier),
    movesRemaining: s.movesRemaining - 1,
    movesMade: s.movesMade + 1,
  };
}

export function emptyIndices(s: BoardState): number[] {
  const out: number[] = [];
  for (let i = 0; i < s.cells.length; i++) {
    if (s.cells[i] === null) out.push(i);
  }
  return out;
}

export function applyDrop(s: BoardState, tier: number, landing: Prng): BoardState {
  const empties = emptyIndices(s);
  if (empties.length === 0) {
    return { ...s, dropIndex: s.dropIndex + 1 };
  }
  const idx = empties[landing.nextInt(empties.length)];
  const cells = s.cells.slice();
  cells[idx] = { id: s.nextTileId, tier };
  return {
    ...s,
    cells,
    nextTileId: s.nextTileId + 1,
    dropIndex: s.dropIndex + 1,
  };
}

export function hasMergeAvailable(s: BoardState): boolean {
  const seen = new Set<number>();
  for (const c of s.cells) {
    if (c === null || c.tier >= kMaxTier) continue;
    if (seen.has(c.tier)) return true;
    seen.add(c.tier);
  }
  return false;
}

export function evaluateStatus(s: BoardState): BoardState {
  if (s.movesRemaining <= 0) {
    return { ...s, status: "outOfMoves" };
  }
  if (!hasMergeAvailable(s)) {
    return { ...s, status: "deadlocked" };
  }
  return { ...s, status: "playing" };
}

export function highestTier(s: BoardState): number {
  let m = 0;
  for (const c of s.cells) {
    if (c !== null && c.tier > m) m = c.tier;
  }
  return m;
}

// ---- replay verifier ----

/** Normalize a raw move-log entry (spec short form or Dart toJson form). */
function parseEvent(raw: unknown): MoveEvent | null {
  if (typeof raw !== "object" || raw === null) return null;
  const o = raw as Record<string, unknown>;
  const t = (o.t ?? o.type) as unknown;
  if (t === "merge") {
    const from = o.from;
    const to = o.to;
    if (typeof from !== "number" || typeof to !== "number") return null;
    if (!Number.isInteger(from) || !Number.isInteger(to)) return null;
    return { type: "merge", from, to };
  }
  if (t === "continue") {
    return { type: "continue" };
  }
  return null;
}

const REJECT: VerifyResult = {
  valid: false,
  score: 0,
  highestTier: 0,
  reason: "invalid_run",
};

/**
 * Regenerate the `(date,difficulty)` board and replay the move log to compute
 * the authoritative score. Any illegal move, out-of-budget continue, or
 * malformed log yields `{ valid: false }`.
 */
export async function verifyRun(
  date: string,
  difficulty: string,
  log: unknown,
): Promise<VerifyResult> {
  if (!isDifficulty(difficulty)) return REJECT;
  if (!Array.isArray(log)) return REJECT;

  const seeder = new DailySeeder(date, difficulty as Difficulty);
  const start = await seeder.generate();
  const dropTiers = start.dropTiers;
  const landing = await seeder.landingPrng();

  let board = start.board;
  let continues = 0;

  for (const raw of log) {
    const ev = parseEvent(raw);
    if (ev === null) return REJECT;

    if (ev.type === "merge") {
      // Mirror GameCubit.merge: must currently be playing.
      if (board.status !== "playing") return REJECT;
      if (!canMerge(board, ev.from, ev.to)) return REJECT;
      board = merge(board, ev.from, ev.to);
      if (board.dropIndex < dropTiers.length) {
        board = applyDrop(board, dropTiers[board.dropIndex], landing);
      }
      board = evaluateStatus(board);
    } else {
      // Mirror GameCubit.grantAdReward / canOfferAd guard.
      if (board.status !== "outOfMoves") return REJECT;
      if (continues >= kMaxAdContinuesPerDay) return REJECT;
      if (board.adContinuesUsed >= kMaxAdContinuesPerDay) return REJECT;
      if (!hasMergeAvailable(board)) return REJECT;
      continues += 1;
      board = {
        ...board,
        movesRemaining: board.movesRemaining + kAdMoveReward,
        adContinuesUsed: board.adContinuesUsed + 1,
        status: "playing",
      };
    }

    if (board.movesRemaining < 0) return REJECT;
  }

  return {
    valid: true,
    score: board.score,
    highestTier: highestTier(board),
  };
}
