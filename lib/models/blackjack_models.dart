import 'card_model.dart';

class BlackjackHand {
  final List<CardModel> cards;
  final int betAmount;
  bool isStanding;
  bool isBusted;
  bool isDoubledDown;

  BlackjackHand({
    List<CardModel>? cards,
    this.betAmount = 0,
    this.isStanding = false,
    this.isBusted = false,
    this.isDoubledDown = false,
  }) : cards = cards ?? [];

  int get handValue {
    int total = 0;
    int aces = 0;
    for (final c in cards) {
      final v = _cardValue(c.value);
      total += v;
      if (v == 11) aces++;
    }
    while (total > 21 && aces > 0) {
      total -= 10;
      aces--;
    }
    return total;
  }

  bool get isBlackjack => cards.length == 2 && handValue == 21 && betAmount > 0;
  bool get canSplit => cards.length == 2 && _cardValue(cards[0].value) == _cardValue(cards[1].value);
  bool get isFinished => isStanding || isBusted || isBlackjack;

  int _cardValue(String v) {
    switch (v) {
      case 'A': return 11;
      case 'K': case 'Q': case 'J': return 10;
    default: return int.tryParse(v) ?? 0;
    }
  }

  BlackjackHand copyWith({
    List<CardModel>? cards,
    int? betAmount,
    bool? isStanding,
    bool? isBusted,
    bool? isDoubledDown,
  }) => BlackjackHand(
      cards: cards ?? this.cards,
      betAmount: betAmount ?? this.betAmount,
      isStanding: isStanding ?? this.isStanding,
      isBusted: isBusted ?? this.isBusted,
      isDoubledDown: isDoubledDown ?? this.isDoubledDown,
    );

  Map<String, dynamic> toMap() => {
    'cards': cards.map((c) => c.toMap()).toList(),
    'betAmount': betAmount,
    'isStanding': isStanding,
    'isBusted': isBusted,
    'isDoubledDown': isDoubledDown,
  };

  factory BlackjackHand.fromMap(Map<String, dynamic> m) => BlackjackHand(
    cards: (m['cards'] as List?)?.map((c) => CardModel.fromJson(c)).toList() ?? [],
    betAmount: m['betAmount'] ?? 0,
    isStanding: m['isStanding'] ?? false,
    isBusted: m['isBusted'] ?? false,
    isDoubledDown: m['isDoubledDown'] ?? false,
  );
}

class BlackjackPlayer {
  final String id;
  String name;
  int chipBalance;
  final bool isLocal;
  final bool isDealer;
  final List<BlackjackHand> hands;
  int activeHandIndex;
  int totalBet;

  BlackjackPlayer({
    required this.id,
    required this.name,
    this.chipBalance = 1000,
    this.isLocal = false,
    this.isDealer = false,
    List<BlackjackHand>? hands,
    this.activeHandIndex = 0,
    this.totalBet = 0,
  }) : hands = hands ?? [BlackjackHand()];

  BlackjackHand get currentHand => hands[activeHandIndex];
  bool get isBlackjack => hands.length == 1 && hands[0].isBlackjack;
  bool get isFinished =>
      hands.every((h) => h.isFinished || h.cards.isEmpty);
  bool get canSplit =>
      hands.length == 1 && hands[0].canSplit && !hands[0].isDoubledDown;

  BlackjackPlayer copyWith({
    String? id, String? name, int? chipBalance, bool? isLocal, bool? isDealer,
    List<BlackjackHand>? hands, int? activeHandIndex, int? totalBet,
  }) => BlackjackPlayer(
      id: id ?? this.id, name: name ?? this.name,
      chipBalance: chipBalance ?? this.chipBalance,
      isLocal: isLocal ?? this.isLocal,
      isDealer: isDealer ?? this.isDealer,
      hands: hands ?? this.hands,
      activeHandIndex: activeHandIndex ?? this.activeHandIndex,
      totalBet: totalBet ?? this.totalBet,
    );

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'chipBalance': chipBalance,
    'isLocal': isLocal, 'isDealer': isDealer,
    'hands': hands.map((h) => h.toMap()).toList(),
    'activeHandIndex': activeHandIndex, 'totalBet': totalBet,
  };

  factory BlackjackPlayer.fromMap(Map<String, dynamic> m) => BlackjackPlayer(
    id: m['id'] ?? '', name: m['name'] ?? '',
    chipBalance: m['chipBalance'] ?? 1000,
    isLocal: m['isLocal'] ?? false, isDealer: m['isDealer'] ?? false,
    hands: (m['hands'] as List?)?.map((h) => BlackjackHand.fromMap(h)).toList() ?? [BlackjackHand()],
    activeHandIndex: m['activeHandIndex'] ?? 0,
    totalBet: m['totalBet'] ?? 0,
  );
}

enum BlackjackPhase { betting, dealing, playerTurn, dealerTurn, roundEnd }

class BlackjackState {
  final List<BlackjackPlayer> players;
  final int currentPlayerIndex;
  final int currentHandIndex;
  final BlackjackPhase phase;
  final List<CardModel> deck;
  final String? message;

  BlackjackState({
    this.players = const [],
    this.currentPlayerIndex = 0,
    this.currentHandIndex = 0,
    this.phase = BlackjackPhase.betting,
    this.deck = const [],
    this.message,
  });

  BlackjackState copyWith({
    List<BlackjackPlayer>? players, int? currentPlayerIndex,
    int? currentHandIndex, BlackjackPhase? phase,
    List<CardModel>? deck, String? message, bool clearMessage = false,
  }) => BlackjackState(
      players: players ?? this.players,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      currentHandIndex: currentHandIndex ?? this.currentHandIndex,
      phase: phase ?? this.phase,
      deck: deck ?? this.deck,
      message: clearMessage ? null : (message ?? this.message),
    );
}
