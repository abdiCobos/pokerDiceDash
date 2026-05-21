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
  final List<int> kickers;

  const HandResult({
    required this.rank,
    required this.bestHand,
    required this.kickers,
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
  static int _cardValue(String value) {
    switch (value) {
      case '2': return 2;
      case '3': return 3;
      case '4': return 4;
      case '5': return 5;
      case '6': return 6;
      case '7': return 7;
      case '8': return 8;
      case '9': return 9;
      case '10': return 10;
      case 'J': return 11;
      case 'Q': return 12;
      case 'K': return 13;
      case 'A': return 14;
      default: return 0;
    }
  }

  static HandResult evaluate(List<CardModel> hand, List<CardModel> community) {
    final allCards = [...hand, ...community];
    if (allCards.length < 5) {
      return HandResult(rank: HandRank.highCard, bestHand: allCards, kickers: []);
    }

    final combos = _combinations(allCards, 5);
    HandResult? best;

    for (final combo in combos) {
      final result = _evaluateFive(combo);
      if (best == null || _compareResults(result, best) > 0) {
        best = result;
      }
    }

    return best!;
  }

  static int _compareResults(HandResult a, HandResult b) {
    if (a.rank.index != b.rank.index) {
      return a.rank.index.compareTo(b.rank.index);
    }
    for (var i = 0; i < a.kickers.length && i < b.kickers.length; i++) {
      if (a.kickers[i] != b.kickers[i]) {
        return a.kickers[i].compareTo(b.kickers[i]);
      }
    }
    return 0;
  }

  static int compareKickers(List<int> a, List<int> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return 0;
  }

  static HandResult _evaluateFive(List<CardModel> cards) {
    final sorted = List<CardModel>.from(cards)
      ..sort((a, b) => _cardValue(b.value).compareTo(_cardValue(a.value)));

    final values = sorted.map((c) => _cardValue(c.value)).toList();
    final suits = sorted.map((c) => c.suit).toList();

    final isFlush = suits.every((s) => s == suits[0]);
    final isStraight = _checkStraight(values);
    final aceLowStraight = _checkAceLowStraight(values);

    final valueCounts = <int, int>{};
    for (final v in values) {
      valueCounts[v] = (valueCounts[v] ?? 0) + 1;
    }

    final pairs = <int>[];
    int threeOfAKind = 0;
    int fourOfAKind = 0;

    for (final entry in valueCounts.entries) {
      if (entry.value == 4) fourOfAKind = entry.key;
      if (entry.value == 3) threeOfAKind = entry.key;
      if (entry.value == 2) pairs.add(entry.key);
    }
    pairs.sort((a, b) => b.compareTo(a));

    // Royal Flush
    if (isFlush && isStraight && values[0] == 14 && values[1] == 13) {
      return HandResult(rank: HandRank.royalFlush, bestHand: sorted, kickers: []);
    }

    // Straight Flush
    if (isFlush && isStraight) {
      final high = aceLowStraight ? 5 : values[0];
      return HandResult(rank: HandRank.straightFlush, bestHand: sorted, kickers: [high]);
    }

    // Four of a Kind
    if (fourOfAKind != 0) {
      final kicker = values.where((v) => v != fourOfAKind).toList();
      return HandResult(rank: HandRank.fourOfAKind, bestHand: sorted, kickers: [fourOfAKind, ...kicker]);
    }

    // Full House
    if (threeOfAKind != 0 && pairs.isNotEmpty) {
      return HandResult(rank: HandRank.fullHouse, bestHand: sorted, kickers: [threeOfAKind, pairs[0]]);
    }

    // Flush
    if (isFlush) {
      return HandResult(rank: HandRank.flush, bestHand: sorted, kickers: values);
    }

    // Straight
    if (isStraight) {
      final high = aceLowStraight ? 5 : values[0];
      return HandResult(rank: HandRank.straight, bestHand: sorted, kickers: [high]);
    }

    // Three of a Kind
    if (threeOfAKind != 0) {
      final kickers = values.where((v) => v != threeOfAKind).toList();
      return HandResult(rank: HandRank.threeOfAKind, bestHand: sorted, kickers: [threeOfAKind, ...kickers]);
    }

    // Two Pair
    if (pairs.length >= 2) {
      final kicker = values.where((v) => v != pairs[0] && v != pairs[1]).toList();
      return HandResult(rank: HandRank.twoPair, bestHand: sorted, kickers: [pairs[0], pairs[1], ...kicker]);
    }

    // One Pair
    if (pairs.length == 1) {
      final kickers = values.where((v) => v != pairs[0]).toList();
      return HandResult(rank: HandRank.onePair, bestHand: sorted, kickers: [pairs[0], ...kickers]);
    }

    // High Card
    return HandResult(rank: HandRank.highCard, bestHand: sorted, kickers: values);
  }

  static bool _checkStraight(List<int> values) {
    for (var i = 0; i < values.length - 1; i++) {
      if (values[i] - values[i + 1] != 1) return false;
    }
    return true;
  }

  static bool _checkAceLowStraight(List<int> values) {
    if (values[0] != 14) return false;
    final aceLow = [5, 4, 3, 2, 1];
    for (var i = 0; i < values.length; i++) {
      final v = values[i] == 14 ? 1 : values[i];
      if (v != aceLow[i]) return false;
    }
    return true;
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
