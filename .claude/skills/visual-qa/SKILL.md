---
name: visual-qa
description: Render the Poker Dice Dash tables (Texas, Dice Dash, Blackjack) to PNG at phone/tablet/PC sizes and inspect them. Use after ANY change to a table screen, seat layout, card/chip widget or theme, and before telling the user a visual change is done.
---

# Visual QA (render tables to PNG and look at them)

There is no emulator in this environment, so verify UI by rendering the real
screens inside `flutter test` with real fonts and reading the images.

## Run

1. Copy the harness into the test folder (the leading `_` marks it temporary):
   `cp .claude/skills/visual-qa/snapshot_test.dart.txt test/_visual_snapshot_test.dart`
2. Edit `sizes` / the cases at the bottom if the change needs a specific state
   (e.g. showdown, round end, 8 players, multiplayer waiting room).
3. Run it (Git Bash), writing PNGs to the session scratchpad:
   ```bash
   OUT="<scratchpad dir, forward slashes>"
   FONTS="$(cygpath -m "$(dirname $(dirname $(which flutter)))")/bin/cache/artifacts/material_fonts"
   flutter test test/_visual_snapshot_test.dart --dart-define=OUT=$OUT --dart-define=FONTS=$FONTS 2>&1 | grep -E "overflowed|passed|failed"
   ```
4. Open every PNG with the Read tool and actually look at it.
5. Clean up: `rm test/_visual_snapshot_test.dart` and
   `git checkout -- .flutter-plugins-dependencies macos/Flutter/GeneratedPluginRegistrant.swift`
   ONLY if those two generated files were clean before you started (check `git status` first).

## Expected noise (ignore)
- `MissingPluginException` / `PlatformException(channel-error ...)`: audioplayers,
  wakelock and nsd have no plugin in tests. The PNGs are still written.
- Emoji and the ♠ glyph render as boxes: Roboto in tests has no emoji/symbol fallback.

## Real failures (fix before finishing)
- Any `A RenderFlex overflowed by N pixels` line: count must be 0.
- Seats overlapping each other, the community cards, the dice, the local seat or the buttons.
- Text clipped, titles off-center, watermark text showing through a panel.
- Seats of different heights/widths in the same row or ring (they must look uniform).
- Anything outside the screen at 640x360.

## Checklist per image
- Header: back button left, title optically centered on the SCREEN, balance right.
- Opponents spread symmetrically around the oval table, current turn highlighted in amber.
- Local seat bottom-center, readable cards, controls never covering cards.
- Blackjack: dealer top-center with rules text beside it, all seats in one row (compact at 5+), dock at the bottom.
