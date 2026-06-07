import 'package:supabase_flutter/supabase_flutter.dart';

/// Anonymous sign-in + display-name management.
///
/// Isolates supabase_flutter auth so the rest of the app never imports the
/// plugin directly (mirrors [AdService]). Identity is anonymous-first: a fresh
/// install gets an anonymous session; the player then sets a display name which
/// is stored in the `players` table.
class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  /// The current authenticated user id, or null when signed out.
  String? get currentUserId => _client.auth.currentUser?.id;

  /// True when there is an active session.
  bool get isSignedIn => _client.auth.currentSession != null;

  /// Ensure an anonymous session exists. Idempotent: returns immediately if a
  /// session is already present, otherwise signs in anonymously.
  Future<void> ensureSignedIn() async {
    if (_client.auth.currentSession != null) return;
    await _client.auth.signInAnonymously();
  }

  /// The current player's display name, or null if they haven't set one yet
  /// (first run). Reads the player's own `players` row.
  Future<String?> displayName() async {
    final id = currentUserId;
    if (id == null) return null;
    final row = await _client
        .from('players')
        .select('display_name')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return row['display_name'] as String?;
  }

  /// True once a display name has been set (i.e. the player has onboarded).
  Future<bool> hasDisplayName() async => (await displayName()) != null;

  /// Persist the player's display name (+ optional avatar). Upserts the
  /// player's own row, keyed by their auth id.
  Future<void> setDisplayName(String name, {String? avatar}) async {
    final id = currentUserId;
    if (id == null) {
      throw StateError('Cannot set display name before signing in.');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 20) {
      throw ArgumentError('Display name must be 1-20 characters.');
    }
    await _client.from('players').upsert({
      'id': id,
      'display_name': trimmed,
      if (avatar != null) 'avatar': avatar,
    });
  }
}
