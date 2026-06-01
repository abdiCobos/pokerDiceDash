import '../services/logger_service.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/blackjack_models.dart';
import '../models/card_model.dart';
import '../services/sound_service.dart';
import '../services/logger_service.dart';

class BlackjackProvider extends ChangeNotifier {
  BlackjackState _state = BlackjackState();
  BlackjackState get state => _state;
  List<BlackjackPlayer> get players => _state.players;
  BlackjackPlayer? get dealer => players.cast<BlackjackPlayer?>().firstWhere((p) => p!.isDealer, orElse: () => null);
  List<BlackjackPlayer> get humanPlayers => players.where((p) => !p.isDealer).toList();
  BlackjackPhase get phase => _state.phase;
  int get currentPlayerIndex => _state.currentPlayerIndex;
  String? get message => _state.message;
  bool _isMultiplayer = false;
  bool get isMultiplayer => _isMultiplayer;

  static final _random = Random();

  void initSinglePlayer({int botCount = 0}) {
    AppLogger().event('blackjack_start', params: {'bot_count': botCount.toString()});
    _isMultiplayer = false;
    final list = <BlackjackPlayer>[];
    list.add(BlackjackPlayer(id: 'dealer', name: 'Dealer', isDealer: true, chipBalance: 99999));
    list.add(BlackjackPlayer(id: '0', name: 'Tú', chipBalance: 1000, isLocal: true));
    for (var i = 0; i < botCount; i++) {
      list.add(BlackjackPlayer(id: '${i + 1}', name: 'Bot ${i + 1}', chipBalance: 1000));
    }
    _state = BlackjackState(players: list, deck: _freshDeck(), phase: BlackjackPhase.betting);
    notifyListeners();
  }

  List<CardModel> _freshDeck() {
    const suits = [Suit.hearts, Suit.diamonds, Suit.clubs, Suit.spades];
    const values = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
    final deck = <CardModel>[];
    for (var d = 0; d < 6; d++) {
      for (final s in suits) {
        for (final v in values) {
          deck.add(CardModel(value: v, suit: s));
        }
      }
    }
    deck.shuffle(_random);
    return deck;
  }

  CardModel _draw() {
    if (_state.deck.length < 20) {
      _state = _state.copyWith(deck: _freshDeck());
    }
    final card = _state.deck.last;
    _state = _state.copyWith(deck: _state.deck.sublist(0, _state.deck.length - 1));
    return card;
  }

  void placeBet(String playerId, int amount) {
    AppLogger().event('blackjack_bet', params: {'player_id': playerId, 'amount': amount.toString()});
    final idx = players.indexWhere((p) => p.id == playerId);
    if (idx < 0) return;
    final p = players[idx];
    if (amount <= 0 || amount > p.chipBalance) return;
    final updated = <BlackjackPlayer>[...players];
    updated[idx] = BlackjackPlayer(
      id: p.id, name: p.name, chipBalance: p.chipBalance - amount,
      isLocal: p.isLocal, isDealer: p.isDealer, betAmount: amount,
    );
    _state = _state.copyWith(players: updated);
    notifyListeners();

    final humanPlayers = updated.where((p) => !p.isDealer && p.betAmount > 0).toList();
    AppLogger().log('🎰 Apuesta: $playerId=$amount, humanosConApuesta=${humanPlayers.length}');

    if (humanPlayers.length >= 1 && humanPlayers.every((p) => p.betAmount > 0)) {
      Future.delayed(const Duration(milliseconds: 300), _startDealing);
    }
  }

  void _startDealing() {
    final updated = <BlackjackPlayer>[...players];
    for (var i = 0; i < updated.length; i++) {
      updated[i] = BlackjackPlayer(
        id: updated[i].id, name: updated[i].name, chipBalance: updated[i].chipBalance,
        isLocal: updated[i].isLocal, isDealer: updated[i].isDealer,
        betAmount: updated[i].betAmount, hand: [],
        isStanding: false, isBusted: false,
      );
    }
    // Deal 2 cards each
    for (var round = 0; round < 2; round++) {
      for (var i = 0; i < updated.length; i++) {
        updated[i].hand.add(_draw());
      }
    }
    SoundService().cardMix();
    _state = BlackjackState(players: updated, deck: _state.deck, phase: BlackjackPhase.dealing);
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 800), () {
      // Auto-stand for blackjack players
      for (var i = 0; i < _state.players.length; i++) {
        if (!_state.players[i].isDealer && _state.players[i].isBlackjack) {
          final u = <BlackjackPlayer>[..._state.players];
          u[i] = BlackjackPlayer(
            id: u[i].id, name: u[i].name, chipBalance: u[i].chipBalance,
            isLocal: u[i].isLocal, isDealer: u[i].isDealer,
            hand: u[i].hand, betAmount: u[i].betAmount,
            isStanding: true, isBusted: false,
          );
          _state = _state.copyWith(players: u);
        }
      }
      _state = _state.copyWith(phase: BlackjackPhase.playerTurn, currentPlayerIndex: 0);
      _advanceToNextActivePlayer();
      notifyListeners();
    });
  }

  void _advanceToNextActivePlayer() {
    final humans = humanPlayers;
    if (humans.isEmpty) {
      _startDealerTurn();
      return;
    }
    // Find next player that hasn't acted yet
    var idx = _state.currentPlayerIndex;
    for (var loop = 0; loop < humans.length; loop++) {
      final p = humans[idx];
      if (!p.isStanding && !p.isBusted && !p.isBlackjack) {
        _state = _state.copyWith(currentPlayerIndex: idx);
        notifyListeners();
        // Auto-play bot
        if (_isMultiplayer || !p.isLocal) {
          Future.delayed(const Duration(milliseconds: 600), () => _autoPlayBot(p.id));
        }
        return;
      }
      idx = (idx + 1) % humans.length;
    }
    _startDealerTurn();
  }

  void _autoPlayBot(String playerId) {
    final p = _state.players.firstWhere((p) => p.id == playerId);
    if (p.handValue < 17) {
      hit(playerId);
    } else {
      stand(playerId);
    }
  }

  void hit(String playerId) {
    if (_state.phase != BlackjackPhase.playerTurn) return;
    final idx = _state.players.indexWhere((p) => p.id == playerId);
    if (idx < 0) return;
    final card = _draw();
    final updated = <BlackjackPlayer>[..._state.players];
    updated[idx].hand.add(card);
    SoundService().cardMix();

    if (updated[idx].handValue > 21) {
      updated[idx] = BlackjackPlayer(
        id: updated[idx].id, name: updated[idx].name, chipBalance: updated[idx].chipBalance,
        isLocal: updated[idx].isLocal, isDealer: updated[idx].isDealer,
        hand: updated[idx].hand, betAmount: updated[idx].betAmount,
        isStanding: true, isBusted: true,
      );
      AppLogger().log('💥 BUST: $playerId=${updated[idx].handValue}');
    }
    _state = _state.copyWith(players: updated, deck: _state.deck);
    notifyListeners();

    if (updated[idx].isBusted) {
      Future.delayed(const Duration(milliseconds: 500), _advanceToNextActivePlayer);
    }
  }

  void stand(String playerId) {
    if (_state.phase != BlackjackPhase.playerTurn) return;
    final idx = _state.players.indexWhere((p) => p.id == playerId);
    if (idx < 0) return;
    final updated = <BlackjackPlayer>[..._state.players];
    updated[idx] = BlackjackPlayer(
      id: updated[idx].id, name: updated[idx].name, chipBalance: updated[idx].chipBalance,
      isLocal: updated[idx].isLocal, isDealer: updated[idx].isDealer,
      hand: updated[idx].hand, betAmount: updated[idx].betAmount,
      isStanding: true, isBusted: updated[idx].isBusted,
    );
    _state = _state.copyWith(players: updated);
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 300), _advanceToNextActivePlayer);
  }

  void _startDealerTurn() {
    final d = dealer;
    if (d == null) return;
    _state = _state.copyWith(phase: BlackjackPhase.dealerTurn, message: 'Turno del Dealer');
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 500), _dealerPlay);
  }

  void _dealerPlay() {
    final d = dealer;
    if (d == null) return;
    final updated = <BlackjackPlayer>[..._state.players];
    final dIdx = updated.indexWhere((p) => p.isDealer);

    // Dealer hits until 17+
    while (updated[dIdx].handValue < 17) {
      updated[dIdx].hand.add(_draw());
      SoundService().cardMix();
    }
    _state = _state.copyWith(players: updated, deck: _state.deck);
    notifyListeners();

    final dealerVal = updated[dIdx].handValue;
    final dealerBj = updated[dIdx].isBlackjack;
    AppLogger().log('🎰 Dealer: $dealerVal (${dealerBj ? "BJ" : ""})');

    // Resolve bets
    final results = <String, String>{};
    for (var i = 0; i < updated.length; i++) {
      if (updated[i].isDealer) continue;
      final p = updated[i];
      int winAmount = 0;
      String result = '';

      if (p.isBusted) {
        result = '💥 Bust - Pierde ${p.betAmount}';
        winAmount = 0;
      } else if (dealerVal > 21) {
        winAmount = p.isBlackjack ? (p.betAmount * 2.5).toInt() : p.betAmount * 2;
        result = p.isBlackjack ? '🃏 Blackjack! Gana $winAmount' : '✅ Dealer bust - Gana $winAmount';
      } else if (p.isBlackjack && !dealerBj) {
        winAmount = (p.betAmount * 2.5).toInt();
        result = '🃏 Blackjack! Gana $winAmount';
      } else if (p.handValue > dealerVal) {
        winAmount = p.betAmount * 2;
        result = '✅ ${p.handValue} vs $dealerVal - Gana $winAmount';
      } else if (p.handValue == dealerVal) {
        winAmount = p.betAmount;
        result = '🤝 Empate ${p.handValue} - Recupera $winAmount';
      } else {
        result = '❌ ${p.handValue} vs $dealerVal - Pierde ${p.betAmount}';
      }

      updated[i] = BlackjackPlayer(
        id: updated[i].id, name: updated[i].name,
        chipBalance: updated[i].chipBalance + winAmount,
        isLocal: updated[i].isLocal, isDealer: updated[i].isDealer,
        hand: updated[i].hand, betAmount: updated[i].betAmount,
        isStanding: updated[i].isStanding, isBusted: updated[i].isBusted,
      );
      results[updated[i].id] = result;
    }

    final msgs = results.values.join('\n');
    _state = _state.copyWith(players: updated, phase: BlackjackPhase.roundEnd, message: msgs);
    SoundService().chipsWin();
    notifyListeners();

    // Auto new round after delay
    AppLogger().event('blackjack_round_end');
    Future.delayed(const Duration(seconds: 4), newRound);
  }

  void newRound() {
    if (_isMultiplayer) return;
    final updated = <BlackjackPlayer>[..._state.players];
    for (var i = 0; i < updated.length; i++) {
      if (updated[i].chipBalance <= 0 && !updated[i].isDealer) {
        updated[i] = BlackjackPlayer(
          id: updated[i].id, name: updated[i].name, chipBalance: 1000,
          isLocal: updated[i].isLocal, isDealer: updated[i].isDealer,
          betAmount: 0,
        );
      } else {
        updated[i] = BlackjackPlayer(
          id: updated[i].id, name: updated[i].name, chipBalance: updated[i].chipBalance,
          isLocal: updated[i].isLocal, isDealer: updated[i].isDealer,
          betAmount: 0, hand: [],
          isStanding: false, isBusted: false,
        );
      }
    }
    _state = BlackjackState(players: updated, deck: _freshDeck(), phase: BlackjackPhase.betting);
    notifyListeners();
  }
}
