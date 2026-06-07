import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models/difficulty.dart';
import '../../domain/models/friend.dart';
import '../../infrastructure/friends_service.dart';
import '../widgets/friends_leaderboard.dart';

/// Friends hub: your friend code + invite, add-by-code, optional contacts
/// matching (privacy-first), and the friends leaderboard for a tier.
///
/// Device-only flows (contacts permission prompt, native share sheet) are
/// delegated to [flutter_contacts] / [share_plus] and degrade gracefully:
/// denying contacts keeps the code path fully usable.
class FriendsScreen extends StatefulWidget {
  final FriendsService service;
  final Difficulty initialDifficulty;
  final String Function() todayProvider;

  /// Seam: load raw contact identifiers (phones + emails). Defaults to
  /// [flutter_contacts] with a permission request. Tests inject a fake so the
  /// privacy/match logic can be exercised without the plugin. Returns null when
  /// permission is denied.
  final Future<List<String>?> Function()? loadContacts;

  /// Seam: share the invite link. Defaults to the native share sheet.
  final Future<void> Function(String text)? shareInvite;

  const FriendsScreen({
    super.key,
    required this.service,
    required this.todayProvider,
    this.initialDifficulty = Difficulty.easy,
    this.loadContacts,
    this.shareInvite,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _codeController = TextEditingController();
  String? _myCode;
  String? _status;
  bool _busy = false;
  List<Friend> _matched = const [];

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadCode() async {
    try {
      final code = await widget.service.myFriendCode();
      if (mounted) setState(() => _myCode = code);
    } catch (_) {
      // Offline; leave code null. The list/board still attempt to load.
    }
  }

  Future<void> _redeem() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final res = await widget.service.redeemCode(code);
      if (!mounted) return;
      setState(() {
        switch (res.status) {
          case RedeemStatus.ok:
            _status = 'Friend added!';
            _codeController.clear();
          case RedeemStatus.self:
            _status = "That's your own code.";
          case RedeemStatus.invalidCode:
            _status = "We couldn't find that code.";
          case RedeemStatus.unauthenticated:
            _status = 'Sign in required.';
          case RedeemStatus.error:
            _status = 'Something went wrong. Try again.';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _status = 'Network error. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite() async {
    final code = _myCode;
    if (code == null) return;
    final link = FriendsService.inviteLink(code);
    final text = 'Add me on Merge Loop! $link';
    final share = widget.shareInvite ??
        (String t) async => Share.share(t, subject: 'Merge Loop invite');
    await share(text);
  }

  Future<void> _matchContacts() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final loader = widget.loadContacts ?? _defaultLoadContacts;
      final raw = await loader();
      if (raw == null) {
        // Permission denied: graceful fallback to friend codes.
        if (mounted) {
          setState(() => _status =
              'Contacts permission denied. You can still add friends by code.');
        }
        return;
      }
      // Opt in (store own hashes is a separate explicit step; here we match).
      final matches = await widget.service.matchContacts(raw);
      if (!mounted) return;
      setState(() {
        _matched = matches;
        _status = matches.isEmpty
            ? 'No contacts are on Merge Loop yet.'
            : 'Found ${matches.length} contact(s) on Merge Loop.';
      });
    } catch (_) {
      if (mounted) setState(() => _status = 'Could not match contacts.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Default contacts loader: request permission, read phones + emails.
  Future<List<String>?> _defaultLoadContacts() async {
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) return null;
    final contacts =
        await FlutterContacts.getContacts(withProperties: true);
    final ids = <String>[];
    for (final c in contacts) {
      for (final p in c.phones) {
        ids.add(p.number);
      }
      for (final e in c.emails) {
        ids.add(e.address);
      }
    }
    return ids;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12141C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12141C),
        foregroundColor: Colors.white,
        title: const Text('Friends'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('Your friend code'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _myCode ?? '…',
                  key: const Key('my-friend-code'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2),
                ),
              ),
              FilledButton.icon(
                key: const Key('invite-button'),
                onPressed: _myCode == null ? null : _invite,
                icon: const Icon(Icons.share),
                label: const Text('Invite'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionTitle('Add a friend by code'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('code-input'),
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Enter code',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('redeem-button'),
                onPressed: _busy ? null : _redeem,
                child: const Text('Add'),
              ),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: 8),
            Text(_status!,
                key: const Key('friends-status'),
                style: const TextStyle(color: Colors.white70)),
          ],
          const SizedBox(height: 24),
          _sectionTitle('Find friends from contacts'),
          const SizedBox(height: 4),
          const Text(
            'Your contacts never leave your device — only secure, '
            'anonymized fingerprints are checked against opted-in players.',
            key: Key('contacts-privacy-note'),
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('match-contacts-button'),
            onPressed: _busy ? null : _matchContacts,
            icon: const Icon(Icons.contacts),
            label: const Text('Match contacts'),
          ),
          for (final f in _matched)
            ListTile(
              key: Key('matched-${f.playerId}'),
              dense: true,
              title: Text(f.displayName,
                  style: const TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.person_add, color: Colors.white54),
            ),
          const SizedBox(height: 24),
          _sectionTitle('Friends leaderboard'),
          const SizedBox(height: 8),
          SizedBox(
            height: 320,
            child: FriendsLeaderboard(
              service: widget.service,
              difficulty: widget.initialDifficulty,
              date: widget.todayProvider(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800),
      );
}
