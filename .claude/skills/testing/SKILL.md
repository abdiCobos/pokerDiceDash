---
name: testing
description: How to test Poker Dice Dash (analyze, unit tests for rules/layout/protocol, provider flow tests with fake time). Use when adding or running tests, or before committing any change to lib/.
---

# Testing guide

- Run: `flutter analyze` (compare the issue COUNT with the baseline; the repo has ~34
  pre-existing infos/warnings, do not add new ones) then `flutter test`.
- `flutter analyze`/`flutter test` regenerate `.flutter-plugins-dependencies` and
  `macos/Flutter/GeneratedPluginRegistrant.swift`. Never commit them unless the user asks;
  never `git stash` while they are dirty (the pop will conflict) - stash only paths you own.

## What to test
- Pure logic first: `HandEvaluator` (every rank, kickers, ties), blackjack scoring
  (soft aces, 5-card Charlie, split/double, payouts), pot splitting.
- Turn loop: a whole round with bots must reach its end phase. Pattern in
  `test/blackjack_bots_test.dart`: `testWidgets` + `tester.pump(Duration)` as fake time,
  the human acts ONCE per turn (multiple calls hide stalls), assert end phase, then
  `pump(5 s)` to drain timers. Write the test so it FAILS on the bug first.
- Bots: decision engines are pure Dart; test them with seeded `Random` and sample many
  seeds (see `test/poker_bot_ai_test.dart`), plus a full-flow test per mode and difficulty.
- Layout: `test/seat_layout_test.dart` asserts no overlaps across sizes and player counts.
- Network: `test/p2p_service_test.dart` with real sockets on 127.0.0.1.
- Visual: `visual-qa` skill (renders PNGs). Not a committed test.

## Determinism
Inject `Random(seed)` where a test depends on cards; otherwise loop enough rounds
(10-20) that random deals cover the branch you care about.
