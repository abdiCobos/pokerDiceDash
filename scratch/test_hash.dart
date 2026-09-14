import 'package:poker/poker.dart' as pk;
import '../poker_lib/src/constants/precalculated_table.dart';

void main() {
  final cards = [
    pk.Card(rank: pk.Rank.seven, suit: pk.Suit.club),
    pk.Card(rank: pk.Rank.king, suit: pk.Suit.club),
    pk.Card(rank: pk.Rank.eight, suit: pk.Suit.club),
    pk.Card(rank: pk.Rank.seven, suit: pk.Suit.diamond),
    pk.Card(rank: pk.Rank.ten, suit: pk.Suit.club),
  ];
  final set = pk.ImmutableCardSet.from(cards);
  
  final cardLengthEachRank = {
    pk.Rank.ace: 0,
    pk.Rank.deuce: 0,
    pk.Rank.trey: 0,
    pk.Rank.four: 0,
    pk.Rank.five: 0,
    pk.Rank.six: 0,
    pk.Rank.seven: 0,
    pk.Rank.eight: 0,
    pk.Rank.nine: 0,
    pk.Rank.ten: 0,
    pk.Rank.jack: 0,
    pk.Rank.queen: 0,
    pk.Rank.king: 0,
  };
  int remainingCardLength = set.length;

  for (final card in set) {
    cardLengthEachRank[card.rank] = cardLengthEachRank[card.rank]! + 1;
  }
  
  int hash = 0;
  for (final rank in const [
    pk.Rank.deuce, pk.Rank.trey, pk.Rank.four, pk.Rank.five, pk.Rank.six, pk.Rank.seven, pk.Rank.eight, pk.Rank.nine, pk.Rank.ten, pk.Rank.jack, pk.Rank.queen, pk.Rank.king, pk.Rank.ace,
  ]) {
    final length = cardLengthEachRank[rank]!;
    if (length == 0) continue;
    hash += dpReference[length]![rank]![remainingCardLength];
    remainingCardLength -= length;
    if (remainingCardLength == 0) break;
  }
  
  print('hash: $hash');
  print('asRainbow[hash]: ${asRainbow[hash]}');
}
