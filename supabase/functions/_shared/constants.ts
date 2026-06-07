// Tunable game constants — TS port of lib/domain/constants.dart. Must stay in
// lockstep with the Dart constants for cross-language replay parity.

/** Board is a fixed kGridSize × kGridSize matrix. */
export const kGridSize = 5;
export const kCellCount = kGridSize * kGridSize; // 25

/** Tier 0 = empty. Tiers 1..kMaxTier are live tiles (displayed as 2^tier). */
export const kMaxTier = 11; // 2^11 = 2048

/** Daily move budget. One move == one successful merge. */
export const kMovesPerDay = 30;

/** Moves granted per rewarded video, and the daily cap on rewarded continues. */
export const kAdMoveReward = 3;
export const kMaxAdContinuesPerDay = 3;

/** Maximum number of drops that can ever occur in one day. */
export const kMaxDrops = kMovesPerDay + kAdMoveReward * kMaxAdContinuesPerDay; // 39

/**
 * Upper bound (inclusive) of the drop tier band for drop number [n].
 * Drops are drawn from tiers [1 .. dropCap(n)]. The band widens by drop INDEX
 * (not board state) so the item sequence is identical for all players.
 */
export function dropCap(n: number): number {
  const c = 2 + Math.floor(n / 6);
  return c > 6 ? 6 : c;
}

/** Difficulty tiers. `name` is the stable seed-key token. */
export const DIFFICULTIES = ["easy", "medium", "hard", "legendary"] as const;
export type Difficulty = (typeof DIFFICULTIES)[number];

/** Number of tiles placed on the board at the start of the day, per tier. */
export const STARTING_FILL: Record<Difficulty, number> = {
  easy: 10,
  medium: 8,
  hard: 6,
  legendary: 4,
};

export function isDifficulty(s: string): s is Difficulty {
  return (DIFFICULTIES as readonly string[]).includes(s);
}
