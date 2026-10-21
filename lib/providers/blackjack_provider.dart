import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/blackjack_models.dart';
import '../models/card_model.dart';
import '../services/sound_service.dart';
import '../services/logger_service.dart';
import '../services/blackjack_bot_ai.dart';
import '../services/bot_service.dart';
import '../services/poker_bot_ai.dart' show BotDifficulty;
import '../services/p2p_service.dart';
import 'game_provider.dart';

class BlackjackProvider extends ChangeNotifier {
  BlackjackState _state = BlackjackState();
  BlackjackState get state => _state;
  List<BlackjackPlayer> get players => _state.players;
  BlackjackPlayer? get dealer => players.cast<BlackjackPlayer?>().firstWhere((p) => p!.isDealer, orElse: () => null);
  List<BlackjackPlayer> get activePlayers => players.where((p) => !p.isDealer).toList();
  List<BlackjackPlayer> get botPlayers => players.where((p) => p.isBot).toList();
  List<BlackjackPlayer> get humanOnlyPlayers => players.where((p) => !p.isDealer && !p.isBot).toList();
  BlackjackPlayer get localPlayer => players.firstWhere(
        (p) => p.isLocal,
        // A client can render before the host's first state names its seat.
        orElse: () => BlackjackPlayer(id: localPlayerId, name: 'Tú', chipBalance: 0, isLocal: true),
      );
  BlackjackPhase get phase => _state.phase;
  int get currentPlayerIndex => _state.currentPlayerIndex;
  String? get message => _state.message;
  bool _isMultiplayer = false;
  bool get isMultiplayer => _isMultiplayer;
  bool _isHost = true;
  bool get isHost => _isHost;
  String localPlayerId = '0';

  /// Per-player outcome of the last resolved round (short label + net chips),
  /// shown on each seat. Empty outside [BlackjackPhase.roundEnd].
  Map<String, String> _roundOutcome = const {};
  Map<String, String> get roundOutcome => _roundOutcome;
  Map<String, int> _roundNet = const {};
  Map<String, int> get roundNet => _roundNet;

  static final _random = Random();

  // --- LAN multiplayer -------------------------------------------------------
  // The host is authoritative: it runs the whole game and sends each client a
  // BJ_STATE snapshot; clients only send BJ_ACTION intents. Joins, passwords,
  // tokens and reconnects are handled by the lobby ([GameProvider]).
  static const Duration remoteTurnTimeout = Duration(seconds: 40);
  static const Duration awayTurnDelay = Duration(seconds: 2);
  static const Duration bettingTimeout = Duration(seconds: 30);
  static const Duration autoNextRound = Duration(seconds: 12);

  P2PService? _p2p;
  GameProvider? _lobby;
  StreamSubscription<Map<String, dynamic>>? _messageSub;
  StreamSubscription<SeatEvent>? _seatSub;
  Timer? _broadcastTimer;
  Timer? _turnTimer;
  Timer? _bettingTimer;
  Timer? _nextRoundTimer;
  bool _disposed = false;
  final String _session = '${DateTime.now().microsecondsSinceEpoch}';
  int _seq = 0;
  String? _remoteSession;
  int _lastRemoteSeq = -1;
  int _remoteDeckCount = 0;
  final Set<String> _away = {};

  /// Seats whose player is disconnected (host and clients see the same set).
  Set<String> get awaySeats => _away;
  int get deckCount => _isMultiplayer && !_isHost ? _remoteDeckCount : _state.deck.length;
  bool get isClient => _isMultiplayer && !_isHost;

  void _logAndNotify(String method) {
    if (_disposed) return;
    try {
      AppLogger().log('BJ:$method');
      notifyListeners();
      if (_isMultiplayer && _isHost) _scheduleBroadcast();
    } catch (e, s) {
      AppLogger().error('BJ:$method failed: $e', s);
    }
  }

  void _scheduleBroadcast() {
    if (_broadcastTimer != null) return;
    _broadcastTimer = Timer(const Duration(milliseconds: 90), () {
      _broadcastTimer = null;
      _sendStateNow();
    });
  }

  /// Snapshot for clients. The dealer's hole card is hidden until it is revealed.
  Map<String, dynamic> exportState() {
    final reveal = _state.phase == BlackjackPhase.dealerTurn || _state.phase == BlackjackPhase.roundEnd;
    return {
      'phase': _state.phase.name,
      'currentPlayerIndex': _state.currentPlayerIndex,
      'currentHandIndex': _state.currentHandIndex,
      'message': _state.message,
      'deckCount': _state.deck.length,
      'away': _away.toList(),
      'roundOutcome': _roundOutcome,
      'roundNet': _roundNet,
      'players': [
        for (final p in _state.players)
          if (p.isDealer && !reveal && p.hands.isNotEmpty && p.hands[0].cards.length > 1)
            (p.toMap()
              ..['hands'] = [
                {
                  ...p.hands[0].toMap(),
                  'cards': [
                    p.hands[0].cards[0].toMap(),
                    for (var i = 1; i < p.hands[0].cards.length; i++) CardModel(value: '2', suit: Suit.spades).toMap(),
                  ],
                },
              ])
          else
            p.toMap()..['isLocal'] = false,
      ],
    };
  }

  void _sendStateNow() {
    final p2p = _p2p;
    if (p2p == null || !_isHost || _disposed) return;
    _seq++;
    p2p.broadcastMessage({'type': 'BJ_STATE', 'session': _session, 'seq': _seq, 'state': exportState()});
  }

  /// Applies a host snapshot on a client.
  void applyRemoteState(Map<String, dynamic> st) {
    final previousCards = players.fold<int>(0, (n, p) => n + p.hands.fold<int>(0, (m, h) => m + h.cards.length));
    final previousBets = players.fold<int>(0, (n, p) => n + p.totalBet);
    final previousPhase = _state.phase;
    final list = <BlackjackPlayer>[
      for (final raw in (st['players'] as List? ?? const []))
        () {
          final pl = BlackjackPlayer.fromMap(Map<String, dynamic>.from(raw as Map));
          return pl.copyWith(isLocal: pl.id == localPlayerId);
        }(),
    ];
    final phase = BlackjackPhase.values.firstWhere(
      (ph) => ph.name == st['phase'],
      orElse: () => _state.phase,
    );
    _remoteDeckCount = (st['deckCount'] as num?)?.toInt() ?? 0;
    _away
      ..clear()
      ..addAll([for (final a in (st['away'] as List? ?? const [])) a.toString()]);
    _roundOutcome = Map<String, String>.from((st['roundOutcome'] as Map?) ?? const {});
    _roundNet = {
      for (final e in ((st['roundNet'] as Map?) ?? const {}).entries) e.key.toString(): (e.value as num).toInt(),
    };
    _state = BlackjackState(
      players: list,
      currentPlayerIndex: (st['currentPlayerIndex'] as num?)?.toInt() ?? 0,
      currentHandIndex: (st['currentHandIndex'] as num?)?.toInt() ?? 0,
      phase: phase,
      message: st['message'] as String?,
    );
    final nowCards = list.fold<int>(0, (n, p) => n + p.hands.fold<int>(0, (m, h) => m + h.cards.length));
    if (nowCards > previousCards) SoundService().cardMix();
    final betsNow = list.fold<int>(0, (n, p) => n + p.totalBet);
    if (betsNow > previousBets && phase == BlackjackPhase.betting) SoundService().chipsRaise();
    if (phase == BlackjackPhase.roundEnd && previousPhase != BlackjackPhase.roundEnd) _playResultSound();
    _logAndNotify('applyRemoteState');
  }

  /// Chips sound if the local player won or pushed, a card "thud" if they lost.
  void _playResultSound() {
    final net = _roundNet[localPlayerId];
    if (net == null || net >= 0) {
      SoundService().chipsWin();
    } else {
      SoundService().cardFold();
    }
  }

  void _attachNetwork(P2PService p2p, GameProvider lobby) {
    _p2p = p2p;
    _lobby = lobby;
    _messageSub = p2p.onMessageReceived.listen(_onMessage);
    if (_isHost) {
      _seatSub = lobby.seatEvents.listen(_onSeatEvent);
      // Anyone who joined before this table opened.
      lobby.connectedSeats.forEach((id, name) => addRemotePlayer(id, name));
    } else {
      localPlayerId = lobby.localPlayerId;
      // The host's first snapshot may have arrived before this table existed.
      p2p.broadcastMessage({'type': 'BJ_HELLO'});
    }
  }

  void _onMessage(Map<String, dynamic> msg) {
    if (_disposed) return;
    final type = msg['type'];
    if (_isHost) {
      final sender = msg['_senderEndpointId'] as String? ?? '';
      if (type == 'BJ_HELLO') {
        _sendStateNow();
        return;
      }
      if (type == 'BJ_ACTION') {
        // The seat comes from the socket, never from the message.
        final seat = _lobby?.seatForEndpoint(sender);
        if (seat == null) return;
        handleRemoteAction(seat, msg['action'] as String? ?? '', (msg['value'] as num?)?.toInt() ?? 0);
      }
      return;
    }
    if (type == 'BJ_STATE') {
      final sess = msg['session'] as String?;
      final sq = (msg['seq'] as num?)?.toInt();
      if (sess != null && sq != null) {
        if (sess != _remoteSession) {
          _remoteSession = sess;
          _lastRemoteSeq = -1;
        }
        if (sq <= _lastRemoteSeq) return;
        _lastRemoteSeq = sq;
      }
      final st = msg['state'];
      if (st is Map) applyRemoteState(Map<String, dynamic>.from(st));
    } else if (type == 'ASSIGN_SEAT') {
      // Reconnected: same seat, ask for a fresh snapshot.
      localPlayerId = msg['playerId'] as String? ?? localPlayerId;
      _p2p?.broadcastMessage({'type': 'BJ_HELLO'});
    }
  }

  void _onSeatEvent(SeatEvent e) {
    if (_disposed) return;
    switch (e.kind) {
      case SeatEventKind.joined:
        addRemotePlayer(e.seatId, e.name);
      case SeatEventKind.back:
        _away.remove(e.seatId);
        _logAndNotify('seatBack');
      case SeatEventKind.away:
        _away.add(e.seatId);
        _logAndNotify('seatAway');
        if (_isTurnOf(e.seatId)) _armTurnTimer(e.seatId);
        _maybeDealWhenEveryoneBet();
      case SeatEventKind.left:
        final idx = players.indexWhere((p) => p.id == e.seatId);
        if (idx >= 0 && players[idx].totalBet == 0) {
          _state = _state.copyWith(players: [...players]..removeAt(idx));
          _logAndNotify('seatLeft');
        } else {
          _away.add(e.seatId);
          _logAndNotify('seatLeftMidRound');
        }
        _maybeDealWhenEveryoneBet();
    }
  }

  /// Host: applies an intent from a remote seat. The usual turn guards apply.
  void handleRemoteAction(String seatId, String action, int value) {
    switch (action) {
      case 'BET':
        if (_state.phase == BlackjackPhase.betting) placeBet(seatId, value);
      case 'HIT':
        hit(seatId);
      case 'STAND':
        stand(seatId);
      case 'DOUBLE':
        doubleDown(seatId);
      case 'SPLIT':
        splitPair(seatId);
    }
  }

  bool _sendIntent(String action, [int value = 0]) {
    if (!isClient) return false;
    _p2p?.broadcastMessage({'type': 'BJ_ACTION', 'action': action, 'value': value});
    return true;
  }

  /// Human seats that must bet before the deal (bots bet on their own, away seats are skipped).
  List<BlackjackPlayer> get _expectedBettors =>
      players.where((p) => !p.isDealer && !p.isBot && !_away.contains(p.id) && p.chipBalance + p.totalBet > 0).toList();

  void _maybeDealWhenEveryoneBet() {
    if (!_isHost || _state.phase != BlackjackPhase.betting) return;
    final bettors = players.where((p) => !p.isDealer && p.totalBet > 0).toList();
    if (bettors.isEmpty) return;
    if (_expectedBettors.every((p) => p.totalBet > 0)) {
      _bettingTimer?.cancel();
      _bettingTimer = null;
      _startDealingSequence();
    } else if (_isMultiplayer) {
      // Do not let one idle player hold the table forever.
      _bettingTimer ??= Timer(bettingTimeout, () {
        _bettingTimer = null;
        if (_state.phase == BlackjackPhase.betting && players.any((p) => !p.isDealer && p.totalBet > 0)) {
          _startDealingSequence();
        }
      });
    }
  }

  /// Multiplayer: a human seat that does not act (or is disconnected) stands.
  void _armTurnTimer(String seatId) {
    _turnTimer?.cancel();
    if (!_isMultiplayer || !_isHost) return;
    final delay = _away.contains(seatId) ? awayTurnDelay : remoteTurnTimeout;
    _turnTimer = Timer(delay, () {
      _turnTimer = null;
      if (_isTurnOf(seatId)) stand(seatId);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _messageSub?.cancel();
    _seatSub?.cancel();
    _broadcastTimer?.cancel();
    _turnTimer?.cancel();
    _bettingTimer?.cancel();
    _nextRoundTimer?.cancel();
    super.dispose();
  }

  /// How the Blackjack bots play (see [BlackjackBotBrain]).
  BotDifficulty botDifficulty = BotDifficulty.normal;

  void initSinglePlayer({int botCount = 0, String playerName = 'Yo', BotDifficulty difficulty = BotDifficulty.normal}) {
    botDifficulty = difficulty;
    try {
      AppLogger().event('blackjack_start', params: {'bot_count': botCount.toString()});
      _isMultiplayer = false;
      _isHost = true;
      localPlayerId = '0';
      final list = <BlackjackPlayer>[];
      list.add(BlackjackPlayer(id: 'dealer', name: 'Dealer', isDealer: true, chipBalance: 99999));
      final actualName = playerName.trim().isEmpty ? 'Yo' : playerName.trim();
      list.add(BlackjackPlayer(id: '0', name: actualName, chipBalance: 1000, isLocal: true));
      for (var i = 0; i < botCount; i++) {
        list.add(BlackjackPlayer(id: '${i + 1}', name: getBotName(i), chipBalance: 1000, isBot: true));
      }
      _state = BlackjackState(players: list, deck: _freshDeck(), phase: BlackjackPhase.betting);
      AppLogger().log('BJ:Creados 6 mazos (312 cartas) - inicial');
      _logAndNotify('initSinglePlayer');
    } catch (e, s) {
      AppLogger().error('BJ:initSinglePlayer crash: $e', s);
    }
  }

  /// LAN table. [p2p] and [lobby] are optional only so tests can drive a host alone.
  void initMultiplayer({required bool asHost, String hostName = 'Host', P2PService? p2p, GameProvider? lobby}) {
    try {
      _isMultiplayer = true;
      _isHost = asHost;
      localPlayerId = asHost ? '0' : (lobby?.localPlayerId ?? '1');
      if (asHost) {
        final list = <BlackjackPlayer>[];
        list.add(BlackjackPlayer(id: 'dealer', name: 'Dealer', isDealer: true, chipBalance: 99999));
        final actualHost = hostName.trim().isEmpty ? 'Host' : hostName.trim();
        list.add(BlackjackPlayer(id: '0', name: actualHost, chipBalance: 1000, isLocal: true));
        _state = BlackjackState(players: list, deck: _freshDeck(), phase: BlackjackPhase.waiting);
      } else {
        _state = BlackjackState(phase: BlackjackPhase.waiting); // filled by the host's snapshot
      }
      if (p2p != null && lobby != null) _attachNetwork(p2p, lobby);
      _logAndNotify('initMultiplayer');
    } catch (e, s) {
      AppLogger().error('BJ:initMultiplayer crash: $e', s);
    }
  }

  void addRemotePlayer(String playerId, String name) {
    if (!_isHost) return;
    if (players.any((p) => p.id == playerId)) {
      _away.remove(playerId);
      _logAndNotify('addRemotePlayer-again');
      return;
    }
    final list = <BlackjackPlayer>[..._state.players];
    list.add(BlackjackPlayer(id: playerId, name: name, chipBalance: 1000));
    _state = _state.copyWith(players: list);
    _logAndNotify('addRemotePlayer');
  }

  void startMatch() {
    if (!_isHost || !_isMultiplayer) return;
    _lobby?.markMatchStarted();
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

  void _autoBetBots() {
    try {
      var updated = <BlackjackPlayer>[...players];
      bool changed = false;
      for (var i = 0; i < updated.length; i++) {
        final p = updated[i];
        if (p.isBot && p.totalBet == 0) {
          int amount = 50 + _random.nextInt(151); // 50 to 200
          if (amount > p.chipBalance) amount = p.chipBalance;
          if (amount <= 0) continue;
          
          final hand = BlackjackHand(betAmount: amount);
          updated[i] = p.copyWith(
            chipBalance: p.chipBalance - amount,
            hands: [hand],
            totalBet: amount,
          );
          changed = true;
        }
      }
      if (changed) {
        _state = _state.copyWith(players: updated);
        _logAndNotify('_autoBetBots');
      }
    } catch (e, s) {
      AppLogger().error('BJ:_autoBetBots crash: $e', s);
    }
  }

  void placeBet(String playerId, int amount) {
    try {
      AppLogger().log('BJ:placeBet $playerId=$amount');
      if (_sendIntent('BET', amount)) return;
      if (_state.phase != BlackjackPhase.betting) return;
      final idx = players.indexWhere((p) => p.id == playerId);
      if (idx < 0) return;
      final p = players[idx];
      if (p.totalBet > 0 || amount <= 0 || amount > p.chipBalance) return;
      
      final updated = <BlackjackPlayer>[...players];
      final hand = BlackjackHand(betAmount: amount);
      updated[idx] = p.copyWith(
        chipBalance: p.chipBalance - amount,
        hands: [hand],
        totalBet: amount,
      );
      _state = _state.copyWith(players: updated);
      SoundService().chipsRaise();
      _logAndNotify('placeBet');

      _autoBetBots();
      _maybeDealWhenEveryoneBet();
    } catch (e, s) {
      AppLogger().error('BJ:placeBet crash: $e', s);
    }
  }

  void _startDealingSequence() {
    try {
      AppLogger().log('BJ:_startDealingSequence');
      final updated = <BlackjackPlayer>[...players];
      for (var i = 0; i < updated.length; i++) {
        updated[i] = updated[i].copyWith(
          hands: [BlackjackHand(betAmount: updated[i].totalBet)],
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
    // Players who did not bet (idle or disconnected) sit this round out.
    final slots = [
      for (var i = 0; i < playerList.length; i++)
        if (playerList[i].isDealer || playerList[i].totalBet > 0) i,
    ];
    final maxSteps = slots.length * 2;

    void dealNextCard() {
      if (_disposed) return;
      if (dealStep >= maxSteps) {
        Future.delayed(const Duration(milliseconds: 400), _afterDealComplete);
        return;
      }
      final slot = slots[dealStep % slots.length];
      final updated = <BlackjackPlayer>[..._state.players];
      final card = _draw();
      updated[slot].hands[0].cards.add(card);
      if (dealStep % slots.length == 0) SoundService().cardMix();
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
      final active = activePlayers;
      if (active.isEmpty) { _startDealerTurn(); return; }
      var pIdx = _state.currentPlayerIndex;
      for (var loop = 0; loop < active.length * 5; loop++) {
        final p = active[pIdx % active.length];
        for (var hIdx = 0; hIdx < p.hands.length; hIdx++) {
          if (!p.hands[hIdx].isFinished && p.hands[hIdx].cards.length >= 2) {
            final updatedPlayers = <BlackjackPlayer>[..._state.players];
            final playerMainIdx = updatedPlayers.indexWhere((pl) => pl.id == p.id);
            if (playerMainIdx >= 0) {
              updatedPlayers[playerMainIdx] = updatedPlayers[playerMainIdx].copyWith(activeHandIndex: hIdx);
            }
            _state = _state.copyWith(players: updatedPlayers, currentPlayerIndex: pIdx % active.length, currentHandIndex: hIdx);
            _logAndNotify('_advanceToNextActivePlayer-$pIdx-$hIdx');
            if (p.isBot || (!_isMultiplayer && !p.isLocal)) {
              Future.delayed(const Duration(milliseconds: 600), () => _autoPlayBot(p.id));
            } else {
              _armTurnTimer(p.id);
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

  bool _isTurnOf(String playerId) {
    if (_state.phase != BlackjackPhase.playerTurn) return false;
    final active = activePlayers;
    if (active.isEmpty) return false;
    return active[_state.currentPlayerIndex % active.length].id == playerId;
  }

  int _dealerUpcardValue() {
    final d = dealer;
    if (d == null || d.hands.isEmpty || d.hands[0].cards.isEmpty) return 10;
    final v = d.hands[0].cards[0].value;
    if (v == 'A') return 11;
    return int.tryParse(v) ?? 10;
  }

  /// Plays one action for a bot and, if its hand is still open, schedules the
  /// next one. Every bot turn must end in a finished hand or the round freezes.
  void _autoPlayBot(String playerId) {
    try {
      if (!_isTurnOf(playerId)) return;
      final pIdx = players.indexWhere((p) => p.id == playerId);
      if (pIdx < 0) return;
      final hIdx = _state.currentHandIndex;
      final p = players[pIdx];
      if (hIdx >= p.hands.length) return;
      final hand = p.hands[hIdx];
      final affordable = p.chipBalance >= hand.betAmount;
      final move = BlackjackBotBrain(difficulty: botDifficulty).decide(
        hand,
        _dealerUpcardValue(),
        canDouble: affordable && hand.cards.length == 2,
        canSplit: affordable && p.canSplit,
      );
      switch (move) {
        case BlackjackMove.stand:
          stand(playerId);
          return;
        case BlackjackMove.double:
          doubleDown(playerId); // one card, then the turn moves on
          return;
        case BlackjackMove.split:
          splitPair(playerId);
        case BlackjackMove.hit:
          hit(playerId);
      }
      // Still deciding the same (or the next split) hand: think again.
      final after = players.firstWhere((pl) => pl.id == playerId);
      final cur = _state.currentHandIndex;
      if (_isTurnOf(playerId) && cur < after.hands.length && !after.hands[cur].isFinished) {
        Future.delayed(const Duration(milliseconds: 700), () => _autoPlayBot(playerId));
      }
    } catch (e, s) {
      AppLogger().error('BJ:_autoPlayBot crash: $e', s);
      // Never leave the table stuck on a bot.
      if (_isTurnOf(playerId)) stand(playerId);
    }
  }

  void hit(String playerId) {
    try {
      if (_sendIntent('HIT')) return;
      AppLogger().log('BJ:hit $playerId phase=${_state.phase}');
      // Ignore taps outside this player's turn or on a finished hand (double taps
      // would otherwise schedule extra turn advances and replay bots).
      if (!_isTurnOf(playerId)) return;
      final pIdx = players.indexWhere((p) => p.id == playerId);
      if (pIdx < 0) return;
      final updated = <BlackjackPlayer>[...players];
      final hands = <BlackjackHand>[...updated[pIdx].hands];
      final hIdx = _state.currentHandIndex < hands.length ? _state.currentHandIndex : hands.length - 1;
      if (hIdx < 0 || hIdx >= hands.length || hands[hIdx].isFinished) return;
      final card = _draw();
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
    }
  }

  void stand(String playerId) {
    try {
      if (_sendIntent('STAND')) return;
      AppLogger().log('BJ:stand $playerId');
      if (!_isTurnOf(playerId)) return;
      final pIdx = players.indexWhere((p) => p.id == playerId);
      if (pIdx < 0) return;
      final hands = <BlackjackHand>[...players[pIdx].hands];
      final hIdx = _state.currentHandIndex < hands.length ? _state.currentHandIndex : hands.length - 1;
      if (hIdx >= hands.length || hIdx < 0 || hands[hIdx].isFinished) return;
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
      if (_sendIntent('DOUBLE')) return;
      AppLogger().log('BJ:doubleDown $playerId');
      if (!_isTurnOf(playerId)) return;
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
      if (_sendIntent('SPLIT')) return;
      AppLogger().log('BJ:splitPair $playerId');
      if (!_isTurnOf(playerId)) return;
      final pIdx = players.indexWhere((p) => p.id == playerId);
      if (pIdx < 0) return;
      final p = players[pIdx];
      if (!p.canSplit) return;
      final betPerHand = p.hands[0].betAmount;
      if (p.chipBalance < betPerHand) return;
      final cards = p.hands[0].cards;
      final hand1 = BlackjackHand(cards: [cards[0]], betAmount: betPerHand, isSplit: true);
      final hand2 = BlackjackHand(cards: [cards[1]], betAmount: betPerHand, isSplit: true);
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
      // A split 21 is not a natural: it just stands (and pays 1:1).
      if (hand2.handValue == 21) hand2.isStanding = true;
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
    _turnTimer?.cancel();
    _turnTimer = null;
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
      final allPlayersBusted = activePlayers.every((p) => p.hands.every((h) => h.isBusted || h.cards.isEmpty));
      AppLogger().log('BJ:allBusted=$allPlayersBusted');
      if (!allPlayersBusted) { _dealerDrawCardSequential(dIdx, dealerHand); return; }
      _resolveRound();
    } catch (e, s) {
      AppLogger().error('BJ:_dealerPlay crash: $e', s);
    }
  }

  void _dealerDrawCardSequential(int dIdx, BlackjackHand hand) {
    if (hand.handValue >= 17) {
      if (hand.handValue > 21) hand.isBusted = true; // shown as "BUST" on the dealer badge
      var updated = <BlackjackPlayer>[...players];
      updated[dIdx] = updated[dIdx].copyWith(hands: [hand]);
      _state = _state.copyWith(players: updated);
      _logAndNotify('_dealerDrawCard-done');
      AppLogger().log('BJ:dealerFinal=${hand.handValue} bj=${hand.isBlackjack}');
      Future.delayed(const Duration(milliseconds: 500), _resolveRound);
      return;
    }
    hand.cards.add(_draw());
    SoundService().cardMix();
    var updated = <BlackjackPlayer>[...players];
    updated[dIdx] = updated[dIdx].copyWith(hands: [hand]);
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
      final outcome = <String, String>{};
      final net = <String, int>{};
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
        final played = p.hands.where((h) => h.cards.isNotEmpty).toList();
        if (played.isNotEmpty) {
          net[p.id] = netChange;
          if (netChange > 0) {
            outcome[p.id] = p.isBlackjack ? 'BLACKJACK' : (p.hands.any((h) => h.isCharlie) ? 'CHARLIE' : 'GANA');
          } else if (netChange == 0) {
            outcome[p.id] = 'EMPATE';
          } else {
            outcome[p.id] = played.every((h) => h.isBusted) ? 'BUST' : 'PIERDE';
          }
        }
        finalPlayers[i] = p;
      }
      final msgs = results.values.join('\n');
      _roundOutcome = outcome;
      _roundNet = net;
      _state = _state.copyWith(players: finalPlayers, phase: BlackjackPhase.roundEnd, message: msgs);
      _playResultSound();
      _logAndNotify('_resolveRound');
      if (_isMultiplayer && _isHost) {
        _nextRoundTimer?.cancel();
        _nextRoundTimer = Timer(autoNextRound, () {
          _nextRoundTimer = null;
          if (_state.phase == BlackjackPhase.roundEnd) newRound();
        });
      }
      AppLogger().event('blackjack_round_end');
    } catch (e, s) {
      AppLogger().error('BJ:_resolveRound crash: $e', s);
    }
  }

  void newRound() {
    if (isClient) return; // the host deals the next round
    _nextRoundTimer?.cancel();
    _nextRoundTimer = null;
    try {
      _roundOutcome = const {};
      _roundNet = const {};
      var updated = <BlackjackPlayer>[..._state.players];
      for (var i = 0; i < updated.length; i++) {
        final balance = updated[i].chipBalance <= 0 && !updated[i].isDealer ? 1000 : updated[i].chipBalance;
        updated[i] = updated[i].copyWith(
          chipBalance: balance,
          hands: [BlackjackHand()],
          totalBet: 0,
        );
      }
      _state = BlackjackState(players: updated, deck: _state.deck, phase: BlackjackPhase.betting);
      _logAndNotify('newRound');
    } catch (e, s) {
      AppLogger().error('BJ:newRound crash: $e', s);
    }
  }
}
