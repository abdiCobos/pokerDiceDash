---
name: flutter-responsive-layout
description: Use when placing player seats, cards or controls on the poker/blackjack tables so they never overlap on small phones (landscape ~360 dp high) and still look good on PC.
---

# Responsive table layout (Poker Dice Dash)

## Rules
1. Scale from BOTH dimensions: `s = min(w / 800, h / 400).clamp(0.5, 1.3)`. Never scale from width alone: a phone in landscape is ~850x380 dp.
2. Reserve space first, distribute the rest: header (pot/back), local seat (bottom), controls/action panel, community cards (center). Opponents use what is left.
3. Opponent seats sit on an ellipse inside the free rectangle (see `lib/ui/layout/seat_layout.dart`). Angles are spread evenly across the upper arc; never hard-code `Alignment` per player count.
4. Compact mode when `h < 450`: opponents show name + chips + small card strip (no badges text, no bet label).
5. Blackjack: 1-4 seats in one row; 5+ seats in two rows. Never use `Expanded` columns narrower than ~110 dp.
6. Always wrap seats in `FittedBox(fit: BoxFit.scaleDown)` as a last-resort guard against overflow.

## Checklist before finishing
- Test sizes: 640x360, 800x360, 851x393, 915x412, 1280x720, 1920x1080.
- 2, 4, 6 and 8 players at each size; no seat rectangle intersects another, the community cards, or the local seat.
- Use `test/seat_layout_test.dart` helpers to assert non-overlap.
