import 'dart:async';

import '../services/logger_service.dart';

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/game_state.dart';

import '../models/player_model.dart';

import '../models/card_model.dart';

import '../models/hand_evaluator.dart';

import '../services/p2p_service.dart';
import '../services/sound_service.dart';
import '../services/bot_service.dart';


class GameProvider extends ChangeNotifier {
  bool _isExiting = false;

  final P2PService _p2pService;

  StreamSubscription? _messageSubscription;
  StreamSubscription<String>? _disconnectSubscription;

  // --- Network robustness state -------------------------------------------
  bool _isDisposed = false;
  int _epoch = 0; // bumped on every new game so stale async loops stop
  final Set<String> _leftSeats = {}; // host: seats whose owner left on purpose
  Timer? _broadcastTimer;
  Timer? _newRoundTimer;
  Timer? _watchdogTimer;
  Timer? _reconnectTimer;
  int _stallTicks = 0;
  int _stateSeq = 0;
  final String _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
  String? _stateSession;
  int _lastStateSeq = -1;

  /// Host side: which seat is bound to which socket, and which token owns which seat.
  final Map<String, String> _endpointPlayer = {};
  final Map<String, String> _tokenToPlayer = {};

  /// Client side: secret id that lets us reclaim our seat after a reconnect.
  String? _playerToken;
  String get playerToken => _playerToken ??= _randomToken();
  String _randomToken() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  bool _clientConnectionLost = false;
  bool get isConnectionLost => _clientConnectionLost;
  bool _reconnectGaveUp = false;
  bool get reconnectGaveUp => _reconnectGaveUp;
  int _reconnectAttempt = 0;
  bool _reconnectBusy = false;
  bool _hasSeat = false; // client: the host confirmed our seat at least once



  bool _isMultiplayer = false;

  GameMode _gameMode = GameMode.diceDash;



  GameState _state = GameState(status: GameStatus.diceTurn);

  final List<PlayerModel> _players = [];

  final List<CardModel> _deck = [];



  int _die1 = 1;

  int _die2 = 1;

  bool _isHost = true;

  bool _luckySevenApplied = false;



  String? _centralMessage;

  String? get centralMessage => _centralMessage;



  void setCentralMessage(String msg) {

    _centralMessage = msg;

    notifyListeners();

    Future.delayed(const Duration(seconds: 2), () {

      _centralMessage = null;

      notifyListeners();

    });

  }



  GameProvider({required P2PService p2pService}) : _p2pService = p2pService {
    _watchdogTimer = Timer.periodic(const Duration(seconds: 2), (_) => _watchdogTick());

    _listenToMessages();

    _listenToDisconnections();

    _initDebugMode();

  }



  void _listenToDisconnections() {
    _disconnectSubscription = _p2pService.onDisconnected.listen(_onPeerDisconnected);
  }

  void _onPeerDisconnected(String endpointId) {
    if (_isExiting || _isDisposed) return;
    AppLogger().log('Peer desconectado: $endpointId');
    if (_isHost) {
      final seatId = _endpointPlayer.remove(endpointId);
      if (seatId == null) return;
      if (!_matchStarted) {
        // Still in the waiting room: just free the seat.
        _players.removeWhere((x) => x.id == seatId);
        updateAdvertisedName();
        notifyListeners();
        return;
      }
      final p = _players.where((x) => x.id == seatId).firstOrNull;
      if (p != null) {
        p.isAway = true;
        notifyListeners();
      }
    } else if (_isMultiplayer && _hasSeat) {
      _startReconnect();
    }
  }

  /// A client left on purpose (back button): never wait for it again.
  void _handleLeave(String endpointId) {
    final seatId = _endpointPlayer[endpointId];
    if (seatId == null) return;
    _leftSeats.add(seatId);
    // Same bookkeeping as a dropped connection (frees the seat before the match,
    // marks it away afterwards so the watchdog plays its turns).
    _onPeerDisconnected(endpointId);
  }

  // --- Client auto-reconnect (exponential backoff) ---------------------------
  void _startReconnect() {
    if (_reconnectTimer != null || _reconnectBusy || _isExiting || _isDisposed) return;
    _clientConnectionLost = true;
    _reconnectGaveUp = false;
    _reconnectAttempt = 0;
    notifyListeners();
    _scheduleReconnectAttempt();
  }

  void _scheduleReconnectAttempt() {
    if (_isExiting || _isDisposed) return;
    if (_reconnectAttempt >= 10) {
      _reconnectGaveUp = true;
      _reconnectTimer = null;
      notifyListeners();
      return;
    }
    final delay = Duration(seconds: min(1 << _reconnectAttempt, 8));
    _reconnectTimer = Timer(delay, () async {
      _reconnectTimer = null;
      if (_isExiting || _isDisposed) return;
      _reconnectBusy = true;
      final ok = await _p2pService.reconnectToLastHost();
      _reconnectBusy = false;
      if (_isExiting || _isDisposed) return;
      if (ok) {
        final ep = '${_p2pService.lastHost}:${_p2pService.lastPort}';
        _p2pService.sendMessage(ep, {
          'type': 'JOIN_REQUEST',
          'playerName': _hostName,
          'password': '',
          'token': playerToken,
          'endpointId': ep,
        });
        // If the host never answers with ASSIGN_SEAT, try again.
        _reconnectTimer = Timer(const Duration(seconds: 6), () {
          _reconnectTimer = null;
          if (_clientConnectionLost) {
            _reconnectAttempt++;
            _scheduleReconnectAttempt();
          }
        });
      } else {
        _reconnectAttempt++;
        _scheduleReconnectAttempt();
      }
    });
  }

  void _onSeatConfirmed() {
    _hasSeat = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    _reconnectGaveUp = false;
    _clientConnectionLost = false;
  }

  // --- Host watchdog: keeps rounds moving no matter what ----------------------
  void _watchdogTick() {
    if (_isDisposed || _isExiting || !_isHost || !_isMultiplayer || !_matchStarted) return;
    // 1) Showdown finished but no new round is scheduled.
    if (_state.phase == PokerPhase.showdown &&
        _state.status == GameStatus.finished &&
        _newRoundTimer == null) {
      _stallTicks++;
      if (_stallTicks >= 6) {
        _stallTicks = 0;
        AppLogger().log('Watchdog: ronda detenida, iniciando nueva ronda');
        scheduleNewRound();
      }
      return;
    }
    _stallTicks = 0;
    // 2) It is the turn of a disconnected player: play for them.
    final ci = _state.currentPlayerIndex;
    if (ci < 0 || ci >= _players.length) return;
    final p = _players[ci];
    if (!p.isAway || p.isFolded) return;
    if (_state.status == GameStatus.diceTurn && _gameMode == GameMode.diceDash) {
      rollDice();
    } else if (_state.status == GameStatus.betting) {
      final toCall = _currentBet - (_betsThisPhase[p.id] ?? 0);
      if (toCall > 0) {
        fold(p.id);
      } else {
        call(p.id);
      }
    }
  }



  void setMultiplayer(bool value) {

    AppLogger().log('ðŸ”§ setMultiplayer: $value (isHost=$_isHost)');

    _isMultiplayer = value;

    _initDebugMode();

  }



  void _initDebugMode() {
    _isExiting = false;
    _epoch++;
    _matchStarted = false;
    _newRoundTimer?.cancel();
    _newRoundTimer = null;
    _leftSeats.clear();
    _hasSeat = false;
    _clientConnectionLost = false;
    _reconnectGaveUp = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _endpointPlayer.clear();
    _tokenToPlayer.clear();

    _players.clear();

    _state = GameState(status: GameStatus.waitingPlayers, phase: PokerPhase.preFlop);



    if (_isMultiplayer) {

      if (_isHost) {

        _players.add(PlayerModel(

          id: '0',

          name: _hostName,

          chipBalance: 1000,

          isLocal: true,

        ));

        localPlayerId = '0';

        _nextSeatId = 1;

      } else {

        _nextSeatId = 1;

      }

      notifyListeners();

      return;

    }



    final localName = _hostName.isNotEmpty ? _hostName : 'Yo';

    // Texas Holdem: bots, direct into betting (no dice)
    if (_gameMode == GameMode.texasHoldem) {
      _players.add(PlayerModel(id: '0', name: localName, chipBalance: 1000, isLocal: true));
      for (var i = 1; i <= _botCount; i++) {
        _players.add(PlayerModel(id: '$i', name: getBotName(i - 1), chipBalance: 1000, isBot: true));
      }
      shuffleAndDeal();
      _state = _state.copyWith(status: GameStatus.betting, phase: PokerPhase.preFlop);
      notifyListeners();
      SoundService().cardMix();
      _checkBotTurn();
      return;
    }

    // Dice Dash: bots, diceTurn
    _players.add(PlayerModel(id: '0', name: localName, chipBalance: 1000, isLocal: true));
    for (var i = 1; i <= _botCount; i++) {
      _players.add(PlayerModel(id: '$i', name: getBotName(i - 1), chipBalance: 1000, isBot: true));
    }
    shuffleAndDeal();
    _state = _state.copyWith(status: GameStatus.diceTurn, phase: PokerPhase.preFlop);
    notifyListeners();
    SoundService().cardMix();
  }



  List<CardModel> _generateDeck() {

    const values = [

      '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'

    ];



    final deck = <CardModel>[];

    for (final suit in Suit.values) {

      for (final value in values) {

        deck.add(CardModel(value: value, suit: suit));

      }

    }

    return deck;

  }



  GameState get state => _state;

  List<PlayerModel> get players => _players;

  List<CardModel> get deck => _deck;

  int get die1 => _die1;

  int get die2 => _die2;

  int get diceTotal => _die1 + _die2;

  bool get isHost => _isHost;

  GameMode get gameMode => _gameMode;

  int get pot => _totalContributions.values.fold(0, (a, b) => a + b);

  List<CardModel> get communityCards => _state.communityCards;

  int get revealedCommunityCount => _state.revealedCommunityCount;

  PokerPhase get phase => _state.phase;

  int get dealerIndex => _state.dealerIndex;

  int get smallBlindIndex {
    if (_players.isEmpty) return 0;
    final active = _players.where((p) => !p.isBankrupt).length;
    if (active == 2) return _state.dealerIndex;
    return (_state.dealerIndex + 1) % _players.length;
  }

  int get bigBlindIndex {
    if (_players.isEmpty) return 0;
    final active = _players.where((p) => !p.isBankrupt).length;
    if (active == 2) {
      var next = (_state.dealerIndex + 1) % _players.length;
      while (next != _state.dealerIndex && (_players[next].isBankrupt)) {
        next = (next + 1) % _players.length;
      }
      return next;
    }
    return (_state.dealerIndex + 2) % _players.length;
  }

  P2PService get p2pService => _p2pService;



  CardModel? _lastBurnedCard;

  CardModel? get lastBurnedCard => _lastBurnedCard;



  bool _isBetting = false;

  bool get isBetting => _isBetting;



  bool _isPotFlying = false;

  bool get isPotFlying => _isPotFlying;

  String? _winnerId;
  String? get winnerId => _winnerId;

  // Result of the last finished hand, shown by the results banner and the
  // winner ribbon on the seats. Cleared when the next hand is dealt.
  List<String> _resultWinnerIds = const [];
  List<String> get resultWinnerIds => _resultWinnerIds;
  String? _resultTitle;
  String? get resultTitle => _resultTitle;
  int _resultAmount = 0;
  int get resultAmount => _resultAmount;

  void _setResult(List<String> winnerIds, String title, int amount) {
    _resultWinnerIds = List.unmodifiable(winnerIds);
    _resultTitle = title;
    _resultAmount = amount;
  }

  void _clearResult() {
    _resultWinnerIds = const [];
    _resultTitle = null;
    _resultAmount = 0;
  }
  int _flyingPotAmount = 0;

  int get flyingPotAmount => _flyingPotAmount;

  int _currentBet = 0;

  final Map<String, int> _betsThisPhase = {};

  final Set<String> _playersActedThisPhase = {};

  bool _isChaosSwapping = false;

  bool get isChaosSwapping => _isChaosSwapping;

  String? _animatingBetPlayerId;

  String? get animatingBetPlayerId => _animatingBetPlayerId;

  int _rollCounter = 0;

  int get rollCounter => _rollCounter;

  int _communityCardRenderCounter = 0;

  int get communityCardRenderCounter => _communityCardRenderCounter;

  List<CardModel>? _winningCards;

  List<CardModel>? get winningCards => _winningCards;

  int _roundCounter = 0;

  int get roundCounter => _roundCounter;

  final Map<String, int> _totalContributions = {};



  String localPlayerId = '0';

  int _nextSeatId = 1;



  String _roomName = '';

  String _hostName = 'Host';

  String _roomPassword = '';

  bool _matchStarted = false;
  int _botCount = 3;
  int get botCount => _botCount;
  void setBotCount(int count) {
    _botCount = count.clamp(1, 7);
  }

  void setPlayerName(String name) {

    _hostName = name;

    final local = _players.where((p) => p.isLocal).firstOrNull;

    if (local != null) {

      local.name = name;

      notifyListeners();

    }

  }



  void setRoomMetadata(String name, String password) {

    _roomName = name;

    _roomPassword = password;

  }



  void updateAdvertisedName() {

    if (!_isHost || _roomName.isEmpty) return;

    final hasPassword = _roomPassword.isNotEmpty;

    final count = _players.length;

    final started = _matchStarted;

    final metadata = '$_roomName|$count/4|${hasPassword ? '1' : '0'}|${started ? '1' : '0'}|${_gameMode.name}';

    _p2pService.updateServiceName(metadata); // keeps the TCP port stable

  }



  void assignSeatToClient(String endpointId, {String playerName = '', String token = ''}) {
    AppLogger().log('assignSeatToClient: endpointId=$endpointId');
    if (!_isHost) return;

    // Reconnection: a known token reclaims its previous seat.
    if (token.isNotEmpty && _tokenToPlayer.containsKey(token)) {
      final seatId = _tokenToPlayer[token]!;
      final existing = _players.where((p) => p.id == seatId).firstOrNull;
      if (existing != null) {
        final oldEndpoints = _endpointPlayer.entries
            .where((e) => e.value == seatId && e.key != endpointId)
            .map((e) => e.key)
            .toList();
        for (final old in oldEndpoints) {
          _endpointPlayer.remove(old);
          _p2pService.disconnectEndpoint(old);
        }
        existing.isAway = false;
        _endpointPlayer[endpointId] = seatId;
        AppLogger().log('Jugador ${existing.name} recupera su asiento $seatId');
        _p2pService.sendMessage(endpointId, {
          'type': 'ASSIGN_SEAT',
          'endpointId': endpointId,
          'playerId': seatId,
        });
        notifyListeners();
        _sendStateNow();
        return;
      }
    }

    final playerId = _nextSeatId.toString();
    _nextSeatId++;

    _players.add(PlayerModel(
      id: playerId,
      name: playerName.isEmpty ? 'Jugador $playerId' : playerName,
      chipBalance: 1000,
      isLocal: false,
    ));
    _endpointPlayer[endpointId] = playerId;
    if (token.isNotEmpty) _tokenToPlayer[token] = playerId;

    updateAdvertisedName();
    AppLogger().event('player_joined', params: {'player_name': playerName.isEmpty ? 'Jugador' : playerName, 'game_mode': _gameMode.name});

    _p2pService.sendMessage(endpointId, {
      'type': 'ASSIGN_SEAT',
      'endpointId': endpointId,
      'playerId': playerId,
    });

    notifyListeners();
    _sendStateNow();
  }



  void _sendPlayerAction(String action, {int value = 0}) {

    _p2pService.broadcastMessage({

      'type': 'PLAYER_ACTION',

      'action': action,

      'playerId': localPlayerId,

      'value': value,

    });

  }



  void _addContribution(String playerId, int amount) {

    _totalContributions[playerId] = (_totalContributions[playerId] ?? 0) + amount;

  }



  void _clearBets() {

    _betsThisPhase.clear();

    _currentBet = 0;

    _playersActedThisPhase.clear();

  }



  PlayerModel? get currentPlayer =>

      _players.isNotEmpty ? _players[_state.currentPlayerIndex] : null;



  void setHost(bool value) {

    _isHost = value;

    notifyListeners();

  }



  void setGameMode(GameMode mode) {

    _gameMode = mode;

    notifyListeners();

  }



  void _listenToMessages() {

    _messageSubscription = _p2pService.onMessageReceived.listen((message) {

      final type = message['type'] as String?;



      if (type == 'STATE_UPDATE' && !_isHost) {
        final sess = message['session'] as String?;
        final sq = message['seq'] as int?;
        if (sess != null && sq != null) {
          if (sess != _stateSession) {
            _stateSession = sess;
            _lastStateSeq = -1;
          }
          if (sq <= _lastStateSeq) return;
          _lastStateSeq = sq;
        }

        _syncStateFromMap(message['state'] as Map<String, dynamic>);

        notifyListeners();

        return;

      }



      if (type == 'JOIN_REJECTED' && !_isHost) {

        final reason = message['reason'] as String? ?? '';

        AppLogger().log('ðŸš« JOIN_REJECTED recibido en GameProvider: $reason');

        return;

      }



      if (type == 'JOIN_REQUEST' && _isHost) {

        final pass = message['password'] as String? ?? '';

        final senderEpId = message['_senderEndpointId'] as String? ?? '';

        AppLogger().log('ðŸ”” JOIN_REQUEST recibido: senderEndpointId=$senderEpId');

        if (_roomPassword.isNotEmpty && pass != _roomPassword && !_tokenToPlayer.containsKey(message['token'] as String? ?? '')) {

          AppLogger().log('ðŸ”’ JOIN_REQUEST rechazado: password incorrecta');

          _p2pService.sendMessage(senderEpId, {'type': 'JOIN_REJECTED', 'reason': 'password'});

          AppLogger().event('join_rejected_password');

          return;

        }

        AppLogger().log('ðŸ”“ JOIN_REQUEST aceptado: $senderEpId');

        assignSeatToClient(senderEpId, playerName: message['playerName'] as String? ?? 'Jugador', token: message['token'] as String? ?? '');

        return;

      }



      if (type == 'LEAVE' && _isHost) {
        _handleLeave(message['_senderEndpointId'] as String? ?? '');
        return;
      }

      if (type == 'PLAYER_ACTION' && _isHost) {
        // The seat is taken from the socket, never from what the client claims.
        final senderEpId = message['_senderEndpointId'] as String? ?? '';
        final seatId = _endpointPlayer[senderEpId];
        if (seatId == null) {
          AppLogger().log('PLAYER_ACTION ignorada: emisor sin asiento ($senderEpId)');
          return;
        }
        _processRemoteAction(
          message['action'] as String? ?? '',
          seatId,
          (message['value'] as num?)?.toInt() ?? 0,
        );
        return;
      }



      if (type == 'ASSIGN_SEAT' && !_isHost && _isMultiplayer) {

        AppLogger().log('ðŸŽ« Cliente recibiÃ³ ASSIGN_SEAT: playerId=${message['playerId']}');

        localPlayerId = message['playerId'] as String? ?? localPlayerId;
        _onSeatConfirmed();

        for (final p in _players) {

          p.isLocal = p.id == localPlayerId;

        }

        notifyListeners();

        return;

      }



      if (type == 'DICE_ROLL') {

        final values = message['values'] as List<dynamic>?;

        final pot = message['pot'] as int?;

        if (values != null && values.length == 2) {

          _die1 = values[0] as int;

          _die2 = values[1] as int;



          bool swapFlag = _state.mustSwapHands;



          if (_die1 == 1 && _die2 == 1) {

            swapFlag = true;

          }



          _state = _state.copyWith(

            mustSwapHands: swapFlag,

            pot: pot ?? _state.pot,

            status: GameStatus.betting,

          );

          notifyListeners();

        }

      }



      if (type == 'NEXT_TURN') {

        final index = message['index'] as int?;

        final phase = message['phase'] as String?;

        final revealed = message['revealed'] as int?;

        if (index != null) {

          _state = _state.copyWith(

            currentPlayerIndex: index,

            status: GameStatus.diceTurn,

            phase: phase != null ? PokerPhase.values.byName(phase) : null,

            revealedCommunityCount: revealed ?? _state.revealedCommunityCount,

          );

          _luckySevenApplied = false;

          notifyListeners();

        }

      }



      if (type == 'NEW_ROUND') {

        final dealerIdx = message['dealerIndex'] as int?;

        final pot = message['pot'] as int?;

        if (dealerIdx != null) {

          _state = _state.copyWith(

            dealerIndex: dealerIdx,

            pot: pot ?? _state.pot,

          );

          notifyListeners();

        }

      }

    });

  }



  void addPlayer(PlayerModel player) {

    _players.add(player);

    notifyListeners();

  }



  void removePlayer(String id) {

    _players.removeWhere((p) => p.id == id);

    notifyListeners();

  }



  void updateStatus(GameStatus status) {

    _state = _state.copyWith(status: status);

    notifyListeners();

  }



  void nextTurn() {

    if (_players.isEmpty) return;

    _isBetting = false;

    AppLogger().log('ðŸ”„ nextTurn: currentPlayerIndex=${_state.currentPlayerIndex} status=${_state.status} phase=${_state.phase}');



    final activePlayers = _players.where((p) => !p.isFolded && p.chipBalance > 0).toList();

    final unFoldedPlayers = _players.where((p) => !p.isFolded).toList();

    final allInPlayers = _players.where((p) => !p.isFolded && p.chipBalance == 0).toList();

    for (final p in allInPlayers) { if (!_playersActedThisPhase.contains(p.id)) _playersActedThisPhase.add(p.id); }

    AppLogger().log('ðŸ”„ nextTurn stats: active=${activePlayers.length} unF=${unFoldedPlayers.length} allIn=${allInPlayers.length} acted=${_playersActedThisPhase.length}');

    if (unFoldedPlayers.length == 1) {

      final winner = unFoldedPlayers.first;

      final totalContribs = _totalContributions.values.fold(0, (a, b) => a + b);

      winner.chipBalance += totalContribs;

      _totalContributions.clear();

      _setResult([winner.id], 'por abandono', totalContribs);
      setCentralMessage('¡${winner.name} gana por abandono!');

      scheduleNewRound();

      return;

    }

    if (activePlayers.isEmpty && allInPlayers.isEmpty) {

      advancePhase();

      return;

    }

    if (activePlayers.length <= 1 && allInPlayers.isEmpty) {

      advancePhase();

      return;

    }



    final allActed = unFoldedPlayers.every(

      (p) => _playersActedThisPhase.contains(p.id),

    );



    if (allActed) {

      advancePhase();

      return;

    }



    var nextIndex = (_state.currentPlayerIndex + 1) % _players.length;

    var loopCount = 0;

    while (loopCount < _players.length * 2 &&

        (_players[nextIndex].isFolded ||

         _players[nextIndex].isBankrupt ||

         _playersActedThisPhase.contains(_players[nextIndex].id))) {

      nextIndex = (nextIndex + 1) % _players.length;

      loopCount++;

    }



    if (loopCount >= _players.length * 2) {

      advancePhase();

      return;

    }



    final nextStatus = _gameMode == GameMode.texasHoldem ? GameStatus.betting : GameStatus.diceTurn;

    _state = _state.copyWith(

      currentPlayerIndex: nextIndex,

      status: nextStatus,

    );

    AppLogger().log('ðŸ”„ nextTurn result: nextIndex=$nextIndex playersActed=${_playersActedThisPhase.toList()}');

    _luckySevenApplied = false;



    if (_isHost) {

      _p2pService.broadcastMessage({

        'type': 'NEXT_TURN',

        'index': nextIndex,

      });

    }



    notifyListeners();
    broadcastState();
    _checkBotTurn();
  }



  Future<void> advancePhase() async {
    final epoch = _epoch;
    if (_isExiting || epoch != _epoch) return;
    _clearBets();
    _playersActedThisPhase.clear();
    final currentPhase = _state.phase;

    switch (currentPhase) {
      case PokerPhase.preFlop:
        _burnCard();
        _communityCardRenderCounter++;
        _state = _state.copyWith(
          phase: PokerPhase.flop,
          currentPlayerIndex: -1,
          status: _gameMode == GameMode.texasHoldem ? GameStatus.betting : GameStatus.diceTurn,
          turnsCompleted: 0,
        );
        notifyListeners();
        for (int i = 0; i < 3; i++) {
          try { SoundService().cardPlace(); } catch (_) {}
          _state = _state.copyWith(revealedCommunityCount: _state.revealedCommunityCount + 1);
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 200));
          if (_isExiting || epoch != _epoch) return;
        }
        break;
      case PokerPhase.flop:
        _burnCard();
        _state = _state.copyWith(
          phase: PokerPhase.turn,
          currentPlayerIndex: -1,
          status: _gameMode == GameMode.texasHoldem ? GameStatus.betting : GameStatus.diceTurn,
          turnsCompleted: 0,
        );
        notifyListeners();
        try { SoundService().cardPlace(); } catch (_) {}
        _state = _state.copyWith(revealedCommunityCount: 4);
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 200));
          if (_isExiting || epoch != _epoch) return;
        break;
      case PokerPhase.turn:
        _burnCard();
        _state = _state.copyWith(
          phase: PokerPhase.river,
          currentPlayerIndex: -1,
          status: _gameMode == GameMode.texasHoldem ? GameStatus.betting : GameStatus.diceTurn,
          turnsCompleted: 0,
        );
        notifyListeners();
        try { SoundService().cardPlace(); } catch (_) {}
        _state = _state.copyWith(revealedCommunityCount: 5);
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 200));
          if (_isExiting || epoch != _epoch) return;
        break;
      case PokerPhase.river:
        _state = _state.copyWith(
          phase: PokerPhase.showdown,
          status: GameStatus.finished,
        );
        determineWinner();
        return;


      case PokerPhase.showdown:

        return;

    }



    _luckySevenApplied = false;



    // Post-flop: turn starts from Small Blind

    int startIndex = smallBlindIndex;

    var findLoop = 0;

    while (findLoop < _players.length * 2 &&

        (_players[startIndex].isFolded || _players[startIndex].chipBalance <= 0)) {

      startIndex = (startIndex + 1) % _players.length;

      findLoop++;

    }

    _state = _state.copyWith(

      currentPlayerIndex: startIndex,

    );



    if (_isHost) {

      _p2pService.broadcastMessage({

        'type': 'NEXT_TURN',

        'index': startIndex,

        'phase': _state.phase.name,

        'revealed': _state.revealedCommunityCount,

      });

    }



    notifyListeners();
    broadcastState();
    _checkBotTurn();
  }



  void _burnCard() {

    if (_deck.isNotEmpty) {

      _lastBurnedCard = _deck.removeLast();

    }

  }



  Future<void> determineWinner() async {
    final epoch = _epoch;

    _state = _state.copyWith(currentPlayerIndex: -1);

    notifyListeners();



    final activePlayers = _players.where((p) => !p.isFolded).toList();

    if (activePlayers.isEmpty) {

      scheduleNewRound();

      return;

    }



    final winners = <PlayerModel>[];

    HandResult? bestHandResult;



    for (final player in activePlayers) {

      if (player.hand.length < 2) continue;

      final result = HandEvaluator.evaluate(player.hand, _state.communityCards);

      if (bestHandResult == null || result.power > bestHandResult.power) {

        bestHandResult = result;

        winners.clear();

        winners.add(player);

      } else if (result.power == bestHandResult.power) {

        winners.add(player);

      }

    }



    if (winners.isNotEmpty && bestHandResult != null) {

      _winningCards = [];

      for (final w in winners) {

        final r = HandEvaluator.evaluate(w.hand, _state.communityCards);

        _winningCards!.addAll(r.bestHand);

      }

      notifyListeners();



      await Future.delayed(const Duration(milliseconds: 2000));
      if (_isExiting || epoch != _epoch) return;



      final totalPot = _totalContributions.values.fold(0, (a, b) => a + b);

      final splitAmount = totalPot ~/ winners.length;

      for (final w in winners) {

        w.chipBalance += splitAmount;

      }

      _totalContributions.clear();

      _flyingPotAmount = splitAmount;

      SoundService().chipsWin();



      _setResult([for (final w in winners) w.id], bestHandResult.rankName, splitAmount);

      if (winners.length > 1) {

        setCentralMessage('¡Empate! Bote dividido con ${bestHandResult.rankName}');
      } else {

        _winnerId = winners.first.id;

        _isPotFlying = true;

        setCentralMessage('¡${winners.first.name} gana con ${bestHandResult.rankName}!');

      }

      notifyListeners();

    } else {

      setCentralMessage('¡Showdown! No hay ganador');

      notifyListeners();

    }



    scheduleNewRound();

  }



  void scheduleNewRound() {
    _newRoundTimer?.cancel();
    _newRoundTimer = Timer(const Duration(seconds: 5), () {
      _newRoundTimer = null;
      if (_isExiting || _isDisposed) return;
      _centralMessage = null;
      shuffleAndDeal();
    });
  }



  void completePotTransfer() {

    _isPotFlying = false;

    _winnerId = null;

    _flyingPotAmount = 0;

    notifyListeners();

  }



  void addToPot(int amount) {

    notifyListeners();

  }



  void dealCardToPlayer(String playerId, CardModel card) {

    final player = _players.firstWhere((p) => p.id == playerId);

    player.hand = [...player.hand, card];

    notifyListeners();

  }



  void updateChipBalance(String playerId, int amount) {

    final player = _players.firstWhere((p) => p.id == playerId);

    player.chipBalance += amount;

    notifyListeners();

  }



  void startMatch() {

    if (!_isHost || _players.length < 2) return;

    _matchStarted = true;

    shuffleAndDeal();

    final startStatus = _gameMode == GameMode.texasHoldem ? GameStatus.betting : GameStatus.diceTurn;

    _state = _state.copyWith(status: startStatus, phase: PokerPhase.preFlop);

    updateAdvertisedName();

    notifyListeners();

    AppLogger().event('game_started', params: {'game_mode': _gameMode.name});

    broadcastState();

  }



  void resetGame() {

    _state = GameState(phase: PokerPhase.preFlop);

    _players.clear();

    _deck.clear();

    _die1 = 1;

    _die2 = 1;

    _rollCounter = 0;

    _roundCounter = 0;

    _communityCardRenderCounter = 0;

    _luckySevenApplied = false;

    _currentBet = 0;

    _totalContributions.clear();

    _betsThisPhase.clear();

    _playersActedThisPhase.clear();

    _winningCards = null;
    _winnerId = null;
    _clearResult();
    _isPotFlying = false;
    _animatingBetPlayerId = null;

    _lastBurnedCard = null;

    _isChaosSwapping = false;

    _centralMessage = null;

    _matchStarted = false;

    _initDebugMode();

  }



  void rollDice() {

    if (_gameMode == GameMode.texasHoldem) return;

    if (!_isHost) {

      _sendPlayerAction('ROLL_DICE');

      return;

    }

    final random = Random();

    _die1 = random.nextInt(6) + 1;

    _die2 = random.nextInt(6) + 1;

    SoundService().diceRoll();



    bool swapFlag = _state.mustSwapHands;



    if (_die1 == 1 && _die2 == 1) {

      swapFlag = true;

    }



    if (_die1 == 6 && _die2 == 6) {

      // TODO: Implementar ALL-IN forzado

    }



    if (diceTotal == 7 && !_luckySevenApplied) {

      _luckySevenApplied = true;

      final extra = (pot * 0.30).toInt();

      final activeIdx = _state.currentPlayerIndex;

      if (activeIdx < _players.length) {

        _addContribution(_players[activeIdx].id, extra);

      }

      SoundService().chipsMultiply();

      AppLogger().event('lucky_seven', params: {'pot_bonus': extra.toString()});

      setCentralMessage('Dados de la suerte. El Pot aumenta un 30%');

    }



    // TODO: Blackjack 21 â€” Si dados == 2 y 1, activar evento especial:

    // Repartir 2 cartas extra al jugador del turno y habilitar

    // una apuesta flash (solo vÃ¡lida durante ese turno).



    _state = _state.copyWith(

      mustSwapHands: swapFlag,

      status: GameStatus.betting,

    );



    if (_isHost) {

      _p2pService.broadcastMessage({

        'type': 'DICE_ROLL',

        'values': [_die1, _die2],

      });

    }



    _rollCounter++;
    notifyListeners();
    _checkBotTurn();
  }



  void shuffleAndDeal() {

    _roundCounter++;

    _communityCardRenderCounter++;

    _totalContributions.clear();

    _betsThisPhase.clear();

    _currentBet = 0;

    _playersActedThisPhase.clear();

    _winningCards = null;
    _clearResult();



    for (final p in _players) {
      if (_leftSeats.contains(p.id)) p.chipBalance = 0;
    }
    // Mark bankrupt players
    for (final player in _players) {
      if (player.chipBalance <= 0) {
        if (player.isBot) {
          player.chipBalance = 1000; // Auto-rebuy for bots
          player.isBankrupt = false;
          player.isFolded = false;
        } else {
          player.isBankrupt = true;
          player.isFolded = true;
        }
      }
    }



    final activePlayers = _players.where((p) => !p.isBankrupt && p.chipBalance > 0).toList();

    if (activePlayers.length < 2) {
      AppLogger().log('NOT_ENOUGH_PLAYERS: resetting all chips to 1000');
      for (final p in _players) {
        p.isBankrupt = false;
        p.isFolded = false;
        p.chipBalance = 1000;
        p.hand = [];
      }
      notifyListeners();
      broadcastState();
      scheduleNewRound();
      return;
    }



    int nextActive(int startIndex) {

      var idx = startIndex;

      var loop = 0;

      while (loop < _players.length && (_players[idx].isBankrupt || _players[idx].chipBalance <= 0)) {

        idx = (idx + 1) % _players.length;

        loop++;

      }

      return idx;

    }



    final dealerIdx = nextActive((_state.dealerIndex + 1) % _players.length);

    int sbIdx;

    int bbIdx;



    if (activePlayers.length == 2) {

      sbIdx = dealerIdx;

      bbIdx = nextActive((dealerIdx + 1) % _players.length);

    } else {

      sbIdx = nextActive((dealerIdx + 1) % _players.length);

      bbIdx = nextActive((sbIdx + 1) % _players.length);

    }



    _state = _state.copyWith(dealerIndex: dealerIdx);



    final actualSB = min(10, _players[sbIdx].chipBalance);

    final actualBB = min(20, _players[bbIdx].chipBalance);

    _players[sbIdx].chipBalance -= actualSB;

    _players[bbIdx].chipBalance -= actualBB;



    _playersActedThisPhase.clear();

    _currentBet = 20;



    _betsThisPhase[_players[sbIdx].id] = actualSB;

    _betsThisPhase[_players[bbIdx].id] = actualBB;

    _addContribution(_players[sbIdx].id, actualSB);

    _addContribution(_players[bbIdx].id, actualBB);



    AppLogger().log('ðŸŽ¯ BLINDS: SB=${_players[sbIdx].name}(${_players[sbIdx].id})=$actualSB BB=${_players[bbIdx].name}(${_players[bbIdx].id})=$actualBB dealerIndex=$dealerIdx');



    _deck

      ..clear()

      ..addAll(_generateDeck())

      ..shuffle(Random());



    for (final player in _players) {

      player.hand = [];

      player.isFolded = player.isBankrupt;

    }



    for (var i = 0; i < 2; i++) {

      for (final player in _players) {

        if (_deck.isNotEmpty && !player.isBankrupt) {

          player.hand = [...player.hand, _deck.removeLast()];

        }

      }

    }



    final community = <CardModel>[];

    for (var i = 0; i < 5; i++) {

      if (_deck.isNotEmpty) {

        community.add(_deck.removeLast());

      }

    }



    _lastBurnedCard = null;

    final utgIdx = activePlayers.length == 2
        ? dealerIdx
        : nextActive((bbIdx + 1) % _players.length);

    final nextStatus = _gameMode == GameMode.texasHoldem ? GameStatus.betting : GameStatus.diceTurn;
    _state = _state.copyWith(
      status: nextStatus,
      currentPlayerIndex: utgIdx,
      communityCards: community,

      phase: PokerPhase.preFlop,

      revealedCommunityCount: 0,

      turnsCompleted: 0,

    );



    if (_isHost) {

      _p2pService.broadcastMessage({

        'type': 'NEW_ROUND',

        'dealerIndex': dealerIdx,

        'pot': actualSB + actualBB,

      });

    }



    notifyListeners();
    _checkBotTurn();
  }



  void swapHands() {

    if (_players.length < 2) return;

    triggerChaosSwap();

  }



  Future<void> triggerChaosSwap() async {

    final activePlayers = _players.where((p) => !p.isFolded && !p.isBankrupt).toList();

    if (activePlayers.length < 2) {

      _state = _state.copyWith(mustSwapHands: false);

      return;

    }



    setCentralMessage('¡MODO CAOS! Intercambio de cartas');

    await Future.delayed(const Duration(seconds: 2));



    _isChaosSwapping = true;

    SoundService().caosCard();

    AppLogger().event('chaos_swap', params: {'game_mode': _gameMode.name});

    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));



    try {
      if (!_isHost) return; // clients only animate; the host sends the real hands
      final pool = <CardModel>[];

      for (final p in activePlayers) {

        pool.addAll(p.hand);

      }



      if (pool.length != activePlayers.length * 2) return;



      pool.shuffle(Random());



      for (final p in activePlayers) {

        p.hand = [pool.removeLast(), pool.removeLast()];

      }



      _state = _state.copyWith(mustSwapHands: false);

    } finally {

      await Future.delayed(const Duration(milliseconds: 100));

      _isChaosSwapping = false;

      _state = _state.copyWith(mustSwapHands: false);

      notifyListeners();

    }

  }



  void fold(String playerId) {

    AppLogger().log('ðŸŸ¥ FOLD llamado: playerId=$playerId isHost=$_isHost');

    if (!_isHost) {

      _sendPlayerAction('FOLD');

      return;

    }

    final idx = _players.indexWhere((p) => p.id == playerId);

    if (idx < 0) return;

    _players[idx].isFolded = true;

    _playersActedThisPhase.add(playerId);

    _isBetting = true;

    SoundService().cardFold();

    AppLogger().event('fold', params: {'player_id': playerId, 'game_mode': _gameMode.name});

    notifyListeners();



    Future.delayed(const Duration(milliseconds: 500), () {

      _isBetting = false;

      notifyListeners();

    });



    nextTurn();

  }



  void call(String playerId) {

    AppLogger().log('ðŸŸ¦ CALL llamado: playerId=$playerId isHost=$_isHost');

    if (!_isHost) {

      _sendPlayerAction('CALL');

      return;

    }

    final idx = _players.indexWhere((p) => p.id == playerId);

    if (idx < 0) return;

    final player = _players[idx];

    final alreadyBet = _betsThisPhase[playerId] ?? 0;

    final amountToCall = _currentBet - alreadyBet;



    int actualCall = 0;

    if (amountToCall > 0) {

      actualCall = min(amountToCall, player.chipBalance);

      player.chipBalance -= actualCall;

      _addContribution(playerId, actualCall);

      _betsThisPhase[playerId] = alreadyBet + actualCall;

      SoundService().chipsRaise();

    } else {

      _betsThisPhase[playerId] = _currentBet;

    }



    _playersActedThisPhase.add(playerId);

    _isBetting = true;



    if (actualCall > 0) {

      _animatingBetPlayerId = playerId;

      notifyListeners();

      Future.delayed(const Duration(milliseconds: 500), () {

        if (_animatingBetPlayerId == playerId) {

          _animatingBetPlayerId = null;

          notifyListeners();

        }

      });

    } else {

      notifyListeners();

    }



    nextTurn();

  }



  void raise(String playerId, int amount) {

    if (!_isHost) {

      _sendPlayerAction('RAISE', value: amount);

      return;

    }

    final idx = _players.indexWhere((p) => p.id == playerId);

    if (idx < 0) return;

    final player = _players[idx];

    final amountToCall = _currentBet - (_betsThisPhase[playerId] ?? 0);

    final totalDeduction = amountToCall + amount;

    if (totalDeduction <= 0 || player.chipBalance < totalDeduction) return;



    player.chipBalance -= totalDeduction;

    _currentBet += amount;

    _betsThisPhase[playerId] = (_betsThisPhase[playerId] ?? 0) + totalDeduction;

    _addContribution(playerId, totalDeduction);

    SoundService().chipsRaise();



    if (totalDeduction >= player.chipBalance && totalDeduction > 0) {

      AppLogger().log('ðŸŸ§ ALL-IN RAISE: $playerId se queda sin fichas');

    }



    _playersActedThisPhase.clear();

    _playersActedThisPhase.add(playerId);

    for (final p in _players) { if (!p.isFolded && p.chipBalance == 0 && p.id != playerId) _playersActedThisPhase.add(p.id); }



    _isBetting = true;

    _animatingBetPlayerId = playerId;

    notifyListeners();



    Future.delayed(const Duration(milliseconds: 500), () {

      _isBetting = false;

      _animatingBetPlayerId = null;

      notifyListeners();

    });



    nextTurn();

  }




  void _rushToShowdown() {
    // Reveal all community cards and go directly to showdown
    while (_state.phase != PokerPhase.showdown) {
      advancePhase();
    }
    _state = _state.copyWith(
      status: GameStatus.finished,
      revealedCommunityCount: 5,
    );
    AppLogger().log('ALL_IN_SHOWDOWN: 5 cartas comunitarias reveladas');
    determineWinner();
    notifyListeners();
    broadcastState();
  }

  int get currentBet => _currentBet;




  void rebuyPlayer(String playerId) {
    final idx = _players.indexWhere((p) => p.id == playerId);
    if (idx < 0) { AppLogger().error('REBUY_FAIL: playerId=$playerId not found'); return; }
    final player = _players[idx];
    final handOver = _state.status == GameStatus.finished || _state.phase == PokerPhase.showdown;
    player.chipBalance = 1000;
    player.isBankrupt = false;
    if (handOver) player.isFolded = false; // mid-hand: stay folded until the next deal
    _playersActedThisPhase.remove(player.id);
    _isBetting = false;
    AppLogger().log('REBUY: ${player.name} recibe 1000 fichas');
    if (_state.status == GameStatus.finished || _state.phase == PokerPhase.showdown) {
      AppLogger().log('REBUY en partida terminada - iniciando nueva ronda');
      _matchStarted = true;
      _winnerId = null;
      _isPotFlying = false;
      _centralMessage = null;
      broadcastState();
      scheduleNewRound();
      return;
    }
    notifyListeners();
  }

  void rebuyLocalPlayer() {

    if (!_isHost) {

      _sendPlayerAction('REBUY');

      return;

    }

    final local = _players.where((p) => p.isLocal).firstOrNull;

    if (local == null) return;

    local.chipBalance = 1000;

    local.isBankrupt = false;

    local.isFolded = false;

    _playersActedThisPhase.remove(local.id);

    _isBetting = false;

    AppLogger().log('ðŸ’µ REBUY: ${local.name} recibe 1000 fichas');

    if (_state.status == GameStatus.finished || _state.phase == PokerPhase.showdown) {

      AppLogger().log('ðŸ’µ REBUY en partida terminada - iniciando nueva ronda');

      _matchStarted = true;

      _winnerId = null;

      _isPotFlying = false;

      _centralMessage = null;

      broadcastState();

      scheduleNewRound();

      return;

    }

    notifyListeners();
  }



  int getPlayerBet(String playerId) => _betsThisPhase[playerId] ?? 0;



  /// Full game state. With [mask] = true, hidden information is removed:
  /// other players' hands (until showdown) and community cards not yet revealed.
  Map<String, dynamic> exportGameState({String? forPlayerId, bool mask = false}) {
    final hidden = CardModel(value: '2', suit: Suit.spades).toMap();
    final showdown = _state.phase == PokerPhase.showdown;
    return {
      'players': _players.map((p) {
        final m = p.toMap();
        final visible = !mask || p.id == forPlayerId || (showdown && !p.isFolded);
        if (!visible) {
          m['hand'] = List.generate(p.hand.length, (_) => hidden);
        }
        return m;
      }).toList(),
      'communityCards': [
        for (var i = 0; i < _state.communityCards.length; i++)
          (!mask || i < _state.revealedCommunityCount) ? _state.communityCards[i].toMap() : hidden,
      ],
      'pot': pot,
      'currentBet': _currentBet,
      'currentPlayerIndex': _state.currentPlayerIndex,
      'dealerIndex': _state.dealerIndex,
      'phase': _state.phase.name,
      'status': _state.status.name,
      'revealedCommunityCount': _state.revealedCommunityCount,
      'turnsCompleted': _state.turnsCompleted,
      'rollCounter': _rollCounter,
      'die1': _die1,
      'die2': _die2,
      'mustSwapHands': _state.mustSwapHands,
      'totalContributions': Map.from(_totalContributions),
      'gameMode': _gameMode.name,
      'betsThisPhase': Map.from(_betsThisPhase),
      'winningCards': _winningCards?.map((c) => c.toMap()).toList(),
      'result': _resultTitle == null
          ? null
          : {'winners': _resultWinnerIds, 'title': _resultTitle, 'amount': _resultAmount},
    };
  }



  /// Coalesces bursts of state changes into one send (~11 per second max).
  void broadcastState() {
    if (!_isHost || _isDisposed) return;
    if (_broadcastTimer != null) return;
    _broadcastTimer = Timer(const Duration(milliseconds: 90), () {
      _broadcastTimer = null;
      _sendStateNow();
    });
  }

  void _sendStateNow() {
    if (!_isHost || _isDisposed) return;
    final endpoints = _p2pService.connectedEndpoints;
    if (endpoints.isEmpty) return;
    _stateSeq++;
    for (final ep in endpoints) {
      _p2pService.sendMessage(ep, {
        'type': 'STATE_UPDATE',
        'session': _sessionId,
        'seq': _stateSeq,
        'state': exportGameState(forPlayerId: _endpointPlayer[ep], mask: true),
      });
    }
  }



  void _syncStateFromMap(Map<String, dynamic> state) {

    AppLogger().log('ðŸ“¥ Cliente _syncStateFromMap: currentPlayerIndex=${state['currentPlayerIndex']} status=${state['status']} numPlayers=${(state['players'] as List?)?.length}');

    if (state['gameMode'] != null) {

      _gameMode = GameMode.values.byName(state['gameMode'] as String);

    }

    _currentBet = state['currentBet'] as int? ?? _currentBet;

    _die1 = state['die1'] as int? ?? _die1;

    _die2 = state['die2'] as int? ?? _die2;

    _rollCounter = state['rollCounter'] as int? ?? _rollCounter;

    _state = _state.copyWith(

      currentPlayerIndex: state['currentPlayerIndex'] as int?,

      dealerIndex: state['dealerIndex'] as int?,

      revealedCommunityCount: state['revealedCommunityCount'] as int?,

      phase: _parsePhase(state['phase'] as String?),

      status: _parseStatus(state['status'] as String?),

      mustSwapHands: state['mustSwapHands'] as bool? ?? _state.mustSwapHands,

      turnsCompleted: state['turnsCompleted'] as int? ?? _state.turnsCompleted,

      communityCards: state['communityCards'] != null

          ? (state['communityCards'] as List<dynamic>)

              .map((c) => CardModel.fromJson(c as Map<String, dynamic>))

              .toList()

          : _state.communityCards,

    );

    if (state['players'] != null) {

      final playerList = state['players'] as List<dynamic>;

      _players.clear();

      for (final data in playerList) {

        final pData = data as Map<String, dynamic>;

        _players.add(PlayerModel(

          id: pData['id'] as String? ?? '',

          name: pData['name'] as String? ?? '',

          chipBalance: pData['chipBalance'] as int? ?? 1000,

          isLocal: pData['id'] == localPlayerId,

          isFolded: pData['isFolded'] as bool? ?? false,

          isBankrupt: pData['isBankrupt'] as bool? ?? false,
          isBot: pData['isBot'] as bool? ?? false,
          isAway: pData['isAway'] as bool? ?? false,

          hand: pData['hand'] != null

              ? (pData['hand'] as List<dynamic>)

                  .map((c) => CardModel.fromJson(c as Map<String, dynamic>))

                  .toList()

              : [],

        ));

      }

    }

    if (state['totalContributions'] != null) {

      _totalContributions.clear();

      (state['totalContributions'] as Map<String, dynamic>).forEach((k, v) {

        _totalContributions[k] = v as int;

      });

    }

    if (state['betsThisPhase'] != null) {

      _betsThisPhase.clear();

      (state['betsThisPhase'] as Map<String, dynamic>).forEach((k, v) {

        _betsThisPhase[k] = v as int;

      });

    }

    if (state['winningCards'] != null) {
      _winningCards = (state['winningCards'] as List<dynamic>)
          .map((c) => CardModel.fromJson(c as Map<String, dynamic>))
          .toList();
    }
    final result = state['result'];
    if (result is Map) {
      _setResult(
        [for (final id in (result['winners'] as List? ?? const [])) id.toString()],
        result['title']?.toString() ?? '',
        (result['amount'] as num?)?.toInt() ?? 0,
      );
    } else {
      _clearResult();
    }
  }



  PokerPhase _parsePhase(String? name) {

    if (name == null) return _state.phase;

    return PokerPhase.values.firstWhere((p) => p.name == name, orElse: () => _state.phase);

  }



  GameStatus _parseStatus(String? name) {

    if (name == null) return _state.status;

    return GameStatus.values.firstWhere((s) => s.name == name, orElse: () => _state.status);

  }



  void _processRemoteAction(String action, String playerId, int value) {
    if (action != 'REBUY') {
      final ci = _state.currentPlayerIndex;
      if (ci < 0 || ci >= _players.length || _players[ci].id != playerId) {
        AppLogger().log('Accion ignorada (no es su turno): $action $playerId');
        return;
      }
    }

    AppLogger().log('ðŸ“¨ _processRemoteAction: action=$action playerId=$playerId value=$value');

    switch (action) {

      case 'FOLD':

        fold(playerId);

        break;

      case 'CALL':

        call(playerId);

        break;

      case 'RAISE':

        raise(playerId, value);

        break;

      case 'ROLL_DICE':

        rollDice();

        break;

      case 'REBUY':
        rebuyPlayer(playerId);

        break;

    }

  }



  @override

  void notifyListeners() {

    if (_isDisposed) return;
    super.notifyListeners();

    if (_isHost) {

      broadcastState();

    }

  }



  void _checkBotTurn() {
    if (_isExiting || _state.status == GameStatus.finished) return;
    if (_state.currentPlayerIndex < 0 || _state.currentPlayerIndex >= _players.length) return;
    
    final activePlayer = _players[_state.currentPlayerIndex];
    if (!activePlayer.isBot) return;
    
    if (_state.status == GameStatus.diceTurn && _gameMode == GameMode.diceDash) {
      _playBotDice(activePlayer);
    } else if (_state.status == GameStatus.betting) {
      _playBotTurn(activePlayer);
    }
  }

  Future<void> _playBotDice(PlayerModel bot) async {
    final epoch = _epoch;
    if (_isExiting || epoch != _epoch) return;
    await Future.delayed(Duration(milliseconds: 1000 + Random().nextInt(1000)));
    if (_isExiting || epoch != _epoch) return;
    if (_state.currentPlayerIndex < 0 || _state.currentPlayerIndex >= _players.length) return;
    if (_players[_state.currentPlayerIndex].id != bot.id) return;
    if (_state.status != GameStatus.diceTurn) return;
    
    rollDice();
  }

  Future<void> _playBotTurn(PlayerModel bot) async {
    final epoch = _epoch;
    if (_isExiting || epoch != _epoch) return;
    await Future.delayed(Duration(milliseconds: 1500 + Random().nextInt(1000)));
    if (_isExiting || epoch != _epoch) return;
    
    if (_state.currentPlayerIndex < 0 || _state.currentPlayerIndex >= _players.length) return;
    if (_players[_state.currentPlayerIndex].id != bot.id) return;
    if (_isExiting || epoch != _epoch || _state.status == GameStatus.finished) return;

    final amountToCall = _currentBet - (_betsThisPhase[bot.id] ?? 0);
    bool isHighConfidence = false;
    bool isMediumConfidence = false;

    if (_state.phase == PokerPhase.preFlop) {
      if (bot.hand.length >= 2) {
        final c1 = bot.hand[0].value;
        final c2 = bot.hand[1].value;
        if (c1 == c2) {
          isHighConfidence = true;
        } else if (['J', 'Q', 'K', 'A'].contains(c1) || ['J', 'Q', 'K', 'A'].contains(c2)) {
          isMediumConfidence = true;
        }
      }
    } else {
      final eval = HandEvaluator.evaluate(bot.hand, _state.communityCards.take(_state.revealedCommunityCount).toList());
      if (eval.rank == HandRank.highCard) {
        // low
      } else if (eval.rank == HandRank.onePair) {
        isMediumConfidence = true;
      } else {
        isHighConfidence = true;
      }
    }

    final rand = Random().nextInt(100);

    void safeRaise(int raiseAmount) {
      final totalDeduction = amountToCall + raiseAmount;
      if (bot.chipBalance > totalDeduction) {
        raise(bot.id, raiseAmount);
      } else {
        call(bot.id);
      }
    }

    if (amountToCall > 0) {
      if (!isMediumConfidence && !isHighConfidence) {
        if (rand < 85) fold(bot.id);
        else call(bot.id);
      } else if (isMediumConfidence) {
        if (rand < 80) call(bot.id);
        else safeRaise(50);
      } else {
        if (rand < 30) call(bot.id);
        else safeRaise(100);
      }
    } else {
      if (isHighConfidence) {
        if (rand < 50) call(bot.id);
        else safeRaise(50);
      } else {
        call(bot.id);
      }
    }
  }

  void exitGame() {
    _isExiting = true;
    _newRoundTimer?.cancel();
    _newRoundTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _clientConnectionLost = false;
    final wasSeated = _hasSeat;
    _hasSeat = false;
    if (_isMultiplayer && !_isHost) {
      if (wasSeated) {
        for (final ep in _p2pService.connectedEndpoints) {
          _p2pService.sendMessage(ep, {'type': 'LEAVE'});
        }
      }
      // Give the LEAVE message a moment to leave the socket before closing it.
      Future.delayed(const Duration(milliseconds: 200), _p2pService.disconnectAll);
    }
    _state = _state.copyWith(status: GameStatus.finished);
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _messageSubscription?.cancel();
    _disconnectSubscription?.cancel();
    _broadcastTimer?.cancel();
    _newRoundTimer?.cancel();
    _watchdogTimer?.cancel();
    _reconnectTimer?.cancel();
    super.dispose();
  }
}
