import 'package:poker/poker.dart' as pk;
import 'card_model.dart';

enum HandRank {
  highCard,
  onePair,
  twoPair,
  threeOfAKind,
  straight,
  flush,
  fullHouse,
  fourOfAKind,
  straightFlush,
  royalFlush,
}

class HandResult {
  final HandRank rank;
  final List<CardModel> bestHand;
  final int power;

  const HandResult({
    required this.rank,
    required this.bestHand,
    required this.power,
  });

  String get rankName {
    switch (rank) {
      case HandRank.highCard: return 'Carta Alta';
      case HandRank.onePair: return 'Par';
      case HandRank.twoPair: return 'Doble Par';
      case HandRank.threeOfAKind: return 'Trío';
      case HandRank.straight: return 'Escalera';
      case HandRank.flush: return 'Color';
      case HandRank.fullHouse: return 'Full House';
      case HandRank.fourOfAKind: return 'Póker';
      case HandRank.straightFlush: return 'Escalera de Color';
      case HandRank.royalFlush: return 'Escalera Real';
    }
  }
}

class HandEvaluator {
  static pk.Rank _mapRank(String value) {
    switch (value) {
      case '2': return pk.Rank.deuce;
      case '3': return pk.Rank.trey;
      case '4': return pk.Rank.four;
      case '5': return pk.Rank.five;
      case '6': return pk.Rank.six;
      case '7': return pk.Rank.seven;
      case '8': return pk.Rank.eight;
      case '9': return pk.Rank.nine;
      case '10': return pk.Rank.ten;
      case 'J': return pk.Rank.jack;
      case 'Q': return pk.Rank.queen;
      case 'K': return pk.Rank.king;
      case 'A': return pk.Rank.ace;
      default: return pk.Rank.deuce;
    }
  }

  static pk.Suit _mapSuit(Suit suit) {
    switch (suit) {
      case Suit.spades: return pk.Suit.spade;
      case Suit.hearts: return pk.Suit.heart;
      case Suit.diamonds: return pk.Suit.diamond;
      case Suit.clubs: return pk.Suit.club;
    }
  }

  static pk.Card _toPokerCard(CardModel c) {
    return pk.Card(rank: _mapRank(c.value), suit: _mapSuit(c.suit));
  }

  static HandRank _mapHandRank(pk.MadeHand hand) {
    if (hand.type == pk.MadeHandType.straightFlush) {
      if (hand.power == 7461) return HandRank.royalFlush;
      return HandRank.straightFlush;
    }
    switch (hand.type) {
      case pk.MadeHandType.highcard: return HandRank.highCard;
      case pk.MadeHandType.pair: return HandRank.onePair;
      case pk.MadeHandType.twoPairs: return HandRank.twoPair;
      case pk.MadeHandType.trips: return HandRank.threeOfAKind;
      case pk.MadeHandType.straight: return HandRank.straight;
      case pk.MadeHandType.flush: return HandRank.flush;
      case pk.MadeHandType.fullHouse: return HandRank.fullHouse;
      case pk.MadeHandType.quads: return HandRank.fourOfAKind;
      case pk.MadeHandType.straightFlush: return HandRank.straightFlush;
    }
  }

  static HandResult evaluate(List<CardModel> hand, List<CardModel> community) {
    final allCards = [...hand, ...community];
    if (allCards.length < 5) {
      return HandResult(rank: HandRank.highCard, bestHand: allCards, power: 0);
    }

    final combos = _combinations(allCards, 5);
    HandResult? best;

    for (final combo in combos) {
      final pkCards = combo.map((c) => _toPokerCard(c)).toList();
      final cardSet = pk.ImmutableCardSet.from(pkCards);
      final madeHand = pk.MadeHand.best(cardSet);
      
      final result = HandResult(
        rank: _mapHandRank(madeHand),
        bestHand: combo,
        power: madeHand.power,
      );

      if (best == null || result.power > best.power) {
        best = result;
      }
    }

    return best!;
  }

  static List<List<CardModel>> _combinations(List<CardModel> list, int k) {
    if (k == 0) return [[]];
    if (list.isEmpty) return [];

    final result = <List<CardModel>>[];
    final first = list[0];
    final rest = list.sublist(1);

    for (final combo in _combinations(rest, k - 1)) {
      result.add([first, ...combo]);
    }
    result.addAll(_combinations(rest, k));

    return result;
  }
}
