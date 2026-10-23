import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/card_model.dart';
import 'package:poker_dice_dash/models/game_state.dart';
import 'package:poker_dice_dash/providers/game_provider.dart';
import 'package:poker_dice_dash/services/p2p_service.dart';

CardModel c(String v, Suit s) => CardModel(value: v, suit: s);

GameProvider diceGame(int bots) {
  final g = GameProvider(p2pService: P2PService())
    ..setHost(true)
    ..setMultiplayer(false)
    ..setGameMode(GameMode.diceDash)
    ..setBotCount(bots);
  g.resetGame();
  return g;
}

/// Waits until it is the local player's turn to roll.
Future<bool> waitMyRoll(WidgetTester tester, GameProvider g) async {
  for (var i = 0; i < 600; i++) {
    final idx = g.state.currentPlayerIndex;
    if (idx >= 0 && g.players[idx].id == g.localPlayerId && g.state.status == GameStatus.diceTurn &&
        g.centralMessage == null && !g.isBetting) {
      return true;
    }
    // Keep the hand moving if the local player must bet.
    if (idx >= 0 && g.players[idx].id == g.localPlayerId && g.state.status == GameStatus.betting &&
        !g.isBetting && !g.diceEventBusy && g.centralMessage == null) {
      g.call(g.localPlayerId);
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  return false;
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

  test('which roll triggers which event', () {
    expect(GameProvider.diceEventFor(1, 1), DiceEvent.swap);
    expect(GameProvider.diceEventFor(6, 6), DiceEvent.allIn);
    expect(GameProvider.diceEventFor(3, 3), DiceEvent.spy);
    expect(GameProvider.diceEventFor(6, 1), DiceEvent.extraCard);
    expect(GameProvider.diceEventFor(1, 6), DiceEvent.extraCard);
    expect(GameProvider.diceEventFor(2, 1), DiceEvent.none); // the 21 event was removed
    expect(GameProvider.diceEventFor(5, 2), DiceEvent.luckySeven);
    expect(GameProvider.diceEventFor(4, 3), DiceEvent.luckySeven);
    expect(GameProvider.diceEventFor(4, 3, luckySevenAvailable: false), DiceEvent.none);
    expect(GameProvider.diceEventFor(5, 4), DiceEvent.none);
    expect(GameProvider.diceEventFor(2, 2), DiceEvent.none);
  });

  test('carta extra keeps the strongest two cards', () {
    final three = [c('K', Suit.hearts), c('2', Suit.clubs), c('K', Suit.spades)];
    final best = GameProvider.bestTwoOf(three, const []);
    expect(best.map((x) => x.value).toList(), ['K', 'K']);
    // With a board, the card that makes a flush wins over a high card.
    final board = [c('3', Suit.hearts), c('7', Suit.hearts), c('9', Suit.hearts)];
    final withBoard = GameProvider.bestTwoOf([c('A', Suit.spades), c('4', Suit.hearts), c('5', Suit.hearts)], board);
    expect(withBoard.every((x) => x.suit == Suit.hearts), isTrue);
  });

  testWidgets('1+1: the chaos swap waits for the dice to land too', (tester) async {
    final g = diceGame(3);
    expect(await waitMyRoll(tester, g), isTrue);
    g.debugNextDice = [1, 1];
    g.rollDice();
    expect(g.lastDiceEvent, DiceEvent.swap);
    expect(g.state.mustSwapHands, isFalse, reason: 'the CAOS screen would show before the dice land');
    await tester.pump(GameProvider.diceRollAnimation);
    expect(g.state.mustSwapHands, isTrue);
    await finish(tester, g);
  });

  testWidgets('doble 6: the roller goes all-in', (tester) async {
    final g = diceGame(3);
    expect(await waitMyRoll(tester, g), isTrue);
    final me = g.players.firstWhere((p) => p.id == g.localPlayerId);
    g.debugNextDice = [6, 6];
    g.rollDice();
    expect(g.lastDiceEvent, DiceEvent.allIn);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(me.chipBalance, 0, reason: 'the roller kept chips');
    expect(me.isFolded, isFalse);
    await finish(tester, g);
  });

  testWidgets('doble 3: the spy sees one opponent card, nobody else does', (tester) async {
    final g = diceGame(3);
    expect(await waitMyRoll(tester, g), isTrue);
    g.debugNextDice = [3, 3];
    g.rollDice();
    expect(g.lastDiceEvent, DiceEvent.spy);
    // Nothing is revealed (and no message) until the dice land.
    expect(g.centralMessage, isNull);
    expect([for (final p in g.players) for (var i = 0; i < p.hand.length; i++) if (g.isCardSpied(g.localPlayerId, p.id, i)) 1], isEmpty);
    await tester.pump(GameProvider.diceRollAnimation);
    expect(g.centralMessage, isNotNull);
    final spiedSeats = [
      for (final p in g.players)
        for (var i = 0; i < p.hand.length; i++)
          if (g.isCardSpied(g.localPlayerId, p.id, i)) '${p.id}:$i',
    ];
    expect(spiedSeats, hasLength(1));
    final parts = spiedSeats.single.split(':');
    final target = g.players.firstWhere((p) => p.id == parts[0]);
    final idx = int.parse(parts[1]);
    expect(target.id, isNot(g.localPlayerId));

    // Over the network: the spy's snapshot carries the real card, another player's does not.
    final mine = g.exportGameState(forPlayerId: g.localPlayerId, mask: true);
    final theirs = g.exportGameState(forPlayerId: g.players.firstWhere((p) => p.id != g.localPlayerId && p.id != target.id).id, mask: true);
    Map<String, dynamic> seat(Map<String, dynamic> st) =>
        (st['players'] as List).cast<Map<String, dynamic>>().firstWhere((m) => m['id'] == target.id);
    final realCard = target.hand[idx].toMap();
    expect((seat(mine)['hand'] as List)[idx], realCard);
    expect((seat(theirs)['hand'] as List)[idx], isNot(realCard));
    await finish(tester, g);
  });

  testWidgets('6+1: three cards for a moment, then the best two', (tester) async {
    final g = diceGame(3);
    expect(await waitMyRoll(tester, g), isTrue);
    final me = g.players.firstWhere((p) => p.id == g.localPlayerId);
    g.debugNextDice = [6, 1];
    g.rollDice();
    expect(g.lastDiceEvent, DiceEvent.extraCard);
    expect(me.hand, hasLength(2), reason: 'the third card must wait for the dice to land');
    expect(g.diceEventBusy, isTrue);
    await tester.pump(GameProvider.diceRollAnimation);
    expect(me.hand, hasLength(3));
    final three = List.of(me.hand);
    // The three cards stay on screen, then the one that goes is marked before it leaves.
    await tester.pump(const Duration(milliseconds: 2000));
    expect(me.hand, hasLength(3));
    expect([for (var i = 0; i < 3; i++) if (g.isDiscardingCard(me.id, i)) i], isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect([for (var i = 0; i < 3; i++) if (g.isDiscardingCard(me.id, i)) i], hasLength(1));
    expect(me.hand, hasLength(3));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(me.hand, hasLength(2));
    final board = g.communityCards.take(g.revealedCommunityCount).toList();
    expect(me.hand, GameProvider.bestTwoOf(three, board));
    expect(g.diceEventBusy, isFalse);
    expect([for (var i = 0; i < 2; i++) if (g.isDiscardingCard(me.id, i)) i], isEmpty);
    await finish(tester, g);
  });

  testWidgets('a bot that rolls doble 6 also goes all-in and the hand goes on', (tester) async {
    final g = diceGame(3);
    var forced = false;
    PlayerModelRef? bot;
    for (var i = 0; i < 1500 && !forced; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      final idx = g.state.currentPlayerIndex;
      if (idx >= 0 && g.players[idx].isBot && g.state.status == GameStatus.diceTurn && g.debugNextDice == null) {
        g.debugNextDice = [6, 6];
        bot = PlayerModelRef(g.players[idx].id);
        forced = true;
      } else if (idx >= 0 && g.players[idx].id == g.localPlayerId && !g.isBetting && g.centralMessage == null) {
        if (g.state.status == GameStatus.diceTurn) g.rollDice();
        if (g.state.status == GameStatus.betting && !g.diceEventBusy) g.call(g.localPlayerId);
      }
    }
    expect(forced, isTrue);
    final start = g.roundCounter;
    for (var i = 0; i < 200 && g.players.firstWhere((p) => p.id == bot!.id).chipBalance > 0 && g.roundCounter == start; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(g.players.firstWhere((p) => p.id == bot!.id).chipBalance == 0 || g.roundCounter != start, isTrue);
    await finish(tester, g);
  });
}

class PlayerModelRef {
  final String id;
  PlayerModelRef(this.id);
}
