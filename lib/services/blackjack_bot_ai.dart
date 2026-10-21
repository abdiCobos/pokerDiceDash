import 'dart:math';

import '../models/blackjack_models.dart';
import 'poker_bot_ai.dart' show BotDifficulty;

enum BlackjackMove { hit, stand, double, split }

/// Blackjack bot decisions.
/// - Normal / Difícil: multi-deck basic strategy (dealer stands on all 17s,
///   double after split allowed). Normal makes a small mistake now and then.
/// - Fácil: a casual player ("hit below 15").
/// Pure Dart so it is unit-tested directly.
class BlackjackBotBrain {
  final BotDifficulty difficulty;
  final Random _rng;

  BlackjackBotBrain({this.difficulty = BotDifficulty.normal, Random? random}) : _rng = random ?? Random();

  static int cardValue(String v) => switch (v) {
        'A' => 11,
        'K' || 'Q' || 'J' => 10,
        _ => int.tryParse(v) ?? 0,
      };

  /// True when an ace still counts as 11 without busting.
  static bool isSoft(BlackjackHand h) {
    var hard = 0;
    var aces = 0;
    for (final c in h.cards) {
      if (c.value == 'A') {
        aces++;
        hard += 1;
      } else {
        hard += cardValue(c.value);
      }
    }
    return aces > 0 && hard + 10 <= 21;
  }

  /// [dealerUp] is the dealer's visible card value (2..11, ace = 11).
  BlackjackMove decide(BlackjackHand hand, int dealerUp, {required bool canDouble, required bool canSplit}) {
    final total = hand.handValue;
    if (difficulty == BotDifficulty.easy) return total < 15 ? BlackjackMove.hit : BlackjackMove.stand;

    var move = _basic(hand, total, dealerUp, canDouble: canDouble, canSplit: canSplit);
    // A normal bot sometimes plays a close spot "by feel".
    if (difficulty == BotDifficulty.normal && total >= 12 && total <= 16 && _rng.nextDouble() < 0.12) {
      move = move == BlackjackMove.stand ? BlackjackMove.hit : BlackjackMove.stand;
    }
    return move;
  }

  BlackjackMove _basic(BlackjackHand hand, int total, int up, {required bool canDouble, required bool canSplit}) {
    final twoCards = hand.cards.length == 2;
    bool vs(int lo, int hi) => up >= lo && up <= hi;
    BlackjackMove doubleOr(BlackjackMove fallback) => canDouble && twoCards ? BlackjackMove.double : fallback;

    // Pairs.
    if (canSplit && twoCards && hand.cards[0].value == hand.cards[1].value) {
      final v = cardValue(hand.cards[0].value);
      final split = switch (v) {
        11 || 8 => true,
        10 || 5 => false,
        9 => vs(2, 9) && up != 7,
        7 => vs(2, 7),
        6 => vs(2, 6),
        4 => vs(5, 6),
        2 || 3 => vs(2, 7),
        _ => false,
      };
      if (split) return BlackjackMove.split;
    }

    // Soft totals (A + x).
    if (isSoft(hand)) {
      if (total >= 19) return BlackjackMove.stand;
      if (total == 18) {
        if (vs(3, 6)) return doubleOr(BlackjackMove.stand);
        return up >= 9 ? BlackjackMove.hit : BlackjackMove.stand;
      }
      if (total == 17) return vs(3, 6) ? doubleOr(BlackjackMove.hit) : BlackjackMove.hit;
      if (total >= 15) return vs(4, 6) ? doubleOr(BlackjackMove.hit) : BlackjackMove.hit;
      return vs(5, 6) ? doubleOr(BlackjackMove.hit) : BlackjackMove.hit;
    }

    // Hard totals.
    if (total >= 17) return BlackjackMove.stand;
    if (total >= 13) return vs(2, 6) ? BlackjackMove.stand : BlackjackMove.hit;
    if (total == 12) return vs(4, 6) ? BlackjackMove.stand : BlackjackMove.hit;
    if (total == 11) return up <= 10 ? doubleOr(BlackjackMove.hit) : BlackjackMove.hit;
    if (total == 10) return vs(2, 9) ? doubleOr(BlackjackMove.hit) : BlackjackMove.hit;
    if (total == 9) return vs(3, 6) ? doubleOr(BlackjackMove.hit) : BlackjackMove.hit;
    return BlackjackMove.hit;
  }
}
