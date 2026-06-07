// Mulberry32 — a tiny, fast, fully reproducible PRNG.
//
// TypeScript port of lib/domain/engine/prng.dart, ported line-for-line.
// JavaScript numbers are 64-bit floats, so every 32-bit operation MUST use
// `Math.imul(...)` for multiplies and `>>> 0` after every arithmetic step to
// emulate Dart's `& 0xFFFFFFFF` truncation. This is the make-or-break detail:
// the sequence must be byte-identical to the Dart implementation everywhere.
export class Prng {
  private state: number;

  constructor(seed: number) {
    this.state = seed >>> 0;
  }

  /** Next unsigned 32-bit integer. */
  nextU32(): number {
    this.state = (this.state + 0x6d2b79f5) >>> 0;
    let t = this.state;
    t = Math.imul(t ^ (t >>> 15), t | 1) >>> 0;
    t = ((t + Math.imul(t ^ (t >>> 7), 61 | t)) >>> 0) ^ t;
    t = t >>> 0;
    return (t ^ (t >>> 14)) >>> 0;
  }

  /** Double in [0, 1). */
  nextDouble(): number {
    return this.nextU32() / 4294967296.0;
  }

  /** Integer in [0, max). [max] must be > 0. */
  nextInt(max: number): number {
    return this.nextU32() % max;
  }
}
