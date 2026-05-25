import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import '../models/player_model.dart';
import '../models/card_model.dart';
import '../models/hand_evaluator.dart';
import '../services/p2p_service.dart';

class GameProvider extends ChangeNotifier {
  final P2PService _p2pService;
  StreamSubscription? _messageSubscription;

  bool _isMultiplayer = false;

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
    _listenToMessages();
    _initDebugMode();
  }

  void setMultiplayer(bool value) {
    debugPrint('🔧 setMultiplayer: $value (isHost=$_isHost)');
    _isMultiplayer = value;
    _initDebugMode();
  }

  void _initDebugMode() {
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

    _players.add(PlayerModel(
      id: '0',
      name: 'Tú',
      chipBalance: 1000,
      isLocal: true,
    ));

    _players.add(PlayerModel(
      id: '1',
      name: 'Jugador 2',
      chipBalance: 1000,
    ));

    _players.add(PlayerModel(
      id: '2',
      name: 'Jugador 3',
      chipBalance: 1000,
    ));

    _players.add(PlayerModel(
      id: '3',
      name: 'Jugador 4',
      chipBalance: 1000,
    ));

    shuffleAndDeal();
    _state = _state.copyWith(status: GameStatus.diceTurn, phase: PokerPhase.preFlop);
    notifyListeners();
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
  int get pot => _totalContributions.values.fold(0, (a, b) => a + b);
  List<CardModel> get communityCards => _state.communityCards;
  int get revealedCommunityCount => _state.revealedCommunityCount;
  PokerPhase get phase => _state.phase;
  int get dealerIndex => _state.dealerIndex;
  int get smallBlindIndex => _players.isEmpty ? 0 : (_state.dealerIndex + 1) % _players.length;
  int get bigBlindIndex => _players.isEmpty ? 0 : (_state.dealerIndex + 2) % _players.length;
  P2PService get p2pService => _p2pService;

  CardModel? _lastBurnedCard;
  CardModel? get lastBurnedCard => _lastBurnedCard;

  bool _isBetting = false;
  bool get isBetting => _isBetting;

  bool _isPotFlying = false;
  bool get isPotFlying => _isPotFlying;
  String? _winnerId;
  String? get winnerId => _winnerId;
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
    final metadata = '$_roomName|$count/4|${hasPassword ? '1' : '0'}|${started ? '1' : '0'}';
    _p2pService.stopAdvertising();
    _p2pService.startAdvertising(metadata);
  }

  void assignSeatToClient(String endpointId, {String playerName = ''}) {
    debugPrint('🪑 assignSeatToClient: endpointId=$endpointId');
    if (!_isHost) return;
    final playerId = _nextSeatId.toString();
    _nextSeatId++;

    _players.add(PlayerModel(
      id: playerId,
      name: playerName.isEmpty ? 'Jugador $playerId' : playerName,
      chipBalance: 1000,
      isLocal: false,
    ));

    updateAdvertisedName();

    _p2pService.broadcastMessage({
      'type': 'ASSIGN_SEAT',
      'endpointId': endpointId,
      'playerId': playerId,
    });

    notifyListeners();
    broadcastState();
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

  void _listenToMessages() {
    _messageSubscription = _p2pService.onMessageReceived.listen((message) {
      final type = message['type'] as String?;

      if (type == 'STATE_UPDATE' && !_isHost) {
        _syncStateFromMap(message['state'] as Map<String, dynamic>);
        notifyListeners();
        return;
      }

      if (type == 'JOIN_REJECTED' && !_isHost) {
        final reason = message['reason'] as String? ?? '';
        debugPrint('🚫 JOIN_REJECTED: $reason');
        _centralMessage = reason == 'password' ? 'Contraseña incorrecta' : 'No se pudo unir';
        notifyListeners();
        return;
      }

      if (type == 'JOIN_REQUEST' && _isHost) {
        final pass = message['password'] as String? ?? '';
        final epId = message['endpointId'] as String? ?? '';
        if (_roomPassword.isNotEmpty && pass != _roomPassword) {
          debugPrint('🔒 JOIN_REQUEST rechazado: password incorrecta');
          _p2pService.sendMessage(epId, {'type': 'JOIN_REJECTED', 'reason': 'password'});
          return;
        }
        debugPrint('🔓 JOIN_REQUEST aceptado');
        assignSeatToClient(epId, playerName: message['playerName'] as String? ?? 'Jugador');
        return;
      }

      if (type == 'PLAYER_ACTION' && _isHost) {
        debugPrint('🎮 Host recibió PLAYER_ACTION: action=${message['action']} playerId=${message['playerId']}');
        _processRemoteAction(
          message['action'] as String? ?? '',
          message['playerId'] as String? ?? '',
          message['value'] as int? ?? 0,
        );
        return;
      }

      if (type == 'ASSIGN_SEAT' && !_isHost && _isMultiplayer) {
        debugPrint('🎫 Cliente recibió ASSIGN_SEAT: playerId=${message['playerId']}');
        localPlayerId = message['playerId'] as String? ?? localPlayerId;
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
    debugPrint('🔄 nextTurn: currentPlayerIndex=${_state.currentPlayerIndex} status=${_state.status}');

    final activePlayers = _players.where((p) => !p.isFolded && p.chipBalance > 0).toList();
    final unFoldedPlayers = _players.where((p) => !p.isFolded).toList();
    final allInPlayers = _players.where((p) => !p.isFolded && p.chipBalance == 0).toList();
    for (final p in allInPlayers) { if (!_playersActedThisPhase.contains(p.id)) _playersActedThisPhase.add(p.id); }
    debugPrint('🔄 nextTurn stats: active=${activePlayers.length} unF=${unFoldedPlayers.length} allIn=${allInPlayers.length} acted=${_playersActedThisPhase.length}');
    if (unFoldedPlayers.length == 1) {
      final winner = unFoldedPlayers.first;
      final totalContribs = _totalContributions.values.fold(0, (a, b) => a + b);
      winner.chipBalance += totalContribs;
      _totalContributions.clear();
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
         _players[nextIndex].chipBalance <= 0 ||
         _playersActedThisPhase.contains(_players[nextIndex].id))) {
      nextIndex = (nextIndex + 1) % _players.length;
      loopCount++;
    }

    if (loopCount >= _players.length * 2) {
      advancePhase();
      return;
    }

    _state = _state.copyWith(
      currentPlayerIndex: nextIndex,
      status: GameStatus.diceTurn,
    );
    debugPrint('🔄 nextTurn result: nextIndex=$nextIndex playersActed=${_playersActedThisPhase.toList()}');
    _luckySevenApplied = false;

    if (_isHost) {
      _p2pService.broadcastMessage({
        'type': 'NEXT_TURN',
        'index': nextIndex,
      });
    }

    notifyListeners();
  }

  void advancePhase() {
    _clearBets();
    final currentPhase = _state.phase;

    switch (currentPhase) {
      case PokerPhase.preFlop:
        _burnCard();
        _communityCardRenderCounter++;
        _state = _state.copyWith(
          phase: PokerPhase.flop,
          currentPlayerIndex: 0,
          status: GameStatus.diceTurn,
          revealedCommunityCount: 3,
          turnsCompleted: 0,
        );
        break;
      case PokerPhase.flop:
        _burnCard();
        _state = _state.copyWith(
          phase: PokerPhase.turn,
          currentPlayerIndex: 0,
          status: GameStatus.diceTurn,
          revealedCommunityCount: 4,
          turnsCompleted: 0,
        );
        break;
      case PokerPhase.turn:
        _burnCard();
        _state = _state.copyWith(
          phase: PokerPhase.river,
          currentPlayerIndex: 0,
          status: GameStatus.diceTurn,
          revealedCommunityCount: 5,
          turnsCompleted: 0,
        );
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
  }

  void _burnCard() {
    if (_deck.isNotEmpty) {
      _lastBurnedCard = _deck.removeLast();
    }
  }

  Future<void> determineWinner() async {
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
      if (bestHandResult == null ||
          result.rank.index > bestHandResult.rank.index ||
          (result.rank.index == bestHandResult.rank.index &&
              HandEvaluator.compareKickers(result.kickers, bestHandResult.kickers) > 0)) {
        bestHandResult = result;
        winners.clear();
        winners.add(player);
      } else if (result.rank.index == bestHandResult.rank.index &&
          HandEvaluator.compareKickers(result.kickers, bestHandResult.kickers) == 0) {
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

      final totalPot = _totalContributions.values.fold(0, (a, b) => a + b);
      final splitAmount = totalPot ~/ winners.length;
      for (final w in winners) {
        w.chipBalance += splitAmount;
      }
      _totalContributions.clear();
      _flyingPotAmount = splitAmount;

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
    Future.delayed(const Duration(seconds: 5), () {
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
    _state = _state.copyWith(status: GameStatus.diceTurn, phase: PokerPhase.preFlop);
    updateAdvertisedName();
    notifyListeners();
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
    _isPotFlying = false;
    _animatingBetPlayerId = null;
    _lastBurnedCard = null;
    _isChaosSwapping = false;
    _centralMessage = null;
    _matchStarted = false;
    _initDebugMode();
  }

  void rollDice() {
    if (!_isHost) {
      _sendPlayerAction('ROLL_DICE');
      return;
    }
    final random = Random();
    _die1 = random.nextInt(6) + 1;
    _die2 = random.nextInt(6) + 1;

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
      setCentralMessage('Dados de la suerte. El Pot aumenta un 30%');
    }

    // TODO: Blackjack 21 — Si dados == 2 y 1, activar evento especial:
    // Repartir 2 cartas extra al jugador del turno y habilitar
    // una apuesta flash (solo válida durante ese turno).

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
  }

  void shuffleAndDeal() {
    _roundCounter++;
    _communityCardRenderCounter++;
    _totalContributions.clear();
    _betsThisPhase.clear();
    _currentBet = 0;
    _playersActedThisPhase.clear();
    _winningCards = null;

    // Mark bankrupt players
    for (final player in _players) {
      if (player.chipBalance <= 0) {
        player.isBankrupt = true;
        player.isFolded = true;
      }
    }

    final activePlayers = _players.where((p) => !p.isBankrupt && p.chipBalance > 0).toList();
    if (activePlayers.length < 2) {
      _deck.clear();
      notifyListeners();
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

    debugPrint(_betsThisPhase.toString());

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
        ? nextActive((dealerIdx + 1) % _players.length)
        : nextActive((bbIdx + 1) % _players.length);
    _state = _state.copyWith(
      status: GameStatus.diceTurn,
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
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));

    try {
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
    debugPrint('🟥 FOLD llamado: playerId=$playerId isHost=$_isHost');
    if (!_isHost) {
      _sendPlayerAction('FOLD');
      return;
    }
    final idx = _players.indexWhere((p) => p.id == playerId);
    if (idx < 0) return;
    _players[idx].isFolded = true;
    _playersActedThisPhase.add(playerId);
    _isBetting = true;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 500), () {
      _isBetting = false;
      notifyListeners();
    });

    nextTurn();
  }

  void call(String playerId) {
    debugPrint('🟦 CALL llamado: playerId=$playerId isHost=$_isHost');
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

    if (totalDeduction >= player.chipBalance && totalDeduction > 0) {
      debugPrint('🟧 ALL-IN RAISE: $playerId se queda sin fichas');
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

  int get currentBet => _currentBet;

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
    debugPrint('💵 REBUY: ${local.name} recibe 1000 fichas');
    notifyListeners();
    nextTurn();
  }

  int getPlayerBet(String playerId) => _betsThisPhase[playerId] ?? 0;

  Map<String, dynamic> exportGameState() => {
    'players': _players.map((p) => p.toMap()).toList(),
    'communityCards': _state.communityCards.map((c) => c.toMap()).toList(),
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
    'betsThisPhase': Map.from(_betsThisPhase),
    'winningCards': _winningCards?.map((c) => c.toMap()).toList(),
  };

  void broadcastState() {
    if (!_isHost) return;
    _p2pService.broadcastMessage({
      'type': 'STATE_UPDATE',
      'state': exportGameState(),
    });
  }

  void _syncStateFromMap(Map<String, dynamic> state) {
    debugPrint('📥 Cliente _syncStateFromMap: currentPlayerIndex=${state['currentPlayerIndex']} status=${state['status']} numPlayers=${(state['players'] as List?)?.length}');
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
    debugPrint('📨 _processRemoteAction: action=$action playerId=$playerId value=$value');
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
        rebuyLocalPlayer();
        break;
    }
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (_isHost) {
      broadcastState();
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}
