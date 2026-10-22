import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/game_state.dart';
import 'package:poker_dice_dash/providers/game_provider.dart';
import 'package:poker_dice_dash/services/p2p_service.dart';

int chipsOnTable(GameProvider g) => g.players.fold<int>(0, (a, p) => a + p.chipBalance) + g.pot;

GameProvider newGame(GameMode mode, int bots) {
  final g = GameProvider(p2pService: P2PService())
    ..setHost(true)
    ..setMultiplayer(false)
    ..setGameMode(mode)
    ..setBotCount(bots);
  g.resetGame();
  return g;
}

/// The local player acts randomly (fold / call / raise / all-in) when it is their turn.
void humanActs(GameProvider g, Random rng) {
  final idx = g.state.currentPlayerIndex;
  if (idx < 0 || idx >= g.players.length) return;
  final me = g.players[idx];
  // Like the real UI: no buttons for someone who folded.
  if (me.id != g.localPlayerId || me.isFolded || g.centralMessage != null || g.isBetting || g.diceEventBusy) return;
  if (g.state.status == GameStatus.diceTurn) {
    g.rollDice();
    return;
  }
  if (g.state.status != GameStatus.betting) return;
  final toCall = max(0, g.currentBet - g.getPlayerBet(me.id));
  final r = rng.nextInt(10);
  if (r < 2 && toCall > 0) {
    g.fold(me.id);
  } else if (r < 6 || me.chipBalance <= toCall) {
    g.call(me.id);
  } else if (r < 8) {
    g.raise(me.id, min(40, me.chipBalance - toCall));
  } else {
    g.raise(me.id, me.chipBalance - toCall); // all-in
  }
}

Future<void> finish(WidgetTester tester, GameProvider g) async {
  g.exitGame();
  g.dispose();
  await tester.pump(const Duration(seconds: 10));
}

void main() {
  setUpAll(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      messenger.setMockMethodCallHandler(MethodChannel(ch), (call) async => null);
    }
  });

  testWidgets('short stacks: all-ins, side pots and run-outs never create, lose or freeze chips', (tester) async {
    final rng = Random(11);
    final g = newGame(GameMode.texasHoldem, 5);
    // Uneven, short stacks so all-ins and side pots happen constantly.
    final stacks = [60, 140, 35, 300, 90, 220];
    for (var i = 0; i < g.players.length; i++) {
      g.debugSetChips(g.players[i].id, stacks[i % stacks.length]);
    }
    var round = g.roundCounter;
    var handTotal = chipsOnTable(g);
    var hands = 0;
    var ticksInHand = 0;
    var contribs = <String, int>{};
    var chipsBefore = <String, int>{};
    var sidePotChecks = 0;
    for (var tick = 0; tick < 20000 && hands < 25; tick++) {
      final c = g.debugContributions;
      if (c.isNotEmpty) {
        contribs = Map.of(c);
        chipsBefore = {for (final p in g.players) p.id: p.chipBalance};
      }
      await tester.pump(const Duration(milliseconds: 100));
      ticksInHand++;
      if (contribs.isNotEmpty && g.debugContributions.isEmpty && g.roundCounter == round) {
        // The pot was just paid: nobody may collect more than their stack could cover
        // (a short all-in only wins the main pot, the rest is a side pot).
        for (final p in g.players) {
          final gain = p.chipBalance - (chipsBefore[p.id] ?? p.chipBalance);
          if (gain <= 0) continue;
          final mine = contribs[p.id] ?? 0;
          final coverable = contribs.values.fold<int>(0, (a, x) => a + min(x, mine));
          final folds = contribs.keys.where((id) => g.players.firstWhere((q) => q.id == id).isFolded).length;
          // Everybody else folded: the whole pot (incl. uncalled chips) is theirs.
          if (folds == contribs.length - 1) continue;
          expect(gain, lessThanOrEqualTo(coverable), reason: 'hand $hands: ${p.name} won $gain covering only $coverable');
          sidePotChecks++;
        }
        contribs = {};
      }
      if (g.roundCounter != round) {
        // New deal (broke bots are rebought here): new baseline.
        round = g.roundCounter;
        handTotal = chipsOnTable(g);
        hands++;
        ticksInHand = 0;
      }
      expect(chipsOnTable(g), handTotal, reason: 'hand $hands: chips created or lost');
      for (final p in g.players) {
        expect(p.chipBalance, greaterThanOrEqualTo(0));
      }
      expect(ticksInHand, lessThan(1500), reason: 'hand $hands is stuck (phase ${g.phase}, status ${g.state.status})');
      humanActs(g, rng);
    }
    expect(hands, 25, reason: 'hands stopped advancing');
    expect(sidePotChecks, greaterThan(5));
    await finish(tester, g);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('you fold and everyone left is all-in: the hand still finishes', (tester) async {
    final g = newGame(GameMode.texasHoldem, 3);
    // Bots shorter than the big blind: the blinds and calls put them all-in.
    for (final p in g.players.where((p) => p.isBot)) {
      g.debugSetChips(p.id, 15);
    }
    final start = g.roundCounter;
    var sawShowdown = false;
    for (var tick = 0; tick < 3000 && g.roundCounter < start + 4; tick++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (g.phase == PokerPhase.showdown && g.revealedCommunityCount == 5) sawShowdown = true;
      for (final p in g.players.where((p) => p.isBot && p.chipBalance > 15)) {
        g.debugSetChips(p.id, 15); // keep them short after wins / rebuys
      }
      final idx = g.state.currentPlayerIndex;
      if (idx >= 0 && g.players[idx].id == g.localPlayerId && !g.players[idx].isFolded &&
          g.state.status == GameStatus.betting && !g.isBetting && g.centralMessage == null) {
        g.fold(g.localPlayerId); // the human (with chips) always folds
      }
    }
    expect(sawShowdown, isTrue);
    expect(g.roundCounter, greaterThanOrEqualTo(start + 4), reason: 'all-in hands froze');
    await finish(tester, g);
  });

  testWidgets('heads-up: after the flop the big blind (non-dealer) acts first', (tester) async {
    final g = newGame(GameMode.texasHoldem, 1);
    var checked = 0;
    var lastPhase = g.phase;
    var waitingFirstActor = false;
    for (var tick = 0; tick < 6000 && checked < 6; tick++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (g.phase != lastPhase) {
        lastPhase = g.phase;
        waitingFirstActor = g.phase == PokerPhase.flop || g.phase == PokerPhase.turn || g.phase == PokerPhase.river;
      }
      final idx = g.state.currentPlayerIndex;
      if (waitingFirstActor && idx >= 0) {
        waitingFirstActor = false;
        // Only meaningful while both players still have chips to bet.
        if (g.players.every((p) => p.chipBalance > 0 && !p.isFolded)) {
          expect(idx, isNot(g.dealerIndex), reason: 'dealer acted first after the flop heads-up');
          expect(idx, g.bigBlindIndex);
          checked++;
        }
      }
      if (idx >= 0 && g.players[idx].id == g.localPlayerId && g.state.status == GameStatus.betting && !g.isBetting) {
        g.call(g.localPlayerId);
      }
    }
    expect(checked, greaterThanOrEqualTo(6));
    await finish(tester, g);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('blind badges point at the seats that posted the blinds, never a bankrupt seat', (tester) async {
    final g = newGame(GameMode.texasHoldem, 4);
    // A bankrupt human sits between the dealer and the blinds.
    g.debugSetChips(g.localPlayerId, 0);
    final start = g.roundCounter;
    for (var tick = 0; tick < 4000 && g.roundCounter < start + 4; tick++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (g.phase == PokerPhase.preFlop && g.state.status != GameStatus.finished && g.pot > 0) {
        final sb = g.players[g.smallBlindIndex];
        final bb = g.players[g.bigBlindIndex];
        expect(sb.isBankrupt, isFalse);
        expect(bb.isBankrupt, isFalse);
        expect(g.smallBlindIndex, isNot(g.bigBlindIndex));
      }
    }
    await finish(tester, g);
  });

  testWidgets('raises must add chips: zero or negative raises are ignored', (tester) async {
    final g = newGame(GameMode.texasHoldem, 2);
    await tester.pump(const Duration(milliseconds: 100));
    // The small blind still owes chips: a "raise" of -5 must not lower the bet to call.
    final sb = g.players[g.smallBlindIndex];
    final before = sb.chipBalance;
    final betBefore = g.currentBet;
    g.raise(sb.id, -5);
    g.raise(sb.id, -500);
    g.raise(sb.id, 0);
    expect(sb.chipBalance, before);
    expect(g.currentBet, betBefore);
    await finish(tester, g);
  });

  testWidgets('Dice Dash: the lucky 7 bonus is house money, at most once per hand', (tester) async {
    final rng = Random(5);
    final g = newGame(GameMode.diceDash, 4);
    var round = g.roundCounter;
    var handTotal = chipsOnTable(g);
    int? bonus;
    var hands = 0;
    for (var tick = 0; tick < 20000 && hands < 20; tick++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (g.roundCounter != round) {
        round = g.roundCounter;
        handTotal = chipsOnTable(g);
        bonus = null;
        hands++;
      }
      final delta = chipsOnTable(g) - handTotal;
      expect(delta, greaterThanOrEqualTo(0), reason: 'chips lost');
      if (delta > 0) {
        bonus ??= delta;
        expect(delta, bonus, reason: 'lucky 7 paid twice in one hand');
      }
      humanActs(g, rng);
    }
    expect(hands, 20);
    await finish(tester, g);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
