import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'infrastructure/ad_service.dart';
import 'infrastructure/auth_service.dart';
import 'infrastructure/hive_storage_service.dart';
import 'infrastructure/leaderboard_service.dart';
import 'infrastructure/supabase_client.dart';
import 'presentation/screens/display_name_screen.dart';
import 'presentation/screens/tier_select_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  final storage = HiveStorageService();
  await storage.init();

  final adService = AdService();
  await adService.init();

  // Online layer (Phase 2). Degrades gracefully: if Supabase isn't configured
  // (no --dart-define) or anon sign-in fails, the game still runs offline.
  AuthService? auth;
  LeaderboardService? leaderboard;
  bool needsDisplayName = false;
  if (await initSupabase()) {
    auth = AuthService(supabase);
    leaderboard = LeaderboardService(supabase);
    try {
      await auth.ensureSignedIn();
      needsDisplayName = !(await auth.hasDisplayName());
    } catch (_) {
      // Offline / auth failure: keep playing offline; retry on next launch.
      auth = null;
      leaderboard = null;
    }
  }

  runApp(MergeLoopApp(
    storage: storage,
    adService: adService,
    auth: auth,
    leaderboard: leaderboard,
    needsDisplayName: needsDisplayName,
  ));
}

class MergeLoopApp extends StatefulWidget {
  final HiveStorageService storage;
  final AdService adService;
  final AuthService? auth;
  final LeaderboardService? leaderboard;
  final bool needsDisplayName;

  const MergeLoopApp({
    super.key,
    required this.storage,
    required this.adService,
    this.auth,
    this.leaderboard,
    this.needsDisplayName = false,
  });

  @override
  State<MergeLoopApp> createState() => _MergeLoopAppState();
}

class _MergeLoopAppState extends State<MergeLoopApp> {
  late bool _needsDisplayName;

  @override
  void initState() {
    super.initState();
    _needsDisplayName = widget.needsDisplayName;
  }

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (_needsDisplayName && widget.auth != null) {
      home = DisplayNameScreen(
        auth: widget.auth!,
        onSaved: () => setState(() => _needsDisplayName = false),
      );
    } else {
      home = TierSelectScreen(
        storage: widget.storage,
        adService: widget.adService,
        leaderboard: widget.leaderboard,
      );
    }
    return MaterialApp(
      title: 'Merge Loop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: home,
    );
  }
}
