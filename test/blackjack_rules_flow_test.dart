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
  await tester.pump(const Duration(milliseconds: 800));
  return bj;
}

Future<void> settle(WidgetTester tester, BlackjackProvider bj) async {
  for (var i = 0; i < 100 && bj.phase != BlackjackPhase.roundEnd; i++) {
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

  testWidgets('dealer blackjack ends the round at once and beats a normal hand', (tester) async {
    final bj = await deal(tester, ['A', 'K'], ['9', '7']);
    await settle(tester, bj);
    expect(bj.phase, BlackjackPhase.roundEnd, reason: 'the player must not get a turn against a dealer natural');
    expect(bj.roundNet['0'], -100);
    expect(bj.localPlayer.chipBalance, 900);
    await tester.pump(const Duration(seconds: 15));
  });

  testWidgets('blackjack against dealer blackjack is a push', (tester) async {
    final bj = await deal(tester, ['K', 'A'], ['A', 'Q']);
    await settle(tester, bj);
    expect(bj.roundNet['0'], 0);
    expect(bj.roundOutcome['0'], 'EMPATE');
    expect(bj.localPlayer.chipBalance, 1000);
    await tester.pump(const Duration(seconds: 15));
  });

  testWidgets('player blackjack against a normal dealer hand pays 3:2', (tester) async {
    final bj = await deal(tester, ['9', '7'], ['A', 'K']);
    await settle(tester, bj);
    expect(bj.roundNet['0'], 150);
    await tester.pump(const Duration(seconds: 15));
  });

  testWidgets('double is only allowed on the first two cards', (tester) async {
    final bj = await deal(tester, ['9', '7'], ['2', '3']);
    expect(bj.phase, BlackjackPhase.playerTurn);
    bj.debugStackDeck([c('2', Suit.clubs)]);
    bj.hit('0'); // 2 + 3 + 2 = 7, three cards
    await tester.pump(const Duration(milliseconds: 100));
    final chips = bj.localPlayer.chipBalance;
    bj.doubleDown('0');
    await tester.pump(const Duration(milliseconds: 100));
    expect(bj.localPlayer.chipBalance, chips, reason: 'doubled after hitting');
    expect(bj.localPlayer.hands[0].isDoubledDown, isFalse);
    bj.stand('0');
    await settle(tester, bj);
    await tester.pump(const Duration(seconds: 15));
  });
}
