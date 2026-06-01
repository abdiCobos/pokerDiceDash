import 'dart:math';
import '../models/card_model.dart';
import '../models/hand_evaluator.dart';
import '../models/game_state.dart';

class BotAction {
  final String type;
  final int? amount;
  BotAction(this.type, [this.amount]);
}

class BotService {
  static final _random = Random();

  BotAction decideAction(
    List<CardModel> hand,
    List<CardModel> communityCards,
    int currentBet,
    int alreadyBet,
    int chipBalance,
  ) {
    final handResult = HandEvaluator.evaluate(hand, communityCards);
    final rank = handResult?.rank ?? HandRank.highCard;
    final amountToCall = currentBet - alreadyBet;

    if (communityCards.isEmpty) {
      final strong = _isStrongPair(hand) || _isHighConnectors(hand);
      final medium = _isMediumPair(hand) || _isSuitedConnectors(hand) || _hasHighCards(hand);

      if (strong) {
        if (amountToCall <= 0) return BotAction('RAISE', _clampRaise(20, 100, chipBalance));
        return BotAction('CALL');
      }
      if (medium) {
        if (amountToCall <= 20) return BotAction('CALL');
        if (_random.nextDouble() < 0.4 && amountToCall <= 0) return BotAction('RAISE', _clampRaise(10, 50, chipBalance));
        return BotAction('CALL');
      }
      if (amountToCall <= 0) return BotAction('CHECK');
      if (amountToCall > 10) return BotAction('FOLD');
      if (_random.nextDouble() < 0.3) return BotAction('CALL');
      return BotAction('FOLD');
    }

    double aggression;
    switch (rank) {
      case HandRank.royalFlush: case HandRank.straightFlush: aggression = 1.0; break;
      case HandRank.fourOfAKind: aggression = 0.95; break;
      case HandRank.fullHouse: aggression = 0.9; break;
      case HandRank.flush: aggression = 0.75; break;
      case HandRank.straight: aggression = 0.65; break;
      case HandRank.threeOfAKind: aggression = 0.55; break;
      case HandRank.twoPair: aggression = 0.45; break;
      case HandRank.onePair: aggression = 0.25; break;
      default: aggression = 0.1 + (_random.nextDouble() * 0.1);
    }
    aggression += (_random.nextDouble() - 0.5) * 0.2;
    aggression = aggression.clamp(0.0, 1.0);

    if (amountToCall <= 0) {
      if (aggression > 0.5) return BotAction('RAISE', _clampRaise(20, 200, chipBalance));
      return BotAction('CHECK');
    }

    if (aggression > 0.6) {
      if (_random.nextDouble() < 0.4) return BotAction('RAISE', _clampRaise(amountToCall, amountToCall * 3, chipBalance));
      return BotAction('CALL');
    }

    if (aggression > 0.3) {
      if (amountToCall <= chipBalance * 0.3) return BotAction('CALL');
      if (_random.nextDouble() < 0.5) return BotAction('CALL');
      return BotAction('FOLD');
    }

    if (amountToCall <= 5) return BotAction('CALL');
    return BotAction('FOLD');
  }

  bool _isStrongPair(List<CardModel> hand) {
    if (hand.length < 2) return false;
    if (hand[0].value == hand[1].value) return ['A','K','Q','J'].contains(hand[0].value);
    return false;
  }

  bool _isMediumPair(List<CardModel> hand) {
    if (hand.length < 2) return false;
    if (hand[0].value == hand[1].value) {
      final v = hand[0].value;
      final n = int.tryParse(v);
      return n != null && n >= 7;
    }
    return false;
  }

  bool _isHighConnectors(List<CardModel> hand) {
    if (hand.length < 2) return false;
    final high = ['A','K','Q','J','10'];
    return high.contains(hand[0].value) && high.contains(hand[1].value) && hand[0].suit == hand[1].suit;
  }

  bool _isSuitedConnectors(List<CardModel> hand) {
    if (hand.length < 2) return false;
    return hand[0].suit == hand[1].suit;
  }

  bool _hasHighCards(List<CardModel> hand) {
    return hand.any((c) => ['A','K','Q','J'].contains(c.value));
  }

  int _clampRaise(int minAmt, int maxAmt, int chipBalance) {
    final amt = minAmt + _random.nextInt(max(maxAmt - minAmt + 1, 1));
    return amt.clamp(1, chipBalance);
  }
}
