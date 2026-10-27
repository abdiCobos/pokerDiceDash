---
name: ui-style-guide
description: Visual language of Poker Dice Dash (casino felt palette, oval table, seats, badges, buttons, Spanish/English UI copy, animation timing). Use whenever creating or restyling any screen, widget, dialog or animation so the game stays consistent.
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
- **Pot**: `_PotText` badge ("BOTE 70" + chip) centered under the community cards at
  `SeatLayout.potRect`; pulses when it grows; the pot flies from there to the winner.
- **Bets**: `_BetStack` (chip by denomination + amount pill) on the felt at
  `SeatLayout.betRect` / `localBetRect`, sliding in from the seat (450 ms). When there is no
  free spot (crowded phone top row) the seat shows an orange inline pill next to its chips.
  Chip colors: white <20, red 20+, blue 50+, green 100+, black 500+ (`_chipAssetFor`).
- **Results**: poker `_ResultsBanner` (trophy, "¡Ganaste!" / "¡X gana!" / "¡Empate!", hand,
  green +amount pill) for ~2.8 s from `GameProvider.resultTitle/resultWinnerIds/resultAmount`
  (synced to clients), then a gold "GANADOR +N" ribbon stays on the winner seat until the
  next deal. Blackjack: per-seat pill at round end (BLACKJACK/CHARLIE gold, GANA green,
  EMPATE blue-grey, PIERDE/BUST red, with net chips) from `roundOutcome/roundNet`.
- **Main menu** (`lobby_screen.dart`): `AppLogo` (round felt emblem drawn by `AppIconPainter`, the
  same painter as the launcher icon, + title in the bundled `AlfaSlabOne` font with a gold gradient).
  Landscape = logo left / options right, never scrolls; portrait = logo on top. Modes are
  `_ModeTile`s (accent chip + name + tagline, hover/focus glow); bottom row = gold "Jugar en red"
  pill + "Cómo jugar" and "Ajustes" icon pills. Never use emoji/suit glyphs in UI text that must
  render everywhere: draw suits with `SpadePainter` (system fonts may lack '♠').
- **Screen transitions**: global fade + 0.94->1 zoom (`_TableFadeTransitionsBuilder` in main.dart).
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

## Copy (Spanish + English)
- NEVER write user-facing text as a literal. Add it to `tool/l10n_strings.py` (key -> (es, en)),
  run `python tool/l10n_strings.py && flutter gen-l10n`, then use `context.t.key` (`lib/l10n/l10n.dart`).
  Placeholders are Strings, in order of appearance in the Spanish text.
- The language is the device's (Spanish for `es`, English otherwise) or the one picked in Ajustes
  (`GameSettings().language`). Spanish stays neutral (Spain/LatAm).
- Providers never build sentences: they expose codes (`TableMessage`, `HostNotice`, `resultRank`,
  Blackjack outcome codes 'GANA'...) and the screens word them (`AppTexts` in l10n.dart), so on
  the LAN each player reads their own language. Keep sending the old Spanish `title` in the poker
  result for v1.1.0 clients.
- Poker action words stay English caps in both languages: FOLD, CALL, CHECK, RAISE, ALL-IN.
  Blackjack: PEDIR/PLANTAR/DOBLAR/DIVIDIR (es), HIT/STAND/DOUBLE/SPLIT (en).
- Money shown as `$900` in Blackjack, plain chip count in poker.
- Check both languages with the visual-qa harness (`--dart-define=LANG=en`).

## Cards
- Face-up cards are the PNGs in `assets/images/cards/`, drawn to FILL the card box.
- Card backs are drawn in code (`CardBackPainter` in `card_widget.dart`: red, gold inner border,
  diamond lattice, rounded shadow). Do not reintroduce a PNG back: it had a white/grey rim.
- The card box is `CardWidget.cardWidth/cardHeight * scale * CardWidget.autoScaleOf(context)`;
  any layout that reserves space for cards must use the same factor.

## Sound
- MP3 only (`assets/sounds/*.mp3`): Windows, macOS and iOS cannot decode OGG.
- Host/single player play sounds where the action happens (provider); LAN clients play the same
  sounds from state diffs (`_SoundSnapshot` in game_provider, `applyRemoteState` in blackjack).
  Community card flips play from the table widget. `test/sounds_test.dart` checks every table.

## Table options
- Gear `TableOptionsButton` (lib/ui/widgets/table_options.dart) in both table headers opens
  "Opciones": Sonido, Juego rápido (`GameSettings().pace` scales bot/dealer delays), Mostrar mi
  probabilidad (poker `_OddsPill` on the local seat), Pantalla siempre encendida, Salir de la mesa
  (top bar, reachable without scrolling). Settings live in `GameSettings` (persisted).

## Motion
- State changes 250 ms (`AnimatedContainer`), card deal ~350 ms per card, bot "thinking" 600-700 ms.
- Animations must never gate game logic: logic advances on its own timers; UI follows state.
- Animated widgets in variable-length lists (seats, bets) MUST have stable keys on the outermost
  widget (`ValueKey('seat_<id>')`, `ValueKey('betpos_<id>')`) and live in their own Stack layer;
  never toggle a wrapper widget (e.g. `if (folded) Opacity(...) else child`) around animated
  children: it rebuilds them and replays their animation. Fold = `_FoldAnimator`.
  Regression test: `test/table_identity_test.dart`.

- Dice roll (`_RollingDice`, keyed by `rollCounter`): 1150 ms tumble from the roller's seat with
  bounces and a landing squash, then a coloured event label (¡SUERTE!, ¡INTERCAMBIO!, ¡ALL-IN!,
  ¡ESPÍA!, ¡CARTA EXTRA!). Spied cards get a purple glow + eye icon; the discarded extra card
  fades and rises before it leaves.

## Scene backgrounds (themes)
- Menu and tables sit on `SceneBackground` (lib/ui/widgets/scene_background.dart), which follows
  `GameSettings().theme` (`TableTheme`: `clasico` (plain green, no picture), `cantina`, `garito`, `casino`; chosen in Ajustes, saved as `table_theme`; casino is the default on a fresh install).
- Every theme has three pixel-art PNGs in assets/images/cantina/, drawn by `tool/pixelart/cantina.py`
  (no external art): `<theme>_bg.png` 444x200 (phones ~20:9), `<theme>_bg_16x9.png` 356x200 (PC),
  `<theme>_menu.png` 200x444 (portrait menu). Shown with `FilterQuality.none`. Edit the script and run it
  (all scenes); never hand-edit PNGs. test/table_theme_test.dart checks every file exists.
- Felt and rail per theme: `TableFeltStyle.of(theme)` (casino: wine-red felt, gold rail edge).
- Ajustes shows the theme cards two per row (four in one row cut the names).
- Adding a theme: new enum value (label + description), a table and a menu scene in the script, a
  `TableFeltStyle`. Keep detail OUTSIDE the table oval (x 10-90 %, y 20-85 %); right-hand objects use `R(x)`.
- Controls over a scene need a dark backdrop (black54 disc / pill) to stay readable.

## Before finishing a visual change
Run the `visual-qa` skill and look at the PNGs at 800x360, 640x360 and 1280x720.
