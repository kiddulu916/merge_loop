/// Mulberry32 — a tiny, fast, fully reproducible PRNG.
///
/// Dart's `Random(seed)` is NOT guaranteed stable across platforms or SDK
/// versions, which would break "same board for everyone". We ship our own so
/// the sequence is byte-identical everywhere.
class Prng {
  int _state;

  Prng(int seed) : _state = seed & 0xFFFFFFFF;

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;

  /// Next unsigned 32-bit integer.
  int nextU32() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t = ((t + _imul(t ^ (t >>> 7), 61 | t)) & 0xFFFFFFFF) ^ t;
    t &= 0xFFFFFFFF;
    return (t ^ (t >>> 14)) & 0xFFFFFFFF;
  }

  /// Double in [0, 1).
  double nextDouble() => nextU32() / 4294967296.0;

  /// Integer in [0, max). [max] must be > 0.
  int nextInt(int max) => nextU32() % max;
}
