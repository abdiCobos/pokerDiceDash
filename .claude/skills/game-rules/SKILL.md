---
name: game-rules
description: Source of truth for the rules of Poker Dice Dash's three modes (Texas Hold'em, Dice Dash, Blackjack) as implemented, plus the known rule bugs. Use before changing game logic in game_provider.dart, blackjack_provider.dart, hand_evaluator.dart or bot code, and when the user asks how a mode works.
---

# Game rules (as implemented, 2026-10-20)

If you change a rule, update this file in the same change. If code and this file disagree,
ask the user which one is intended before "fixing" either.

## Texas Hold'em - `lib/providers/game_provider.dart`
- Everyone starts with 1000. Bots 1-7 (`setBotCount` clamps). Default mode is `diceDash`.
- One fresh shuffled 52-card deck per hand. 2 hole cards each (two passes). All 5 community
  cards are drawn at deal time and revealed via `revealedCommunityCount` (flop 3, turn 1, river 1).
  Burn cards are cosmetic (they do not change the board).
- Blinds SB 10 / BB 20 (or the player's stack if less). Dealer moves to the next active seat
  each hand. 3+ players: SB = after dealer, BB = after SB, UTG acts first preflop.
  Heads-up: dealer is SB.
- Actions: FOLD; CALL/CHECK pays `min(toCall, chips)` (short call = all-in for less);
  RAISE(amount) = call + amount on top, reopens action for everyone not all-in.
  No minimum raise, no cap. UI hides RAISE if calling already means all-in.
- A street ends when every unfolded player has acted (all-ins count as acted). Last player
  standing wins by fold. Post-flop action starts from `smallBlindIndex`.
- Showdown: `HandEvaluator` best 5 of 7, paid with main and side pots (`PotCalculator`).
- Bankruptcy: a human with 0 chips is `isBankrupt` (folded, no cards) and rebuys to 1000 with
  RECOMPRAR. Bots auto-rebuy to 1000. If fewer than 2 active players remain, all reset to 1000.
- Next hand starts 5 s after the end.

## Dice Dash - same as Texas plus a dice step before EVERY action
- Turn = `GameStatus.diceTurn` (current player rolls 2d6; only the host rolls, clients send
  `ROLL_DICE`; bots roll after 1-2 s) -> `GameStatus.betting` (same player acts) -> next player.
- 1+1 "INTERCAMBIO" (chaos): all live hole cards are pooled, shuffled and redealt 2 each (~2.4 s animation).
- Total 7 "Dados de la suerte": the pot grows by 30% of house money, once per hand.
- Events come from `GameProvider.diceEventFor(a, b)` (`enum DiceEvent`); while one runs,
  `diceEventBusy` blocks bots, the UI and the turn watchdog:
  - Every event waits `diceRollAnimation` (1.25 s) so nothing shows before the dice land.
  - 6+6 "¡ALL-IN!": after 1.4 s the roller raises their whole stack (or calls if they cannot raise).
  - 3+3 "¡ESPÍA!": the roller sees one random hole card of one live opponent (`isCardSpied`;
    unmasked only in that viewer's snapshot; cleared on each deal and on 1+1).
  - 1+6 "¡CARTA EXTRA!": the roller gets a third hole card, shows all three 2.2 s, marks the one that goes (`isDiscardingCard`, fades 0.9 s), keeps the best two (`bestTwoOf`).
  - 2+1 "¡21!" (Blackjack vs dealer) was tried and REMOVED on 2026-10-21: too invasive. Do not re-add.
  - Sum 7 (other than 1+6) = lucky 7 below.

## Hand ranking - `lib/models/hand_evaluator.dart`
High card < pair < two pair < trips < straight < flush < full house < quads < straight flush
< royal flush. A-2-3-4-5 is a 5-high straight. Power = rank<<20 + five 4-bit kickers; equal power = split.

## Blackjack - `lib/providers/blackjack_provider.dart`
- 6-deck shoe (312), replaced by a fresh shoe when < 20 cards remain at a draw.
- Players start with 1000 (auto-rebuy to 1000 at the new round if broke). Bots bet 50-200.
- Payouts (total returned): blackjack 2.5x (3:2), win 2x, 5-Card Charlie 2x (beats dealer 21),
  push 1x, bust 0.
- Dealer draws below 17, stands on every 17 (including soft 17); skips drawing if all players busted.
- Dealer blackjack (natural) ends the round before anyone plays; blackjack vs blackjack = push.
- Double: doubles the bet, exactly one card, then stands. Split: once, identical values only
  (K+Q cannot split), each hand gets one card.
- Bots: basic strategy-lite (hit <= 11; 12-16 hit vs dealer 7-A, 12 also vs 2-3; else stand).

## Rule fixes (2026-10-21) - keep these invariants
- Side pots: showdown pays with `PotCalculator.distribute` (lib/models/pot_calculator.dart):
  one pot per all-in level, folded money stays in, odd chips go left of the dealer, house
  bonus is dead money for the main pot. Never pay "pot / winners".
- All-in run-out: when nobody can bet against anybody (`_bettingIsOver`), the board is dealt
  to showdown without betting (`_runOutBoard`). Also checked right after the deal.
- Post-flop the first to act is the first player LEFT OF THE DEALER who can still bet (SB with
  3+ players, BB heads-up). Blinds seats are stored at the deal (`_sbIndex/_bbIndex`, synced).
- Fold win ends the hand: status `finished`, no current player.
- Raises must be > 0; remote actions are checked for turn AND step (bet vs roll).
- Lucky 7 (Dice Dash): +30% of the pot as HOUSE money (`_houseBonus`), once per hand.
- Rebuy mid-hand: chips now, cards from the next deal.
- Bots wait while the INTERCAMBIO swap is running.
- Blackjack: dealer natural (`isNatural`) ends the round at once; player blackjack vs dealer
  blackjack is a push; double only on the first two cards.
- Tests: `test/pot_calculator_test.dart`, `test/poker_rules_test.dart`,
  `test/blackjack_rules_flow_test.dart` (each one was checked to FAIL on the old code).

## Still open
- 6+6 forced all-in and 2+1 "Blackjack event" in Dice Dash are TODOs (not implemented).
- `lib/services/bot_service.dart` `decideAction` is dead code (only `getBotName` is used).

## Bots (2026-10-21)
- Poker: `lib/services/poker_bot_ai.dart` (`PokerBotBrain`, pure Dart). Monte Carlo equity vs
  the live opponents (120/260/450 samples for Fácil/Normal/Difícil, easy adds noise), pot odds,
  pot-sized raises in chip units of 10, shoves when committed, bluffs/steals in heads-up or
  3-way pots after the flop. Each seat has a `BotPersonality` (Tiburón, Roca, Calculador,
  Maníaco, Pescador). `_playBotTurn` calls it; bots stop re-raising after 3 raises per street.
- Blackjack: `lib/services/blackjack_bot_ai.dart` (`BlackjackBotBrain`): full multi-deck basic
  strategy (S17, DAS) for Normal/Difícil (Normal deviates ~12% on 12-16), "hit below 15" for Fácil.
- Difficulty is picked in the table setup dialog and saved (`bot_difficulty` pref).
- Tests: `test/poker_bot_ai_test.dart`, `test/blackjack_bot_ai_test.dart`,
  `test/poker_bots_flow_test.dart` (full hands per mode/difficulty), `test/blackjack_bots_test.dart`.
