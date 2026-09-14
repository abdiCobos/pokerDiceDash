import 'package:poker/poker.dart' as pk;

void main() {
  final cards = [
    pk.Card(rank: pk.Rank.seven, suit: pk.Suit.club),
    pk.Card(rank: pk.Rank.king, suit: pk.Suit.club),
    pk.Card(rank: pk.Rank.eight, suit: pk.Suit.club),
    pk.Card(rank: pk.Rank.seven, suit: pk.Suit.diamond),
    pk.Card(rank: pk.Rank.ten, suit: pk.Suit.club),
  ];
  final set = pk.ImmutableCardSet.from(cards);
  print('set length: ${set.length}');
  final hand = pk.MadeHand.best(set);
  print('hand type: ${hand.type}');
  print('hand value: ${hand.hashCode}');
  print('hand power: ${hand.power}');
}
