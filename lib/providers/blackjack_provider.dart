import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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
  bool _isHost = true;
  bool get isHost => _isHost;
  String localPlayerId = '0';

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
      _isHost = true;
      localPlayerId = '0';
      final list = <BlackjackPlayer>[];
      list.add(BlackjackPlayer(id: 'dealer', name: 'Dealer', isDealer: true, chipBalance: 99999));
      list.add(BlackjackPlayer(id: '0', name: 'Yo', chipBalance: 1000, isLocal: true));
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

  void initMultiplayer({required bool asHost}) {
    try {
      _isMultiplayer = true;
      _isHost = asHost;
      localPlayerId = asHost ? '0' : '1';
      final list = <BlackjackPlayer>[];
      list.add(BlackjackPlayer(id: 'dealer', name: 'Dealer', isDealer: true, chipBalance: 99999));
      list.add(BlackjackPlayer(id: '0', name: 'Host', chipBalance: 1000, isLocal: asHost));
      _state = BlackjackState(players: list, deck: _freshDeck(), phase: BlackjackPhase.waiting);
      _logAndNotify('initMultiplayer');
    } catch (e, s) {
      AppLogger().error('BJ:initMultiplayer crash: $e', s);
    }
  }

  void addRemotePlayer(String playerId, String name) {
    if (!_isHost) return;
    final list = <BlackjackPlayer>[..._state.players];
    list.add(BlackjackPlayer(id: playerId, name: name, chipBalance: 1000));
    _state = _state.copyWith(players: list);
    _logAndNotify('addRemotePlayer');
  }

  void startMatch() {
    if (!_isHost || !_isMultiplayer) return;
    _state = _state.copyWith(phase: BlackjackPhase.betting);
    _logAndNotify('startMatch');
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
      _dealCardsSequentially(updated);
    } catch (e, s) {
      AppLogger().error('BJ:_startDealingSequence crash: $e', s);
    }
  }

  void _dealCardsSequentially(List<BlackjackPlayer> playerList) {
    var dealStep = 0;
    final maxSteps = playerList.length * 2;
    // Total dealt card count for animation delay
    final totalDealt = <String, int>{};

    void dealNextCard() {
      if (dealStep >= maxSteps) {
        Future.delayed(const Duration(milliseconds: 400), _afterDealComplete);
        return;
      }
      final slot = dealStep % playerList.length;
      final updated = <BlackjackPlayer>[..._state.players];
      final card = _draw();
      updated[slot].hands[0].cards.add(card);
      if (dealStep % playerList.length == 0) SoundService().cardMix();
      _state = _state.copyWith(players: updated, deck: _state.deck);
      _logAndNotify('_dealCardsSequentially-$dealStep');
      dealStep++;
      // 350ms delay between each card
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
      final dealerBj = updated[dealerIdx].hands[0].isBlackjack;
      AppLogger().log('BJ:dealerBJ=$dealerBj dealerVal=${updated[dealerIdx].hands[0].handValue}');
      for (var i = 0; i < updated.length; i++) {
        if (updated[i].isDealer) continue;
        if (updated[i].hands[0].isBlackjack) updated[i].hands[0].isStanding = true;
      }
      _state = _state.copyWith(players: updated);
      _logAndNotify('_afterDealComplete');
      if (dealerBj) {
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
      for (var loop = 0; loop < humans.length * 5; loop++) {
        final p = humans[pIdx % humans.length];
        for (var hIdx = 0; hIdx < p.hands.length; hIdx++) {
          if (!p.hands[hIdx].isFinished && p.hands[hIdx].cards.length >= 2) {
            final updatedPlayers = <BlackjackPlayer>[..._state.players];
            final playerMainIdx = updatedPlayers.indexWhere((pl) => pl.id == p.id);
            if (playerMainIdx >= 0) {
              updatedPlayers[playerMainIdx] = updatedPlayers[playerMainIdx].copyWith(activeHandIndex: hIdx);
            }
            _state = _state.copyWith(players: updatedPlayers, currentPlayerIndex: pIdx % humans.length, currentHandIndex: hIdx);
            _logAndNotify('_advanceToNextActivePlayer-$pIdx-$hIdx');
            if (!p.isLocal) {
              Future.delayed(const Duration(milliseconds: 600), () => _autoPlayBot(p.id));
            }
            return;
          }
        }
        pIdx++;
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
      if (h.handValue < 17) hit(playerId); else stand(playerId);
    } catch (e, s) {
      AppLogger().error('BJ:_autoPlayBot crash: $e', s);
    }
  }

  void hit(String playerId) {
    try {
      AppLogger().log('BJ:hit $playerId phase=${_state.phase}');
      if (_state.phase != BlackjackPhase.playerTurn) return;
      final pIdx = players.indexWhere((p) => p.id == playerId);
      if (pIdx < 0) return;
      final card = _draw();
      final updated = <BlackjackPlayer>[...players];
      final hands = <BlackjackHand>[...updated[pIdx].hands];
      final hIdx = _state.currentHandIndex < hands.length ? _state.currentHandIndex : hands.length - 1;
      if (hIdx < 0 || hIdx >= hands.length) return;
      hands[hIdx].cards.add(card);
      SoundService().cardMix();
      final val = hands[hIdx].handValue;
      AppLogger().log('BJ:hit hand=$hIdx val=$val cards=${hands[hIdx].cards.length}');
      if (val > 21) {
        hands[hIdx].isBusted = true;
        hands[hIdx].isStanding = true;
        AppLogger().log('BJ:BUST $playerId=$val hand=$hIdx');
      } else if (val == 21) {
        hands[hIdx].isStanding = true;
        AppLogger().log('BJ:21 $playerId=$val hand=$hIdx');
      } else if (hands[hIdx].cards.length >= 5) {
        hands[hIdx].isStanding = true;
        hands[hIdx].isCharlie = true;
        AppLogger().log('BJ:5-Card Charlie $playerId=$val hand=$hIdx');
      }
      updated[pIdx] = updated[pIdx].copyWith(hands: hands, activeHandIndex: hIdx);
      _state = _state.copyWith(players: updated, deck: _state.deck, currentHandIndex: hIdx);
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
      FirebaseCrashlytics.instance.recordError(e, s, fatal: false);
    }
  }

  void stand(String playerId) {
    try {
      AppLogger().log('BJ:stand $playerId');
      if (_state.phase != BlackjackPhase.playerTurn) return;
      final pIdx = players.indexWhere((p) => p.id == playerId);
      if (pIdx < 0) return;
      final hands = <BlackjackHand>[...players[pIdx].hands];
      final hIdx = _state.currentHandIndex < hands.length ? _state.currentHandIndex : hands.length - 1;
      if (hIdx >= hands.length || hIdx < 0) return;
      hands[hIdx].isStanding = true;
      AppLogger().log('BJ:stand hand=$hIdx value=${hands[hIdx].handValue}');
      final updated = <BlackjackPlayer>[...players];
      updated[pIdx] = players[pIdx].copyWith(hands: hands, activeHandIndex: hIdx);
      _state = _state.copyWith(players: updated, currentHandIndex: hIdx);
      _logAndNotify('stand');
      Future.delayed(const Duration(milliseconds: 400), _advanceToNextActivePlayer);
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
        hands: hands, chipBalance: players[pIdx].chipBalance - extraBet,
        totalBet: players[pIdx].totalBet + extraBet,
      );
      _state = _state.copyWith(players: updated);
      _logAndNotify('doubleDown');
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
      hand1.cards.add(_draw());
      SoundService().cardMix();
      _state = _state.copyWith(deck: _state.deck);
      _logAndNotify('splitPair-card1');
      hand2.cards.add(_draw());
      SoundService().cardMix();
      final updated = <BlackjackPlayer>[...players];
      updated[pIdx] = p.copyWith(
        hands: [hand1, hand2], chipBalance: p.chipBalance - betPerHand,
        totalBet: p.totalBet + betPerHand, activeHandIndex: 0,
      );
      _state = _state.copyWith(players: updated, deck: _state.deck, currentHandIndex: 0);
      _logAndNotify('splitPair');
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
      final dealerPlayer = players[dIdx];
      final dealerHand = BlackjackHand(
        cards: List.from(dealerPlayer.hands[0].cards),
        betAmount: dealerPlayer.hands[0].betAmount,
        isStanding: dealerPlayer.hands[0].isStanding,
        isBusted: dealerPlayer.hands[0].isBusted,
      );
      final allPlayersBusted = humanPlayers.every((p) => p.hands.every((h) => h.isBusted || h.cards.isEmpty));
      AppLogger().log('BJ:allBusted=$allPlayersBusted');
      if (!allPlayersBusted) { _dealerDrawCardSequential(dIdx, dealerHand); return; }
      _resolveRound();
    } catch (e, s) {
      AppLogger().error('BJ:_dealerPlay crash: $e', s);
    }
  }

  void _dealerDrawCardSequential(int dIdx, BlackjackHand hand) {
    if (hand.handValue >= 17) {
      var updated = <BlackjackPlayer>[...players];
      updated[dIdx] = BlackjackPlayer(
        id: updated[dIdx].id, name: updated[dIdx].name, chipBalance: updated[dIdx].chipBalance,
        isLocal: updated[dIdx].isLocal, isDealer: true, hands: [hand],
      );
      _state = _state.copyWith(players: updated);
      _logAndNotify('_dealerDrawCard-done');
      AppLogger().log('BJ:dealerFinal=${hand.handValue} bj=${hand.isBlackjack}');
      Future.delayed(const Duration(milliseconds: 500), _resolveRound);
      return;
    }
    hand.cards.add(_draw());
    SoundService().cardMix();
    var updated = <BlackjackPlayer>[...players];
    updated[dIdx] = BlackjackPlayer(
      id: updated[dIdx].id, name: updated[dIdx].name, chipBalance: updated[dIdx].chipBalance,
      isLocal: updated[dIdx].isLocal, isDealer: true, hands: [hand],
    );
    _state = _state.copyWith(players: updated, deck: _state.deck);
    _logAndNotify('_dealerDrawCard-hit-${hand.handValue}');
    Future.delayed(const Duration(milliseconds: 700), () => _dealerDrawCardSequential(dIdx, hand));
  }

  void _resolveRound() {
    try {
      AppLogger().log('BJ:_resolveRound');
      final dIdx = players.indexWhere((p) => p.isDealer);
      if (dIdx < 0) return;
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
          } else if (hand.isCharlie) {
            winAmount = hand.betAmount * 2;
          } else if (hand.handValue > dealerVal) {
            winAmount = hand.betAmount * 2;
          } else if (hand.handValue == dealerVal) {
            winAmount = hand.betAmount;
          }
          totalWinnings += winAmount;
        }
        final netChange = totalWinnings - p.totalBet;
        p = p.copyWith(chipBalance: p.chipBalance + totalWinnings);
        String result;
        if (p.hands.any((h) => h.isBusted)) {
          result = 'Bust - Pierdes ${p.totalBet}';
        } else if (dealerVal > 21) {
          result = 'Dealer bust - Ganas ${netChange > 0 ? "+$netChange" : netChange}';
        } else if (p.isBlackjack) {
          result = 'Blackjack! Ganas +${netChange}';
        } else if (p.hands.any((h) => h.isCharlie)) {
          result = '5-Card Charlie! Ganas +${netChange}';
        } else if (p.hands.any((h) => h.handValue > dealerVal)) {
          result = 'Ganas con: ${p.hands.map((h) => h.handValue.toString()).join(" & ")} vs $dealerVal - +${netChange}';
        } else if (p.hands.any((h) => h.handValue == dealerVal)) {
          result = 'Empate ${p.hands[0].handValue} - Recuperas ${totalWinnings}';
        } else {
          result = 'Dealer gana con: $dealerVal - Pierdes ${p.totalBet}';
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
      var updated = <BlackjackPlayer>[..._state.players];
      for (var i = 0; i < updated.length; i++) {
        final balance = updated[i].chipBalance <= 0 && !updated[i].isDealer ? 1000 : updated[i].chipBalance;
        updated[i] = BlackjackPlayer(
          id: updated[i].id, name: updated[i].name, chipBalance: balance,
          isLocal: updated[i].isLocal, isDealer: updated[i].isDealer,
          hands: [BlackjackHand()], totalBet: 0,
        );
      }
      _state = BlackjackState(players: updated, deck: _state.deck, phase: _isMultiplayer ? BlackjackPhase.waiting : BlackjackPhase.betting);
      _logAndNotify('newRound');
    } catch (e, s) {
      AppLogger().error('BJ:newRound crash: $e', s);
    }
  }
}
