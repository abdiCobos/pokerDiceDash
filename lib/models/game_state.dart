import 'card_model.dart';

enum GameStatus {
  waitingPlayers,
  dealing,
  diceTurn,
  betting,
  finished,
}

enum PokerPhase {
  preFlop,
  flop,
  turn,
  river,
  showdown,
}

// TODO: Blackjack 21 — Si dados == 2 y 1, activar evento especial:
// Repartir 2 cartas extra al jugador del turno y habilitar
// una apuesta flash (solo válida durante ese turno).

class GameState {
  final GameStatus status;
  final int currentPlayerIndex;
  final int pot;
  final bool mustSwapHands;
  final List<CardModel> communityCards;
  final PokerPhase phase;
  final int revealedCommunityCount;
  final int turnsCompleted;
  final int dealerIndex;

  GameState({
    this.status = GameStatus.waitingPlayers,
    this.currentPlayerIndex = 0,
    this.pot = 0,
    this.mustSwapHands = false,
    this.communityCards = const [],
    this.phase = PokerPhase.preFlop,
    this.revealedCommunityCount = 0,
    this.turnsCompleted = 0,
    this.dealerIndex = 0,
  });

  GameState copyWith({
    GameStatus? status,
    int? currentPlayerIndex,
    int? pot,
    bool? mustSwapHands,
    List<CardModel>? communityCards,
    PokerPhase? phase,
    int? revealedCommunityCount,
    int? turnsCompleted,
    int? dealerIndex,
  }) {
    return GameState(
      status: status ?? this.status,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      pot: pot ?? this.pot,
      mustSwapHands: mustSwapHands ?? this.mustSwapHands,
      communityCards: communityCards ?? this.communityCards,
      phase: phase ?? this.phase,
      revealedCommunityCount: revealedCommunityCount ?? this.revealedCommunityCount,
      turnsCompleted: turnsCompleted ?? this.turnsCompleted,
      dealerIndex: dealerIndex ?? this.dealerIndex,
    );
  }
}
