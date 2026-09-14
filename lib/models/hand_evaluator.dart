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
  static int _val(String v) {
    if (v == 'A') return 14;
    if (v == 'K') return 13;
    if (v == 'Q') return 12;
    if (v == 'J') return 11;
    return int.tryParse(v) ?? 2;
  }

  static HandResult evaluate(List<CardModel> hand, List<CardModel> community) {
    final allCards = [...hand, ...community];
    if (allCards.isEmpty) {
      return HandResult(rank: HandRank.highCard, bestHand: [], power: 0);
    }

    // Evaluate combinations of up to 5 cards
    int k = allCards.length < 5 ? allCards.length : 5;
    final combos = _combinations(allCards, k);
    HandResult? best;

    for (final combo in combos) {
      final res = _evaluateCombo(combo);
      if (best == null || res.power > best.power) {
        best = res;
      }
    }

    return best!;
  }

  static HandResult _evaluateCombo(List<CardModel> combo) {
    // Sort descending by value for easier processing
    final sorted = List<CardModel>.from(combo)
      ..sort((a, b) => _val(b.value).compareTo(_val(a.value)));
    
    List<int> vals = sorted.map((c) => _val(c.value)).toList();
    
    // Check flush
    bool isFlush = sorted.length >= 5 && sorted.every((c) => c.suit == sorted.first.suit);
    
    // Check straight
    bool isStraight = false;
    if (vals.length >= 5) {
      if (vals[0] == vals[1]+1 && vals[1] == vals[2]+1 && vals[2] == vals[3]+1 && vals[3] == vals[4]+1) {
        isStraight = true;
      } else if (vals[0] == 14 && vals[1] == 5 && vals[2] == 4 && vals[3] == 3 && vals[4] == 2) {
        isStraight = true;
        vals = [5, 4, 3, 2, 1]; // Treat Ace as 1 for power calculation
      }
    }

    if (isFlush && isStraight) {
      if (vals[0] == 14) return HandResult(rank: HandRank.royalFlush, bestHand: sorted, power: _power(HandRank.royalFlush, vals));
      return HandResult(rank: HandRank.straightFlush, bestHand: sorted, power: _power(HandRank.straightFlush, vals));
    }

    // Group by value to find pairs, trips, quads
    final counts = <int, int>{};
    for (var v in vals) counts[v] = (counts[v] ?? 0) + 1;
    
    final grouped = counts.entries.toList()..sort((a, b) {
      if (a.value != b.value) return b.value.compareTo(a.value); // sort by count descending
      return b.key.compareTo(a.key); // then by card value descending
    });

    final tieBreakers = grouped.map((e) => e.key).toList();

    if (grouped.isNotEmpty && grouped[0].value == 4) {
      return HandResult(rank: HandRank.fourOfAKind, bestHand: sorted, power: _power(HandRank.fourOfAKind, tieBreakers));
    }
    if (grouped.length > 1 && grouped[0].value == 3 && grouped[1].value >= 2) {
      return HandResult(rank: HandRank.fullHouse, bestHand: sorted, power: _power(HandRank.fullHouse, tieBreakers));
    }
    if (isFlush) {
      return HandResult(rank: HandRank.flush, bestHand: sorted, power: _power(HandRank.flush, vals));
    }
    if (isStraight) {
      return HandResult(rank: HandRank.straight, bestHand: sorted, power: _power(HandRank.straight, vals));
    }
    if (grouped.isNotEmpty && grouped[0].value == 3) {
      return HandResult(rank: HandRank.threeOfAKind, bestHand: sorted, power: _power(HandRank.threeOfAKind, tieBreakers));
    }
    if (grouped.length > 1 && grouped[0].value == 2 && grouped[1].value == 2) {
      return HandResult(rank: HandRank.twoPair, bestHand: sorted, power: _power(HandRank.twoPair, tieBreakers));
    }
    if (grouped.isNotEmpty && grouped[0].value == 2) {
      return HandResult(rank: HandRank.onePair, bestHand: sorted, power: _power(HandRank.onePair, tieBreakers));
    }
    
    return HandResult(rank: HandRank.highCard, bestHand: sorted, power: _power(HandRank.highCard, vals));
  }

  static int _power(HandRank rank, List<int> tieBreakers) {
    int p = rank.index << 20; // top 4 bits for rank (up to 9)
    for (int i = 0; i < tieBreakers.length && i < 5; i++) {
      // Each tiebreaker takes 4 bits (values up to 14 fit in 4 bits: 1110)
      p |= (tieBreakers[i] << (16 - i * 4));
    }
    return p;
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
