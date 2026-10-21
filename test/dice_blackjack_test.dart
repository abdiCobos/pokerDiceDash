import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/card_model.dart';
import 'package:poker_dice_dash/models/dice_blackjack.dart';

CardModel c(String v) => CardModel(value: v, suit: Suit.clubs);

/// Deal order: player, player, dealer, dealer, then hits / dealer draws.
DiceBlackjack event(List<String> cards) =>
    DiceBlackjack(playerId: 'p', playerName: 'P', stackedCards: [for (final v in cards) c(v)]);

void main() {
  test('bet limits: 10 to 200, never more than the free chips', () {
    final e = event(['9', '8', '10', '7']);
    expect(e.placeBet(5, 1000), isFalse);
    expect(e.placeBet(250, 1000), isFalse);
    expect(e.placeBet(80, 60), isFalse);
    expect(DiceBlackjack.maxBetFor(60), 60);
    expect(DiceBlackjack.canPlay(9), isFalse);
    expect(e.placeBet(50, 1000), isTrue);
    expect(e.stage, DiceBlackjackStage.playing);
  });

  test('player blackjack pays 3:2 at once', () {
    final e = event(['A', 'K', '10', '7']);
    e.placeBet(100, 1000);
    expect(e.stage, DiceBlackjackStage.done);
    expect(e.payout, 250);
    expect(e.net, 150);
  });

  test('dealer blackjack wins at once', () {
    final e = event(['10', '9', 'A', 'Q']);
    e.placeBet(100, 1000);
    expect(e.stage, DiceBlackjackStage.done);
    expect(e.net, -100);
  });

  test('both blackjack is a push', () {
    final e = event(['A', 'J', 'K', 'A']);
    e.placeBet(40, 1000);
    expect(e.net, 0);
  });

  test('bust loses, dealer does not draw', () {
    final e = event(['10', '6', '10', '7', 'K']);
    e.placeBet(60, 1000);
    e.hit(); // 26
    expect(e.stage, DiceBlackjackStage.done);
    expect(e.net, -60);
    expect(e.dealer.cards, hasLength(2));
  });

  test('dealer draws to 17 and busts: player wins 1:1', () {
    final e = event(['10', '8', '10', '6', 'K']); // player 18, dealer 16 then K
    e.placeBet(50, 1000);
    e.stand();
    while (e.dealerStep()) {}
    expect(e.dealer.handValue, 26);
    expect(e.net, 50);
  });

  test('push returns the bet', () {
    final e = event(['10', '8', '10', '8']);
    e.placeBet(70, 1000);
    e.stand();
    while (e.dealerStep()) {}
    expect(e.payout, 70);
    expect(e.net, 0);
  });

  test('hitting to 21 stands automatically', () {
    final e = event(['5', '6', '10', '7', 'K']);
    e.placeBet(30, 1000);
    e.hit(); // 21
    expect(e.stage, DiceBlackjackStage.dealer);
  });

  test('skipping risks nothing', () {
    final e = event(['5', '6', '10', '7']);
    e.skip();
    expect(e.stage, DiceBlackjackStage.done);
    expect(e.net, 0);
    e.hit();
    expect(e.player.cards, isEmpty);
  });

  test('clients do not see the dealer hole card while the player decides', () {
    final e = event(['10', '6', '9', 'K']);
    e.placeBet(50, 1000);
    final m = e.toMap();
    expect(m['hiddenHole'], isTrue);
    expect((m['dealer'] as List)[1], isNot(c('K').toMap()));
    e.stand();
    final after = e.toMap();
    expect((after['dealer'] as List)[1], CardModel(value: 'K', suit: Suit.clubs).toMap());
    final copy = DiceBlackjack.fromMap(after);
    expect(copy.dealer.cards[1].value, 'K');
  });
}
