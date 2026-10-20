---
name: responsive-layout
description: Placing player seats, cards, the table oval and controls on the Texas/Dice Dash and Blackjack screens so nothing overlaps on small landscape phones (~360 dp high) and it still looks good on PC. Use when touching lib/ui/layout/seat_layout.dart, game_table_screen.dart or blackjack_table_screen.dart layout code.
---

# Responsive table layout

## Scale
- `s = SeatLayout.tableScale(size) = min(w / 800, h / 400).clamp(0.5, 1.3)`. Scale from BOTH
  dimensions; a phone in landscape is ~800x360 dp. Every size in widgets is `x * _s`.
- Cards scale internally by `SeatLayout.cardAutoScale(w)`; account for it in seat sizes.

## Poker (Texas / Dice Dash) - `lib/ui/layout/seat_layout.dart`
- `SeatLayout.placeOpponents(size, opponents, diceMode)` returns one rect per opponent,
  ordered clockwise from the local player's left, plus `scale` (shrink 0.5-1.0) and `table`.
- Preferred: `_placeOnEllipse` spreads seats by ARC LENGTH along the upper half of an ellipse
  (left -> top -> right). The ellipse spans from the header to just above the action panel /
  roll / start buttons. It shrinks by 0.94 until no seat overlaps another seat or any
  `fixedObstacles` rect. Fallback: `_placeInColumns` (left column, top row, right column).
- `fixedObstacles` must mirror the real widgets (header, local seat, community cards, action
  panel, roll button, start button, dice). If you move one of those widgets, update its rect
  here in the same change, or the layout and its tests lie.
- `SeatLayout.tableRect` is the felt oval; seats may sit on its rail, never on the community cards.
- `opponentSeatSize` must match `_PlayerSeat` (name row 18*s fixed + chips row + cards).
  Seats get `width: rect.width` as a MIN width so the ring looks uniform; `FittedBox(scaleDown)`
  is the last-resort guard against overflow.

## Blackjack - `blackjack_table_screen.dart`
- Dealer top-center, rules text in `Expanded` flanks beside it (never underneath it).
- All player seats in one `Row` of `Expanded` (compact at 5+), wrapped in `FittedBox(scaleDown)`,
  starting below the dealer at `112 * _s`. Never let a seat get narrower than ~110 dp.
- Header: `Stack` with the title centered over the side `Row`.

## Done means
- `flutter test test/seat_layout_test.dart` passes (sizes 640x360 ... 1920x1080, 1-7 opponents,
  dice on/off, no overlaps, inside the screen). Add sizes/cases there when you add a constraint.
- `visual-qa` skill run with 0 `overflowed` lines and the PNGs looked at.
