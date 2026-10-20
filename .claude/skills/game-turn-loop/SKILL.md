---
name: game-turn-loop
description: Rules that keep every Poker Dice Dash round moving (turn advancement, bot scheduling, guards against double taps, watchdogs, async delays). Use when touching turn/phase code, bot actions, timers or Future.delayed in game_provider.dart or blackjack_provider.dart, or when the user reports a frozen game ("se quedó congelada", "el bot ya no siguió").
---

# Turn loop: a round must ALWAYS reach its end

A frozen table is the worst bug in this game. Every change to turn logic must keep these
invariants and be proven by a test that runs whole rounds with bots.

## Invariants
1. **Every turn ends in a state change that schedules the next step.** After any action,
   either the same actor is scheduled again (bot not finished) or the turn advances.
   Bug fixed 2026-10-20: a Blackjack bot that hit without finishing its hand was never
   rescheduled -> "Turno de Doyle... pensando jugada" forever. `_autoPlayBot` now loops itself.
2. **Actions are guarded by turn and state.** `hit/stand/doubleDown/splitPair` return early
   unless `_isTurnOf(playerId)` and the hand is not finished. Without this a double tap
   schedules two advances and replays bots (it also hid the freeze in tests).
3. **Delayed callbacks re-check before acting.** Anything run from `Future.delayed`/`Timer`
   must re-validate phase, current player and (poker) `_epoch`; stale work is dropped silently.
4. **Only `isBot` seats are played by AI.** Remote humans wait for their action or the away
   timeout; local humans wait for input. (Blackjack still auto-plays every non-local seat;
   fix this when adding Blackjack multiplayer.)
5. **A failure never stalls.** If bot logic throws, fall back to the safest action
   (stand / check / fold) for that seat.
6. **Something guarantees progress.** Poker host: `_watchdogTick` every 2 s (multiplayer
   only today) restarts a stuck showdown and plays away seats. Single player has no watchdog:
   be extra careful there, or extend the watchdog when you touch it.
7. **Animations never gate logic.** UI reacts to state; game timers advance the game.

## Timing conventions
Bot think 600-700 ms (Blackjack), 1.5-2.5 s (poker), dice roll 1-2 s, deal 350 ms per card,
next poker hand 5 s after the end.

## Required test
For any change here, a `testWidgets` test that plays 10-20 full rounds with bots using
`tester.pump(Duration)` as fake time, where the human acts ONCE per turn, and asserts the
end phase is reached (see `test/blackjack_bots_test.dart`). Confirm it fails without the fix.
Known open stall risks are listed in the `game-rules` skill ("Known rule bugs" 1, 8, 11).
