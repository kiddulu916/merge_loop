import 'dart:async';

import 'package:app_links/app_links.dart';

/// Parses invite deep links and bridges them to a redeem callback.
///
/// Supported forms:
///   mergecount://invite/<code>          (custom scheme)
///   https://mergecount.app/invite/<code> (App Links / Universal Links fallback)
///
/// The PURE part — [parseInviteCode] — is fully unit-tested. The app_links
/// wiring (cold-start `getInitialLink` + warm `uriLinkStream`) is isolated here
/// so it can be swapped/mocked. Per the spec failure-mode "lost on cold start":
/// a code parsed before auth is ready is QUEUED ([pendingCode]) and replayed by
/// the app once a session + display name exist.
class DeepLinkService {
  final AppLinks _appLinks;

  /// Called with a parsed invite code. May be invoked from cold start (initial
  /// link) and from warm resume (stream). If null at parse time, the code is
  /// queued in [pendingCode] for later replay.
  void Function(String code)? onInviteCode;

  /// A code captured before [onInviteCode] was wired (cold start before auth).
  /// The app consumes this via [takePendingCode] once it's ready to redeem.
  String? _pendingCode;
  StreamSubscription<Uri>? _sub;

  DeepLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  /// The queued cold-start code, if any (without clearing it).
  String? get pendingCode => _pendingCode;

  /// Pure parser: extract the invite code from a deep-link [uri], or null if it
  /// isn't an invite link. Accepts both the custom scheme and the https path.
  static String? parseInviteCode(Uri uri) {
    // mergecount://invite/<code>  → host == 'invite', first path segment is code.
    if (uri.scheme == 'mergecount') {
      if (uri.host == 'invite') {
        final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segs.isNotEmpty) return segs.first;
      }
      return null;
    }
    // https://<host>/invite/<code>
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segs.length >= 2 && segs[0] == 'invite') return segs[1];
      return null;
    }
    return null;
  }

  /// Parse a raw link string; null when it's not an invite link or unparsable.
  static String? parseInviteCodeString(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) return null;
    return parseInviteCode(uri);
  }

  /// Start listening: handle the cold-start link then subscribe to warm links.
  /// Safe to call once after the app boots.
  Future<void> init() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(initial);
    } catch (_) {
      // No initial link / platform not ready — ignore.
    }
    _sub = _appLinks.uriLinkStream.listen(_handle, onError: (_) {});
  }

  void _handle(Uri uri) {
    final code = parseInviteCode(uri);
    if (code == null) return;
    final cb = onInviteCode;
    if (cb != null) {
      cb(code);
    } else {
      _pendingCode = code; // queue for replay once the app is ready.
    }
  }

  /// Consume and clear the queued cold-start code (returns null if none).
  String? takePendingCode() {
    final c = _pendingCode;
    _pendingCode = null;
    return c;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
