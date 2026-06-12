import 'package:flutter/material.dart';

import '../../domain/constants.dart';

/// First-run coachmark overlay (Phase 4). Shown once, over the real board, to
/// teach the three things a new player must grasp before the merge-anywhere
/// rule "clicks": drag any tile onto an equal one (no gravity/rows), the day is
/// a fixed [kMovesPerDay]-move budget, and a board with no equal pair is a
/// deadlock that ends the run.
///
/// Pure presentation. The parent decides WHEN to show it (gated by the
/// `tutorialSeen` profile flag) and persists that flag in [onDismiss] BEFORE
/// removing the overlay, so it can never re-appear on relaunch. Skippable at any
/// step via the "Skip" affordance (which also dismisses).
class TutorialOverlay extends StatefulWidget {
  /// Called exactly once when the player finishes the last step OR skips. The
  /// parent MUST persist `tutorialSeen = true` here before tearing the overlay
  /// down (failure mode: overlay shows every launch).
  final VoidCallback onDismiss;

  const TutorialOverlay({super.key, required this.onDismiss});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialStep {
  final IconData icon;
  final String title;
  final String body;
  const _TutorialStep(this.icon, this.title, this.body);
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  int _step = 0;

  static const _steps = <_TutorialStep>[
    _TutorialStep(
      Icons.touch_app,
      'Merge anywhere',
      'Drag any tile onto another tile of the SAME value to combine them — '
          'no rows, no gravity. Anywhere on the board works.',
    ),
    _TutorialStep(
      Icons.timer_outlined,
      '$kMovesPerDay moves a day',
      'You get exactly $kMovesPerDay merges per daily puzzle. Spend them well '
          '— the higher you climb, the higher your score.',
    ),
    _TutorialStep(
      Icons.warning_amber_rounded,
      'Mind the deadlock',
      'If no two tiles share a value, there is no legal merge and the run '
          'ends. Plan ahead so you always leave yourself a pair.',
    ),
  ];

  bool get _isLast => _step >= _steps.length - 1;

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      setState(() => _step++);
    }
  }

  /// Persist + dismiss exactly once (guards against a double tap on the last
  /// step racing two dismissals).
  bool _dismissed = false;
  void _finish() {
    if (_dismissed) return;
    _dismissed = true;
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    return Material(
      key: const Key('tutorial-overlay'),
      color: Colors.black.withValues(alpha: 0.82),
      child: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  key: const Key('tutorial-skip'),
                  onPressed: _finish,
                  child: const Text('Skip',
                      style: TextStyle(color: Colors.white70)),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(step.icon, color: Colors.amberAccent, size: 64),
                    const SizedBox(height: 24),
                    Text(step.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    Text(step.body,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            height: 1.4)),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _steps.length; i++)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _step
                                  ? Colors.amberAccent
                                  : Colors.white24,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('tutorial-next'),
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(_isLast ? "Let's play" : 'Next',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
