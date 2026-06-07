import 'package:flutter/material.dart';

import '../../application/game_cubit.dart';
import '../../domain/models/difficulty.dart';
import '../../domain/models/leaderboard_entry.dart';
import '../../infrastructure/leaderboard_service.dart';

/// Per-tier daily leaderboard with tier tabs. Highlights the player's own row.
class LeaderboardScreen extends StatefulWidget {
  final LeaderboardService service;

  /// The tier shown first.
  final Difficulty initialDifficulty;

  /// Override for tests; defaults to the real UTC date string.
  final String Function()? todayProvider;

  const LeaderboardScreen({
    super.key,
    required this.service,
    this.initialDifficulty = Difficulty.easy,
    this.todayProvider,
  });

  String today() => (todayProvider ?? utcToday)();

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: Difficulty.values.length,
      vsync: this,
      initialIndex: Difficulty.values.indexOf(widget.initialDifficulty),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12141C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12141C),
        foregroundColor: Colors.white,
        title: const Text('Leaderboard'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: Colors.deepPurpleAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: [for (final d in Difficulty.values) Tab(text: d.label)],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final d in Difficulty.values)
            _TierBoard(
              key: ValueKey('board-${d.name}'),
              service: widget.service,
              difficulty: d,
              date: widget.today(),
            ),
        ],
      ),
    );
  }
}

class _TierBoard extends StatefulWidget {
  final LeaderboardService service;
  final Difficulty difficulty;
  final String date;

  const _TierBoard({
    super.key,
    required this.service,
    required this.difficulty,
    required this.date,
  });

  @override
  State<_TierBoard> createState() => _TierBoardState();
}

class _TierBoardState extends State<_TierBoard>
    with AutomaticKeepAliveClientMixin {
  late Future<List<LeaderboardEntry>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = widget.service
        .fetch(difficulty: widget.difficulty, date: widget.date);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.service
          .fetch(difficulty: widget.difficulty, date: widget.date);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<LeaderboardEntry>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
        }
        if (snap.hasError) {
          return _Message(
            key: const Key('lb-error'),
            text: "Couldn't load the leaderboard.\nPull to retry.",
            onRetry: _refresh,
          );
        }
        final entries = snap.data ?? const <LeaderboardEntry>[];
        if (entries.isEmpty) {
          return _Message(
            key: const Key('lb-empty'),
            text: 'No scores yet today.\nBe the first!',
            onRetry: _refresh,
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            key: const Key('lb-list'),
            itemCount: entries.length,
            itemBuilder: (context, i) => _Row(entry: entries[i]),
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  final LeaderboardEntry entry;
  const _Row({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('lb-row-${entry.rank}'),
      color: entry.isMe
          ? Colors.deepPurpleAccent.withValues(alpha: 0.18)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text('#${entry.rank}',
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: entry.isMe ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          Text('${entry.score}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          if (entry.isMe) ...[
            const SizedBox(width: 8),
            const Text('You',
                style: TextStyle(
                    color: Colors.deepPurpleAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final Future<void> Function() onRetry;
  const _Message({super.key, required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // Wrap in a scrollable so RefreshIndicator works on the empty/error states.
    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 16)),
        ],
      ),
    );
  }
}
