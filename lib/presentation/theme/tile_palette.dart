import 'package:flutter/material.dart';

import '../../domain/models/cosmetic.dart';

/// Maps a tier to its tile color. Tier 0 (empty) uses a translucent slot color.
///
/// Phase 4: tile colors are now driven by the selectable [Cosmetic] palettes
/// (see `domain/models/cosmetic.dart`). The static [colorForTier] keeps the
/// original `classic` ramp as the default so existing callers/tests are
/// unaffected; pass a [Cosmetic] to render an unlocked theme.
class TilePalette {
  const TilePalette._();

  /// Default (classic) tier color. Backward-compatible with Phase 1 callers.
  static Color colorForTier(int tier) => colorFor(Cosmetic.classic, tier);

  /// Tier color for a specific cosmetic palette.
  static Color colorFor(Cosmetic cosmetic, int tier) {
    final ramp = cosmetic.colors;
    return Color(ramp[tier.clamp(0, ramp.length - 1)]);
  }

  static Color textColorForTier(int tier) => Colors.white;

  /// Colorblind-safe pattern set (Phase 4), keyed by tile tier. Adjacent tiers
  /// map to visually distinct patterns so tiles can be told apart WITHOUT relying
  /// on hue (e.g. in grayscale). Tier 0 (empty) has no pattern. The pattern is a
  /// subtle background overlay rendered behind the always-on numeral, so the
  /// value stays legible.
  ///
  /// The cycle length (8) exceeds the typical run of adjacent live tiers, so no
  /// two neighbouring tiers ever share a pattern in practice.
  static TilePattern patternForTier(int tier) {
    if (tier <= 0) return TilePattern.none;
    const cycle = [
      TilePattern.dots,
      TilePattern.stripesDiagonal,
      TilePattern.grid,
      TilePattern.stripesHorizontal,
      TilePattern.cross,
      TilePattern.stripesVertical,
      TilePattern.checker,
      TilePattern.rings,
    ];
    return cycle[(tier - 1) % cycle.length];
  }
}

/// A colorblind-safe tile pattern (Phase 4). Distinguishes tiers by shape, not
/// hue. Painted as a subtle low-opacity overlay so the numeral stays readable.
enum TilePattern {
  none,
  dots,
  stripesDiagonal,
  stripesHorizontal,
  stripesVertical,
  grid,
  cross,
  checker,
  rings,
}
