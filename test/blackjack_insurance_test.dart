import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/blackjack_models.dart';
import 'package:poker_dice_dash/models/card_model.dart';
import 'package:poker_dice_dash/providers/blackjack_provider.dart';

CardModel c(String v, [Suit s = Suit.spades]) => CardModel(value: v, suit: s);

/// One player against the dealer. Deal order: dealer, player, dealer, player.
Future<BlackjackProvider> deal(WidgetTester tester, List<String> dealer, List<String> player, {int bet = 100}) async {
  final bj = BlackjackProvider()..initSinglePlayer(botCount: 0);
  bj.debugStackDeck([c(dealer[0]), c(player[0]), c(dealer[1], Suit.hearts), c(player[1], Suit.hearts)]);
  bj.placeBet('0', bet);
  for (var i = 0; i < 40 && bj.phase == BlackjackPhase.dealing; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return bj;
}

Future<void> settle(WidgetTester tester, BlackjackProvider bj) async {
  for (var i = 0; i < 150 && bj.phase != BlackjackPhase.roundEnd; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      messenger.setMockMethodCallHandler(MethodChannel(ch), (call) async => null);
    }
  });

  testWidgets('dealer ace: insurance is offered before the dealer peeks', (tester) async {
    final bj = await deal(tester, ['A', 'K'], ['9', '7']);
    expect(bj.phase, BlackjackPhase.insurance);
    expect(bj.canInsure(bj.localPlayer), isTrue);
    expect(BlackjackProvider.insuranceCost(bj.localPlayer), 50);
    await tester.pump(const Duration(seconds: 3));
    expect(bj.phase, BlackjackPhase.insurance, reason: 'the round must wait for the answer');
    bj.takeInsurance('0', false);
    await settle(tester, bj);
    await tester.pump(const Duration(seconds: 15));
  });

  testWidgets('insurance against a dealer blackjack pays 2:1: the bet is covered', (tester) async {
    final bj = await deal(tester, ['A', 'K'], ['9', '7']);
    bj.takeInsurance('0', true);
    expect(bj.localPlayer.insuranceBet, 50);
    expect(bj.localPlayer.chipBalance, 850);
    await settle(tester, bj);
    expect(bj.roundOutcome['0'], 'SEGURO');
    expect(bj.roundNet['0'], 0);
    expect(bj.localPlayer.chipBalance, 1000);
    await tester.pump(const Duration(seconds: 15));
  });

  testWidgets('insurance is lost when the dealer has no blackjack, and the hand goes on', (tester) async {
    final bj = await deal(tester, ['A', '7'], ['10', '8']);
    bj.takeInsurance('0', true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(bj.phase, BlackjackPhase.playerTurn);
    bj.stand('0');
    await settle(tester, bj);
    // 18 against 18: push on the hand, insurance lost.
    expect(bj.roundNet['0'], -50);
    expect(bj.localPlayer.chipBalance, 950);
    await tester.pump(const Duration(seconds: 15));
  });

  testWidgets('no answer in time counts as "no": the table never waits forever', (tester) async {
    final bj = await deal(tester, ['A', 'K'], ['9', '7']);
    expect(bj.phase, BlackjackPhase.insurance);
    await tester.pump(BlackjackProvider.insuranceTimeout + const Duration(milliseconds: 100));
    await settle(tester, bj);
    expect(bj.localPlayer.insuranceBet, 0);
    expect(bj.roundNet['0'], -100);
    expect(bj.localPlayer.chipBalance, 900);
    await tester.pump(const Duration(seconds: 15));
  });

  testWidgets('a player with blackjack is not offered insurance', (tester) async {
    final bj = await deal(tester, ['A', '7'], ['A', 'K']);
    expect(bj.phase, isNot(BlackjackPhase.insurance));
    await settle(tester, bj);
    expect(bj.roundNet['0'], 150);
    await tester.pump(const Duration(seconds: 15));
  });

  testWidgets('no ace showing, no insurance', (tester) async {
    final bj = await deal(tester, ['K', '7'], ['9', '7']);
    expect(bj.phase, BlackjackPhase.playerTurn);
    bj.takeInsurance('0', true);
    expect(bj.localPlayer.insuranceBet, 0);
    bj.stand('0');
    await settle(tester, bj);
    await tester.pump(const Duration(seconds: 15));
  });

  testWidgets('bots never insure and do not hold the offer open', (tester) async {
    final bj = BlackjackProvider()..initSinglePlayer(botCount: 2);
    // dealer, me, bot1, bot2, dealer, me, bot1, bot2
    bj.debugStackDeck([c('A'), c('9'), c('8'), c('7'), c('K', Suit.hearts), c('7', Suit.hearts), c('8', Suit.hearts), c('9', Suit.hearts)]);
    bj.placeBet('0', 100);
    for (var i = 0; i < 40 && bj.phase == BlackjackPhase.dealing; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(bj.phase, BlackjackPhase.insurance);
    bj.takeInsurance('0', false);
    await settle(tester, bj);
    for (final b in bj.botPlayers) {
      expect(b.insuranceBet, 0);
    }
    expect(bj.phase, BlackjackPhase.roundEnd);
    await tester.pump(const Duration(seconds: 15));
  });
}
