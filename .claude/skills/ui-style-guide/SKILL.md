---
name: ui-style-guide
description: Visual language of Poker Dice Dash (casino felt palette, oval table, seats, badges, buttons, Spanish UI copy, animation timing). Use whenever creating or restyling any screen, widget, dialog or animation so the game stays consistent.
---

# Poker Dice Dash UI style guide

The look is a dark, warm casino: green felt, wooden rail, gold trim, amber for
"your attention here". Landscape only. Everything scales with `_s` (see the
`responsive-layout` skill). Never hard-code pixel sizes without `* _s`.

## Palette (use these, do not invent new greens)
| Role | Value |
|---|---|
| Screen background (radial) | `0xFF0A4D28` center -> `0xFF052915` edge |
| Table felt (radial) | `0xFF168A4E` -> `0xFF0E6B3A` -> `0xFF0A5530` |
| Table rail (wood) | `0xFF3E2410`, outline `0xFF2A1708` |
| Gold trim / local player border | `0xFFD4AF37` (alpha 0.45-0.6 for lines) |
| Current turn / primary highlight | `Colors.amber` border + `amber @0.22` fill + amber glow |
| Seat panel | `0xFF07160D @0.82`, border `white24` |
| Money / balance | `Colors.greenAccent` (Blackjack header), chip counts in `Colors.amber` |
| Bet tag | orange pill (`Colors.deepOrange`-ish) with white text |
| Danger / fold / bust | `Colors.redAccent` |
| Secondary text | `white70`, hints `white54` |

## Components
- **Table**: stadium-shaped felt (`borderRadius = height / 2`) inside a 9*s wooden rail,
  black shadow blur ~22*s. Drawn by `_buildTableFelt` from `SeatLayout.tableRect`. Decorative only (`IgnorePointer`).
- **Opponent seat**: uniform size inside its layout rect. Name row has a FIXED height (18*s)
  so seats with a D/SB/BB badge are the same height as seats without one. Name: bold white 10*s,
  one line, ellipsis. Bots show `Icons.smart_toy` (white54), local shows `Icons.person` (amber).
- **Role badges**: 16*s circles. D = white/black, SB = lightBlue, BB = blue, D/SB pill 26x16.
- **Current turn**: amber 2px border + glow. Never signal turn with color alone in new
  widgets: also use a dot, icon or status text ("Turno de X...").
- **Folded**: cards at opacity 0.4. **Away (disconnected)**: `Icons.wifi_off` redAccent.
- **Buttons** (action dock): big rounded pills, icon + UPPERCASE label, colors by meaning:
  green = take a card / positive, red = stop / fold, orange = double / raise, blue = call/check.
- **Headers**: back button left, title centered on the SCREEN (use a `Stack` with the
  title centered over a `Row` of side items; never center between two unequal Spacers),
  balance right.
- **Watermark / rules text**: amber @0.18-0.22, letterSpacing 2. Never place it where a
  translucent panel sits on top of it (it shows through). Put it beside panels instead.

## Copy (Spanish, Spain/LatAm neutral)
- UI text is Spanish. Poker action words stay in English caps as players know them:
  FOLD, CALL, CHECK, RAISE, ALL-IN. Blackjack uses Spanish: PEDIR, PLANTAR, DOBLAR, DIVIDIR.
- Status lines: "Turno de {name}... pensando jugada", "Tu turno", "Barajando...".
- Money shown as `$900` in Blackjack, plain chip count in poker.

## Motion
- State changes 250 ms (`AnimatedContainer`), card deal ~350 ms per card, bot "thinking" 600-700 ms.
- Animations must never gate game logic: logic advances on its own timers; UI follows state.

## Before finishing a visual change
Run the `visual-qa` skill and look at the PNGs at 800x360, 640x360 and 1280x720.
