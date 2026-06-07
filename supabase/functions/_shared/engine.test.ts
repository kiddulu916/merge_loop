// Cross-language parity + replay-verification tests.
//
// The "expected" values below were CAPTURED from the Dart implementation via a
// throwaway test (test/domain/engine/_temp_vectors_test.dart, since deleted).
// They pin the TS port to be byte-identical to Dart. If these ever drift, the
// server board != client board and every legit run would be rejected — so these
// assertions are the CI gate for the determinism port.
//
// Run: deno test supabase/functions/_shared/engine.test.ts

import { assertEquals, assertFalse } from "jsr:@std/assert@1";
import { Prng } from "./prng.ts";
import { DailySeeder, seedForKey } from "./seeder.ts";
import { type MoveEvent, verifyRun } from "./engine.ts";

// ---- Captured Dart vectors ----

const DART_SEED_KEY_2026_06_07_LEGENDARY = 550419188;

const DART_PRNG: Record<string, number[]> = {
  "1": [
    2693262067, 11749833, 2265367787, 4213581821, 4159151403, 1207330352,
    2632122864, 3095568220, 1828783984, 4272732017, 1955374602, 2099329838,
    596715197, 1734070562, 1063107040, 663542962, 2100857034, 289351446,
    1694877057, 3294703884,
  ],
  "42": [
    2581720956, 1925393290, 3661312704, 2876485805, 750819978, 2261697747,
    1173505300, 2683257857, 3717185310, 2028586305, 1073414265, 3788413843,
    3202918453, 1318561460, 847198783, 2150616774, 2948976162, 2622596789,
    16505353, 2021992966,
  ],
  "0x9E3779B9": [
    1541420728, 454851044, 2900350524, 3942498910, 436270539, 1292797714,
    107332754, 2003106812, 1860262629, 2351451603, 2189223826, 1319006189,
    3858527959, 1458065988, 439542631, 1065433749, 1124176789, 3650098597,
    824228062, 2846529103,
  ],
  "keyHash": [
    4278839893, 1416147163, 1509739711, 3814287932, 3837562946, 3501279784,
    1635852863, 2569168105, 2576248468, 2155669214, 853677039, 3297811397,
    4082003367, 3270720374, 1308521369, 3090506910, 624426149, 2081899626,
    3346979326, 656422535,
  ],
};

// (2026-06-07, legendary) initial board: index -> {id, tier} or null.
const DART_LEGENDARY_CELLS: ({ id: number; tier: number } | null)[] = [
  null, null, null, null, null,
  null, null, null, null, null,
  null, { id: 1, tier: 1 }, null, { id: 3, tier: 2 }, null,
  null, null, null, { id: 0, tier: 2 }, null,
  null, { id: 2, tier: 1 }, null, null, null,
];
const DART_LEGENDARY_NEXT_TILE_ID = 4;
const DART_LEGENDARY_DROP_TIERS = [
  1, 1, 2, 2, 2, 1, 3, 1, 3, 1, 2, 3, 2, 2, 1, 1, 1, 1, 5, 1, 4, 3, 1, 4, 1, 3,
  6, 1, 5, 1, 5, 6, 1, 4, 5, 3, 1, 3, 1,
];

// Captured legit run (legendary, greedy -> deadlock at 6 merges, score 48).
const DART_LEGIT_LEGENDARY: MoveEvent[] = [
  { type: "merge", from: 21, to: 11 },
  { type: "merge", from: 13, to: 11 },
  { type: "merge", from: 3, to: 0 },
  { type: "merge", from: 18, to: 0 },
  { type: "merge", from: 23, to: 20 },
  { type: "merge", from: 11, to: 0 },
];
const DART_LEGIT_LEGENDARY_SCORE = 48;
const DART_LEGIT_LEGENDARY_TIER = 4;

// Captured legit run (easy, full 30 moves + 3 continues, score 752, tier 6).
const DART_LEGIT_EASY: MoveEvent[] = [
  { type: "merge", from: 11, to: 5 },
  { type: "merge", from: 20, to: 12 },
  { type: "merge", from: 24, to: 21 },
  { type: "merge", from: 7, to: 5 },
  { type: "merge", from: 12, to: 8 },
  { type: "merge", from: 14, to: 13 },
  { type: "merge", from: 16, to: 9 },
  { type: "merge", from: 15, to: 9 },
  { type: "merge", from: 18, to: 3 },
  { type: "merge", from: 21, to: 20 },
  { type: "merge", from: 5, to: 3 },
  { type: "merge", from: 9, to: 8 },
  { type: "merge", from: 23, to: 10 },
  { type: "merge", from: 22, to: 10 },
  { type: "merge", from: 18, to: 12 },
  { type: "merge", from: 13, to: 10 },
  { type: "merge", from: 19, to: 14 },
  { type: "merge", from: 12, to: 7 },
  { type: "merge", from: 20, to: 7 },
  { type: "merge", from: 6, to: 0 },
  { type: "merge", from: 11, to: 0 },
  { type: "merge", from: 21, to: 0 },
  { type: "merge", from: 3, to: 0 },
  { type: "merge", from: 8, to: 7 },
  { type: "merge", from: 14, to: 10 },
  { type: "merge", from: 4, to: 0 },
  { type: "merge", from: 19, to: 2 },
  { type: "merge", from: 13, to: 2 },
  { type: "merge", from: 20, to: 2 },
  { type: "merge", from: 23, to: 2 },
  { type: "continue" },
  { type: "merge", from: 7, to: 2 },
  { type: "merge", from: 8, to: 3 },
  { type: "merge", from: 17, to: 3 },
  { type: "continue" },
  { type: "merge", from: 12, to: 3 },
  { type: "merge", from: 10, to: 3 },
  { type: "merge", from: 18, to: 1 },
  { type: "continue" },
  { type: "merge", from: 23, to: 16 },
  { type: "merge", from: 9, to: 7 },
  { type: "merge", from: 7, to: 6 },
];
const DART_LEGIT_EASY_SCORE = 752;
const DART_LEGIT_EASY_TIER = 6;

// ---- PRNG parity ----

Deno.test("PRNG matches Dart vectors byte-for-byte", () => {
  const cases: [string, number][] = [
    ["1", 1],
    ["42", 42],
    ["0x9E3779B9", 0x9e3779b9],
    ["keyHash", DART_SEED_KEY_2026_06_07_LEGENDARY],
  ];
  for (const [label, seed] of cases) {
    const p = new Prng(seed);
    const got = Array.from({ length: 20 }, () => p.nextU32());
    assertEquals(got, DART_PRNG[label], `PRNG sequence mismatch for seed ${label}`);
  }
});

Deno.test("seedForKey matches Dart byte-order reduction", async () => {
  const seed = await seedForKey("2026-06-07:legendary");
  assertEquals(seed, DART_SEED_KEY_2026_06_07_LEGENDARY);
});

// ---- Board parity ----

Deno.test("legendary board for 2026-06-07 matches Dart", async () => {
  const start = await new DailySeeder("2026-06-07", "legendary").generate();
  assertEquals(start.board.cells, DART_LEGENDARY_CELLS);
  assertEquals(start.board.nextTileId, DART_LEGENDARY_NEXT_TILE_ID);
  assertEquals(start.dropTiers, DART_LEGENDARY_DROP_TIERS);
});

// ---- Replay parity ----

Deno.test("verifyRun on captured legit legendary run matches Dart score", async () => {
  const r = await verifyRun("2026-06-07", "legendary", DART_LEGIT_LEGENDARY);
  assertEquals(r.valid, true);
  assertEquals(r.score, DART_LEGIT_LEGENDARY_SCORE);
  assertEquals(r.highestTier, DART_LEGIT_LEGENDARY_TIER);
});

Deno.test("verifyRun on captured legit easy run (30 moves + 3 continues) matches Dart", async () => {
  const r = await verifyRun("2026-06-07", "easy", DART_LEGIT_EASY);
  assertEquals(r.valid, true);
  assertEquals(r.score, DART_LEGIT_EASY_SCORE);
  assertEquals(r.highestTier, DART_LEGIT_EASY_TIER);
});

Deno.test("verifyRun accepts the spec short-form {t:...} event shape", async () => {
  const shortForm = DART_LEGIT_LEGENDARY.map((e) =>
    e.type === "merge" ? { t: "merge", from: e.from, to: e.to } : { t: "continue" }
  );
  const r = await verifyRun("2026-06-07", "legendary", shortForm);
  assertEquals(r.valid, true);
  assertEquals(r.score, DART_LEGIT_LEGENDARY_SCORE);
});

// ---- Tamper rejection ----

Deno.test("rejects an illegal merge (cells empty / mismatched tier)", async () => {
  const tampered: MoveEvent[] = [
    ...DART_LEGIT_LEGENDARY,
    { type: "merge", from: 7, to: 9 }, // both empty after the legit run
  ];
  const r = await verifyRun("2026-06-07", "legendary", tampered);
  assertFalse(r.valid);
});

Deno.test("rejects a merge of distinct tiers", async () => {
  // First board move: cell 11 (tier1) into cell 13 (tier2) is illegal.
  const r = await verifyRun("2026-06-07", "legendary", [
    { type: "merge", from: 11, to: 13 },
  ]);
  assertFalse(r.valid);
});

Deno.test("rejects more continues than the daily cap (4 > 3)", async () => {
  // Take the legit easy run up to its 3rd continue, then inject a 4th continue.
  const idx4thRegion = DART_LEGIT_EASY.findIndex(
    (_e, i) => DART_LEGIT_EASY.slice(0, i + 1).filter((x) => x.type === "continue").length === 3,
  );
  const upTo3 = DART_LEGIT_EASY.slice(0, idx4thRegion + 1);
  const overCap: MoveEvent[] = [...upTo3, { type: "continue" }];
  const r = await verifyRun("2026-06-07", "easy", overCap);
  // The injected continue is illegal because the board is still 'playing'
  // (status != outOfMoves) immediately after a continue OR exceeds the cap.
  assertFalse(r.valid);
});

Deno.test("rejects a continue while still playing (not out of moves)", async () => {
  const r = await verifyRun("2026-06-07", "easy", [
    { type: "merge", from: 11, to: 5 },
    { type: "continue" }, // illegal: board is still playing
  ]);
  assertFalse(r.valid);
});

Deno.test("swapped-tier log yields a different score (or rejection)", async () => {
  // Replay the easy legit log against the LEGENDARY board: the cells differ, so
  // most merges become illegal -> rejected (definitely not the easy score).
  const r = await verifyRun("2026-06-07", "legendary", DART_LEGIT_EASY);
  if (r.valid) {
    assertFalse(r.score === DART_LEGIT_EASY_SCORE);
  } else {
    assertFalse(r.valid);
  }
});

Deno.test("rejects an invalid difficulty", async () => {
  const r = await verifyRun("2026-06-07", "impossible", DART_LEGIT_LEGENDARY);
  assertFalse(r.valid);
});

Deno.test("rejects a malformed move log", async () => {
  const r = await verifyRun("2026-06-07", "legendary", [{ type: "teleport" }]);
  assertFalse(r.valid);
});
