import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/card_model.dart';
import 'package:poker_dice_dash/models/dice_blackjack.dart';
import 'package:poker_dice_dash/models/game_state.dart';
import 'package:poker_dice_dash/providers/game_provider.dart';
import 'package:poker_dice_dash/services/p2p_service.dart';

CardModel c(String v) => CardModel(value: v, suit: Suit.diamonds);

GameProvider diceGame(int bots) {
  final g = GameProvider(p2pService: P2PService())
    ..setHost(true)
    ..setMultiplayer(false)
    ..setGameMode(GameMode.diceDash)
    ..setBotCount(bots);
  g.resetGame();
  return g;
}

Future<bool> waitMyRoll(WidgetTester tester, GameProvider g) async {
  for (var i = 0; i < 600; i++) {
    final idx = g.state.currentPlayerIndex;
    if (idx >= 0 && g.players[idx].id == g.localPlayerId && g.state.status == GameStatus.diceTurn &&
        g.centralMessage == null && !g.isBetting) {
      return true;
    }
    if (idx >= 0 && g.players[idx].id == g.localPlayerId && g.state.status == GameStatus.betting &&
        !g.isBetting && !g.diceEventBusy && g.centralMessage == null) {
      g.call(g.localPlayerId);
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  return false;
}

Future<void> waitEventClosed(WidgetTester tester, GameProvider g, {int ticks = 120}) async {
  for (var i = 0; i < ticks && (g.diceBlackjack != null || g.diceEventBusy); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> finish(WidgetTester tester, GameProvider g) async {
  g.exitGame();
  g.dispose();
  await tester.pump(const Duration(seconds: 30));
}

void main() {
  setUpAll(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      messenger.setMockMethodCallHandler(MethodChannel(ch), (call) async => null);
    }
  });

  testWidgets('2+1 opens the 21 event: blackjack pays 3:2 and poker goes on', (tester) async {
    final g = diceGame(3);
    expect(await waitMyRoll(tester, g), isTrue);
    final me = g.players.firstWhere((p) => p.id == g.localPlayerId);
    final before = me.chipBalance;
    g.debugDiceBjCards = [c('A'), c('K'), c('10'), c('7')];
    g.debugNextDice = [2, 1];
    g.rollDice();
    expect(g.diceBlackjack, isNotNull);
    expect(g.diceEventBusy, isTrue);
    g.diceBjBet(me.id, 100);
    expect(g.diceBlackjack!.stage, DiceBlackjackStage.done);
    expect(me.chipBalance, before + 150);
    await waitEventClosed(tester, g);
    expect(g.diceBlackjack, isNull);
    expect(g.diceEventBusy, isFalse);
    // Back to poker: it is still my turn to bet.
    expect(g.players[g.state.currentPlayerIndex].id, me.id);
    expect(g.state.status, GameStatus.betting);
    await finish(tester, g);
  });

  testWidgets('a player who does nothing cannot hold the table (no bet after the timeout)', (tester) async {
    final g = diceGame(3);
    expect(await waitMyRoll(tester, g), isTrue);
    final me = g.players.firstWhere((p) => p.id == g.localPlayerId);
    final before = me.chipBalance;
    g.debugNextDice = [1, 2];
    g.rollDice();
    expect(g.diceBlackjack, isNotNull);
    await tester.pump(GameProvider.diceBjDecisionTime + const Duration(milliseconds: 200));
    expect(g.diceBlackjack?.skipped ?? true, isTrue);
    await waitEventClosed(tester, g);
    expect(g.diceBlackjack, isNull);
    expect(me.chipBalance, before);
    await finish(tester, g);
  });

  testWidgets('timeout while playing stands; the dealer plays and the hand is paid', (tester) async {
    final g = diceGame(3);
    expect(await waitMyRoll(tester, g), isTrue);
    final me = g.players.firstWhere((p) => p.id == g.localPlayerId);
    final before = me.chipBalance;
    // Player 18 vs dealer 10+6 -> draws K -> busts: player wins 1:1.
    g.debugDiceBjCards = [c('10'), c('8'), c('10'), c('6'), c('K')];
    g.debugNextDice = [2, 1];
    g.rollDice();
    g.diceBjBet(me.id, 50);
    expect(me.chipBalance, before - 50);
    await tester.pump(GameProvider.diceBjDecisionTime + const Duration(milliseconds: 200));
    for (var i = 0; i < 40 && g.diceBlackjack != null && g.diceBlackjack!.stage != DiceBlackjackStage.done; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(g.diceBlackjack!.net, 50);
    expect(me.chipBalance, before + 50);
    await waitEventClosed(tester, g);
    await finish(tester, g);
  });

  testWidgets('the 21 bet must be between 10 and 200, and only the event player acts', (tester) async {
    final g = diceGame(2);
    expect(await waitMyRoll(tester, g), isTrue);
    final me = g.players.firstWhere((p) => p.id == g.localPlayerId);
    g.debugNextDice = [2, 1];
    g.rollDice();
    final before = me.chipBalance;
    g.diceBjBet(me.id, 5);
    g.diceBjBet(me.id, 500);
    expect(g.diceBlackjack!.stage, DiceBlackjackStage.betting);
    expect(me.chipBalance, before);
    final other = g.players.firstWhere((p) => p.id != me.id);
    g.diceBjBet(other.id, 50);
    expect(g.diceBlackjack!.bet, 0);
    g.diceBjSkip(me.id);
    await waitEventClosed(tester, g);
    await finish(tester, g);
  });

  testWidgets('a bot that rolls 2+1 bets, plays its hand and the poker hand continues', (tester) async {
    final g = diceGame(3);
    var forced = false;
    var sawEvent = false;
    String? botId;
    final start = g.roundCounter;
    for (var i = 0; i < 4000 && (!sawEvent || g.diceBlackjack != null || g.roundCounter == start); i++) {
      await tester.pump(const Duration(milliseconds: 50));
      final idx = g.state.currentPlayerIndex;
      if (!forced && idx >= 0 && g.players[idx].isBot && g.state.status == GameStatus.diceTurn) {
        g.debugNextDice = [2, 1];
        botId = g.players[idx].id;
        forced = true;
      }
      if (g.diceBlackjack != null) {
        sawEvent = true;
        final owner = g.players.firstWhere((p) => p.id == g.diceBlackjack!.playerId);
        expect(owner.isBot, isTrue, reason: 'forced dice for a bot, event opened for ${owner.name} (expected a bot like $botId)');
      }
      if (idx >= 0 && g.players[idx].id == g.localPlayerId && !g.isBetting && !g.diceEventBusy && g.centralMessage == null) {
        if (g.state.status == GameStatus.diceTurn) {
          // The 2+1 is meant for a bot: the human always rolls a plain 5+4
          // (a natural 2+1 would legitimately open the event for the human).
          if (g.debugNextDice != null) forced = false;
          g.debugNextDice = [5, 4];
          g.rollDice();
        }
        if (g.state.status == GameStatus.betting) g.call(g.localPlayerId);
      }
    }
    expect(sawEvent, isTrue);
    expect(g.diceBlackjack, isNull);
    expect(g.roundCounter, greaterThan(start), reason: 'the poker hand did not continue after the event');
    await finish(tester, g);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('leaving during the event gives back the unsettled bet', (tester) async {
    final g = diceGame(2);
    expect(await waitMyRoll(tester, g), isTrue);
    final me = g.players.firstWhere((p) => p.id == g.localPlayerId);
    g.debugDiceBjCards = [c('10'), c('6'), c('9'), c('7')];
    g.debugNextDice = [2, 1];
    g.rollDice();
    final before = me.chipBalance;
    g.diceBjBet(me.id, 80);
    expect(me.chipBalance, before - 80);
    g.exitGame();
    expect(me.chipBalance, before);
    g.dispose();
    await tester.pump(const Duration(seconds: 30));
  });
}
