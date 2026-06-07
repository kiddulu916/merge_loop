import 'package:flutter_test/flutter_test.dart';
import 'package:merge_loop/domain/constants.dart';
import 'package:merge_loop/domain/engine/daily_seeder.dart';

void main() {
  test('same date yields identical initial board and drop tiers', () {
    final a = DailySeeder('2026-06-06').generate();
    final b = DailySeeder('2026-06-06').generate();
    expect(a.board.toJson(), b.board.toJson());
    expect(a.dropTiers, b.dropTiers);
  });

  test('different dates differ', () {
    final a = DailySeeder('2026-06-06').generate();
    final b = DailySeeder('2026-06-07').generate();
    expect(a.board.toJson(), isNot(b.board.toJson()));
  });

  test('initial board has exactly kStartingFill tiles, all tier 1-2', () {
    final start = DailySeeder('2026-06-06').generate();
    expect(start.board.filledCount, kStartingFill);
    for (final c in start.board.cells) {
      if (c != null) expect(c.tier, inInclusiveRange(1, 2));
    }
  });

  test('drop schedule has kMaxDrops tiers, each within its band', () {
    final start = DailySeeder('2026-06-06').generate();
    expect(start.dropTiers.length, kMaxDrops);
    for (var n = 0; n < start.dropTiers.length; n++) {
      expect(start.dropTiers[n], inInclusiveRange(1, dropCap(n)));
    }
  });

  test('landingPrng is independent of dropTier draws and reproducible', () {
    final s = DailySeeder('2026-06-06');
    final p1 = s.landingPrng();
    final p2 = s.landingPrng();
    expect(List.generate(10, (_) => p1.nextU32()),
        List.generate(10, (_) => p2.nextU32()));
  });
}
