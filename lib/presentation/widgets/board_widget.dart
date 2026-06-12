import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/constants.dart';
import '../../domain/models/board_state.dart';
import '../../domain/models/cosmetic.dart';
import '../../domain/models/tile.dart';
import '../theme/tile_palette.dart';
import 'grid_cell_widget.dart';

/// Renders the 5×5 board as a static slot grid with live tiles floating above
/// as AnimatedPositioned widgets keyed by tile id, so merges slide and drops
/// fall smoothly. Drag a tile onto a matching tile to merge; [onMerge] is
/// invoked with (fromIndex, toIndex).
class BoardWidget extends StatelessWidget {
  final BoardState board;
  final void Function(int fromIndex, int toIndex) onMerge;

  /// Selected tile theme. Defaults to classic.
  final Cosmetic cosmetic;

  /// When true, render colorblind-safe per-tier patterns on tiles (Phase 4).
  final bool colorblindMode;

  const BoardWidget({
    super.key,
    required this.board,
    required this.onMerge,
    this.cosmetic = Cosmetic.classic,
    this.colorblindMode = false,
  });

  bool _isMergeable(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return false;
    final from = board.cells[fromIndex];
    final to = board.cells[toIndex];
    if (from == null || to == null) return false;
    return from.tier == to.tier && from.tier < kMaxTier;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final boardSize = constraints.maxWidth;
        final cell = (boardSize - gap * (kGridSize + 1)) / kGridSize;

        Offset offsetFor(int index) {
          final row = index ~/ kGridSize;
          final col = index % kGridSize;
          return Offset(gap + col * (cell + gap), gap + row * (cell + gap));
        }

        final children = <Widget>[];

        // Static backing slots.
        for (var i = 0; i < kCellCount; i++) {
          final pos = offsetFor(i);
          children.add(Positioned(
            left: pos.dx,
            top: pos.dy,
            child: GridCellWidget(tile: null, size: cell, cosmetic: cosmetic),
          ));
        }

        // Floating live tiles (visuals + drag source), keyed by id.
        for (var i = 0; i < kCellCount; i++) {
          final tile = board.cells[i];
          if (tile == null) continue;
          final pos = offsetFor(i);
          children.add(AnimatedPositioned(
            key: ValueKey(tile.id),
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            left: pos.dx,
            top: pos.dy,
            width: cell,
            height: cell,
            child: _DraggableTile(
                index: i,
                tile: tile,
                size: cell,
                cosmetic: cosmetic,
                colorblindMode: colorblindMode),
          ));
        }

        // Drop targets as the TOP layer (translucent) so they reliably receive
        // drops while pointers still pass through to the draggable tiles below.
        for (var i = 0; i < kCellCount; i++) {
          final pos = offsetFor(i);
          children.add(Positioned(
            left: pos.dx,
            top: pos.dy,
            width: cell,
            height: cell,
            child: DragTarget<int>(
              hitTestBehavior: HitTestBehavior.translucent,
              onWillAcceptWithDetails: (d) => _isMergeable(d.data, i),
              onAcceptWithDetails: (d) {
                HapticFeedback.mediumImpact();
                onMerge(d.data, i);
              },
              builder: (context, _, __) => const SizedBox.expand(),
            ),
          ));
        }

        return SizedBox(
          width: boardSize,
          height: boardSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF1E2230),
              borderRadius: BorderRadius.circular(gap * 1.5),
            ),
            child: Stack(children: children),
          ),
        );
      },
    );
  }
}

class _DraggableTile extends StatelessWidget {
  final int index;
  final Tile tile;
  final double size;
  final Cosmetic cosmetic;
  final bool colorblindMode;

  const _DraggableTile({
    required this.index,
    required this.tile,
    required this.size,
    required this.cosmetic,
    this.colorblindMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final face = GridCellWidget(
        tile: tile,
        size: size,
        cosmetic: cosmetic,
        colorblindMode: colorblindMode);
    // The feedback intentionally omits the text label so that find.text()
    // in tests (and in the gesture pipeline) does not find a third instance
    // of the tile value floating in the overlay during a drag gesture.
    final feedbackFace = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: TilePalette.colorFor(cosmetic, tile.tier),
        borderRadius: BorderRadius.circular(size * 0.16),
      ),
    );
    return Draggable<int>(
      data: index,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(scale: 1.1, child: feedbackFace),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: face),
      child: face,
    );
  }
}
