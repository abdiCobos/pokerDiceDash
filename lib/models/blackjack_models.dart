import 'card_model.dart';

class BlackjackPlayer {
  final String id;
  String name;
  int chipBalance;
  final bool isLocal;
  final bool isDealer;
  final List<CardModel> hand;
  bool isStanding;
  bool isBusted;
  int betAmount;

  BlackjackPlayer({
    required this.id,
    required this.name,
    this.chipBalance = 1000,
    this.isLocal = false,
    this.isDealer = false,
    List<CardModel>? hand,
    this.isStanding = false,
    this.isBusted = false,
    this.betAmount = 0,
  }) : hand = hand ?? [];

  int get handValue {
    int total = 0;
    int aces = 0;
    for (final c in hand) {
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

  bool get isBlackjack => hand.length == 2 && handValue == 21;

  int _cardValue(String v) {
    switch (v) {
      case 'A': return 11;
      case 'K': case 'Q': case 'J': return 10;
      default: return int.tryParse(v) ?? 0;
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'chipBalance': chipBalance,
    'isLocal': isLocal,
    'isDealer': isDealer,
    'hand': hand.map((c) => c.toMap()).toList(),
    'isStanding': isStanding,
    'isBusted': isBusted,
    'betAmount': betAmount,
  };

  factory BlackjackPlayer.fromMap(Map<String, dynamic> m) => BlackjackPlayer(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    chipBalance: m['chipBalance'] ?? 1000,
    isLocal: m['isLocal'] ?? false,
    isDealer: m['isDealer'] ?? false,
    hand: (m['hand'] as List?)?.map((c) => CardModel.fromJson(c)).toList() ?? [],
    isStanding: m['isStanding'] ?? false,
    isBusted: m['isBusted'] ?? false,
    betAmount: m['betAmount'] ?? 0,
  );
}

enum BlackjackPhase {
  betting,
  dealing,
  playerTurn,
  dealerTurn,
  roundEnd,
}

class BlackjackState {
  final List<BlackjackPlayer> players;
  final int currentPlayerIndex;
  final BlackjackPhase phase;
  final List<CardModel> deck;
  final String? message;

  BlackjackState({
    this.players = const [],
    this.currentPlayerIndex = 0,
    this.phase = BlackjackPhase.betting,
    this.deck = const [],
    this.message,
  });

  BlackjackState copyWith({
    List<BlackjackPlayer>? players,
    int? currentPlayerIndex,
    BlackjackPhase? phase,
    List<CardModel>? deck,
    String? message,
    bool clearMessage = false,
  }) => BlackjackState(
    players: players ?? this.players,
    currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
    phase: phase ?? this.phase,
    deck: deck ?? this.deck,
    message: clearMessage ? null : (message ?? this.message),
  );
}
