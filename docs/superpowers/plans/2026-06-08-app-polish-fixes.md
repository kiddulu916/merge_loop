# App Polish Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the launcher name, surface the already-built leaderboards, make Share screenshot the result into Facebook, and add a Main Menu button to the result screen.

**Architecture:** Four independent changes. Three are pure Flutter/Dart with widget tests using the codebase's seam-injection pattern. One (Facebook share) adds a thin Android `MethodChannel` that hands a PNG to the Facebook app via an `ACTION_SEND` intent, with an OS-share-sheet fallback. One (leaderboards) is build-config + a discoverability button — the screens already exist.

**Tech Stack:** Flutter, flutter_bloc, share_plus, path_provider, Supabase (already integrated), Kotlin (Android host), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-06-08-app-polish-fixes-design.md`

---

## File Structure

**Created:**
- `lib/infrastructure/score_sharer.dart` — `ScoreSharer` interface + `PlatformScoreSharer` (Facebook intent via MethodChannel + share_plus fallback).
- `android/app/src/main/res/xml/provider_paths.xml` — FileProvider path config for the shared PNG.
- `env/supabase.example.json` — committed template for build-time Supabase keys.
- `docs/BUILD.md` — how to build with online features enabled.

**Modified:**
- `android/app/src/main/AndroidManifest.xml` — label, FileProvider, Facebook package query.
- `ios/Runner/Info.plist` — `CFBundleName` (consistency only).
- `android/app/src/main/kotlin/com/kiddulu/merge_loop/MainActivity.kt` — MethodChannel handler.
- `lib/presentation/screens/score_share_screen.dart` — screenshot capture, `ScoreSharer` seam, Main Menu button.
- `lib/presentation/screens/game_screen.dart` — pass `onMainMenu`.
- `lib/presentation/screens/tier_select_screen.dart` — prominent Leaderboard button + offline snackbar.
- `.gitignore` — ignore `env/supabase.json`.
- `test/presentation/score_share_screen_test.dart` — replace clipboard test with share-seam tests + Main Menu test.
- `test/presentation/tier_select_screen_test.dart` — Leaderboard button tests.

---

## Task 1: Launcher display name → "Merge Loop"

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml:9`
- Modify: `ios/Runner/Info.plist:43`

- [ ] **Step 1: Change the Android launcher label**

In `android/app/src/main/AndroidManifest.xml`, change line 9:

```xml
        android:label="Merge Loop"
```

(was `android:label="merge_loop"`)

- [ ] **Step 2: Change the iOS bundle name for consistency**

In `ios/Runner/Info.plist`, change the `CFBundleName` value (line 43) from `merge_loop` to:

```xml
	<string>Merge Loop</string>
```

(`CFBundleDisplayName` on line 35 is already `Merge Loop`; this is for internal consistency only.)

- [ ] **Step 3: Verify the analyzer is still clean**

Run: `flutter analyze`
Expected: `No issues found!` (these are resource files; this just confirms nothing else broke.)

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "fix: launcher label reads 'Merge Loop'"
```

---

## Task 2: "Main Menu" button on the result screen

**Files:**
- Modify: `lib/presentation/screens/score_share_screen.dart`
- Modify: `lib/presentation/screens/game_screen.dart:109-118`
- Test: `test/presentation/score_share_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Replace the entire body of `test/presentation/score_share_screen_test.dart` with this (the old clipboard test is removed; the share-seam tests are added in Task 5):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_loop/domain/constants.dart';
import 'package:merge_loop/domain/models/board_state.dart';
import 'package:merge_loop/domain/models/game_status.dart';
import 'package:merge_loop/domain/models/tile.dart';
import 'package:merge_loop/infrastructure/storage_service.dart';
import 'package:merge_loop/presentation/screens/score_share_screen.dart';

BoardState _board() {
  final cells = List<Tile?>.filled(kCellCount, null);
  cells[0] = const Tile(id: 1, tier: 6);
  return BoardState(
    cells: cells,
    movesRemaining: 0,
    score: 1234,
    nextTileId: 2,
    dropIndex: 0,
    adContinuesUsed: 0,
    movesMade: 30,
    status: GameStatus.outOfMoves,
  );
}

const _stats = LifetimeStats(
    streak: 4, lastCompletedDate: '2026-06-06', bestScore: 5000, bestTier: 9);

void main() {
  testWidgets('shows the core stats', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ScoreShareScreen(
        board: _board(),
        date: '2026-06-06',
        stats: _stats,
        canOfferAd: false,
        onWatchAd: () {},
      ),
    ));
    expect(find.text('1234'), findsWidgets); // score
    expect(find.textContaining('4'), findsWidgets); // streak
  });

  testWidgets('Main Menu button invokes onMainMenu', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: ScoreShareScreen(
        board: _board(),
        date: '2026-06-06',
        stats: _stats,
        canOfferAd: false,
        onWatchAd: () {},
        onMainMenu: () => tapped++,
      ),
    ));

    expect(find.byKey(const Key('main-menu-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('main-menu-button')));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('Main Menu button is hidden when no callback given',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ScoreShareScreen(
        board: _board(),
        date: '2026-06-06',
        stats: _stats,
        canOfferAd: false,
        onWatchAd: () {},
      ),
    ));
    expect(find.byKey(const Key('main-menu-button')), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/presentation/score_share_screen_test.dart`
Expected: FAIL — `ScoreShareScreen` has no `onMainMenu` parameter (compile error).

- [ ] **Step 3: Add the `onMainMenu` field and button**

In `lib/presentation/screens/score_share_screen.dart`, add the field to the class (next to the other callbacks, after `onWatchAd`):

```dart
  /// Returns to the main menu (tier select). When null, no button is shown.
  final VoidCallback? onMainMenu;
```

Add it to the constructor parameter list (after `required this.onWatchAd,`):

```dart
    this.onMainMenu,
```

Then, in `build`, insert the Main Menu button immediately after the existing Share `FilledButton` (the block ending at the `child: const Text('Share')` button, around line 89):

```dart
              if (onMainMenu != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('main-menu-button'),
                  onPressed: onMainMenu,
                  child: const Text('Main Menu'),
                ),
              ],
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/presentation/score_share_screen_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Wire `onMainMenu` from GameScreen**

In `lib/presentation/screens/game_screen.dart`, in `_buildResult` (the `return ScoreShareScreen(...)` around line 109), add this argument:

```dart
      onMainMenu: () => Navigator.of(context).pop(),
```

The result screen is rendered inside the game route, so popping returns to `TierSelectScreen`, which already refreshes its "done today" badges via the `.then(...)` on its push (`tier_select_screen.dart:220`).

- [ ] **Step 6: Verify analyzer + tests**

Run: `flutter analyze && flutter test test/presentation/score_share_screen_test.dart`
Expected: `No issues found!` then PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/screens/score_share_screen.dart lib/presentation/screens/game_screen.dart test/presentation/score_share_screen_test.dart
git commit -m "feat(ui): add Main Menu button to result screen"
```

---

## Task 3: Prominent Leaderboard button on the main menu

**Files:**
- Modify: `lib/presentation/screens/tier_select_screen.dart`
- Test: `test/presentation/tier_select_screen_test.dart`

- [ ] **Step 1: Write the failing tests**

Append these two tests inside the `main()` block of `test/presentation/tier_select_screen_test.dart` (before the final closing `}` of `main`, after the existing tests):

```dart
  testWidgets('main-menu Leaderboard button is always visible', (tester) async {
    final storage = InMemoryStorageService();
    await tester.pumpWidget(MaterialApp(
      home: TierSelectScreen(
        storage: storage,
        adService: AdService(),
        todayProvider: () => '2026-06-07',
        onTierSelected: (_, __) {},
      ),
    ));
    expect(find.byKey(const Key('open-leaderboard-menu')), findsOneWidget);
  });

  testWidgets('offline, tapping Leaderboard shows an explanatory snackbar',
      (tester) async {
    final storage = InMemoryStorageService();
    await tester.pumpWidget(MaterialApp(
      home: TierSelectScreen(
        storage: storage,
        adService: AdService(),
        todayProvider: () => '2026-06-07',
        onTierSelected: (_, __) {},
      ),
    ));

    await tester.tap(find.byKey(const Key('open-leaderboard-menu')));
    await tester.pump(); // start the snackbar animation
    expect(find.text('Leaderboards need an internet connection.'),
        findsOneWidget);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/presentation/tier_select_screen_test.dart`
Expected: FAIL — no widget with key `open-leaderboard-menu`.

- [ ] **Step 3: Add the button + offline handler**

In `lib/presentation/screens/tier_select_screen.dart`, add this method next to `_openLeaderboard` (after the existing `_openLeaderboard` method, around line 181):

```dart
  /// Main-menu entry point: open the leaderboard when online, otherwise explain
  /// why it's unavailable. Always reachable so there's a visible button.
  void _openLeaderboardOrExplain(BuildContext context) {
    if (widget.leaderboard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Leaderboards need an internet connection.')),
      );
      return;
    }
    _openLeaderboard(context, Difficulty.values.first);
  }
```

Then add the button to `build`. Insert it immediately after the `Resets in ...` countdown `Text` widget and before the `const SizedBox(height: 24)` that precedes the `Expanded(child: ListView(...))` (around line 386):

```dart
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('open-leaderboard-menu'),
                onPressed: () => _openLeaderboardOrExplain(context),
                icon: const Icon(Icons.leaderboard, color: Colors.white),
                label: const Text('Leaderboard'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/tier_select_screen_test.dart`
Expected: PASS (all tests, including the new two).

- [ ] **Step 5: Verify analyzer + full suite**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` then all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/tier_select_screen.dart test/presentation/tier_select_screen_test.dart
git commit -m "feat(ui): add prominent Leaderboard button to main menu"
```

---

## Task 4: Wire Supabase keys into builds (+ backend deploy)

This task connects the existing online layer. No app code changes — the leaderboard/Friends screens and services already exist; they were dark only because the app shipped without `SUPABASE_URL` / `SUPABASE_ANON_KEY`.

**Files:**
- Create: `env/supabase.example.json`
- Create: `docs/BUILD.md`
- Modify: `.gitignore`

- [ ] **Step 1: Create the committed key template**

Create `env/supabase.example.json`:

```json
{
  "SUPABASE_URL": "https://YOUR-PROJECT-REF.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR-ANON-PUBLISHABLE-KEY"
}
```

- [ ] **Step 2: Git-ignore the real key file**

Append to `.gitignore` (under the existing "Secrets / Supabase local state" section):

```gitignore
env/supabase.json
```

- [ ] **Step 3: Create the real key file locally (NOT committed)**

Create `env/supabase.json` with the real values from your Supabase project (Project Settings → API → Project URL and the `anon`/publishable key):

```json
{
  "SUPABASE_URL": "https://<your-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<your-anon-key>"
}
```

Confirm it is ignored:

Run: `git status --porcelain env/supabase.json`
Expected: no output (the file is ignored).

- [ ] **Step 4: Document the build in `docs/BUILD.md`**

Create `docs/BUILD.md`:

```markdown
# Building Merge Loop

## Online features (leaderboards, friends)

The global + Friends leaderboards require Supabase credentials injected at
build time. Without them the app runs offline and the leaderboard entry
points are disabled (the main-menu Leaderboard button shows an
"internet connection" message).

1. Copy `env/supabase.example.json` to `env/supabase.json` and fill in your
   project URL + anon (publishable) key. `env/supabase.json` is git-ignored.
2. Build/run with the key file:

   ```bash
   flutter run --dart-define-from-file=env/supabase.json
   flutter build apk --release --dart-define-from-file=env/supabase.json
   ```

`env/supabase.example.json` is committed as a template; never commit
`env/supabase.json`.

## Backend

The database schema lives in `supabase/migrations/`. Deploy it with the
Supabase CLI (a local dev dependency):

```bash
npx supabase link --project-ref <your-ref>
npx supabase db push
```
```

- [ ] **Step 5: USER ACTION — deploy + verify the backend**

> This step needs your Supabase project ref and access; it cannot be done from app code alone. The leaderboards will show the empty/error state until the schema is deployed.

```bash
npx supabase link --project-ref <your-ref>
npx supabase db push
```

Verify the RPCs the app calls now exist (Supabase SQL editor, or `npx supabase db remote ...`):

```sql
select proname
from pg_proc
where proname in ('ensure_friend_code', 'redeem_code')
order by proname;
```

Expected: both `ensure_friend_code` and `redeem_code` are listed. (These back `FriendsService`; the leaderboard read RPCs from migrations `0001`/`0003` should likewise be present.)

- [ ] **Step 6: Build with keys and confirm the boards light up**

Run: `flutter build apk --release --dart-define-from-file=env/supabase.json`
Then install and launch on a device. Expected: the main-menu **Leaderboard** button opens a populated board; the per-tier leaderboard icons and the Friends header icon are now visible; the Global/Friends toggle works.

- [ ] **Step 7: Commit (template + docs + gitignore only)**

```bash
git add env/supabase.example.json docs/BUILD.md .gitignore
git commit -m "build: inject Supabase keys via --dart-define-from-file"
```

---

## Task 5: Facebook share — capture + ScoreSharer seam (Dart/UI)

This makes the Share button screenshot the result card and hand it to a `ScoreSharer`. The real platform implementation is added in Task 6; here we add the interface, the capture, the UI wiring, and tests with a fake.

**Files:**
- Create: `lib/infrastructure/score_sharer.dart`
- Modify: `lib/presentation/screens/score_share_screen.dart`
- Test: `test/presentation/score_share_screen_test.dart`

- [ ] **Step 1: Create the `ScoreSharer` interface (real impl filled in Task 6)**

Create `lib/infrastructure/score_sharer.dart`:

```dart
import 'dart:typed_data';

/// Shares a rendered PNG of the result card. Two stages so the UI can fall back
/// when Facebook isn't installed.
abstract class ScoreSharer {
  const ScoreSharer();

  /// Hand [pngBytes] to the Facebook app's composer. Returns true if Facebook
  /// handled it, false if it isn't installed (or the platform can't target it).
  Future<bool> shareToFacebook(Uint8List pngBytes);

  /// Fallback: share [pngBytes] via the OS share sheet.
  Future<void> shareToSheet(Uint8List pngBytes);
}
```

(The concrete `PlatformScoreSharer` is added to this file in Task 6, Step 1.)

- [ ] **Step 2: Write the failing tests**

Append these tests inside the `main()` block of `test/presentation/score_share_screen_test.dart` (after the Task 2 tests), and add the imports at the top of the file:

Add to the imports:

```dart
import 'dart:typed_data';
import 'package:merge_loop/infrastructure/score_sharer.dart';
```

Add this fake above `void main()`:

```dart
class _FakeSharer implements ScoreSharer {
  _FakeSharer(this.facebookSucceeds);
  final bool facebookSucceeds;
  int fbCalls = 0;
  int sheetCalls = 0;

  @override
  Future<bool> shareToFacebook(Uint8List pngBytes) async {
    fbCalls++;
    return facebookSucceeds;
  }

  @override
  Future<void> shareToSheet(Uint8List pngBytes) async {
    sheetCalls++;
  }
}
```

Add these tests inside `main()`:

```dart
  testWidgets('Share sends the screenshot to Facebook', (tester) async {
    final sharer = _FakeSharer(true);
    await tester.pumpWidget(MaterialApp(
      home: ScoreShareScreen(
        board: _board(),
        date: '2026-06-06',
        stats: _stats,
        canOfferAd: false,
        onWatchAd: () {},
        sharer: sharer,
        captureOverride: () async => Uint8List.fromList([1, 2, 3]),
      ),
    ));

    await tester.tap(find.byKey(const Key('share-card-button')));
    await tester.pumpAndSettle();

    expect(sharer.fbCalls, 1);
    expect(sharer.sheetCalls, 0);
  });

  testWidgets('Share falls back to the OS sheet when Facebook is absent',
      (tester) async {
    final sharer = _FakeSharer(false);
    await tester.pumpWidget(MaterialApp(
      home: ScoreShareScreen(
        board: _board(),
        date: '2026-06-06',
        stats: _stats,
        canOfferAd: false,
        onWatchAd: () {},
        sharer: sharer,
        captureOverride: () async => Uint8List.fromList([1, 2, 3]),
      ),
    ));

    await tester.tap(find.byKey(const Key('share-card-button')));
    await tester.pumpAndSettle();

    expect(sharer.fbCalls, 1);
    expect(sharer.sheetCalls, 1);
  });
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/presentation/score_share_screen_test.dart`
Expected: FAIL — `ScoreShareScreen` has no `sharer` / `captureOverride` parameters (compile error).

- [ ] **Step 4: Update `ScoreShareScreen` — capture + seams + new `_share`**

In `lib/presentation/screens/score_share_screen.dart`:

(a) Update the imports at the top to:

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models/achievement.dart';
import '../../domain/models/board_state.dart';
import '../../infrastructure/friends_service.dart';
import '../../infrastructure/score_sharer.dart';
import '../../infrastructure/storage_service.dart';
```

(Removes only `package:flutter/services.dart` and `share_grid_builder.dart` — the clipboard path and emoji-grid text are gone. `share_plus` and `friends_service` stay because the existing "Invite a friend" CTA still uses them.)

(b) Add fields (after `final Set<Achievement> newlyUnlocked;`). Keep the existing `shareText` field as-is — it still backs the invite CTA:

```dart
  /// Performs the actual score share. Production uses [PlatformScoreSharer];
  /// tests inject a fake.
  final ScoreSharer sharer;

  /// Test seam: returns the PNG bytes to share, bypassing real rendering.
  /// Production leaves this null and captures the on-screen card.
  final Future<Uint8List?> Function()? captureOverride;
```

(c) Update the constructor: keep `this.shareText,` and add the new defaults:

```dart
    this.onMainMenu,
    this.sharer = const PlatformScoreSharer(),
    this.captureOverride,
```

(d) Add a `GlobalKey` field for the card and a capture helper. Add the key as a field near the top of the class:

```dart
  /// Wraps the visual card so it can be rasterised for sharing.
  final GlobalKey _cardKey = GlobalKey();
```

Wrap the card content in a `RepaintBoundary`. Extract the title + stats + achievements into the boundary. In `build`, replace the children from the `Text('Daily Result')` through the achievements block (everything before the `const SizedBox(height: 24)` that precedes the buttons) with:

```dart
              RepaintBoundary(
                key: _cardKey,
                child: Container(
                  color: const Color(0xFF12141C),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Daily Result',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 24),
                      _bigStat('SCORE', '${board.score}'),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _smallStat('BEST TILE', '${1 << board.highestTier}'),
                          _smallStat('MOVES', '${board.movesMade}'),
                          _smallStat('STREAK', '${stats.streak}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _smallStat('BEST EVER', '${stats.bestScore}'),
                      if (newlyUnlocked.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _achievementsBanner(),
                      ],
                    ],
                  ),
                ),
              ),
```

(e) Delete the old `_cardText()` and `_share()` methods (the clipboard/emoji-grid path) and replace them with the capture + share logic below. **Leave `_invite()`, `_nativeShare()`, and the `if (friendCode != null) ...` invite button block in `build` untouched** — the invite CTA keeps working through `share_plus`:

```dart
  Future<Uint8List?> _capture() async {
    final override = captureOverride;
    if (override != null) return override();
    final ctx = _cardKey.currentContext;
    if (ctx == null) return null;
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _share(BuildContext context) async {
    final png = await _capture();
    if (png == null) return;
    final reached = await sharer.shareToFacebook(png);
    if (!reached) await sharer.shareToSheet(png);
  }
```

The Share `FilledButton` (`key: 'share-card-button'`) keeps calling `_share(context)` — only the method body changed.

> Decision note: only the *score* share switches to the screenshot (Facebook ignores pre-filled text, so the emoji grid is replaced by the image). The invite link still shares as text via the native sheet — that's a different target. `ShareGridBuilder` is now unused by this screen but is still covered by its own unit tests; do not delete it.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/presentation/score_share_screen_test.dart`
Expected: PASS (all tests). The fake `sharer` + `captureOverride` make the Share path deterministic with no real rendering.

- [ ] **Step 6: Verify analyzer**

Run: `flutter analyze`
Expected: `No issues found!` (Resolve any "unused" warnings by removing the now-dead `friendCode` field/import only if flagged.)

- [ ] **Step 7: Commit**

```bash
git add lib/infrastructure/score_sharer.dart lib/presentation/screens/score_share_screen.dart test/presentation/score_share_screen_test.dart
git commit -m "feat(share): screenshot result card behind a ScoreSharer seam"
```

---

## Task 6: Facebook share — native Android intent + production wiring

Adds the real `PlatformScoreSharer`, the `MethodChannel` handler, the FileProvider, and the manifest entries so production builds open Facebook's composer with the screenshot attached.

**Files:**
- Modify: `lib/infrastructure/score_sharer.dart`
- Modify: `android/app/src/main/kotlin/com/kiddulu/merge_loop/MainActivity.kt`
- Create: `android/app/src/main/res/xml/provider_paths.xml`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Implement `PlatformScoreSharer`**

In `lib/infrastructure/score_sharer.dart`, add these imports at the **top** of the file (below the existing `import 'dart:typed_data';`):

```dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
```

Then add this class at the **end** of the file (after the abstract `ScoreSharer`):

```dart
// Production sharer. Tries to open the Facebook app via a platform channel
// (Android ACTION_SEND to com.facebook.katana); falls back to the OS sheet.
class PlatformScoreSharer extends ScoreSharer {
  const PlatformScoreSharer();

  static const MethodChannel _channel = MethodChannel('merge_loop/facebook_share');

  @override
  Future<bool> shareToFacebook(Uint8List pngBytes) async {
    try {
      final ok = await _channel.invokeMethod<bool>('shareImage', {
        'bytes': pngBytes,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // Non-Android / channel not registered: let the caller fall back.
      return false;
    }
  }

  @override
  Future<void> shareToSheet(Uint8List pngBytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/merge_loop_score.png');
    await file.writeAsBytes(pngBytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], subject: 'Merge Loop');
  }
}
```

> Note: `dart:typed_data` is already imported at the top of the file from Task 5; do not import it twice.

- [ ] **Step 2: Add the MethodChannel handler in `MainActivity`**

Replace the contents of `android/app/src/main/kotlin/com/kiddulu/merge_loop/MainActivity.kt` with:

```kotlin
package com.kiddulu.merge_loop

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "merge_loop/facebook_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "shareImage") {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null) {
                        result.success(false)
                    } else {
                        result.success(shareToFacebook(bytes))
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    /** Write the PNG and hand it to the Facebook app. Returns false if FB is
     *  not installed so Dart can fall back to the OS share sheet. */
    private fun shareToFacebook(bytes: ByteArray): Boolean {
        return try {
            val dir = File(cacheDir, "shared").apply { mkdirs() }
            val file = File(dir, "score.png")
            file.writeBytes(bytes)
            val uri = FileProvider.getUriForFile(
                this, "$packageName.fileprovider", file
            )
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                setPackage("com.facebook.katana")
            }
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: Exception) {
            false
        }
    }
}
```

- [ ] **Step 3: Create the FileProvider paths file**

Create `android/app/src/main/res/xml/provider_paths.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <cache-path name="shared" path="shared/" />
</paths>
```

- [ ] **Step 4: Declare the FileProvider and Facebook package query in the manifest**

In `android/app/src/main/AndroidManifest.xml`, add this `<provider>` inside `<application>` (e.g. right after the closing `</activity>` tag, before the `flutterEmbedding` meta-data):

```xml
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/provider_paths" />
        </provider>
```

Then add the Facebook package to the existing `<queries>` block (after the closing `</intent>`, before `</queries>`):

```xml
        <package android:name="com.facebook.katana" />
```

> The `${applicationId}` placeholder resolves to `com.kiddulu.merge_loop` (from `android/app/build.gradle`). This authority differs from share_plus's own provider, so there is no conflict.

- [ ] **Step 5: Verify the build compiles**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter build apk --debug --dart-define-from-file=env/supabase.json`
Expected: BUILD SUCCESSFUL (confirms the Kotlin + manifest + provider compile and merge).

- [ ] **Step 6: Manual device verification**

- On a device **with** Facebook installed: finish a round → tap **Share** → the Facebook composer opens with the score-card screenshot attached and an empty caption.
- On a device/emulator **without** Facebook: tap **Share** → the OS share sheet opens with the same PNG.

- [ ] **Step 7: Commit**

```bash
git add lib/infrastructure/score_sharer.dart android/app/src/main/kotlin/com/kiddulu/merge_loop/MainActivity.kt android/app/src/main/res/xml/provider_paths.xml android/app/src/main/AndroidManifest.xml
git commit -m "feat(share): open Facebook composer with the score screenshot"
```

---

## Final Verification

- [ ] **Run the full suite + analyzer**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` and all tests PASS.

- [ ] **Confirm each spec requirement is covered**

- #1 Launcher name → Task 1.
- #2 Leaderboards visible → Task 3 (button) + Task 4 (keys/deploy).
- #3 Share to Facebook → Tasks 5 + 6.
- #4 Main Menu button → Task 2.

---

## Notes for the implementer

- **Seam pattern:** this codebase tests UI by injecting fakes for platform/IO seams (see `LeaderboardService.withSeams`, the `shareText` seam this plan replaces). Keep the `sharer` + `captureOverride` seams; never reach a real `MethodChannel` or `boundary.toImage` in a widget test.
- **Image capture in tests is intentionally avoided** via `captureOverride` — `RenderRepaintBoundary.toImage` is unreliable headless.
- **Backend deploy (Task 4 Step 5) is a user action** — it needs the Supabase project ref + credentials and cannot be completed from app code. If skipped, the boards render their empty/error states even after key wiring.
- **iOS Facebook share is out of scope** (Android-only release). On iOS, `PlatformScoreSharer.shareToFacebook` returns false via `MissingPluginException` and the OS sheet fallback runs — a safe degrade if an iOS build is ever made.
