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

  static final _random = Random();

  void _logAndNotify(String method) {
    try {
      AppLogger().log('BJ:$method');
      notifyListeners();
    } catch (e, s) {
      AppLogger().error('BJ:$method failed: $e', s);
    }
  }

  void initSinglePlayer({int botCount = 0}) {
    try {
      AppLogger().event('blackjack_start', params: {'bot_count': botCount.toString()});
      _isMultiplayer = false;
      final list = <BlackjackPlayer>[];
      list.add(BlackjackPlayer(id: 'dealer', name: 'Dealer', isDealer: true, chipBalance: 99999));
      list.add(BlackjackPlayer(id: '0', name: 'Tú', chipBalance: 1000, isLocal: true));
      for (var i = 0; i < botCount; i++) {
        list.add(BlackjackPlayer(id: '${i + 1}', name: 'Bot ${i + 1}', chipBalance: 1000));
      }
      _state = BlackjackState(players: list, deck: _freshDeck(), phase: BlackjackPhase.betting);
      AppLogger().log('BJ:Creados 6 mazos (312 cartas) - inicial');
      _logAndNotify('initSinglePlayer');
    } catch (e, s) {
      AppLogger().error('BJ:initSinglePlayer crash: $e', s);
    }
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
    AppLogger().log('BJ:Mazo nuevo: 312 cartas (6 decks)');
    return deck;
  }

  CardModel _draw() {
    if (_state.deck.length < 20) {
      _state = _state.copyWith(deck: _freshDeck(), message: 'Barajando 6 mazos nuevos...', clearMessage: false);
      AppLogger().log('BJ:Reshuffle - quedaban ${_state.deck.length} cartas - barajando otros 6 mazos');
    }
    final card = _state.deck.last;
    _state = _state.copyWith(deck: _state.deck.sublist(0, _state.deck.length - 1));
    return card;
  }

  void placeBet(String playerId, int amount) {
    try {
      AppLogger().log('BJ:placeBet $playerId=$amount');
      final idx = players.indexWhere((p) => p.id == playerId);
      if (idx < 0) return;
      final p = players[idx];
      if (amount <= 0 || amount > p.chipBalance) return;
      final updated = <BlackjackPlayer>[...players];
      final hand = BlackjackHand(betAmount: amount);
      updated[idx] = BlackjackPlayer(
        id: p.id, name: p.name, chipBalance: p.chipBalance - amount,
        isLocal: p.isLocal, isDealer: p.isDealer,
        hands: [hand], totalBet: amount,
      );
      _state = _state.copyWith(players: updated);
      _logAndNotify('placeBet');

      final bettors = updated.where((p) => !p.isDealer && p.totalBet > 0).toList();
      AppLogger().log('BJ:bettors=${bettors.length}');
      if (bettors.length >= 1 && bettors.every((p) => p.totalBet > 0)) {
        _startDealingSequence();
      }
    } catch (e, s) {
      AppLogger().error('BJ:placeBet crash: $e', s);
    }
  }

  void _startDealingSequence() {
    try {
      AppLogger().log('BJ:_startDealingSequence');
      final updated = <BlackjackPlayer>[...players];
      for (var i = 0; i < updated.length; i++) {
        updated[i] = BlackjackPlayer(
          id: updated[i].id, name: updated[i].name, chipBalance: updated[i].chipBalance,
          isLocal: updated[i].isLocal, isDealer: updated[i].isDealer,
          hands: [BlackjackHand(betAmount: updated[i].totalBet)],
          totalBet: updated[i].totalBet,
        );
      }
      _state = BlackjackState(players: updated, deck: _state.deck, phase: BlackjackPhase.dealing);
      _logAndNotify('_startDealingSequence-phase');

      // Deal cards one by one with delays
      _dealCardsSequentially(updated);
    } catch (e, s) {
      AppLogger().error('BJ:_startDealingSequence crash: $e', s);
    }
  }

  int _getNextDealIndex(int currentPlayerSlot, int dealRound) {
    // Deal round 0: each player gets 1st card (in order, ending with dealer face-up)
    // Deal round 1: each player gets 2nd card (in order, dealer gets hole card face-down)
    // Total: 2 * players.length cards
    return (dealRound * players.length) + currentPlayerSlot;
  }

  void _dealCardsSequentially(List<BlackjackPlayer> playerList) {
    var dealStep = 0;
    final maxSteps = playerList.length * 2;

    void dealNextCard() {
      if (dealStep >= maxSteps) {
        Future.delayed(const Duration(milliseconds: 400), _afterDealComplete);
        return;
      }
      final round = dealStep ~/ playerList.length;
      final slot = dealStep % playerList.length;

      final updated = <BlackjackPlayer>[..._state.players];
      final card = _draw();
      updated[slot].hands[0].cards.add(card);
      if (dealStep % playerList.length == 0) {
        SoundService().cardMix();
      }
      _state = _state.copyWith(players: updated, deck: _state.deck);
      _logAndNotify('_dealCardsSequentially-$dealStep');
      dealStep++;
      Future.delayed(const Duration(milliseconds: 350), dealNextCard);
    }

    dealNextCard();
  }

  void _afterDealComplete() {
    try {
      AppLogger().log('BJ:_afterDealComplete');
      var updated = <BlackjackPlayer>[..._state.players];
      final dealerIdx = updated.indexWhere((p) => p.isDealer);
      if (dealerIdx < 0) return;

      // If dealer has blackjack, end round
      final dealerBj = updated[dealerIdx].hands[0].isBlackjack;
      AppLogger().log('BJ:dealerBJ=$dealerBj dealerVal=${updated[dealerIdx].hands[0].handValue}');

      // Auto-stand for player blackjacks
      for (var i = 0; i < updated.length; i++) {
        if (updated[i].isDealer) continue;
        if (updated[i].hands[0].isBlackjack) {
          updated[i].hands[0].isStanding = true;
        }
      }

      _state = _state.copyWith(players: updated);
      _logAndNotify('_afterDealComplete');

      if (dealerBj && dealerIdx == updated.length - 1) {
        // All players lose unless they also have BJ
        Future.delayed(const Duration(milliseconds: 500), _startDealerTurn);
      } else {
        _state = _state.copyWith(phase: BlackjackPhase.playerTurn, currentPlayerIndex: 0, currentHandIndex: 0);
        _logAndNotify('_afterDealComplete-playerTurn');
        Future.delayed(const Duration(milliseconds: 300), _advanceToNextActivePlayer);
      }
    } catch (e, s) {
      AppLogger().error('BJ:_afterDealComplete crash: $e', s);
    }
  }

  void _advanceToNextActivePlayer() {
    try {
      final humans = humanPlayers;
      if (humans.isEmpty) { _startDealerTurn(); return; }

      var pIdx = _state.currentPlayerIndex;
      var hIdx = 0;
      for (var loop = 0; loop < humans.length * 5; loop++) {
        final p = humans[pIdx];
        // Check all hands of this player
        for (hIdx = 0; hIdx < p.hands.length; hIdx++) {
          if (!p.hands[hIdx].isFinished && p.hands[hIdx].cards.length >= 2) {
            _state = _state.copyWith(currentPlayerIndex: pIdx, currentHandIndex: hIdx);
            _logAndNotify('_advanceToNextActivePlayer-$pIdx-$hIdx');
            // Auto-play bot
            if (!p.isLocal) {
              Future.delayed(const Duration(milliseconds: 600), () => _autoPlayBot(p.id));
            }
            return;
          }
        }
        pIdx = (pIdx + 1) % humans.length;
      }
      _startDealerTurn();
    } catch (e, s) {
      AppLogger().error('BJ:_advanceToNextActivePlayer crash: $e', s);
    }
  }

  void _autoPlayBot(String playerId) {
    try {
      final pIdx = players.indexWhere((p) => p.id == playerId);
      if (pIdx < 0) return;
      final p = players[pIdx];
      final h = p.currentHand;
      if (h.handValue < 17) {
        hit(playerId);
      } else {
        stand(playerId);
      }
    } catch (e, s) {
      AppLogger().error('BJ:_autoPlayBot crash: $e', s);
    }
  }

  void hit(String playerId) {
    try {
      AppLogger().log('BJ:hit $playerId');
      if (_state.phase != BlackjackPhase.playerTurn) return;
      final pIdx = players.indexWhere((p) => p.id == playerId);
      if (pIdx < 0) return;
      final card = _draw();
      final updated = <BlackjackPlayer>[...players];
      final hands = <BlackjackHand>[...updated[pIdx].hands];
      final hIdx = updated[pIdx].activeHandIndex;
      hands[hIdx].cards.add(card);
      SoundService().cardMix();

      final val = hands[hIdx].handValue;
      if (val > 21) {
        hands[hIdx].isBusted = true;
        hands[hIdx].isStanding = true;
        AppLogger().log('BJ:BUST $playerId=$val');
      } else if (val == 21) {
        hands[hIdx].isStanding = true;
        AppLogger().log('BJ:21 $playerId=$val');
      }
      updated[pIdx] = updated[pIdx].copyWith(hands: hands);
      _state = _state.copyWith(players: updated, deck: _state.deck);
      _logAndNotify('hit');

      if (hands[hIdx].isFinished) {
        Future.delayed(const Duration(milliseconds: 400), _advanceToNextActivePlayer);
      } else if (hands[hIdx].isDoubledDown) {
        hands[hIdx].isStanding = true;
        updated[pIdx] = updated[pIdx].copyWith(hands: hands);
        _state = _state.copyWith(players: updated);
        _logAndNotify('hit-doubledDown');
        Future.delayed(const Duration(milliseconds: 400), _advanceToNextActivePlayer);
      }
    } catch (e, s) {
      AppLogger().error('BJ:hit crash: $e', s);
    }
  }

  void stand(String playerId) {
    try {
      AppLogger().log('BJ:stand $playerId');
      if (_state.phase != BlackjackPhase.playerTurn) return;
      final pIdx = players.indexWhere((p) => p.id == playerId);
      if (pIdx < 0) return;
      final hands = <BlackjackHand>[...players[pIdx].hands];
      final hIdx = players[pIdx].activeHandIndex;
      if (hIdx >= hands.length) return;
      hands[hIdx].isStanding = true;
      final updated = <BlackjackPlayer>[...players];
      updated[pIdx] = players[pIdx].copyWith(hands: hands);
      _state = _state.copyWith(players: updated);
      _logAndNotify('stand');
      Future.delayed(const Duration(milliseconds: 300), _advanceToNextActivePlayer);
    } catch (e, s) {
      AppLogger().error('BJ:stand crash: $e', s);
    }
  }

  void doubleDown(String playerId) {
    try {
      AppLogger().log('BJ:doubleDown $playerId');
      if (_state.phase != BlackjackPhase.playerTurn) return;
      final pIdx = players.indexWhere((p) => p.id == playerId);
      if (pIdx < 0) return;
      final hands = <BlackjackHand>[...players[pIdx].hands];
      final hIdx = players[pIdx].activeHandIndex;
      if (hIdx >= hands.length) return;
      final extraBet = hands[hIdx].betAmount;
      if (players[pIdx].chipBalance < extraBet) return;
      hands[hIdx] = hands[hIdx].copyWith(betAmount: hands[hIdx].betAmount * 2, isDoubledDown: true);
      final updated = <BlackjackPlayer>[...players];
      updated[pIdx] = players[pIdx].copyWith(
        hands: hands,
        chipBalance: players[pIdx].chipBalance - extraBet,
        totalBet: players[pIdx].totalBet + extraBet,
      );
      _state = _state.copyWith(players: updated);
      _logAndNotify('doubleDown');
      // Deal exactly one more card
      hit(playerId);
    } catch (e, s) {
      AppLogger().error('BJ:doubleDown crash: $e', s);
    }
  }

  void splitPair(String playerId) {
    try {
      AppLogger().log('BJ:splitPair $playerId');
      if (_state.phase != BlackjackPhase.playerTurn) return;
      final pIdx = players.indexWhere((p) => p.id == playerId);
      if (pIdx < 0) return;
      final p = players[pIdx];
      if (!p.canSplit) return;
      final betPerHand = p.hands[0].betAmount;
      if (p.chipBalance < betPerHand) return;

      final cards = p.hands[0].cards;
      final hand1 = BlackjackHand(cards: [cards[0]], betAmount: betPerHand);
      final hand2 = BlackjackHand(cards: [cards[1]], betAmount: betPerHand);

      // Deal one card to each hand
      hand1.cards.add(_draw());
      SoundService().cardMix();
      _state = _state.copyWith(deck: _state.deck);
      _logAndNotify('splitPair-card1');

      hand2.cards.add(_draw());
      SoundService().cardMix();

      final updated = <BlackjackPlayer>[...players];
      updated[pIdx] = p.copyWith(
        hands: [hand1, hand2],
        chipBalance: p.chipBalance - betPerHand,
        totalBet: p.totalBet + betPerHand,
        activeHandIndex: 0,
      );
      _state = _state.copyWith(players: updated, deck: _state.deck, currentHandIndex: 0);
      _logAndNotify('splitPair');

      // Check for 21 in first hand
      if (hand1.handValue == 21) {
        hand1.isStanding = true;
        updated[pIdx] = updated[pIdx].copyWith(hands: [hand1, hand2]);
        _state = _state.copyWith(players: updated);
        _logAndNotify('splitPair-firstHand21');
        _advanceToNextActivePlayer();
      }
    } catch (e, s) {
      AppLogger().error('BJ:splitPair crash: $e', s);
    }
  }

  void _startDealerTurn() {
    try {
      AppLogger().log('BJ:_startDealerTurn');
      final dIdx = players.indexWhere((p) => p.isDealer);
      if (dIdx < 0) return;
      _state = _state.copyWith(phase: BlackjackPhase.dealerTurn);
      _logAndNotify('_startDealerTurn');
      Future.delayed(const Duration(milliseconds: 400), _dealerPlay);
    } catch (e, s) {
      AppLogger().error('BJ:_startDealerTurn crash: $e', s);
    }
  }

  void _dealerPlay() {
    try {
      AppLogger().log('BJ:_dealerPlay');
      final dIdx = players.indexWhere((p) => p.isDealer);
      if (dIdx < 0) return;
      var dealerPlayer = players[dIdx];
      final dealerHand = dealerPlayer.hands[0];

      // Check if all players busted - dealer doesn't need to draw
      final allPlayersBusted = humanPlayers.every((p) =>
          p.hands.every((h) => h.isBusted || h.cards.isEmpty));
      AppLogger().log('BJ:allBusted=$allPlayersBusted');

      if (!allPlayersBusted) {
        var updated = <BlackjackPlayer>[...players];
        while (dealerHand.handValue < 17) {
          dealerHand.cards.add(_draw());
          updated[dIdx] = BlackjackPlayer(
            id: dealerPlayer.id, name: dealerPlayer.name,
            chipBalance: dealerPlayer.chipBalance,
            isLocal: dealerPlayer.isLocal, isDealer: true,
            hands: [dealerHand],
          );
          _state = _state.copyWith(players: updated, deck: _state.deck);
          _logAndNotify('_dealerPlay-hit');
          SoundService().cardMix();
        }
      }

      final dealerVal = dealerHand.handValue;
      final dealerBj = dealerHand.isBlackjack;
      AppLogger().log('BJ:dealerFinal=$dealerVal bj=$dealerBj');

      _resolveRound();
    } catch (e, s) {
      AppLogger().error('BJ:_dealerPlay crash: $e', s);
    }
  }

  void _resolveRound() {
    try {
      AppLogger().log('BJ:_resolveRound');
      final dIdx = players.indexWhere((p) => p.isDealer);
      if (dIdx < 0) return;
      const dealerIdx = 0; // dealer is always first in list
      final dealerVal = players[dIdx].hands[0].handValue;

      final results = <String, String>{};
      var finalPlayers = <BlackjackPlayer>[...players];

      for (var i = 0; i < finalPlayers.length; i++) {
        if (finalPlayers[i].isDealer) continue;
        var p = finalPlayers[i];
        int totalWinnings = 0;

        for (var h = 0; h < p.hands.length; h++) {
          final hand = p.hands[h];
          if (hand.cards.isEmpty) continue;
          int winAmount = 0;

          if (hand.isBusted) {
            winAmount = 0;
          } else if (dealerVal > 21) {
            winAmount = hand.isBlackjack ? (hand.betAmount * 2.5).round() : hand.betAmount * 2;
          } else if (hand.isBlackjack) {
            winAmount = (hand.betAmount * 2.5).round();
          } else if (hand.handValue > dealerVal) {
            winAmount = hand.betAmount * 2;
          } else if (hand.handValue == dealerVal) {
            winAmount = hand.betAmount;
          }
          totalWinnings += winAmount;
        }

        final netChange = totalWinnings - p.totalBet;
        p = p.copyWith(chipBalance: p.chipBalance + totalWinnings);

        final dealerHand = finalPlayers[dIdx].hands[0];
        String result;
        if (p.hands.any((h) => h.isBusted)) {
          result = '💥 Bust - Pierdes ${p.totalBet}';
        } else if (dealerVal > 21) {
          result = '✅ Dealer bust - Ganas ${netChange > 0 ? "+$netChange" : netChange}';
        } else if (p.isBlackjack) {
          result = '🃏 Blackjack! Ganas +${netChange}';
        } else if (p.hands.any((h) => h.handValue > dealerVal)) {
          result = '✅ Ganas con: ${p.hands.map((h) => h.handValue.toString()).join(" & ")} - +${netChange}';
        } else if (p.hands.any((h) => h.handValue == dealerVal)) {
          result = '🤝 Empate - Recuperas ${totalWinnings}';
        } else {
          result = '❌ Dealer gana con: $dealerVal - Pierdes ${p.totalBet}';
        }
        AppLogger().log('BJ:result $i: $result');
        results[p.id] = result;
        finalPlayers[i] = p;
      }

      final msgs = results.values.join('\n');
      _state = _state.copyWith(players: finalPlayers, phase: BlackjackPhase.roundEnd, message: msgs);
      SoundService().chipsWin();
      _logAndNotify('_resolveRound');

      AppLogger().event('blackjack_round_end');
    } catch (e, s) {
      AppLogger().error('BJ:_resolveRound crash: $e', s);
    }
  }

  void newRound() {
    try {
      if (_isMultiplayer) return;
      var updated = <BlackjackPlayer>[..._state.players];
      for (var i = 0; i < updated.length; i++) {
        final balance = updated[i].chipBalance <= 0 && !updated[i].isDealer
            ? 1000 : updated[i].chipBalance;
        updated[i] = BlackjackPlayer(
          id: updated[i].id, name: updated[i].name, chipBalance: balance,
          isLocal: updated[i].isLocal, isDealer: updated[i].isDealer,
          hands: [BlackjackHand()], totalBet: 0,
        );
      }
      _state = BlackjackState(players: updated, deck: _freshDeck(), phase: BlackjackPhase.betting);
      _logAndNotify('newRound');
    } catch (e, s) {
      AppLogger().error('BJ:newRound crash: $e', s);
    }
  }
}
