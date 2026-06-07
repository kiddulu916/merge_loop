// TS port of lib/domain/engine/daily_seeder.dart.
//
// Turns a `(YYYY-MM-DD, Difficulty)` pair into the day's board and drop
// schedule. Each tier is a fully independent deterministic stream keyed by
// `"$date:$difficulty"`. Two independent PRNG streams:
//   - stream A (seedA): initial board placement + drop tiers.
//   - stream B (seedB): landing-cell selection at drop time.

import { Prng } from "./prng.ts";
import {
  type Difficulty,
  dropCap,
  kCellCount,
  kMaxDrops,
  kMovesPerDay,
  STARTING_FILL,
} from "./constants.ts";
import type { BoardState, Tile } from "./engine.ts";

/** Everything the day needs, derived deterministically from the date. */
export interface DailyStart {
  board: BoardState;
  dropTiers: number[]; // length kMaxDrops; dropTiers[n] = tier of drop n
}

/**
 * Hashes an arbitrary seed key (e.g. "2026-06-07:hard") to a 32-bit seed.
 * Byte order must match Dart exactly:
 *   bytes[0] | bytes[1]<<8 | bytes[2]<<16 | bytes[3]<<24  (then & 0xFFFFFFFF).
 */
export async function seedForKey(key: string): Promise<number> {
  const data = new TextEncoder().encode(key);
  const digest = await crypto.subtle.digest("SHA-256", data);
  const b = new Uint8Array(digest);
  return (b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24)) >>> 0;
}

export class DailySeeder {
  readonly date: string; // UTC YYYY-MM-DD
  readonly difficulty: Difficulty;

  constructor(date: string, difficulty: Difficulty) {
    this.date = date;
    this.difficulty = difficulty;
  }

  get key(): string {
    return `${this.date}:${this.difficulty}`;
  }

  async seedA(): Promise<number> {
    return await seedForKey(this.key);
  }

  async seedB(): Promise<number> {
    return (await seedForKey(this.key)) ^ 0x9e3779b9;
  }

  async generate(): Promise<DailyStart> {
    const a = new Prng(await this.seedA());

    // Initial board: STARTING_FILL tiles of tier 1-2 in deterministic cells.
    const cells: (Tile | null)[] = new Array(kCellCount).fill(null);
    let nextId = 0;
    let placed = 0;
    const startingFill = STARTING_FILL[this.difficulty];
    while (placed < startingFill) {
      const idx = a.nextInt(kCellCount);
      if (cells[idx] !== null) continue; // rejection sampling; deterministic
      cells[idx] = { id: nextId++, tier: 1 + a.nextInt(2) };
      placed++;
    }

    // Drop schedule: tiers only. Band widens by drop index n.
    const tiers: number[] = [];
    for (let n = 0; n < kMaxDrops; n++) {
      tiers.push(1 + a.nextInt(dropCap(n)));
    }

    const board: BoardState = {
      cells,
      movesRemaining: kMovesPerDay,
      score: 0,
      nextTileId: nextId,
      dropIndex: 0,
      adContinuesUsed: 0,
      movesMade: 0,
      status: "playing",
    };
    return { board, dropTiers: tiers };
  }

  /** Fresh landing stream (stream B). */
  async landingPrng(): Promise<Prng> {
    return new Prng(await this.seedB());
  }
}
