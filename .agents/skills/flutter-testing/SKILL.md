---
name: flutter-testing
description: Use when adding or running tests for Poker Dice Dash (hand evaluator, blackjack rules, provider flow, seat layout, protocol).
---

# Testing guide

- Run: `flutter analyze` then `flutter test`.
- Pure logic first: `HandEvaluator` (all hand ranks, kickers, ties), blackjack scoring (soft aces, 5-card Charlie, split/double), pot splitting.
- Layout: unit-test `computeSeatRects` for 2..8 players across the phone/PC sizes in the `flutter-responsive-layout` skill and assert no rectangle overlaps.
- Network: test `P2PService` framing (split/merged TCP chunks), `seq` dropping and token-based seat reclaim with fake sockets on `127.0.0.1`.
- Provider flow: simulate host + disconnected player on their turn and assert the round still advances (watchdog).
- Keep tests deterministic: inject `Random(seed)` and fake timers (`fakeAsync`).
