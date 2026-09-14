import 'package:poker/poker.dart' as pk;
import '../lib/models/card_model.dart';
import '../lib/models/hand_evaluator.dart';

void main() {
  final community = [
    CardModel(suit: Suit.clubs, value: 'K'),
    CardModel(suit: Suit.clubs, value: '8'),
    CardModel(suit: Suit.spades, value: '2'),
    CardModel(suit: Suit.diamonds, value: '7'),
    CardModel(suit: Suit.clubs, value: '10'),
  ];
  final hand = [
    CardModel(suit: Suit.clubs, value: '7'),
    CardModel(suit: Suit.diamonds, value: '3'),
  ];

  final result = HandEvaluator.evaluate(hand, community);
  print('Result rank: ${result.rankName}');
  print('Best hand: ${result.bestHand.map((c) => '${c.value} ${c.suit}').toList()}');
  print('Power: ${result.power}');
}
