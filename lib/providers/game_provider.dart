import 'dart:async';

import '../services/logger_service.dart';

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/game_state.dart';

import '../models/player_model.dart';
import '../models/pot_calculator.dart';
import '../services/game_settings.dart';
import '../services/poker_bot_ai.dart';

import '../models/card_model.dart';

import '../models/hand_evaluator.dart';

import '../services/p2p_service.dart';
import '../services/room_address.dart';
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

  /// Client: the host closed the room on purpose (ROOM_CLOSED). Nothing to reconnect to.
  bool _roomClosed = false;
  bool get roomClosed => _roomClosed;
  int _reconnectAttempt = 0;
  bool _reconnectBusy = false;
  bool _hasSeat = false; // client: the host confirmed our seat at least once

  // --- Turn clock (LAN poker) -------------------------------------------------
  // A connected player who does not act (in another app, distracted) would hold the table
  // forever. After [turnTimeout] the host plays for them: rolls the dice, checks when
  // nothing is owed, folds otherwise. Every device starts the clock when it sees the turn
  // change (the host numbers the turns: turnSerial).
  static Duration turnTimeout = const Duration(seconds: 60); // shortened by tests
  int _turnSerial = 0;
  String _turnKey = '';
  DateTime _turnStartedAt = DateTime.now();

  /// Seconds left for the player whose turn it is (LAN poker only), or null.
  int? get turnSecondsLeft {
    if (!_isMultiplayer || _gameMode == GameMode.blackjack || !_matchStarted && _isHost) return null;
    if (_state.status != GameStatus.betting && _state.status != GameStatus.diceTurn) return null;
    final ci = _state.currentPlayerIndex;
    if (ci < 0 || ci >= _players.length || _players[ci].isBot) return null;
    final left = turnTimeout.inSeconds - DateTime.now().difference(_turnStartedAt).inSeconds;
    return left < 0 ? 0 : left;
  }

  /// Host: a new turn starts a new clock (and a new number that clients follow).
  void _trackTurn() {
    final key = '${_state.currentPlayerIndex}|${_state.status.name}|${_state.phase.name}|'
        '${_state.revealedCommunityCount}|$_roundCounter|$_rollCounter';
    if (key == _turnKey) return;
    _turnKey = key;
    _turnSerial++;
    _turnStartedAt = DateTime.now();
  }

  // --- Host migration (traspaso de anfitrión) ---------------------------------
  // The host keeps every client told who inherits the room (ROSTER): the connected humans
  // in seat order, with the address each would host on. If the host leaves (HOST_LEAVING)
  // or stops answering, the first heir reopens the room on its own device and the others
  // reconnect to it with their tokens. The hand in progress is called off and every bet goes
  // back to its owner: only the old host knew the deck and the hidden cards.
  // Needs at least two heirs: a lone player gets "sala cerrada" as before.
  final Map<String, int> _seatListenPort = {};
  List<HostHeir> _heirs = const [];
  List<Map<String, dynamic>> _rosterSeats = const [];
  final Map<String, String> _inheritedTokens = {};
  String _rosterPassword = '';
  String? _oldHostSeat;
  bool _oldHostLeft = false;
  int _migrationStep = -1; // -1: still trying the old host; i: trying _heirs[i]
  DateTime? _awayGraceUntil;
  String? _hostNotice;
  Timer? _hostNoticeTimer;
  final StreamController<void> _becameHost = StreamController<void>.broadcast();

  /// Fires when this device inherits the room (Blackjack takes over its table then).
  Stream<void> get onBecameHost => _becameHost.stream;

  /// Who would inherit the room right now, best first (both sides keep it up to date).
  List<HostHeir> get heirs => _heirs;

  /// Seat of the host that left on purpose before this device inherited the room.
  String? get departedHostSeat => _oldHostLeft ? _oldHostSeat : null;

  /// Short line for the banner: the room is changing hands, or just did.
  String? get connectionNotice {
    if (_reconnectGaveUp || _roomClosed) return null;
    if (_clientConnectionLost) {
      if (_migrationStep >= 0 && _migrationStep < _heirs.length) {
        return 'El anfitrión salió. ${_heirs[_migrationStep].name} se queda con la mesa…';
      }
      return 'Conexión perdida, reconectando…';
    }
    return _hostNotice;
  }



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



  // Seat changes for game modes that run their own table on top of this
  // lobby (Blackjack): the lobby keeps joins, tokens, passwords and reconnects.
  final StreamController<SeatEvent> _seatEvents = StreamController<SeatEvent>.broadcast();
  Stream<SeatEvent> get seatEvents => _seatEvents.stream;

  void _emitSeat(SeatEventKind kind, String seatId, String name, String endpointId) {
    if (!_seatEvents.isClosed) _seatEvents.add(SeatEvent(kind, seatId, name, endpointId));
  }

  /// Seat bound to a connected socket (host side), or null.
  String? seatForEndpoint(String endpointId) => _endpointPlayer[endpointId];

  /// Seats currently connected (host side): seatId -> player name.
  Map<String, String> get connectedSeats => {
        for (final e in _endpointPlayer.entries)
          e.value: _players.where((p) => p.id == e.value).firstOrNull?.name ?? 'Jugador',
      };

  String get playerName => _hostName;

  /// Marks the room as started for modes that do not use [startMatch] (Blackjack):
  /// drops after this point keep the seat (away) instead of freeing it.
  void markMatchStarted() {
    _matchStarted = true;
    updateAdvertisedName();
    _sendRoster();
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
      final seatName = _players.where((x) => x.id == seatId).firstOrNull?.name ?? '';
      // Left on purpose (LEAVE) or before the match: the seat is free. Dropped mid-match: away.
      final gone = !_matchStarted || _leftSeats.contains(seatId);
      _emitSeat(gone ? SeatEventKind.left : SeatEventKind.away, seatId, seatName, endpointId);
      if (!_matchStarted) {
        // Still in the waiting room: just free the seat.
        _players.removeWhere((x) => x.id == seatId);
        updateAdvertisedName();
        notifyListeners();
        _sendRoster();
        return;
      }
      final p = _players.where((x) => x.id == seatId).firstOrNull;
      if (p != null) {
        p.isAway = true;
        notifyListeners();
      }
      _sendRoster();
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
    if (_roomClosed || _reconnectTimer != null || _reconnectBusy || _isExiting || _isDisposed) return;
    _clientConnectionLost = true;
    _reconnectGaveUp = false;
    _reconnectAttempt = 0;
    _migrationStep = -1;
    notifyListeners();
    _scheduleReconnectAttempt();
  }

  void _scheduleReconnectAttempt() {
    if (_isExiting || _isDisposed || _isHost) return;
    // The old host gets two tries when the room can change hands (ten when it cannot);
    // then the room moves down the list of heirs, several quick tries each.
    final limit = _migrationStep >= 0 ? 6 : (_canMigrate ? 2 : 10);
    if (_reconnectAttempt >= limit) {
      if (!_canMigrate || !_nextMigrationTarget()) {
        _reconnectGaveUp = true;
        _reconnectTimer = null;
        notifyListeners();
        return;
      }
      notifyListeners();
      if (_isHost) return; // this device inherited the room
    }
    final delay = _migrationStep >= 0
        ? const Duration(milliseconds: 1500)
        : Duration(seconds: min(1 << _reconnectAttempt, 8));
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
          'password': _rosterPassword,
          'token': playerToken,
          'endpointId': ep,
          'listenPort': _p2pService.preferredPort,
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
    if (_migrationStep >= 0 && _migrationStep < _heirs.length) {
      _showHostNotice('Ahora el anfitrión es ${_heirs[_migrationStep].name}');
    }
    _migrationStep = -1;
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
    if (_gameMode == GameMode.blackjack) return; // Blackjack runs its own turn timers
    if (_diceEventBusy) return; // dice events (all-in, extra card) have their own timers
    if (_matchWinnerId != null) return; // match over: waits for "Jugar otra vez"
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
    if (!p.isAway && !p.isBot && !p.isFolded && !_isBetting && !_isChaosSwapping &&
        DateTime.now().difference(_turnStartedAt) >= turnTimeout) {
      AppLogger().log('Tiempo agotado: ${p.name} no jugo, se juega por el');
      _playForIdle(p);
      return;
    }
    if (!p.isAway || p.isFolded) return;
    final grace = _awayGraceUntil;
    if (grace != null && DateTime.now().isBefore(grace)) return; // still reconnecting after a handoff
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



  /// Out of time: roll the dice, check when nothing is owed, fold otherwise.
  void _playForIdle(PlayerModel p) {
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
    _roomClosed = false;
    _matchWinnerId = null;
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
    _seatListenPort.clear();
    _heirs = const [];
    _rosterSeats = const [];
    _inheritedTokens.clear();
    _oldHostSeat = null;
    _oldHostLeft = false;
    _migrationStep = -1;
    _awayGraceUntil = null;

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



    // Single player: you are always seat 0. A LAN client left another seat here (e.g. '2'):
    // the table then showed you as an opponent and waited forever for "your" turn.
    localPlayerId = '0';
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

  int get pot => _totalContributions.values.fold(0, (a, b) => a + b) + _houseBonus;

  List<CardModel> get communityCards => _state.communityCards;

  int get revealedCommunityCount => _state.revealedCommunityCount;

  /// Gap between community cards; the table's flip animation fits inside it.
  static const Duration communityCardInterval = Duration(milliseconds: 520);

  PokerPhase get phase => _state.phase;

  int get dealerIndex => _state.dealerIndex;

  // Seats that actually posted the blinds this hand (bankrupt seats are skipped
  // at the deal, so they cannot be derived from the dealer index alone).
  int _sbIndex = 0;
  int _bbIndex = 0;

  int get smallBlindIndex => _players.isEmpty ? 0 : _sbIndex.clamp(0, _players.length - 1);

  int get bigBlindIndex => _players.isEmpty ? 0 : _bbIndex.clamp(0, _players.length - 1);

  // --- Dice Dash events -------------------------------------------------------

  DiceEvent _lastDiceEvent = DiceEvent.none;
  DiceEvent get lastDiceEvent => _lastDiceEvent;

  /// Tests force the next roll (e.g. `[6, 6]`).
  @visibleForTesting
  List<int>? debugNextDice;

  /// A dice event is resolving (forced all-in, extra card): bots and the action
  /// panel wait for it instead of acting on the old situation.
  bool _diceEventBusy = false;
  bool get diceEventBusy => _diceEventBusy;

  /// Cards each viewer was shown by "Espía": viewerId -> {'playerId:cardIndex'}.
  final Map<String, Set<String>> _spied = {};

  /// True when [viewerId] may see card [cardIndex] of [playerId] (Espía).
  bool isCardSpied(String viewerId, String playerId, int cardIndex) =>
      _spied[viewerId]?.contains('$playerId:$cardIndex') ?? false;

  /// Which event a roll triggers. Specific pairs win over the lucky 7
  /// (6+1 is "Carta extra", not "dados de la suerte").
  static DiceEvent diceEventFor(int a, int b, {bool luckySevenAvailable = true}) {
    final lo = min(a, b);
    final hi = max(a, b);
    if (lo == 1 && hi == 1) return DiceEvent.swap;
    if (lo == 6 && hi == 6) return DiceEvent.allIn;
    if (lo == 3 && hi == 3) return DiceEvent.spy;
    if (lo == 1 && hi == 6) return DiceEvent.extraCard;
    if (a + b == 7 && luckySevenAvailable) return DiceEvent.luckySeven;
    return DiceEvent.none;
  }

  /// How long the dice tumble on screen (`_RollingDice`); events start after it.
  static const Duration diceRollAnimation = Duration(milliseconds: 1250);

  void _applyDiceEvent(DiceEvent event, PlayerModel roller) {
    switch (event) {
      case DiceEvent.allIn:
        _scheduleForcedAllIn(roller);
      case DiceEvent.spy:
        _applySpy(roller);
      case DiceEvent.extraCard:
        _applyExtraCard(roller);
      case DiceEvent.luckySeven:
        // House bonus, once per hand, as dead money for the main pot. Crediting it
        // as the roller's own contribution broke side pots and could repeat every turn.
        final extra = (pot * 0.30).toInt();
        _houseBonus += extra;
        SoundService().chipsMultiply();
        AppLogger().event('lucky_seven', params: {'pot_bonus': extra.toString()});
        setCentralMessage('Dados de la suerte. El Pot aumenta un 30%');
      case DiceEvent.swap:
        _state = _state.copyWith(mustSwapHands: true);
      case DiceEvent.none:
        break;
    }
  }

  /// Doble 6: the roller goes all-in after the message.
  void _scheduleForcedAllIn(PlayerModel roller) {
    final epoch = _epoch;
    _diceEventBusy = true;
    setCentralMessage('¡Doble 6! ${roller.name} va ALL-IN');
    Future.delayed(const Duration(milliseconds: 1400), () {
      _diceEventBusy = false;
      if (_isExiting || epoch != _epoch) return;
      final ci = _state.currentPlayerIndex;
      if (ci < 0 || ci >= _players.length || _players[ci].id != roller.id) return;
      if (_state.status != GameStatus.betting || roller.isFolded) return;
      final toCall = max(0, _currentBet - (_betsThisPhase[roller.id] ?? 0));
      if (roller.chipBalance > toCall) {
        raise(roller.id, roller.chipBalance - toCall);
      } else {
        call(roller.id); // all-in for less (or exactly the call)
      }
    });
  }

  /// Doble 3: the roller sees one random card of a random opponent until the hand ends.
  void _applySpy(PlayerModel roller) {
    final targets = _players.where((p) => p.id != roller.id && !p.isFolded && p.hand.isNotEmpty).toList();
    if (targets.isEmpty) return;
    final rnd = Random();
    final target = targets[rnd.nextInt(targets.length)];
    final idx = rnd.nextInt(target.hand.length);
    _spied.putIfAbsent(roller.id, () => {}).add('${target.id}:$idx');
    setCentralMessage('¡Espía! ${roller.name} ve una carta de ${target.name}');
  }

  /// 6+1: the roller gets a third private card and keeps the best two.
  void _applyExtraCard(PlayerModel roller) {
    if (_deck.isEmpty || roller.hand.length != 2) return;
    final epoch = _epoch;
    final extra = _deck.removeLast();
    roller.hand = [...roller.hand, extra];
    _diceEventBusy = true;
    SoundService().cardMix();
    setCentralMessage('¡Carta extra! ${roller.name} se queda con sus dos mejores cartas');
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (_isExiting || epoch != _epoch || roller.hand.length != 3) {
        _diceEventBusy = false;
        return;
      }
      final board = _state.communityCards.take(_state.revealedCommunityCount).toList();
      final keep = bestTwoOf(roller.hand, board);
      _extraDiscard = (roller.id, roller.hand.indexWhere((c) => !keep.contains(c)));
      notifyListeners();
      broadcastState();
      Future.delayed(const Duration(milliseconds: 900), () {
        _extraDiscard = null;
        _diceEventBusy = false;
        if (_isExiting || epoch != _epoch || roller.hand.length != 3) return;
        roller.hand = keep;
        _spied.forEach((_, set) => set.removeWhere((k) => k.startsWith('${roller.id}:')));
        notifyListeners();
        broadcastState();
        _checkBotTurn();
      });
    });
  }

  /// 6+1: the card the roller is about to throw away (playerId, card index).
  (String, int)? _extraDiscard;
  bool isDiscardingCard(String playerId, int cardIndex) =>
      _extraDiscard != null && _extraDiscard!.$1 == playerId && _extraDiscard!.$2 == cardIndex;
  /// The two cards of [three] that make the strongest hand with [board]
  /// (on an empty board: pairs first, then high cards).
  static List<CardModel> bestTwoOf(List<CardModel> three, List<CardModel> board) {
    List<CardModel>? best;
    var bestPower = -1;
    for (var i = 0; i < three.length; i++) {
      for (var j = i + 1; j < three.length; j++) {
        final pair = [three[i], three[j]];
        final power = HandEvaluator.evaluate(pair, board).power;
        if (power > bestPower) {
          bestPower = power;
          best = pair;
        }
      }
    }
    return best ?? three.take(2).toList();
  }

  /// Chips added to the pot by the house (Dice Dash "dados de la suerte").
  /// Dead money: it belongs to whoever wins the main pot.
  int _houseBonus = 0;

  /// Players who can still put chips in this hand.
  List<PlayerModel> get _canBet =>
      _players.where((p) => !p.isFolded && !p.isBankrupt && p.chipBalance > 0 && p.hand.isNotEmpty).toList();

  /// True when nobody can bet against anybody any more (everyone left is all-in,
  /// or one player with chips has already matched): the board is dealt to showdown.
  bool get _bettingIsOver {
    final live = _players.where((p) => !p.isFolded && !p.isBankrupt && p.hand.isNotEmpty).length;
    if (live < 2) return false;
    final can = _canBet;
    if (can.isEmpty) return true;
    if (can.length == 1) return (_betsThisPhase[can.first.id] ?? 0) >= _currentBet;
    return false;
  }

  /// Deals the rest of the board without betting rounds (all-in run-out).
  Future<void> _runOutBoard() async {
    final epoch = _epoch;
    _state = _state.copyWith(currentPlayerIndex: -1);
    notifyListeners();
    broadcastState();
    await Future.delayed(const Duration(milliseconds: 900));
    if (_isExiting || epoch != _epoch) return;
    advancePhase();
  }

  /// Player ids clockwise starting left of the dealer (odd chips of split pots).
  List<String> get _seatOrderFromDealer => [
        for (var i = 1; i <= _players.length; i++) _players[(_state.dealerIndex + i) % _players.length].id,
      ];

  P2PService get p2pService => _p2pService;



  CardModel? _lastBurnedCard;

  CardModel? get lastBurnedCard => _lastBurnedCard;



  bool _isBetting = false;

  bool get isBetting => _isBetting;



  bool _isPotFlying = false;

  bool get isPotFlying => _isPotFlying;

  String? _winnerId;
  String? get winnerId => _winnerId;

  /// Only one seat has chips left: the match is over until the host restarts it.
  String? _matchWinnerId;
  String? get matchWinnerId => _matchWinnerId;

  /// "Jugar otra vez" after a match is won: everyone back to 1000 (host / local only).
  void restartMatch() {
    if (!_isHost || _matchWinnerId == null) return;
    _matchWinnerId = null;
    for (final p in _players) {
      p.chipBalance = 1000;
      p.isBankrupt = false;
      p.isFolded = false;
      p.hand = [];
    }
    AppLogger().event('match_restart', params: {'game_mode': _gameMode.name});
    notifyListeners();
    broadcastState();
    scheduleNewRound();
  }

  // Result of the last finished hand, shown by the results banner and the
  // winner ribbon on the seats. Cleared when the next hand is dealt.
  List<String> _resultWinnerIds = const [];
  List<String> get resultWinnerIds => _resultWinnerIds;
  String? _resultTitle;
  String? get resultTitle => _resultTitle;
  int _resultAmount = 0;
  int get resultAmount => _resultAmount;

  /// Chips each player won at the last showdown (main + side pots, refunds excluded).
  Map<String, int> _resultPayouts = const {};
  Map<String, int> _lastContributions = const {};
  int resultPayoutOf(String playerId) =>
      _resultPayouts[playerId] ?? (_resultWinnerIds.contains(playerId) ? _resultAmount : 0);

  void _setResult(List<String> winnerIds, String title, int amount) {
    _resultWinnerIds = List.unmodifiable(winnerIds);
    _resultTitle = title;
    _resultAmount = amount;
  }

  void _clearResult() {
    _resultPayouts = const {};
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

  BotDifficulty _botDifficulty = BotDifficulty.normal;
  BotDifficulty get botDifficulty => _botDifficulty;
  void setBotDifficulty(BotDifficulty d) {
    _botDifficulty = d;
    notifyListeners();
  }

  /// Short label of each bot's style, for the seat tooltip / debugging.
  BotPersonality personalityOf(PlayerModel bot) => BotPersonality.forSeat(int.tryParse(bot.id) ?? 0);
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

    _p2pService.updateServiceName(_advertisedMetadata()); // keeps the TCP port stable

  }

  String _advertisedMetadata() {
    final hasPassword = _roomPassword.isNotEmpty;
    return '$_roomName|${_players.length}/4|${hasPassword ? '1' : '0'}|${_matchStarted ? '1' : '0'}|${_gameMode.name}';
  }



  void assignSeatToClient(String endpointId, {String playerName = '', String token = '', int? listenPort}) {
    AppLogger().log('assignSeatToClient: endpointId=$endpointId');
    if (!_isHost) return;

    // An inherited room may not know this token (only the first heirs get the list): a
    // player coming back under the same name takes back their empty seat.
    if (_matchStarted && token.isNotEmpty && !_tokenToPlayer.containsKey(token) && playerName.isNotEmpty) {
      final byName = _players
          .where((p) => p.isAway && !p.isBot && !p.isLocal && p.name == playerName && !_leftSeats.contains(p.id))
          .firstOrNull;
      if (byName != null) _tokenToPlayer[token] = byName.id;
    }

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
        if (listenPort != null) _seatListenPort[seatId] = listenPort;
        AppLogger().log('Jugador ${existing.name} recupera su asiento $seatId');
        _p2pService.sendMessage(endpointId, {
          'type': 'ASSIGN_SEAT',
          'endpointId': endpointId,
          'playerId': seatId,
          'gameMode': _gameMode.name,
        });
        _emitSeat(SeatEventKind.back, seatId, existing.name, endpointId);
        notifyListeners();
        _sendStateNow();
        _sendRoster();
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
    if (listenPort != null) _seatListenPort[playerId] = listenPort;

    updateAdvertisedName();
    AppLogger().event('player_joined', params: {'player_name': playerName.isEmpty ? 'Jugador' : playerName, 'game_mode': _gameMode.name});

    _p2pService.sendMessage(endpointId, {
      'type': 'ASSIGN_SEAT',
      'endpointId': endpointId,
      'playerId': playerId,
      'gameMode': _gameMode.name,
    });
    _emitSeat(SeatEventKind.joined, playerId, _players.last.name, endpointId);

    notifyListeners();
    _sendStateNow();
    _sendRoster();
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



  /// Raises made in the current betting round (bots stop re-raising after [_botRaiseCap]).
  int _raisesThisPhase = 0;
  static const int _botRaiseCap = 3;

  void _clearBets() {
    _raisesThisPhase = 0;

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



  @visibleForTesting
  Map<String, int> get debugContributions => Map.unmodifiable(_totalContributions);

  @visibleForTesting
  void debugSetChips(String playerId, int chips) {
    final p = _players.where((x) => x.id == playerId).firstOrNull;
    if (p != null) p.chipBalance = chips;
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

        assignSeatToClient(
          senderEpId,
          playerName: message['playerName'] as String? ?? 'Jugador',
          token: message['token'] as String? ?? '',
          listenPort: (message['listenPort'] as num?)?.toInt(),
        );

        return;

      }



      if (type == 'LEAVE' && _isHost) {
        _handleLeave(message['_senderEndpointId'] as String? ?? '');
        return;
      }

      if (type == 'ROSTER' && !_isHost) {
        _applyRoster(message);
        return;
      }

      if (type == 'HOST_LEAVING' && !_isHost) {
        _onHostLeaving();
        return;
      }

      if (type == 'ROOM_CLOSED' && !_isHost) {
        AppLogger().log('ROOM_CLOSED: el anfitrion cerro la sala');
        _roomClosed = true;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        _clientConnectionLost = false;
        notifyListeners();
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



          // 1+1: the host sets the swap flag once the dice land (state update).
          final swapFlag = _state.mustSwapHands;



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
            // Texas has no dice step: a client must not show "lanzar dados" there.
            status: _gameMode == GameMode.diceDash ? GameStatus.diceTurn : GameStatus.betting,

            phase: phase != null ? PokerPhase.values.byName(phase) : null,

            revealedCommunityCount: revealed ?? _state.revealedCommunityCount,

          );


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

      final totalContribs = pot;
      winner.chipBalance += totalContribs;
      _totalContributions.clear();
      _houseBonus = 0;
      // The hand is over: no more actions until the next deal.
      _state = _state.copyWith(status: GameStatus.finished, currentPlayerIndex: -1);

      _setResult([winner.id], 'por abandono', totalContribs);
      _resultPayouts = {winner.id: totalContribs};
      SoundService().chipsWin();
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



    if (_bettingIsOver) {
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
        // One card at a time at a dealer's pace; the table plays each card's
        // flip animation and sound (on every device, not only on the host).
        for (int i = 0; i < 3; i++) {
          _state = _state.copyWith(revealedCommunityCount: _state.revealedCommunityCount + 1);
          notifyListeners();
          await Future.delayed(communityCardInterval);
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
        _state = _state.copyWith(revealedCommunityCount: 4);
        notifyListeners();
        await Future.delayed(communityCardInterval);
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
        _state = _state.copyWith(revealedCommunityCount: 5);
        notifyListeners();
        await Future.delayed(communityCardInterval);
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



    if (_bettingIsOver) {
      _runOutBoard();
      return;
    }
    // Post-flop the first to act is the first player left of the dealer who can
    // still bet (the small blind with 3+ players, the big blind heads-up).
    var startIndex = (_state.dealerIndex + 1) % _players.length;
    for (var i = 0; i < _players.length; i++) {
      final idx = (_state.dealerIndex + 1 + i) % _players.length;
      if (_canBet.contains(_players[idx])) {
        startIndex = idx;
        break;
      }
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



      // Main pot + side pots: an all-in player only wins what they could cover.
      _lastContributions = Map.of(_totalContributions);
      final payouts = PotCalculator.distribute(
        contributions: Map.of(_totalContributions),
        strength: {
          for (final p in activePlayers)
            if (p.hand.length >= 2) p.id: HandEvaluator.evaluate(p.hand, _state.communityCards).power,
        },
        seatOrder: _seatOrderFromDealer,
        deadMoney: _houseBonus,
      );
      for (final e in payouts.entries) {
        final p = _players.where((x) => x.id == e.key).firstOrNull;
        if (p != null) p.chipBalance += e.value;
      }
      _totalContributions.clear();
      _houseBonus = 0;
      final mainShare = payouts[winners.first.id] ?? 0;
      _flyingPotAmount = mainShare;
      // Ribbons show winnings, not the uncalled part of a bet that simply comes back.
      final contribs = Map.of(_lastContributions);
      final won = <String, int>{};
      for (final e in payouts.entries) {
        final others = contribs.entries.where((x) => x.key != e.key).map((x) => x.value);
        final topOther = others.isEmpty ? 0 : others.reduce(max);
        final refund = max(0, (contribs[e.key] ?? 0) - topOther);
        final net = e.value - refund;
        if (net > 0) won[e.key] = net;
      }
      _resultPayouts = Map.unmodifiable(won);
      SoundService().chipsWin();
      _setResult([for (final w in winners) w.id], bestHandResult.rankName, mainShare);
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
    _sendRoster();

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


    _currentBet = 0;

    _totalContributions.clear();

    _betsThisPhase.clear();
    _raisesThisPhase = 0;

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
    final forced = debugNextDice;
    debugNextDice = null;
    _die1 = forced?[0] ?? random.nextInt(6) + 1;
    _die2 = forced?[1] ?? random.nextInt(6) + 1;
    SoundService().diceRoll();
    final roller = (_state.currentPlayerIndex >= 0 && _state.currentPlayerIndex < _players.length)
        ? _players[_state.currentPlayerIndex]
        : null;
    final event = diceEventFor(_die1, _die2, luckySevenAvailable: !_luckySevenApplied);
    _lastDiceEvent = event;
    // 1+1 included: the "¡CAOS!" screen starts when the swap flag is set, so it waits too.
    final swapFlag = _state.mustSwapHands;
    if (event == DiceEvent.luckySeven) _luckySevenApplied = true;
    // Nothing happens (no message, no card, no panel) until the dice have landed
    // on every screen; meanwhile nobody may act on the old situation.
    if (roller != null && event != DiceEvent.none) {
      _diceEventBusy = true;
      final epoch = _epoch;
      Future.delayed(diceRollAnimation, () {
        if (_isExiting || epoch != _epoch) return;
        _diceEventBusy = false;
        _applyDiceEvent(event, roller);
        notifyListeners();
        broadcastState();
        _checkBotTurn();
      });
    }







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
    SoundService().cardMix();

    _roundCounter++;

    _communityCardRenderCounter++;

    _totalContributions.clear();

    _betsThisPhase.clear();
    _raisesThisPhase = 0;

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

    if (activePlayers.length == 1) {
      // Everybody else is out of chips: announce the winner, nobody is reset behind their back.
      _matchWinnerId = activePlayers.first.id;
      AppLogger().event('match_over', params: {'winner': activePlayers.first.name});
      _state = _state.copyWith(status: GameStatus.finished);
      notifyListeners();
      broadcastState();
      return;
    }
    if (activePlayers.isEmpty) {
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



    _matchWinnerId = null;

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
    _sbIndex = sbIdx;
    _bbIndex = bbIdx;
    _spied.clear();
    _lastDiceEvent = DiceEvent.none;
    _extraDiscard = null;
    _diceEventBusy = false;
    _houseBonus = 0;
    _luckySevenApplied = false;



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
    // The blinds may have put players all-in: nobody left to bet against.
    if (_bettingIsOver) {
      notifyListeners();
      _runOutBoard();
      return;
    }
    // First to act must be someone who still has chips.
    final first = _state.currentPlayerIndex;
    if (first >= 0 && first < _players.length && _players[first].chipBalance <= 0) {
      for (var i = 1; i <= _players.length; i++) {
        final idx = (first + i) % _players.length;
        if (_canBet.contains(_players[idx])) {
          _state = _state.copyWith(currentPlayerIndex: idx);
          break;
        }
      }
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
      _spied.clear(); // the spied cards are in other hands now



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

    final amountToCall = max(0, _currentBet - (_betsThisPhase[playerId] ?? 0));
    final totalDeduction = amountToCall + amount;
    // A raise adds chips on top of the call: never zero or negative (remote input is untrusted).
    if (amount <= 0 || player.chipBalance < totalDeduction) return;



    player.chipBalance -= totalDeduction;

    _currentBet += amount;

    _betsThisPhase[playerId] = (_betsThisPhase[playerId] ?? 0) + totalDeduction;
    _raisesThisPhase++;

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

    // Mid-hand there are no cards for this seat: it plays from the next deal.
    final handOver = _state.status == GameStatus.finished || _state.phase == PokerPhase.showdown;
    local.isFolded = !handOver && local.hand.isEmpty;

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
          m['hand'] = [
            for (var i = 0; i < p.hand.length; i++)
              (forPlayerId != null && isCardSpied(forPlayerId, p.id, i)) ? p.hand[i].toMap() : hidden,
          ];
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
      'sbIndex': _sbIndex,
      'bbIndex': _bbIndex,
      'houseBonus': _houseBonus,
      'diceEvent': _lastDiceEvent.name,
      'diceEventBusy': _diceEventBusy,
      'extraDiscard': _extraDiscard == null ? null : [_extraDiscard!.$1, _extraDiscard!.$2],
      'spied': forPlayerId == null ? const <String>[] : (_spied[forPlayerId]?.toList() ?? const <String>[]),
      'payouts': _resultPayouts,
      'matchWinner': _matchWinnerId,
      'phase': _state.phase.name,
      'status': _state.status.name,
      'revealedCommunityCount': _state.revealedCommunityCount,
      'turnsCompleted': _state.turnsCompleted,
      'turnSerial': _turnSerial,
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
    if (!_isHost || _isDisposed || _gameMode == GameMode.blackjack) return;
    if (_broadcastTimer != null) return;
    _broadcastTimer = Timer(const Duration(milliseconds: 90), () {
      _broadcastTimer = null;
      _sendStateNow();
    });
  }

  void _sendStateNow() {
    if (!_isHost || _isDisposed || _gameMode == GameMode.blackjack) return;
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
    final before = _SoundSnapshot.of(this);

    AppLogger().log('ðŸ“¥ Cliente _syncStateFromMap: currentPlayerIndex=${state['currentPlayerIndex']} status=${state['status']} numPlayers=${(state['players'] as List?)?.length}');

    if (state['gameMode'] != null) {

      _gameMode = GameMode.values.byName(state['gameMode'] as String);

    }

    _currentBet = state['currentBet'] as int? ?? _currentBet;
    final serial = state['turnSerial'] as int?;
    if (serial != null && serial != _turnSerial) {
      _turnSerial = serial;
      _turnStartedAt = DateTime.now();
    }

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
    _sbIndex = state['sbIndex'] as int? ?? _sbIndex;
    _bbIndex = state['bbIndex'] as int? ?? _bbIndex;
    _houseBonus = state['houseBonus'] as int? ?? _houseBonus;
    _lastDiceEvent = DiceEvent.values.where((e) => e.name == state['diceEvent']).firstOrNull ?? _lastDiceEvent;
    _diceEventBusy = state['diceEventBusy'] as bool? ?? _diceEventBusy;
    final xd = state['extraDiscard'];
    _extraDiscard = xd is List && xd.length == 2 ? (xd[0] as String, (xd[1] as num).toInt()) : null;
    final spied = state['spied'];
    if (spied is List) {
      _spied
        ..clear()
        ..[localPlayerId] = {for (final k in spied) k.toString()};
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
    _matchWinnerId = state['matchWinner'] as String?;
    final payouts = state['payouts'];
    if (payouts is Map) {
      _resultPayouts = {for (final e in payouts.entries) e.key.toString(): (e.value as num).toInt()};
    }
    before.playChanges(this);
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
      // Each action only in its step: bets while betting, the roll while rolling.
      final wanted = action == 'ROLL_DICE' ? GameStatus.diceTurn : GameStatus.betting;
      if (_state.status != wanted) {
        AppLogger().log('Accion ignorada (estado ${_state.status.name}): $action $playerId');
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
    if (_isHost) _trackTurn();
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
    await Future.delayed(GameSettings().scaled(Duration(milliseconds: 1000 + Random().nextInt(1000))));
    if (_isExiting || epoch != _epoch) return;
    if (_state.currentPlayerIndex < 0 || _state.currentPlayerIndex >= _players.length) return;
    if (_players[_state.currentPlayerIndex].id != bot.id) return;
    if (_state.status != GameStatus.diceTurn) return;
    
    rollDice();
  }

  Future<void> _playBotTurn(PlayerModel bot) async {
    final epoch = _epoch;
    if (_isExiting || epoch != _epoch) return;
    await Future.delayed(GameSettings().scaled(Duration(milliseconds: 1500 + Random().nextInt(1000))));
    if (_isExiting || epoch != _epoch) return;
    
    if (_state.currentPlayerIndex < 0 || _state.currentPlayerIndex >= _players.length) return;
    if (_players[_state.currentPlayerIndex].id != bot.id) return;
    if (_isExiting || epoch != _epoch || _state.status == GameStatus.finished) return;

    // INTERCAMBIO or a dice event in progress: decide with the final situation.
    if (_isChaosSwapping || _diceEventBusy) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!_isExiting && epoch == _epoch) _checkBotTurn();
      });
      return;
    }
    final amountToCall = max(0, _currentBet - (_betsThisPhase[bot.id] ?? 0));
    final opponents = _players
        .where((p) => p.id != bot.id && !p.isFolded && !p.isBankrupt && p.hand.isNotEmpty)
        .length;
    final situation = BotSituation(
      hole: bot.hand,
      board: _state.communityCards.take(_state.revealedCommunityCount).toList(),
      toCall: amountToCall,
      pot: pot,
      chips: bot.chipBalance,
      opponents: opponents,
    );
    BotDecision decision;
    try {
      decision = PokerBotBrain(difficulty: _botDifficulty).decide(situation, personalityOf(bot));
    } catch (e, st) {
      AppLogger().error('Bot ${bot.name}: fallo al decidir: $e', st);
      decision = BotDecision(amountToCall > 0 ? BotActionKind.fold : BotActionKind.call);
    }
    AppLogger().log('Bot ${bot.name} (${personalityOf(bot).name}, ${_botDifficulty.name}): $decision');
    // Still this bot's turn after thinking? (state may have moved on)
    if (_isExiting || epoch != _epoch || _state.status != GameStatus.betting) return;
    if (_state.currentPlayerIndex < 0 || _state.currentPlayerIndex >= _players.length) return;
    if (_players[_state.currentPlayerIndex].id != bot.id) return;
    switch (decision.kind) {
      case BotActionKind.fold:
        fold(bot.id);
      case BotActionKind.call:
        call(bot.id);
      case BotActionKind.raise:
        // Like a casino cap: no endless bot re-raise wars in one betting round.
        if (_raisesThisPhase < _botRaiseCap && bot.chipBalance >= amountToCall + decision.raiseBy && decision.raiseBy > 0) {
          raise(bot.id, decision.raiseBy);
        } else {
          call(bot.id);
        }
    }
  }

  // --- Host migration ---------------------------------------------------------

  bool get _canMigrate => _heirs.length >= 2 && _matchStarted;

  /// Host: connected humans in seat order (never bots, never the host itself).
  List<HostHeir> _computeHeirs() {
    final out = <HostHeir>[];
    for (final p in _players) {
      if (p.isBot || p.id == localPlayerId || _leftSeats.contains(p.id)) continue;
      final ep = _endpointPlayer.entries.where((e) => e.value == p.id).map((e) => e.key).firstOrNull;
      final address = ep == null ? null : P2PService.parseEndpoint(ep);
      if (address == null) continue;
      out.add(HostHeir(
        seat: p.id,
        name: p.name,
        host: address.$1,
        port: _seatListenPort[p.id] ?? RoomAddress.defaultPort,
      ));
    }
    return out;
  }

  /// Host: tells every client who inherits the room. The first two heirs also get the
  /// tokens, so whoever takes over recognizes everybody coming back.
  void _sendRoster() {
    if (!_isHost || !_isMultiplayer || _isDisposed) return;
    final heirs = _computeHeirs();
    final base = <String, dynamic>{
      'type': 'ROSTER',
      'hostSeat': localPlayerId,
      'heirs': [for (final h in heirs) h.toMap()],
      'seats': [
        for (final p in _players) {'id': p.id, 'name': p.name, 'isBot': p.isBot},
      ],
      'room': _roomName,
      'password': _roomPassword,
      'started': _matchStarted,
    };
    final keyHolders = {for (final h in heirs.take(2)) h.seat};
    for (final e in _endpointPlayer.entries) {
      _p2pService.sendMessage(
        e.key,
        keyHolders.contains(e.value) ? {...base, 'tokens': Map<String, String>.from(_tokenToPlayer)} : base,
      );
    }
  }

  void _applyRoster(Map<String, dynamic> m) {
    _heirs = [
      for (final h in (m['heirs'] as List? ?? const []))
        if (h is Map) HostHeir.fromMap(Map<String, dynamic>.from(h)),
    ];
    _rosterSeats = [
      for (final s in (m['seats'] as List? ?? const []))
        if (s is Map) Map<String, dynamic>.from(s),
    ];
    _oldHostSeat = m['hostSeat'] as String?;
    _roomName = m['room'] as String? ?? _roomName;
    _rosterPassword = m['password'] as String? ?? '';
    if (m['started'] == true) _matchStarted = true;
    final tokens = m['tokens'];
    _inheritedTokens.clear();
    if (tokens is Map) {
      tokens.forEach((k, v) => _inheritedTokens[k.toString()] = v.toString());
    }
  }

  /// Client: the host is leaving on purpose; go straight to the heirs.
  void _onHostLeaving() {
    if (!_canMigrate) {
      _roomClosed = true;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _clientConnectionLost = false;
      notifyListeners();
      return;
    }
    AppLogger().log('HOST_LEAVING: la sala pasa a ${_heirs.first.name}');
    _oldHostLeft = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _clientConnectionLost = true;
    _reconnectGaveUp = false;
    _migrationStep = -1;
    _reconnectAttempt = 0;
    if (!_nextMigrationTarget()) {
      _reconnectGaveUp = true;
    } else if (!_isHost) {
      _scheduleReconnectAttempt();
    }
    notifyListeners();
  }

  /// Moves to the next heir. Returns false when there is nobody left to try.
  bool _nextMigrationTarget() {
    _migrationStep++;
    _reconnectAttempt = 0;
    if (_migrationStep >= _heirs.length) return false;
    final heir = _heirs[_migrationStep];
    if (heir.seat == localPlayerId) {
      _becomeHost();
      return true;
    }
    AppLogger().log('Traspaso: probando con ${heir.name} en ${heir.host}:${heir.port}');
    _p2pService.lastHost = heir.host;
    _p2pService.lastPort = heir.port;
    return true;
  }

  /// This device inherits the room: it opens it under the same name and password, waits
  /// for the others to come back and deals a fresh hand with every bet returned.
  void _becomeHost() {
    AppLogger().log('Traspaso: este dispositivo se queda con la sala');
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isHost = true;
    _epoch++;
    _clientConnectionLost = false;
    _reconnectGaveUp = false;
    _migrationStep = -1;
    _reconnectAttempt = 0;
    _hasSeat = true;
    _matchStarted = true;
    _roomPassword = _rosterPassword;
    _endpointPlayer.clear();
    _tokenToPlayer
      ..clear()
      ..addAll(_inheritedTokens);
    // Poker clients know every seat from the last state; Blackjack ones only from the roster.
    if (_players.isEmpty || _gameMode == GameMode.blackjack) {
      _players
        ..clear()
        ..addAll([
          for (final s in _rosterSeats)
            PlayerModel(id: s['id'] as String? ?? '', name: s['name'] as String? ?? '', isBot: s['isBot'] == true),
        ]);
    }
    for (final p in _players) {
      p.isLocal = p.id == localPlayerId;
      if (!p.isBot && !p.isLocal) p.isAway = true; // until they reconnect
    }
    final oldHost = _oldHostSeat;
    if (_oldHostLeft && oldHost != null) _leftSeats.add(oldHost);
    _nextSeatId = 1 + _players.map((p) => int.tryParse(p.id) ?? 0).fold(0, max);
    _awayGraceUntil = DateTime.now().add(const Duration(seconds: 15));
    if (_gameMode != GameMode.blackjack) _callOffHand();
    _p2pService.startAdvertising(_advertisedMetadata());
    _showHostNotice('El anfitrión salió: ahora tú tienes la mesa');
    notifyListeners();
    if (!_becameHost.isClosed) _becameHost.add(null);
    AppLogger().event('host_migrated', params: {'game_mode': _gameMode.name});
  }

  /// Poker: the hand in progress cannot go on without the old host's deck. Everyone gets
  /// back what they put in and a new hand is dealt shortly.
  void _callOffHand() {
    for (final p in _players) {
      p.chipBalance += _totalContributions[p.id] ?? 0;
      p.hand = [];
      p.isFolded = false;
    }
    _totalContributions.clear();
    _betsThisPhase.clear();
    _playersActedThisPhase.clear();
    _currentBet = 0;
    _raisesThisPhase = 0;
    _houseBonus = 0;
    _diceEventBusy = false;
    _isChaosSwapping = false;
    _isBetting = false;
    _isPotFlying = false;
    _winnerId = null;
    _winningCards = null;
    _extraDiscard = null;
    _spied.clear();
    _clearResult();
    _state = _state.copyWith(communityCards: [], revealedCommunityCount: 0);
    if (_matchWinnerId != null) return; // match over: the new host decides when to play again
    _state = _state.copyWith(status: GameStatus.finished, currentPlayerIndex: -1);
    scheduleNewRound();
  }

  void _showHostNotice(String text) {
    _hostNotice = text;
    _hostNoticeTimer?.cancel();
    _hostNoticeTimer = Timer(const Duration(seconds: 5), () {
      _hostNotice = null;
      notifyListeners();
    });
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
    if (_isMultiplayer && _isHost) {
      if (_matchStarted && _computeHeirs().length >= 2) {
        // Enough players stay: the first heir keeps the room going.
        _sendRoster();
        _p2pService.broadcastMessage({'type': 'HOST_LEAVING'});
      } else {
        // Clients used to stay connected to a host that no longer played: frozen table.
        _p2pService.broadcastMessage({'type': 'ROOM_CLOSED'});
      }
      Future.delayed(const Duration(milliseconds: 300), _p2pService.disconnectAll);
    }
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
    _hostNoticeTimer?.cancel();
    _seatEvents.close();
    _becameHost.close();
    super.dispose();
  }
}

enum SeatEventKind { joined, back, away, left }

/// A player who would inherit the room, and where their device would open it.
class HostHeir {
  final String seat;
  final String name;
  final String host;
  final int port;
  const HostHeir({required this.seat, required this.name, required this.host, required this.port});

  Map<String, dynamic> toMap() => {'seat': seat, 'name': name, 'host': host, 'port': port};

  factory HostHeir.fromMap(Map<String, dynamic> m) => HostHeir(
        seat: m['seat'] as String? ?? '',
        name: m['name'] as String? ?? '',
        host: m['host'] as String? ?? '',
        port: (m['port'] as num?)?.toInt() ?? RoomAddress.defaultPort,
      );
}

class SeatEvent {
  final SeatEventKind kind;
  final String seatId;
  final String name;
  final String endpointId;
  const SeatEvent(this.kind, this.seatId, this.name, this.endpointId);
}

/// What a LAN client compares before/after a host snapshot to play the same
/// sounds the host plays when the actions happen there.
class _SoundSnapshot {
  final int pot;
  final int roll;
  final int localCards;
  final Set<String> folded;
  final bool hadResult;

  _SoundSnapshot(this.pot, this.roll, this.localCards, this.folded, this.hadResult);

  factory _SoundSnapshot.of(GameProvider g) {
    final local = g.players.where((p) => p.id == g.localPlayerId).firstOrNull;
    return _SoundSnapshot(
      g.pot,
      g.rollCounter,
      local?.hand.length ?? 0,
      {for (final p in g.players) if (p.isFolded) p.id},
      g.resultTitle != null,
    );
  }

  void playChanges(GameProvider g) {
    final now = _SoundSnapshot.of(g);
    final sound = SoundService();
    if (localCards == 0 && now.localCards > 0) {
      sound.cardMix(); // new hand dealt
      return;
    }
    if (!hadResult && now.hadResult) {
      sound.chipsWin();
      return;
    }
    if (now.roll != roll) sound.diceRoll();
    if (now.folded.difference(folded).isNotEmpty) {
      sound.cardFold();
    } else if (now.pot > pot) {
      sound.chipsRaise();
    }
  }
}

/// What a Dice Dash roll triggers (see `GameProvider.diceEventFor`).
enum DiceEvent { none, luckySeven, swap, allIn, spy, extraCard }
