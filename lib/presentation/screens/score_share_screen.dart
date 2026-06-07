import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/engine/share_grid_builder.dart';
import '../../domain/models/board_state.dart';
import '../../infrastructure/friends_service.dart';
import '../../infrastructure/storage_service.dart';

/// Offline daily result: the player's own score/tier/moves plus local personal
/// stats. The emoji share is the (offline) comparison mechanism. When a friend
/// code is available, the share card carries an invite link and a dedicated
/// "invite a friend" CTA is shown (Phase 3 growth lever).
class ScoreShareScreen extends StatelessWidget {
  final BoardState board;
  final String date;
  final LifetimeStats stats;
  final bool canOfferAd;
  final VoidCallback onWatchAd;

  /// The player's friend code, when online. When present, the share text
  /// includes an invite link and an "Invite a friend" CTA is shown.
  final String? friendCode;

  /// Seam: native share. Defaults to [share_plus]. Tests inject a fake.
  final Future<void> Function(String text)? shareText;

  const ScoreShareScreen({
    super.key,
    required this.board,
    required this.date,
    required this.stats,
    required this.canOfferAd,
    required this.onWatchAd,
    this.friendCode,
    this.shareText,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12141C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Daily Result',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              _bigStat('SCORE', '${board.score}'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _smallStat('BEST TILE', '${1 << board.highestTier}'),
                  _smallStat('MOVES', '${board.movesMade}'),
                  _smallStat('STREAK', '${stats.streak}'),
                ],
              ),
              const SizedBox(height: 8),
              _smallStat('BEST EVER', '${stats.bestScore}'),
              const SizedBox(height: 24),
              if (canOfferAd)
                FilledButton.tonal(
                  onPressed: onWatchAd,
                  child: const Text('Watch ad for more moves'),
                ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('share-card-button'),
                onPressed: () => _share(context),
                child: const Text('Share'),
              ),
              if (friendCode != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('invite-friend-button'),
                  onPressed: () => _invite(context),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Invite a friend'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The shareable card text: the emoji grid, plus an invite link when online.
  String _cardText() {
    final grid = ShareGridBuilder.build(date: date, board: board);
    if (friendCode == null) return grid;
    return '$grid\n\nPlay & add me: ${FriendsService.inviteLink(friendCode!)}';
  }

  Future<void> _share(BuildContext context) async {
    final text = _cardText();
    final share = shareText;
    if (share != null) {
      await share(text);
      return;
    }
    // Default: copy to clipboard (works headlessly + offline). Production wires
    // [shareText] to share_plus's native sheet; see [_nativeShare].
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Result copied to clipboard!')),
      );
    }
  }

  Future<void> _invite(BuildContext context) async {
    final code = friendCode;
    if (code == null) return;
    final text = 'Add me on Merge Loop! ${FriendsService.inviteLink(code)}';
    final share = shareText ?? _nativeShare;
    await share(text);
  }

  /// Native share sheet via share_plus (device). Used in production when no
  /// [shareText] seam is injected.
  static Future<void> _nativeShare(String text) =>
      Share.share(text, subject: 'Merge Loop');

  Widget _bigStat(String label, String value) => Column(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, letterSpacing: 2)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900)),
        ],
      );

  Widget _smallStat(String label, String value) => Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11, letterSpacing: 1.5)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
        ],
      );
}
