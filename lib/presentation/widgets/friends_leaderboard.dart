import 'package:flutter/material.dart';

import '../../domain/models/difficulty.dart';
import '../../domain/models/leaderboard_entry.dart';
import '../../infrastructure/friends_service.dart';
import 'leaderboard_row.dart';

/// Per-tier friends ranking for a single day. Reuses the Phase 2
/// [LeaderboardRow] so global + friends boards render identically.
class FriendsLeaderboard extends StatefulWidget {
  final FriendsService service;
  final Difficulty difficulty;
  final String date;

  const FriendsLeaderboard({
    super.key,
    required this.service,
    required this.difficulty,
    required this.date,
  });

  @override
  State<FriendsLeaderboard> createState() => _FriendsLeaderboardState();
}

class _FriendsLeaderboardState extends State<FriendsLeaderboard> {
  late Future<List<LeaderboardEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<LeaderboardEntry>> _load() => widget.service
      .friendsLeaderboard(difficulty: widget.difficulty, date: widget.date);

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LeaderboardEntry>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
        }
        if (snap.hasError) {
          return _message(
            const Key('fl-error'),
            "Couldn't load the friends board.\nPull to retry.",
          );
        }
        final entries = snap.data ?? const <LeaderboardEntry>[];
        if (entries.isEmpty) {
          return _message(
            const Key('fl-empty'),
            'No friends on the board yet.\nInvite some!',
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            key: const Key('fl-list'),
            itemCount: entries.length,
            itemBuilder: (context, i) => LeaderboardRow(entry: entries[i]),
          ),
        );
      },
    );
  }

  Widget _message(Key key, String text) => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          key: key,
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
}
