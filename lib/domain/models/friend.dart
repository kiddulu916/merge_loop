/// A friend (a mutual edge in the friend graph). [friendCode] is only known for
/// the current player / when surfaced; for listed friends it may be null.
class Friend {
  final String playerId;
  final String displayName;
  final String? friendCode;

  const Friend({
    required this.playerId,
    required this.displayName,
    this.friendCode,
  });

  static Friend fromJson(Map<String, dynamic> j) => Friend(
        playerId: (j['player_id'] ?? j['playerId']) as String,
        displayName: (j['display_name'] ?? j['displayName']) as String,
        friendCode: (j['friend_code'] ?? j['friendCode']) as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is Friend &&
      other.playerId == playerId &&
      other.displayName == displayName &&
      other.friendCode == friendCode;

  @override
  int get hashCode => Object.hash(playerId, displayName, friendCode);

  @override
  String toString() =>
      'Friend(playerId: $playerId, displayName: $displayName, friendCode: $friendCode)';
}

/// Outcome of redeeming a friend code (via the `redeem_code` RPC).
enum RedeemStatus { ok, invalidCode, self, unauthenticated, error }

class RedeemResult {
  final RedeemStatus status;

  /// The newly-added friend's player id, when [status] is [RedeemStatus.ok].
  final String? friendId;

  const RedeemResult(this.status, {this.friendId});

  bool get ok => status == RedeemStatus.ok;

  static RedeemResult fromJson(Map<String, dynamic> j) {
    if ((j['ok'] as bool?) == true) {
      return RedeemResult(RedeemStatus.ok, friendId: j['friend_id'] as String?);
    }
    switch (j['reason'] as String?) {
      case 'invalid_code':
        return const RedeemResult(RedeemStatus.invalidCode);
      case 'self':
        return const RedeemResult(RedeemStatus.self);
      case 'unauthenticated':
        return const RedeemResult(RedeemStatus.unauthenticated);
      default:
        return const RedeemResult(RedeemStatus.error);
    }
  }
}
