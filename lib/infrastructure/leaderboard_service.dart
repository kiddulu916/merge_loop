import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/difficulty.dart';
import '../domain/models/leaderboard_entry.dart';
import '../domain/models/move.dart';

/// Result of a score submission (mirrors the Edge Function response).
class SubmitResult {
  final bool valid;
  final int score;
  final int highestTier;
  final int rank;

  const SubmitResult({
    required this.valid,
    required this.score,
    required this.highestTier,
    required this.rank,
  });

  static SubmitResult fromJson(Map<String, dynamic> j) => SubmitResult(
        valid: (j['valid'] as bool?) ?? false,
        score: (j['score'] as num?)?.toInt() ?? 0,
        highestTier: (j['highestTier'] as num?)?.toInt() ?? 0,
        rank: (j['rank'] as num?)?.toInt() ?? 0,
      );
}

/// Low-level transport seams. The defaults bind to a real [SupabaseClient];
/// tests inject fakes so the service's payload-shaping + response-mapping logic
/// can be exercised without the plugin.
typedef InvokeFn = Future<Map<String, dynamic>> Function(
    String fn, Map<String, dynamic> body);
typedef RpcFn = Future<List<dynamic>> Function(
    String fn, Map<String, dynamic> params);

/// Submits replay-verified runs and fetches daily per-tier leaderboards.
///
/// The client NEVER submits a score number — only the move log. The
/// `submit-score` Edge Function replays it and computes the authoritative
/// score. Isolates supabase_flutter so callers depend on this service only.
class LeaderboardService {
  final InvokeFn _invoke;
  final RpcFn _rpc;

  /// Production constructor: wires the seams to [client].
  LeaderboardService(SupabaseClient client)
      : _invoke = ((fn, body) async {
          final res = await client.functions.invoke(fn, body: body);
          final data = res.data;
          if (data is Map) return Map<String, dynamic>.from(data);
          return <String, dynamic>{'valid': false};
        }),
        _rpc = ((fn, params) async {
          final res = await client.rpc(fn, params: params);
          return (res as List?) ?? const [];
        });

  /// Test constructor: inject the transport seams directly.
  LeaderboardService.withSeams({required InvokeFn invoke, required RpcFn rpc})
      : _invoke = invoke,
        _rpc = rpc;

  /// Submit a completed run for verification. Sends the move log (and date +
  /// difficulty) to the `submit-score` function. Throws on transport errors so
  /// callers can queue + retry; returns an invalid [SubmitResult] when the
  /// server rejected the run.
  Future<SubmitResult> submitRun({
    required String date,
    required Difficulty difficulty,
    required List<MoveEvent> moveLog,
  }) async {
    final data = await _invoke('submit-score', {
      'date': date,
      'difficulty': difficulty.name,
      'moveLog': moveLog.map((e) => e.toJson()).toList(),
    });
    return SubmitResult.fromJson(data);
  }

  /// Fetch a tier's daily leaderboard (top [limit] + the caller's own row flag),
  /// via the `leaderboard` RPC.
  Future<List<LeaderboardEntry>> fetch({
    required Difficulty difficulty,
    required String date,
    int limit = 100,
  }) async {
    final rows = await _rpc('leaderboard', {
      'p_date': date,
      'p_diff': difficulty.name,
      'p_limit': limit,
    });
    return rows
        .map((e) =>
            LeaderboardEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
