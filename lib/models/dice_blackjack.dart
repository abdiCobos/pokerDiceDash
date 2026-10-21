import 'dart:math';

import 'blackjack_models.dart';
import 'card_model.dart';

/// Dice Dash "21" event (rolled 2+1): the roller plays one hand of Blackjack
/// against the dealer, betting their own free chips against the house.
///
/// Pure Dart, no timers: `GameProvider` drives it and syncs it to LAN clients.
/// It uses its own shoe so the poker deck is never touched.
enum DiceBlackjackStage { betting, playing, dealer, done }

class DiceBlackjack {
  static const int minBet = 10;
  static const int maxBet = 200;

  final String playerId;
  final String playerName;
  DiceBlackjackStage stage = DiceBlackjackStage.betting;
  int bet = 0;
  final BlackjackHand player = BlackjackHand();
  final BlackjackHand dealer = BlackjackHand();

  /// Chips returned to the player when the hand is settled (0 = lost).
  int payout = 0;
  String result = '';
  bool skipped = false;

  final List<CardModel> _shoe;

  DiceBlackjack({required this.playerId, required this.playerName, Random? random, List<CardModel>? stackedCards})
      : _shoe = _newShoe(random ?? Random()) {
    // Tests put known cards on top of the shoe (first card first).
    if (stackedCards != null) _shoe.addAll(stackedCards.reversed);
  }

  static List<CardModel> _newShoe(Random rng) {
    const values = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
    return [
      for (final s in Suit.values)
        for (final v in values) CardModel(value: v, suit: s),
    ]..shuffle(rng);
  }

  CardModel _draw() => _shoe.removeLast();

  /// Highest bet the player may place with [freeChips] (chips not yet in the pot).
  static int maxBetFor(int freeChips) => min(maxBet, freeChips);

  /// The event only happens if the player can afford the minimum bet.
  static bool canPlay(int freeChips) => freeChips >= minBet;

  /// Places the bet and deals. Returns false if the amount is not allowed.
  bool placeBet(int amount, int freeChips) {
    if (stage != DiceBlackjackStage.betting) return false;
    if (amount < minBet || amount > maxBetFor(freeChips)) return false;
    bet = amount;
    player.cards
      ..add(_draw())
      ..add(_draw());
    dealer.cards
      ..add(_draw())
      ..add(_draw());
    // Naturals end the hand at once.
    if (player.isNatural || dealer.isNatural) {
      stage = DiceBlackjackStage.dealer;
      settle();
    } else {
      stage = DiceBlackjackStage.playing;
    }
    return true;
  }

  /// The player declines to bet: the event ends with nothing at stake.
  void skip() {
    if (stage != DiceBlackjackStage.betting) return;
    skipped = true;
    stage = DiceBlackjackStage.done;
    result = 'No apostó';
  }

  void hit() {
    if (stage != DiceBlackjackStage.playing) return;
    player.cards.add(_draw());
    if (player.handValue >= 21) stand();
  }

  void stand() {
    if (stage != DiceBlackjackStage.playing) return;
    stage = DiceBlackjackStage.dealer;
    if (player.handValue > 21) settle();
  }

  /// Dealer draws one card if it must (below 17). Returns true while it keeps drawing.
  bool dealerStep() {
    if (stage != DiceBlackjackStage.dealer) return false;
    if (dealer.handValue < 17) {
      dealer.cards.add(_draw());
      return true;
    }
    settle();
    return false;
  }

  /// Pays the hand: blackjack 3:2, win 1:1, push returns the bet, otherwise lost.
  void settle() {
    if (stage == DiceBlackjackStage.done) return;
    final p = player.handValue;
    final d = dealer.handValue;
    final playerNatural = player.cards.length == 2 && p == 21;
    final dealerNatural = dealer.isNatural;
    if (p > 21) {
      payout = 0;
      result = 'Te pasaste de 21';
    } else if (playerNatural && dealerNatural) {
      payout = bet;
      result = 'Blackjack contra blackjack: empate';
    } else if (playerNatural) {
      payout = (bet * 2.5).round();
      result = '¡Blackjack!';
    } else if (dealerNatural) {
      payout = 0;
      result = 'Blackjack del crupier';
    } else if (d > 21) {
      payout = bet * 2;
      result = 'El crupier se pasó';
    } else if (p > d) {
      payout = bet * 2;
      result = 'Ganas $p a $d';
    } else if (p == d) {
      payout = bet;
      result = 'Empate a $p';
    } else {
      payout = 0;
      result = 'Gana el crupier $d a $p';
    }
    stage = DiceBlackjackStage.done;
  }

  int get net => skipped ? 0 : payout - bet;

  /// Snapshot for LAN clients; the dealer's hole card stays hidden while the player decides.
  Map<String, dynamic> toMap() {
    final hideHole = stage == DiceBlackjackStage.betting || stage == DiceBlackjackStage.playing;
    return {
      'playerId': playerId,
      'playerName': playerName,
      'stage': stage.name,
      'bet': bet,
      'payout': payout,
      'result': result,
      'skipped': skipped,
      'player': [for (final c in player.cards) c.toMap()],
      'dealer': [
        for (var i = 0; i < dealer.cards.length; i++)
          (hideHole && i == 1) ? CardModel(value: '2', suit: Suit.spades).toMap() : dealer.cards[i].toMap(),
      ],
      'hiddenHole': hideHole && dealer.cards.length > 1,
    };
  }

  /// Client-side copy (read only: clients never run the logic).
  factory DiceBlackjack.fromMap(Map<String, dynamic> m) {
    final e = DiceBlackjack(playerId: m['playerId'] as String? ?? '', playerName: m['playerName'] as String? ?? '');
    e.stage = DiceBlackjackStage.values.firstWhere((s) => s.name == m['stage'], orElse: () => DiceBlackjackStage.betting);
    e.bet = (m['bet'] as num?)?.toInt() ?? 0;
    e.payout = (m['payout'] as num?)?.toInt() ?? 0;
    e.result = m['result'] as String? ?? '';
    e.skipped = m['skipped'] as bool? ?? false;
    e.hiddenHole = m['hiddenHole'] as bool? ?? false;
    for (final c in (m['player'] as List? ?? const [])) {
      e.player.cards.add(CardModel.fromJson(Map<String, dynamic>.from(c as Map)));
    }
    for (final c in (m['dealer'] as List? ?? const [])) {
      e.dealer.cards.add(CardModel.fromJson(Map<String, dynamic>.from(c as Map)));
    }
    return e;
  }

  /// Client copies: the dealer's second card is a placeholder until revealed.
  bool hiddenHole = false;

  bool get holeHidden => hiddenHole || stage == DiceBlackjackStage.betting || stage == DiceBlackjackStage.playing;
}
