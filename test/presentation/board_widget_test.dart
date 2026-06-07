import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_loop/domain/constants.dart';
import 'package:merge_loop/domain/models/board_state.dart';
import 'package:merge_loop/domain/models/game_status.dart';
import 'package:merge_loop/domain/models/tile.dart';
import 'package:merge_loop/presentation/widgets/board_widget.dart';

void main() {
  testWidgets('reports a merge when a tile is dragged onto a matching tile', (tester) async {
    final cells = List<Tile?>.filled(kCellCount, null);
    cells[0] = const Tile(id: 1, tier: 2);
    cells[1] = const Tile(id: 2, tier: 2);
    final board = BoardState(
      cells: cells,
      movesRemaining: 30,
      score: 0,
      nextTileId: 3,
      dropIndex: 0,
      adContinuesUsed: 0,
      movesMade: 0,
      status: GameStatus.playing,
    );

    int? gotFrom, gotTo;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BoardWidget(
          board: board,
          onMerge: (from, to) {
            gotFrom = from;
            gotTo = to;
          },
        ),
      ),
    ));

    expect(find.text('4'), findsNWidgets(2));

    final gesture = await tester.startGesture(tester.getCenter(find.text('4').first));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.text('4').last));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(gotFrom, 0);
    expect(gotTo, 1);
  });
}
