import 'package:flutter/material.dart';

import '../../application/game_cubit.dart';
import '../../domain/models/difficulty.dart';
import '../../domain/models/leaderboard_entry.dart';
import '../../infrastructure/friends_service.dart';
import '../../infrastructure/leaderboard_service.dart';
import '../widgets/leaderboard_row.dart';

/// Which board the user is viewing within a tier.
enum LeaderboardScope { global, friends }

/// Per-tier daily leaderboard with tier tabs and a Global / Friends toggle.
/// Highlights the player's own row.
class LeaderboardScreen extends StatefulWidget {
  final LeaderboardService service;

  /// Friends board source. When null, the Global / Friends toggle is hidden and
  /// only the global board shows (offline / friends disabled).
  final FriendsService? friendsService;

  /// The tier shown first.
  final Difficulty initialDifficulty;

  /// Override for tests; defaults to the real UTC date string.
  final String Function()? todayProvider;

  const LeaderboardScreen({
    super.key,
    required this.service,
    this.friendsService,
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
  LeaderboardScope _scope = LeaderboardScope.global;

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
    final showToggle = widget.friendsService != null;
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
      body: Column(
        children: [
          if (showToggle)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SegmentedButton<LeaderboardScope>(
                key: const Key('lb-scope-toggle'),
                segments: const [
                  ButtonSegment(
                    value: LeaderboardScope.global,
                    label: Text('Global'),
                    icon: Icon(Icons.public),
                  ),
                  ButtonSegment(
                    value: LeaderboardScope.friends,
                    label: Text('Friends'),
                    icon: Icon(Icons.group),
                  ),
                ],
                selected: {_scope},
                onSelectionChanged: (s) => setState(() => _scope = s.first),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                for (final d in Difficulty.values)
                  _TierBoard(
                    key: ValueKey('board-${d.name}-${_scope.name}'),
                    service: widget.service,
                    friendsService: widget.friendsService,
                    scope: _scope,
                    difficulty: d,
                    date: widget.today(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TierBoard extends StatefulWidget {
  final LeaderboardService service;
  final FriendsService? friendsService;
  final LeaderboardScope scope;
  final Difficulty difficulty;
  final String date;

  const _TierBoard({
    super.key,
    required this.service,
    required this.friendsService,
    required this.scope,
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
    _future = _load();
  }

  Future<List<LeaderboardEntry>> _load() {
    if (widget.scope == LeaderboardScope.friends &&
        widget.friendsService != null) {
      return widget.friendsService!
          .friendsLeaderboard(difficulty: widget.difficulty, date: widget.date);
    }
    return widget.service
        .fetch(difficulty: widget.difficulty, date: widget.date);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isFriends = widget.scope == LeaderboardScope.friends;
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
            text: isFriends
                ? 'No friends on the board yet.\nInvite some!'
                : 'No scores yet today.\nBe the first!',
            onRetry: _refresh,
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            key: const Key('lb-list'),
            itemCount: entries.length,
            itemBuilder: (context, i) => LeaderboardRow(entry: entries[i]),
          ),
        );
      },
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
