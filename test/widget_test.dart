import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/card_model.dart';
import 'package:poker_dice_dash/models/hand_evaluator.dart';
import 'package:poker_dice_dash/services/bot_service.dart';
import 'package:poker_dice_dash/providers/blackjack_provider.dart';

void main() {
  group('CardModel', () {
    test('creates correct asset path', () {
      final card = CardModel(value: 'A', suit: Suit.hearts);
      expect(card.assetPath, 'assets/images/cards/cardHeartsA.png');
    });

    test('serializes and deserializes correctly', () {
      final card = CardModel(value: 'K', suit: Suit.spades);
      final json = card.toJson();
      final fromJson = CardModel.fromJson(json);
      expect(fromJson.value, 'K');
      expect(fromJson.suit, Suit.spades);
    });
  });

  group('HandEvaluator', () {
    test('evaluates Royal Flush', () {
      final hand = [
        CardModel(value: 'A', suit: Suit.spades),
        CardModel(value: 'K', suit: Suit.spades),
      ];
      final community = [
        CardModel(value: 'Q', suit: Suit.spades),
        CardModel(value: 'J', suit: Suit.spades),
        CardModel(value: '10', suit: Suit.spades),
        CardModel(value: '2', suit: Suit.hearts),
        CardModel(value: '3', suit: Suit.diamonds),
      ];

      final result = HandEvaluator.evaluate(hand, community);
      expect(result.rank, HandRank.royalFlush);
    });

    test('evaluates Full House', () {
      final hand = [
        CardModel(value: 'A', suit: Suit.hearts),
        CardModel(value: 'A', suit: Suit.spades),
      ];
      final community = [
        CardModel(value: 'A', suit: Suit.diamonds),
        CardModel(value: 'K', suit: Suit.clubs),
        CardModel(value: 'K', suit: Suit.hearts),
        CardModel(value: '2', suit: Suit.clubs),
        CardModel(value: '3', suit: Suit.diamonds),
      ];

      final result = HandEvaluator.evaluate(hand, community);
      expect(result.rank, HandRank.fullHouse);
    });

    test('higher hand wins', () {
      final flushHand = [
        CardModel(value: '2', suit: Suit.hearts),
        CardModel(value: '5', suit: Suit.hearts),
      ];
      final straightHand = [
        CardModel(value: '9', suit: Suit.clubs),
        CardModel(value: '8', suit: Suit.diamonds),
      ];
      final community = [
        CardModel(value: '7', suit: Suit.hearts),
        CardModel(value: '6', suit: Suit.hearts),
        CardModel(value: '10', suit: Suit.spades),
        CardModel(value: 'J', suit: Suit.hearts),
        CardModel(value: 'K', suit: Suit.clubs),
      ];

      final flushResult = HandEvaluator.evaluate(flushHand, community);
      final straightResult = HandEvaluator.evaluate(straightHand, community);

      expect(flushResult.power > straightResult.power, isTrue);
    });
  });

  group('DealOrder and Multi-player Seating Logic', () {
    test('calculates correct deal order for any player count', () {
      // For 6 players with dealer at index 2:
      // First card should go to SB (index 3), then 4, 5, 0, 1, and dealer (2) gets last card.
      const numPlayers = 6;
      const dealerIdx = 2;

      int getDealOrder(int playerIdx) {
        return ((playerIdx - dealerIdx - 1) % numPlayers + numPlayers) % numPlayers;
      }

      expect(getDealOrder(3), 0); // SB is first
      expect(getDealOrder(4), 1);
      expect(getDealOrder(5), 2);
      expect(getDealOrder(0), 3);
      expect(getDealOrder(1), 4);
      expect(getDealOrder(2), 5); // Dealer is last of the round
    });

    test('calculates correct deal order for heads-up (2 players)', () {
      const numPlayers = 2;
      const dealerIdx = 0; // Dealer is also SB in heads-up

      int getDealOrder(int playerIdx) {
        return ((playerIdx - dealerIdx - 1) % numPlayers + numPlayers) % numPlayers;
      }

      expect(getDealOrder(1), 0); // Non-dealer gets first card
      expect(getDealOrder(0), 1); // Dealer gets second card
    });
  });

  group('Famous Bot Names', () {
    test('returns legendary gambler names', () {
      expect(kFamousBotNames.contains('Doyle'), isTrue);
      expect(kFamousBotNames.contains('Stu'), isTrue);
      expect(kFamousBotNames.contains('Phil'), isTrue);
      expect(kFamousBotNames.contains('Daniel'), isTrue);
      expect(kFamousBotNames.contains('Vanessa'), isTrue);
    });

    test('getBotName wraps around list length cleanly', () {
      expect(getBotName(0), 'Doyle');
      expect(getBotName(1), 'Stu');
      expect(getBotName(kFamousBotNames.length), 'Doyle');
      expect(getBotName(-1), 'Bot');
    });
  });

  group('Blackjack Single Player Customization', () {
    test('initializes with custom player name and famous bot names', () {
      final bj = BlackjackProvider();
      bj.initSinglePlayer(botCount: 3, playerName: 'Carlos');
      
      expect(bj.players.length, 5); // Dealer + Carlos + 3 bots
      expect(bj.players[0].isDealer, isTrue);
      expect(bj.players[1].name, 'Carlos');
      expect(bj.players[1].isLocal, isTrue);
      expect(bj.players[2].name, 'Doyle');
      expect(bj.players[2].isBot, isTrue);
      expect(bj.players[3].name, 'Stu');
      expect(bj.players[3].isBot, isTrue);
      expect(bj.players[4].name, 'Phil');
      expect(bj.players[4].isBot, isTrue);
    });
  });
}
