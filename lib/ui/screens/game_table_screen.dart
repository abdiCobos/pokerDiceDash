import 'dart:math' as math;
import 'dart:async';
import '../../services/logger_service.dart';
import '../../services/sound_service.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/card_model.dart';
import '../../models/game_state.dart';
import '../../models/player_model.dart';
import '../../providers/game_provider.dart';
import '../layout/seat_layout.dart';
import '../widgets/scene_background.dart';
import '../widgets/host_address_chip.dart';
import '../widgets/connection_banner.dart';
import '../widgets/room_closed_overlay.dart';
import '../widgets/card_widget.dart';
import '../../services/game_settings.dart';
import '../../services/poker_bot_ai.dart';
import '../widgets/table_options.dart';
import '../widgets/betting_chip_widget.dart';
import 'lobby_screen.dart';

class GameTableScreen extends StatefulWidget {
  final bool isMultiplayer;
  final bool isHost;

  const GameTableScreen({super.key, this.isMultiplayer = false, this.isHost = true});

  @override
  State<GameTableScreen> createState() => _GameTableScreenState();
}

class _GameTableScreenState extends State<GameTableScreen>
    with TickerProviderStateMixin {

  final GlobalKey _localSeatKey = GlobalKey();

  bool _lastMustSwap = false;
  int _lastPot = 0;
  int _previousRevealed = 0;
  CardModel? _lastBurned;
  late AnimationController _burnController;
  late Animation<double> _burnAnimation;
  bool _showPotFlying = false;
  int _potFlyingAmount = 0;

  double _screenW = 800;
  double _screenH = 450;
  double _s = 1.0;
  final Map<String, Rect> _seatRects = {};

  StreamSubscription<String>? _hostConnectionSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    _screenW = size.width;
    _screenH = size.height;
    _s = SeatLayout.tableScale(size);
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    GameSettings().applyWakelock(atTable: true);
    _burnController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _burnAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _burnController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final game = context.read<GameProvider>();
      if (!widget.isMultiplayer) {
        game.resetGame();
      } else if (widget.isHost) {
        _setupHost();
      }
    });
  }

  void _setupHost() {}

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    GameSettings().applyWakelock(atTable: false);
    _hostConnectionSub?.cancel();
    _burnController.dispose();
    super.dispose();
  }

  void _showChaosOverlay() {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => _ChaosOverlay(),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }

  void _launchChipAnimation() {} // No-op: chip animation in _PlayerSeat via _BetChipAnimation

  List<PlayerModel> _getPlayersWithDemo(GameProvider game) {
    if (game.players.isNotEmpty) return game.players;
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text('¿Abandonar partida?', style: TextStyle(color: Colors.amber)),
            content: const Text('¿Estás seguro que quieres salir de la partida?', style: TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Salir', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (shouldPop ?? false) {
          if (context.mounted) {
            Provider.of<GameProvider>(context, listen: false).exitGame();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LobbyScreen()),
            );
          }
        }
      },
      child: Scaffold(
      body: SceneBackground(
        child: SafeArea(
          child: Consumer<GameProvider>(
            builder: (context, game, child) {
              final mustSwapChanged = game.state.mustSwapHands && !_lastMustSwap;

              if (mustSwapChanged) {
                _lastMustSwap = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showChaosOverlay();
                  game.swapHands();
                });
              }

              if (!game.state.mustSwapHands) {
                _lastMustSwap = false;
              }

              if (game.pot != _lastPot) {
                _lastPot = game.pot;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _launchChipAnimation();
                });
              }

              final players = _getPlayersWithDemo(game);

              if (game.lastBurnedCard != null && game.lastBurnedCard != _lastBurned) {
                _lastBurned = game.lastBurnedCard;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _burnController.forward(from: 0);
                });
              }

              if (game.isPotFlying && !_showPotFlying) {
                _showPotFlying = true;
                _potFlyingAmount = game.flyingPotAmount;
                final provider = context.read<GameProvider>();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Future.delayed(const Duration(milliseconds: 850), () {
                    if (mounted) {
                      setState(() => _showPotFlying = false);
                      provider.completePotTransfer();
                    }
                  });
                });
              } else if (!game.isPotFlying) {
                _showPotFlying = false;
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  _screenW = w;
                  _screenH = h;
                  _s = SeatLayout.tableScale(Size(w, h));

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildTableFelt(SeatLayout.tableRect(
                        Size(w, h),
                        diceMode: game.gameMode == GameMode.diceDash,
                      )),
                      _buildHeader(game),
                      _buildCenterArea(game),
                      // Seats and bets live in their own layer: their count changes with every
                      // bet, which must not shift (and rebuild) the widgets after them.
                      Positioned.fill(
                        child: Stack(clipBehavior: Clip.none, children: _buildPlayerSeats(players, game)),
                      ),
                      _buildControls(game),
                      if (game.state.status == GameStatus.betting)
                        _buildActionPanel(game),
                      if (_lastBurned != null)
                        _buildBurnedCardAnimation(),
                      if (game.connectionNotice != null)
                        ConnectionBanner(text: game.connectionNotice!, warning: game.isConnectionLost, scale: _s),
                      if (game.resultTitle != null)
                        _ResultsBanner(
                          key: ValueKey('result_${game.roundCounter}_${game.resultWinnerIds.join(',')}'),
                          names: [
                            for (final id in game.resultWinnerIds)
                              game.players.firstWhere((p) => p.id == id, orElse: () => PlayerModel(id: id, name: '?')).name,
                          ],
                          title: game.resultTitle!,
                          amount: game.resultAmount,
                          localWon: game.resultWinnerIds.contains(game.localPlayerId),
                          scale: _s,
                        )
                      else if (game.centralMessage != null)
                        _CenteredStatusAlert(message: game.centralMessage!),
                      if (_showPotFlying && game.winnerId != null)
                        _buildPotFlyingAnimation(game),
                      if (game.roomClosed || (game.isConnectionLost && game.reconnectGaveUp))
                        Positioned.fill(
                          child: RoomClosedOverlay(
                            message: game.roomClosed
                                ? 'El anfitrión cerró la sala.'
                                : 'Se perdió la conexión con el anfitrión.',
                            scale: _s,
                            onExit: () {
                              game.exitGame();
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LobbyScreen()));
                            },
                          ),
                        )
                      else if (game.matchWinnerId != null)
                        Positioned.fill(
                          child: _MatchOverOverlay(
                            winnerName: game.players
                                .firstWhere((p) => p.id == game.matchWinnerId, orElse: () => PlayerModel(id: '', name: '?'))
                                .name,
                            localWon: game.matchWinnerId == game.localPlayerId,
                            canRestart: game.isHost,
                            scale: _s,
                            onRestart: game.restartMatch,
                            onExit: () => Navigator.maybePop(context),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildHeader(GameProvider game) {
    return Positioned(
      top: 12 * _s,
      left: 12 * _s,
      right: 12 * _s,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Dark disc: the arrow sits over the busy cantina background (papel picado).
              Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white, size: 26 * _s),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
              SizedBox(width: 4 * _s),
              TableOptionsButton(scale: _s, poker: true, onExit: () => Navigator.maybePop(context)),
            ],
          ),
          if (widget.isMultiplayer && widget.isHost && game.state.status == GameStatus.waitingPlayers)
            HostAddressChip(port: game.p2pService.hostPort, scale: _s),
          if (game.state.mustSwapHands)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'INTERCAMBIO!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

        ],
      ),
    );
  }

  /// Stadium-shaped felt with a wooden rail; purely decorative.
  Widget _buildTableFelt(Rect table) {
    final style = TableFeltStyle.of(GameSettings().theme);
    return Positioned.fromRect(
      rect: table,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(table.height / 2),
            color: style.rail,
            border: Border.all(color: style.railEdge, width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 22 * _s, spreadRadius: 2 * _s),
            ],
          ),
          padding: EdgeInsets.all(9 * _s),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(table.height / 2),
              gradient: RadialGradient(
                radius: 0.9,
                colors: style.felt,
                stops: const [0.0, 0.6, 1.0],
              ),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.45), width: 1.2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterArea(GameProvider game) {
    final beside = game.revealedCommunityCount > 0;
    final potRect = SeatLayout.potRect(Size(_screenW, _screenH), beside: beside);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Nothing is at stake while the room is still waiting for players.
        if (game.pot > 0 && game.state.status != GameStatus.waitingPlayers)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            left: potRect.left,
            top: potRect.top,
            width: potRect.width,
            height: potRect.height,
            child: Align(
              alignment: beside ? Alignment.centerRight : Alignment.center,
              child: FittedBox(fit: BoxFit.scaleDown, child: _PotText(pot: game.pot, scale: _s)),
            ),
          ),
        Positioned(
          top: SeatLayout.boardTop(Size(_screenW, _screenH)),
          left: 0,
          right: 0,
          child: Center(child: _buildCommunityCards(game)),
        ),
        if (game.gameMode == GameMode.diceDash)
          Positioned(
            top: SeatLayout.diceRect(Size(_screenW, _screenH)).top,
            left: SeatLayout.diceRect(Size(_screenW, _screenH)).left,
            child: _buildDiceArea(game),
          ),
      ],
    );
  }

  List<Widget> _buildPlayerSeats(List<PlayerModel> players, GameProvider game) {
    final widgets = <Widget>[];
    final localId = game.localPlayerId;
    final localIdx = players.indexWhere((p) => p.id == localId);

    // 1. Local player at bottom center
    if (localIdx >= 0) {
      final seat = Container(
        key: _localSeatKey,
        child: _PlayerSeat(
          playerId: localId,
          isLocal: true,
          isCurrentTurn: game.state.currentPlayerIndex == localIdx,
          scale: _s,
        ),
      );
      widgets.add(Positioned(
        key: const ValueKey('seat_local'),
        bottom: 0,
        left: 0,
        right: 0,
        child: Align(alignment: Alignment.bottomCenter, child: seat),
      ));
    }

    // 2. Opponents ordered clockwise around the table from local player
    final totalPlayers = players.length;
    final opponents = <PlayerModel>[];
    if (localIdx >= 0) {
      for (var step = 1; step < totalPlayers; step++) {
        opponents.add(players[(localIdx + step) % totalPlayers]);
      }
    } else {
      opponents.addAll(players.where((p) => p.id != localId));
    }

    final oppCount = opponents.length;
    final layout = SeatLayout.placeOpponents(
      size: Size(_screenW, _screenH),
      opponents: oppCount,
      diceMode: game.gameMode == GameMode.diceDash,
    );
    _seatRects.clear();

    final tableSize = Size(_screenW, _screenH);
    final diceMode = game.gameMode == GameMode.diceDash;
    final placedBets = <Rect>[];
    final betWidgets = <Widget>[];
    final inlineBets = <String>{};
    void addBet(String playerId, Rect betRect, Offset from) {
      final amount = game.getPlayerBet(playerId);
      if (amount <= 0) return;
      // Keyed per player: a new bet elsewhere must not re-animate this one.
      betWidgets.add(Positioned.fromRect(
        key: ValueKey('betpos_$playerId'),
        rect: betRect,
        child: _BetStack(
          key: ValueKey('bet_${game.roundCounter}_$amount'),
          amount: amount,
          from: from - betRect.center,
          scale: _s,
        ),
      ));
    }

    if (localIdx >= 0) {
      final localBet = SeatLayout.localBetRect(tableSize);
      addBet(localId, localBet, Offset(_screenW / 2, _screenH - 40 * _s));
    }

    for (var i = 0; i < oppCount && i < layout.rects.length; i++) {
      final rect = layout.rects[i];
      final others = [for (var j = 0; j < layout.rects.length; j++) if (j != i) layout.rects[j]];
      final betRect = SeatLayout.betRect(
        size: tableSize,
        seat: rect,
        otherSeats: others,
        diceMode: diceMode,
        placedBets: placedBets,
      );
      if (betRect == null) {
        inlineBets.add(opponents[i].id);
        continue;
      }
      placedBets.add(betRect);
      addBet(opponents[i].id, betRect, rect.center);
    }

    for (var i = 0; i < oppCount && i < layout.rects.length; i++) {
      final opp = opponents[i];
      final oppIdx = players.indexWhere((p) => p.id == opp.id);
      final rect = layout.rects[i];
      _seatRects[opp.id] = rect;

      widgets.add(Positioned.fromRect(
        key: ValueKey('seat_${opp.id}'),
        rect: rect,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: _PlayerSeat(
            playerId: opp.id,
            isLocal: false,
            isCurrentTurn: game.state.currentPlayerIndex == oppIdx,
            scale: _s * layout.scale,
            shrink: layout.scale,
            width: rect.width,
            inlineBet: inlineBets.contains(opp.id),
            foldToward: _unitToward(rect.center, Offset(_screenW / 2, _screenH * 0.45)),
          ),
        ),
      ));
    }

    widgets.addAll(betWidgets);
    return widgets;
  }

  static Offset _unitToward(Offset from, Offset to) {
    final d = to - from;
    return d.distance == 0 ? const Offset(0, 1) : d / d.distance;
  }

  Widget _buildCommunityCards(GameProvider game) {
    final cards = game.communityCards;
    final revealed = game.revealedCommunityCount;

    if (revealed == 0 || cards.isEmpty) {
      _previousRevealed = 0;
      return SizedBox(height: 30 * _s);
    }

    final newCardsStart = _previousRevealed;
    _previousRevealed = revealed;
    final winning = game.winningCards;
    final isShowdown = game.phase == PokerPhase.showdown;

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          // All five slots exist from the flop on, so cards already on the felt
          // never shift sideways when the next one lands.
          children: List.generate(5, (i) {
            if (i >= revealed || i >= cards.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Opacity(
                  opacity: 0,
                  child: CardWidget(card: CardModel(value: 'A', suit: Suit.spades), isFaceUp: false, scale: 0.65),
                ),
              );
            }
            final card = cards[i];
            // Cards that appear together (e.g. a client catching up) still go one by one.
            final isNew = i >= newCardsStart;
            final delayMs = isNew ? (i - newCardsStart) * GameProvider.communityCardInterval.inMilliseconds : 0;

            final isWinner = isShowdown && winning != null &&
                winning.any((w) => w.value == card.value && w.suit == card.suit);

            final cardWidget = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _winningGlow(
                isWinner: isWinner,
                isShowdown: isShowdown,
                child: CardWidget(
                  card: card,
                  isFaceUp: true,
                  scale: 0.65,
                ),
              ),
            );

            // Always the same keyed widget, so a table rebuild mid-flip never cuts it.
            return _AnimatedPokerCard(
              key: ValueKey('slot_${i}_round_${game.roundCounter}'),
              delayMs: delayMs,
              scale: _s,
              back: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: CardWidget(card: card, isFaceUp: false, scale: 0.65),
              ),
              child: cardWidget,
            );
          }),
        ),
        SizedBox(height: 3 * _s),
      ],
    );
  }

  Widget _buildDiceArea(GameProvider game) {
    // The dice are thrown from the roller's seat toward the dice spot.
    final diceCenter = SeatLayout.diceRect(Size(_screenW, _screenH)).center;
    final idx = game.state.currentPlayerIndex;
    Offset origin = Offset(_screenW / 2, _screenH);
    if (idx >= 0 && idx < game.players.length) {
      final id = game.players[idx].id;
      if (id != game.localPlayerId) origin = _seatRects[id]?.center ?? Offset(_screenW / 2, 0);
    }
    return _RollingDice(
      key: ValueKey('dice_${game.rollCounter}'),
      die1: game.die1,
      die2: game.die2,
      from: origin - diceCenter,
      event: game.lastDiceEvent,
      animate: game.rollCounter > 0,
      scale: _s,
    );
  }


  Widget _buildControls(GameProvider game) {
    final activeIdx = game.state.currentPlayerIndex;
    final blocked = game.isBetting || game.isChaosSwapping || game.diceEventBusy || game.centralMessage != null;
    final isMyTurn = activeIdx >= 0 && activeIdx < game.players.length &&
        game.players[activeIdx].id == game.localPlayerId;
    final canRoll = game.state.status == GameStatus.diceTurn && isMyTurn && !blocked;

    final canStart = widget.isMultiplayer && widget.isHost &&
        game.players.length >= 2 && game.state.phase == PokerPhase.preFlop &&
        game.state.communityCards.isEmpty && game.state.status == GameStatus.waitingPlayers;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (game.gameMode == GameMode.diceDash)
          Positioned(
            bottom: _screenH * 0.04,
            right: _screenW * 0.03,
            child: Transform.scale(
              scale: _s,
              child: FloatingActionButton.extended(
                onPressed: canRoll ? game.rollDice : null,
                backgroundColor: canRoll ? const Color(0xFFFFA726) : Colors.grey.shade700,
                foregroundColor: Colors.black,
                icon: const Icon(Icons.casino),
                label: const Text('Lanzar Dados', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        if (canStart)
          Positioned(
            bottom: _screenH * 0.28,
            right: _screenW * 0.03,
            child: Material(
              color: Colors.green,
              borderRadius: BorderRadius.circular(10 * _s),
              child: InkWell(
                onTap: () {
                  game.startMatch();
                  game.broadcastState();
                },
                borderRadius: BorderRadius.circular(10 * _s),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16 * _s, vertical: 8 * _s),
                  child: Text('Iniciar Partida',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12 * _s)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionPanel(GameProvider game) {
    final activeIdx = game.state.currentPlayerIndex;
    if (activeIdx < 0 || activeIdx >= game.players.length) return const SizedBox.shrink();
    final activePlayer = game.players[activeIdx];
    if (activePlayer.isFolded) return const SizedBox.shrink();

    final isMyTurn = activePlayer.id == game.localPlayerId;
    final isAllIn = activePlayer.chipBalance <= 0 && !activePlayer.isFolded;
    final blocked = game.isBetting || game.isChaosSwapping || game.diceEventBusy || game.centralMessage != null;
    if (!isMyTurn) {
      if (!widget.isMultiplayer) {
        return const SizedBox.shrink();
      }
      return const SizedBox.shrink();
    }

    // In Texas Hold'em, all-in players should still get to see FOLD/CALL/RAISE
    // (they can only call with their remaining chips, which is handled in call())
    final showAllInControls = isAllIn && game.gameMode == GameMode.texasHoldem;

    final currentBet = game.currentBet;
    final playerBet = game.getPlayerBet(activePlayer.id);
    final amountToCall = currentBet - playerBet;
    AppLogger().log('Apuesta de ${activePlayer.id}: $playerBet');
    final isAllInCall = amountToCall >= activePlayer.chipBalance;

    String callLabel;
    if (amountToCall <= 0) {
      // Nothing to match (also the big blind when nobody raised): it is a check.
      callLabel = 'CHECK';
    } else if (isAllInCall) {
      callLabel = 'ALL-IN (${activePlayer.chipBalance})';
    } else {
      callLabel = 'CALL ($amountToCall)';
    }

    return Positioned(
      bottom: _screenH * 0.06,
      left: _screenW * 0.05,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Actuando como: ${activePlayer.name}',
            style: TextStyle(color: Colors.amber, fontSize: 12 * _s),
          ),
          SizedBox(height: 4 * _s),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: (isAllIn && !showAllInControls)
                ? [
                    Text('ALL-IN', style: TextStyle(color: Colors.orange, fontSize: 11 * _s, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    _ActionButton(label: 'CONTINUAR', color: Colors.orange, enabled: !blocked, onTap: !blocked ? () => game.call(activePlayer.id) : null),
                  ]
                : [
              _ActionButton(
                label: callLabel,
                color: Colors.blue.shade700,
                enabled: !blocked,
                onTap: !blocked ? () => game.call(activePlayer.id) : null,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                label: 'RAISE',
                color: Colors.orange.shade800,
                enabled: !blocked && !isAllInCall,
                onTap: !blocked && !isAllInCall ? () => _showRaiseDialog(context, game, activePlayer.id) : null,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                label: 'FOLD',
                color: Colors.red.shade700,
                enabled: !blocked,
                onTap: !blocked ? () => game.fold(activePlayer.id) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPotFlyingAnimation(GameProvider game) {
    final winnerId = game.winnerId;
    if (winnerId == null) return const SizedBox.shrink();

    final players = game.players;
    final winnerIdx = players.indexWhere((p) => p.id == winnerId);
    if (winnerIdx < 0) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
      builder: (context, t, child) {
        final width = MediaQuery.of(context).size.width;
        final height = MediaQuery.of(context).size.height;

        final potCenter = SeatLayout.potRect(Size(_screenW, _screenH)).center;
        final startX = potCenter.dx;
        final startY = potCenter.dy;

        double endX;
        double endY;

        if (winnerId == game.localPlayerId) {
          endX = width / 2;
          endY = height - 100 * _s;
        } else {
          final seat = _seatRects[winnerId];
          if (seat != null) {
            endX = seat.center.dx;
            endY = seat.center.dy;
          } else {
            endX = width / 2;
            endY = 80 * _s;
          }
        }

        final x = startX + (endX - startX) * t;
        final y = startY + (endY - startY) * t;

        return Positioned(
          left: x - 20 * _s,
          top: y - 25 * _s,
          child: Opacity(
            opacity: (1 - (t > 0.85 ? (t - 0.85) / 0.15 : 0)).clamp(0.0, 1.0).toDouble(),
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40 * _s,
            height: 50 * _s,
            child: Stack(
              children: [
                Positioned(
                  bottom: 0,
                  child: Image.asset('assets/images/chips/chipRedWhite_side.png', width: 40 * _s, errorBuilder: (c, e, s) => const SizedBox.shrink()),
                ),
                Positioned(
                  bottom: 5 * _s,
                  child: Image.asset('assets/images/chips/chipBlueWhite_side.png', width: 40 * _s, errorBuilder: (c, e, s) => const SizedBox.shrink()),
                ),
                Positioned(
                  bottom: 10 * _s,
                  child: Image.asset('assets/images/chips/chipBlackWhite_side.png', width: 40 * _s, errorBuilder: (c, e, s) => const SizedBox.shrink()),
                ),
                Positioned(
                  bottom: 15 * _s,
                  child: Image.asset('assets/images/chips/chipGreenWhite_side.png', width: 40 * _s, errorBuilder: (c, e, s) => const SizedBox.shrink()),
                ),
              ],
            ),
          ),
          Text(
            '+$_potFlyingAmount',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 16 * _s,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBurnedCardAnimation() {
    return AnimatedBuilder(
      animation: _burnAnimation,
      builder: (context, child) {
        final t = _burnAnimation.value;
        final width = MediaQuery.of(context).size.width;
        final height = MediaQuery.of(context).size.height;
        final startX = width / 2 - 26 * _s;
        final startY = height / 2 - 36 * _s;
        final endX = width - 68 * _s;
        final endY = height - 173 * _s;

        final x = startX + (endX - startX) * t;
        final y = startY + (endY - startY) * t;

        return Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: (1 - (t > 0.8 ? (t - 0.8) / 0.2 : 0)).clamp(0.0, 1.0).toDouble(),
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: 52 * _s,
        height: 73 * _s,
        child: CardWidget(
          card: CardModel(value: 'A', suit: Suit.spades),
          isFaceUp: false,
          scale: 0.65,
        ),
      ),
    );
  }

  Widget _winningGlow({required bool isWinner, required bool isShowdown, required Widget child}) {
    if (!isShowdown) return child;
    if (isWinner) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.amber, width: 3),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.amberAccent, blurRadius: 15, spreadRadius: 3),
          ],
        ),
        child: child,
      );
    }
    return Opacity(opacity: 0.3, child: child);
  }
}

/// A community card: slides in face down from the deck, then flips face up
/// with its own sound. Runs once per card (state is kept by its key).
class _AnimatedPokerCard extends StatefulWidget {
  final Widget child;
  final Widget back;
  final int delayMs;
  final double scale;

  const _AnimatedPokerCard({
    super.key,
    required this.child,
    required this.back,
    this.delayMs = 0,
    this.scale = 1.0,
  });

  @override
  State<_AnimatedPokerCard> createState() => _AnimatedPokerCardState();
}

void _showRaiseDialog(BuildContext context, GameProvider game, String playerId) {
  final playerIdx = game.players.indexWhere((p) => p.id == playerId);
  if (playerIdx < 0) return;
  final maxBalance = game.players[playerIdx].chipBalance;
  final amountToCall = max(0, game.currentBet - game.getPlayerBet(playerId));
  final screen = MediaQuery.of(context).size;
  // Landscape phones are ~360 dp tall: everything sits in a few short rows and the whole
  // card scales down to the screen, so it never needs scrolling.
  final s = min(screen.width / 800, screen.height / 400).clamp(0.6, 1.3);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      int raiseAmount = 0;
      return StatefulBuilder(
        builder: (context, setState) {
          final canConfirm = raiseAmount > 0 && amountToCall + raiseAmount <= maxBalance;

          Widget chip(String label, VoidCallback? onTap, {bool allIn = false}) {
            final enabled = onTap != null;
            final bg = allIn ? Colors.red.shade800 : Colors.amber;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 4 * s),
              child: Material(
                color: enabled ? bg : Colors.grey.shade700,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: enabled ? (allIn ? Colors.red : Colors.amber.shade700) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: onTap,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 10 * s),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: enabled ? (allIn ? Colors.white : Colors.black) : Colors.white54,
                        fontSize: 13 * s,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return Dialog(
            backgroundColor: const Color(0xFF1A1A2E),
            insetPadding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 12 * s),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14 * s),
              side: const BorderSide(color: Colors.amber, width: 2),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: screen.height - 24 * s, maxWidth: 460 * s),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20 * s, 14 * s, 20 * s, 10 * s),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Subir apuesta', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15 * s)),
                      SizedBox(height: 6 * s),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('+$raiseAmount', style: TextStyle(color: Colors.amber, fontSize: 28 * s, fontWeight: FontWeight.bold)),
                          SizedBox(width: 12 * s),
                          Text(
                            amountToCall > 0
                                ? 'Igualas $amountToCall · Total ${amountToCall + raiseAmount}'
                                : 'Total ${amountToCall + raiseAmount}',
                            style: TextStyle(color: Colors.orange, fontSize: 13 * s, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 10 * s),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final amount in [10, 50, 100])
                            chip(
                              '+$amount',
                              amountToCall + raiseAmount + amount <= maxBalance
                                  ? () => setState(() => raiseAmount += amount)
                                  : null,
                            ),
                          chip(
                            'ALL IN',
                            maxBalance - amountToCall > 0
                                ? () => setState(() => raiseAmount = maxBalance - amountToCall)
                                : null,
                            allIn: true,
                          ),
                        ],
                      ),
                      SizedBox(height: 10 * s),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text('Cancelar', style: TextStyle(color: Colors.white60, fontSize: 13 * s)),
                          ),
                          SizedBox(width: 24 * s),
                          ElevatedButton(
                            onPressed: canConfirm
                                ? () {
                                    Navigator.pop(dialogContext);
                                    game.raise(playerId, raiseAmount);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade800,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.white12,
                              disabledForegroundColor: Colors.white38,
                              padding: EdgeInsets.symmetric(horizontal: 22 * s, vertical: 10 * s),
                            ),
                            child: Text('Confirmar', style: TextStyle(fontSize: 13 * s, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = (MediaQuery.of(context).size.width / 800).clamp(0.45, 1.3);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7 * s),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 8 * s),
          decoration: BoxDecoration(
            color: enabled ? color : Colors.grey.shade700,
            borderRadius: BorderRadius.circular(7 * s),
            border: Border.all(
              color: enabled ? color.withValues(alpha: 0.7) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? Colors.white : Colors.white54,
              fontSize: 12 * s,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip color by amount, like real casino denominations.
String _chipAssetFor(int amount) {
  if (amount >= 500) return 'assets/images/chips/chipBlackWhite.png';
  if (amount >= 100) return 'assets/images/chips/chipGreenWhite.png';
  if (amount >= 50) return 'assets/images/chips/chipBlueWhite.png';
  if (amount >= 20) return 'assets/images/chips/chipRedWhite.png';
  return 'assets/images/chips/chipWhiteBlue.png';
}

/// A player's bet for the current street, sitting on the felt. Slides in from
/// the seat (`from` is the seat center relative to this widget's center).
class _BetStack extends StatelessWidget {
  final int amount;
  final Offset from;
  final double scale;

  const _BetStack({super.key, required this.amount, required this.from, required this.scale});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final chip = 15 * s;
    final stack = (amount ~/ 50).clamp(0, 2);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Transform.translate(
        offset: from * (1 - t),
        child: Opacity(opacity: (t * 2).clamp(0.0, 1.0).toDouble(), child: child),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: chip,
              height: chip + stack * 2.5 * s,
              child: Stack(
                children: [
                  for (var i = 0; i <= stack; i++)
                    Positioned(
                      left: 0,
                      bottom: i * 2.5 * s,
                      child: Image.asset(
                        _chipAssetFor(amount),
                        width: chip,
                        height: chip,
                        errorBuilder: (c, e, st) => Icon(Icons.circle, color: Colors.redAccent, size: chip),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: 3 * s),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5 * s, vertical: 1.5 * s),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8 * s),
              ),
              child: Text(
                '$amount',
                style: TextStyle(color: Colors.white, fontSize: 9.5 * s, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// End-of-hand banner: who won, with what, and how much. Pops in over the
/// table for a couple of seconds, then gets out of the way so the showdown
/// cards (and the winner ribbon on the seat) stay visible.
/// Only one player has chips left: who won the match, then "Jugar otra vez" (host / local)
/// or leave. Nobody is reset to 1000 behind the players' backs.
class _MatchOverOverlay extends StatelessWidget {
  final String winnerName;
  final bool localWon;
  final bool canRestart;
  final double scale;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  const _MatchOverOverlay({
    required this.winnerName,
    required this.localWon,
    required this.canRestart,
    required this.scale,
    required this.onRestart,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      alignment: Alignment.center,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.7, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutBack,
        builder: (context, k, child) => Transform.scale(scale: k, child: child),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            width: 420 * s,
            padding: EdgeInsets.fromLTRB(20 * s, 16 * s, 20 * s, 16 * s),
            decoration: BoxDecoration(
              color: const Color(0xFF07160D).withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(16 * s),
              border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
              boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.3), blurRadius: 22 * s)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events, color: const Color(0xFFFFD54F), size: 44 * s),
                SizedBox(height: 6 * s),
                Text(
                  localWon ? '¡Ganaste la partida!' : '¡$winnerName gana la partida!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: const Color(0xFFFFD54F), fontSize: 20 * s, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4 * s),
                Text(
                  localWon ? 'Te quedaste con todas las fichas de la mesa.' : 'Se quedó con todas las fichas de la mesa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12 * s),
                ),
                SizedBox(height: 14 * s),
                if (!canRestart)
                  Padding(
                    padding: EdgeInsets.only(bottom: 10 * s),
                    child: Text(
                      'Esperando a que el anfitrión empiece otra partida...',
                      style: TextStyle(color: Colors.white54, fontSize: 11 * s),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: onExit,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white38),
                        padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 10 * s),
                      ),
                      child: Text('Salir', style: TextStyle(fontSize: 13 * s, fontWeight: FontWeight.bold)),
                    ),
                    if (canRestart) ...[
                      SizedBox(width: 10 * s),
                      ElevatedButton.icon(
                        onPressed: onRestart,
                        icon: Icon(Icons.replay, size: 16 * s),
                        label: Text('Jugar otra vez', style: TextStyle(fontSize: 13 * s, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 10 * s),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultsBanner extends StatefulWidget {
  final List<String> names;
  final String title;
  final int amount;
  final bool localWon;
  final double scale;

  const _ResultsBanner({
    super.key,
    required this.names,
    required this.title,
    required this.amount,
    required this.localWon,
    required this.scale,
  });

  @override
  State<_ResultsBanner> createState() => _ResultsBannerState();
}

class _ResultsBannerState extends State<_ResultsBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final tie = widget.names.length > 1;
    final headline = tie ? '¡Empate!' : (widget.localWon ? '¡Ganaste!' : '¡${widget.names.first} gana!');
    final subtitle = tie
        ? '${widget.names.join(' y ')} · ${widget.title}'
        : (widget.localWon ? 'Con ${widget.title}' : widget.title == 'por abandono' ? 'Los demás se retiraron' : 'Con ${widget.title}');
    final amount = tie ? '+${widget.amount} c/u' : '+${widget.amount}';
    final accent = widget.localWon ? const Color(0xFFFFD54F) : const Color(0xFFD4AF37);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * 2800; // ms
          final appear = Curves.easeOutBack.transform((t / 450).clamp(0.0, 1.0));
          final fade = t < 2300 ? 1.0 : (1 - (t - 2300) / 500).clamp(0.0, 1.0);
          return Opacity(
            opacity: (appear.clamp(0.0, 1.0) * fade).toDouble(),
            child: Transform.scale(scale: 0.6 + 0.4 * appear, child: child),
          );
        },
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 22 * s, vertical: 10 * s),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [const Color(0xFF1B1206).withValues(alpha: 0.95), Colors.black.withValues(alpha: 0.92)],
              ),
              borderRadius: BorderRadius.circular(16 * s),
              border: Border.all(color: accent, width: 2),
              boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 24 * s, spreadRadius: 2 * s)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events, color: accent, size: 34 * s),
                SizedBox(width: 12 * s),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline,
                        style: TextStyle(color: accent, fontSize: 18 * s, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    SizedBox(height: 2 * s),
                    Text(subtitle, style: TextStyle(color: Colors.white70, fontSize: 11 * s, fontWeight: FontWeight.w600)),
                  ],
                ),
                SizedBox(width: 16 * s),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 5 * s),
                  decoration: BoxDecoration(
                    color: Colors.green.shade800,
                    borderRadius: BorderRadius.circular(10 * s),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6)),
                  ),
                  child: Text(amount,
                      style: TextStyle(color: Colors.white, fontSize: 15 * s, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenteredStatusAlert extends StatefulWidget {
  final String message;
  const _CenteredStatusAlert({required this.message});

  @override
  State<_CenteredStatusAlert> createState() => _CenteredStatusAlertState();
}

class _CenteredStatusAlertState extends State<_CenteredStatusAlert>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = (MediaQuery.of(context).size.width / 800).clamp(0.45, 1.3);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 28 * s),
          padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 12 * s),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14 * s),
            border: Border.all(color: Colors.amber, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.3),
                blurRadius: 14 * s,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Text(
            widget.message,
            style: TextStyle(
              color: Colors.amber,
              fontSize: 15 * s,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _PotText extends StatefulWidget {
  final int pot;
  final double scale;
  const _PotText({required this.pot, this.scale = 1.0});

  @override
  State<_PotText> createState() => _PotTextState();
}

class _PotTextState extends State<_PotText>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutBack),
    );
  }

  @override
  void didUpdateWidget(covariant _PotText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pot != oldWidget.pot && oldWidget.pot > 0) {
      _pulseController.forward(from: 0).then((_) => _pulseController.reverse());
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10 * widget.scale, vertical: 2 * widget.scale),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12 * widget.scale),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 2),
          boxShadow: [
            BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              _chipAssetFor(widget.pot),
              width: 15 * widget.scale,
              height: 15 * widget.scale,
              errorBuilder: (c, e, st) => Icon(Icons.monetization_on, color: Colors.amber, size: 15 * widget.scale),
            ),
            SizedBox(width: 5 * widget.scale),
            Text(
              'BOTE',
              style: TextStyle(color: Colors.white70, fontSize: 9 * widget.scale, fontWeight: FontWeight.w600, letterSpacing: 1.5),
            ),
            SizedBox(width: 5 * widget.scale),
            Text(
              '${widget.pot}',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 13 * widget.scale,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlyingChip extends StatefulWidget {
  final Offset start;
  final Offset end;
  final VoidCallback onDone;

  const _FlyingChip({
    required this.start,
    required this.end,
    required this.onDone,
  });

  @override
  State<_FlyingChip> createState() => _FlyingChipState();
}

class _FlyingChipState extends State<_FlyingChip> {
  bool _atEnd = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _atEnd = true);
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedPositioned(
          left: _atEnd ? widget.end.dx : widget.start.dx,
          top: _atEnd ? widget.end.dy : widget.start.dy,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
          child: const BettingChipWidget(chipType: 'RedWhite', size: 32),
        ),
      ],
    );
  }
}

/// Marks a card revealed by "Espía" (only the spy sees it): purple glow + eye.
Widget _spiedCard({required bool spied, required double scale, required Widget child}) {
  if (!spied) return child;
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8 * scale),
          boxShadow: [BoxShadow(color: Colors.purpleAccent.withValues(alpha: 0.8), blurRadius: 10 * scale, spreadRadius: 1)],
        ),
        child: child,
      ),
      Positioned(
        top: -6 * scale,
        right: -4 * scale,
        child: Container(
          padding: EdgeInsets.all(2 * scale),
          decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle),
          child: Icon(Icons.visibility, size: 10 * scale, color: Colors.white),
        ),
      ),
    ],
  );
}

Widget _winningGlow({required bool isWinner, required bool isShowdown, required Widget child}) {
    if (!isShowdown) return child;
    if (isWinner) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.amber.withValues(alpha: 0.8), blurRadius: 12, spreadRadius: 2),
          ],
        ),
        child: child,
      );
    }
    return Opacity(opacity: 0.3, child: child);
  }

class _AnimatedPokerCardState extends State<_AnimatedPokerCard>
    with SingleTickerProviderStateMixin {
  static const _slideEnd = 0.42; // first part: travel face down; then flip
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
  bool _started = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (!mounted) return;
      setState(() => _started = true);
      _ctrl.forward(from: 0);
      // The flip is the moment the card "hits" the felt.
      Future.delayed(Duration(milliseconds: (_ctrl.duration!.inMilliseconds * _slideEnd).round()), () {
        if (mounted) SoundService().cardFlip();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        // Waiting for its turn: keep the slot's size but draw nothing.
        if (!_started) return Opacity(opacity: 0, child: widget.back);
        final t = _ctrl.value;
        if (t < _slideEnd) {
          final k = Curves.easeOutCubic.transform(t / _slideEnd);
          return Opacity(
            opacity: (k * 2).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -70 * widget.scale * (1 - k)),
              child: Transform.rotate(angle: -0.25 * (1 - k), child: widget.back),
            ),
          );
        }
        final f = Curves.easeInOut.transform((t - _slideEnd) / (1 - _slideEnd));
        final angle = f * math.pi;
        final showFace = angle > math.pi / 2;
        final pop = 1 + 0.08 * math.sin(angle);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(showFace ? angle - math.pi : angle)
            ..scaleByDouble(pop, pop, 1, 1),
          child: showFace ? widget.child : widget.back,
        );
      },
    );
  }
}

class _DealtCardAnimation extends StatefulWidget {
  final int dealIndex;
  final Widget child;

  const _DealtCardAnimation({
    super.key,
    required this.dealIndex,
    required this.child,
  });

  @override
  State<_DealtCardAnimation> createState() => _DealtCardAnimationState();
}

class _DealtCardAnimationState extends State<_DealtCardAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.easeIn)),
    );

    final delayMs = (widget.dealIndex * 150 + 250).clamp(0, 3000);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = (MediaQuery.of(context).size.width / 800).clamp(0.45, 1.3);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, -72 * s * _slideAnimation.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Fold: the cards are thrown a little toward the table, tilt and fade to the
/// dimmed "folded" look. Plays on every fold; no animation for a seat that was
/// already folded when it appeared.
class _FoldAnimator extends StatefulWidget {
  final bool folded;
  final Offset direction;
  final double scale;
  final Widget child;

  const _FoldAnimator({super.key, required this.folded, required this.direction, required this.scale, required this.child});

  @override
  State<_FoldAnimator> createState() => _FoldAnimatorState();
}

class _FoldAnimatorState extends State<_FoldAnimator> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: widget.folded ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _FoldAnimator old) {
    super.didUpdateWidget(old);
    if (!old.folded && widget.folded) {
      _ctrl.forward(from: 0);
    } else if (old.folded && !widget.folded) {
      _ctrl.value = 0; // new hand
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        // Out toward the table and back: the throw, then the cards settle dimmed.
        final travel = Curves.easeOut.transform((t * 2).clamp(0.0, 1.0)) - Curves.easeIn.transform(((t - 0.5) * 2).clamp(0.0, 1.0));
        final dim = Curves.easeInOut.transform(t);
        return Opacity(
          opacity: 1 - 0.6 * dim,
          child: Transform.translate(
            offset: widget.direction * 26 * widget.scale * travel,
            child: Transform.rotate(
              angle: 0.22 * travel * (widget.direction.dx >= 0 ? 1 : -1),
              child: Transform.scale(scale: 1 - 0.1 * dim, child: child),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Optional helper (Opciones > Mostrar mi probabilidad): the local player's
/// chance of winning against the players still in the hand. Uses only what the
/// player can see (own cards + revealed board). Cached until that changes.
class _OddsPill extends StatelessWidget {
  final String playerId;
  final double scale;

  const _OddsPill({required this.playerId, required this.scale});

  static String? _cacheKey;
  static double _cacheValue = 0;

  static double _equity(GameProvider game, PlayerModel me) {
    final board = game.communityCards.take(game.revealedCommunityCount).toList();
    final opponents = game.players.where((p) => p.id != me.id && !p.isFolded && !p.isBankrupt && p.hand.isNotEmpty).length;
    final key = '${game.roundCounter}|${me.hand.map((c) => '${c.value}${c.suit.index}').join()}|${board.length}|$opponents';
    if (key != _cacheKey) {
      _cacheKey = key;
      _cacheValue = opponents == 0 ? 1 : PokerBotBrain().estimateEquity(me.hand, board, opponents, iterations: 500);
    }
    return _cacheValue;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GameSettings(),
      builder: (context, _) {
        if (!GameSettings().showOdds) return const SizedBox.shrink();
        final game = context.watch<GameProvider>();
        final me = game.players.where((p) => p.id == playerId).firstOrNull;
        if (me == null || me.hand.length < 2 || me.isFolded || game.phase == PokerPhase.showdown) {
          return const SizedBox.shrink();
        }
        final pct = (_equity(game, me) * 100).round();
        final color = pct >= 50 ? Colors.greenAccent : (pct >= 25 ? Colors.amber : Colors.redAccent);
        return Tooltip(
          message: 'Probabilidad de ganar la mano',
          child: Container(
            margin: EdgeInsets.only(left: 6 * scale),
            padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 1 * scale),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8 * scale),
              border: Border.all(color: color.withValues(alpha: 0.7)),
            ),
            child: Text('$pct%', style: TextStyle(color: color, fontSize: 9.5 * scale, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}

/// Dice Dash roll: the two dice fly in from the roller, tumble with bounces while
/// their faces change, settle with a small squash and then the combination lights
/// up with its event name. Keyed by the roll counter, so it plays once per roll.
class _RollingDice extends StatefulWidget {
  final int die1;
  final int die2;
  final Offset from;
  final DiceEvent event;
  final bool animate;
  final double scale;

  const _RollingDice({
    super.key,
    required this.die1,
    required this.die2,
    required this.from,
    required this.event,
    required this.animate,
    required this.scale,
  });

  @override
  State<_RollingDice> createState() => _RollingDiceState();
}

class _RollingDiceState extends State<_RollingDice> with SingleTickerProviderStateMixin {
  static const _travel = 0.78; // share of the animation spent tumbling
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
    value: widget.animate ? 0 : 1,
  );
  final _rng = math.Random();
  late final List<int> _faces1 = List.generate(16, (_) => 1 + _rng.nextInt(6));
  late final List<int> _faces2 = List.generate(16, (_) => 1 + _rng.nextInt(6));
  bool _showLabel = false;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _ctrl.forward().then((_) {
        if (!mounted || widget.event == DiceEvent.none) return;
        setState(() => _showLabel = true);
        Future.delayed(const Duration(milliseconds: 2800), () {
          if (mounted) setState(() => _showLabel = false);
        });
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  (String, Color)? get _label => switch (widget.event) {
        DiceEvent.luckySeven => ('¡SUERTE! +30%', const Color(0xFFFFD54F)),
        DiceEvent.swap => ('¡INTERCAMBIO!', Colors.redAccent),
        DiceEvent.allIn => ('¡ALL-IN!', Colors.deepOrangeAccent),
        DiceEvent.spy => ('¡ESPÍA!', Colors.purpleAccent),
        DiceEvent.extraCard => ('¡CARTA EXTRA!', Colors.tealAccent),
        DiceEvent.none => null,
      };

  Widget _die(int value, bool red, double size) {
    final asset = red ? 'assets/images/dice/dieRed_border$value.png' : 'assets/images/dice/dieWhite_border$value.png';
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.18),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (c, e, st) => Container(
          width: size,
          height: size,
          color: red ? Colors.red : Colors.white,
          alignment: Alignment.center,
          child: Text('$value', style: TextStyle(color: red ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _tumbling(double t, {required int value, required List<int> faces, required bool red, required double delay, required double spin}) {
    final s = widget.scale;
    final size = 40 * s;
    final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
    final k = Curves.easeOutCubic.transform((local / _travel).clamp(0.0, 1.0));
    // Two bounces that shrink as the die slows down.
    final hop = (math.sin(k * math.pi * 2.5)).abs() * (1 - k) * 46 * s;
    final travel = widget.from * (1 - k);
    final rolling = local < _travel;
    final face = rolling ? faces[(local * faces.length / _travel).floor().clamp(0, faces.length - 1)] : value;
    // Landing squash after the tumble.
    final land = rolling ? 0.0 : math.sin(((local - _travel) / (1 - _travel)) * math.pi);
    final scale = rolling ? 1 + 0.22 * (1 - k) : 1 - 0.07 * land;
    return Opacity(
      opacity: (local * 4).clamp(0.0, 1.0),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Shadow on the felt: follows the die but stays on the ground.
          Transform.translate(
            offset: Offset(travel.dx, travel.dy + size * 0.55),
            child: Container(
              width: size * 0.9,
              height: size * 0.22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35 * (0.4 + 0.6 * k)),
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
          Transform.translate(
            offset: travel + Offset(0, -hop),
            child: Transform.rotate(
              angle: spin * (1 - k) * 4 * math.pi,
              child: Transform.scale(scale: scale, child: _die(face, red, size)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final label = _label;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final dice = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tumbling(t, value: widget.die1, faces: _faces1, red: true, delay: 0, spin: 1),
            SizedBox(width: 12 * s),
            _tumbling(t, value: widget.die2, faces: _faces2, red: false, delay: 0.06, spin: -1),
          ],
        );
        final lit = _showLabel && label != null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.all(4 * s),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12 * s),
                boxShadow: lit ? [BoxShadow(color: label.$2.withValues(alpha: 0.65), blurRadius: 18 * s, spreadRadius: 2 * s)] : const [],
              ),
              child: dice,
            ),
            AnimatedOpacity(
              opacity: lit ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: AnimatedScale(
                scale: lit ? 1 : 0.6,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                child: Container(
                  margin: EdgeInsets.only(top: 6 * s),
                  padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 3 * s),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12 * s),
                    border: Border.all(color: label?.$2 ?? Colors.transparent, width: 1.5),
                  ),
                  child: Text(
                    label?.$1 ?? '',
                    style: TextStyle(color: label?.$2 ?? Colors.white, fontSize: 12 * s, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChaosOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = (MediaQuery.of(context).size.width / 800).clamp(0.45, 1.3);
    return Material(
      color: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Container(
              color: Colors.red.withValues(alpha: 0.85),
              child: Center(
                child: Transform.scale(
                  scale: 0.8 + (value * 0.2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 56 * s,
                      ),
                      SizedBox(height: 14 * s),
                      Text(
                        '¡CAOS!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38 * s,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 7 * s,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 7 * s),
                      Text(
                        'Intercambio de manos activado',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16 * s,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlayerSeat extends StatelessWidget {
  final String playerId;
  final bool isLocal;
  final bool isCurrentTurn;
  final double scale;
  final double shrink;

  /// Fixed seat width for opponents so every seat around the table matches.
  final double? width;

  /// No room on the felt for this seat's bet: show it next to the chip count.
  final bool inlineBet;

  /// Direction the cards are thrown when this player folds (toward the table centre).
  final Offset foldToward;

  const _PlayerSeat({
    required this.playerId,
    required this.isLocal,
    required this.isCurrentTurn,
    this.scale = 1.0,
    this.shrink = 1.0,
    this.width,
    this.inlineBet = false,
    this.foldToward = const Offset(0, -1),
  });

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Selector<GameProvider, PlayerModel?>(
      selector: (_, game) {
        final idx = game.players.indexWhere((p) => p.id == playerId);
        return idx >= 0 ? game.players[idx] : null;
      },
      builder: (context, player, child) {
        if (player == null) {
          return const SizedBox.shrink();
        }

        // Main or side pot: each winner shows what they actually collected.
        final winAmount = context.select<GameProvider, int>((g) => g.resultTitle == null ? 0 : g.resultPayoutOf(playerId));
        final isWinner = winAmount > 0;
        final highlight = isCurrentTurn || isWinner;

        final seat = AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          constraints: BoxConstraints(minWidth: width ?? 0),
          padding: EdgeInsets.symmetric(horizontal: 5 * s, vertical: 3 * s),
          decoration: BoxDecoration(
            color: highlight
                ? Colors.amber.withValues(alpha: 0.22)
                : const Color(0xFF07160D).withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(10 * s),
            border: Border.all(
              color: highlight
                  ? (isWinner ? const Color(0xFFFFD54F) : Colors.amber)
                  : (isLocal ? const Color(0xFFD4AF37).withValues(alpha: 0.6) : Colors.white24),
              width: highlight ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: highlight ? Colors.amber.withValues(alpha: 0.35) : Colors.black54,
                blurRadius: highlight ? 10 * s : 6 * s,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fixed height so seats with and without a D/SB/BB badge line up.
              SizedBox(
                height: 18 * s,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLocal)
                      Icon(Icons.person, color: Colors.amber, size: 11 * s)
                    else if (player.isBot)
                      Icon(Icons.smart_toy, color: Colors.white54, size: 11 * s),
                    _buildRoleBadge(context, playerId, s),
                    SizedBox(width: 3 * s),
                    Flexible(
                      child: Text(
                        player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10 * s,
                        ),
                      ),
                    ),
                    if (player.isAway) ...[
                      SizedBox(width: 3 * s),
                      Icon(Icons.wifi_off, color: Colors.redAccent, size: 11 * s),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 2 * s),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/chips/chipBlackWhite.png',
                    width: 14 * s,
                    height: 14 * s,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.monetization_on,
                      color: Colors.amber,
                      size: 14 * s,
                    ),
                  ),
                  SizedBox(width: 3 * s),
                  Text(
                    '${player.chipBalance}',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 9.5 * s,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isLocal) _OddsPill(playerId: playerId, scale: s),
                  if (inlineBet)
                    Selector<GameProvider, int>(
                      selector: (_, g) => g.getPlayerBet(playerId),
                      builder: (context, bet, _) => bet <= 0
                          ? const SizedBox.shrink()
                          : Container(
                              margin: EdgeInsets.only(left: 4 * s),
                              padding: EdgeInsets.symmetric(horizontal: 4 * s, vertical: 0.5 * s),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.shade700,
                                borderRadius: BorderRadius.circular(5 * s),
                              ),
                              child: Text(
                                '$bet',
                                style: TextStyle(color: Colors.white, fontSize: 8.5 * s, fontWeight: FontWeight.bold),
                              ),
                            ),
                    ),
                ],
              ),
              SizedBox(height: 3 * s),
              if (isLocal && player.isBankrupt && Provider.of<GameProvider>(context).matchWinnerId == null)
                Padding(
                  padding: EdgeInsets.only(top: 4 * s, bottom: 4 * s),
                  child: Consumer<GameProvider>(
                    builder: (context, game, child) => Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => game.rebuyLocalPlayer(),
                        borderRadius: BorderRadius.circular(5 * s),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 4 * s),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(5 * s),
                          ),
                          child: Text(
                            'RECOMPRAR',
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 8 * s),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Consumer<GameProvider>(
                builder: (context, game, child) {
                  final idx = game.players.indexWhere((p) => p.id == playerId);
                  if (idx < 0) return const SizedBox.shrink();
                  final livePlayer = game.players[idx];
                  final faceUp = isLocal ? true : (game.phase == PokerPhase.showdown && !livePlayer.isFolded);
                  final dealerIdx = game.dealerIndex;
                  final numPlayers = game.players.isEmpty ? 1 : game.players.length;
                  final dealOrder = ((idx - dealerIdx - 1) % numPlayers + numPlayers) % numPlayers;
                  final isPreFlop = game.phase == PokerPhase.preFlop;
                  final winning = game.winningCards;
                  final isShowdown = game.phase == PokerPhase.showdown;

                  final row = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(livePlayer.hand.length, (cardIdx) {
                      final dealIndex = dealOrder + cardIdx * numPlayers;
                      final card = livePlayer.hand[cardIdx];
                      final isWinner = isShowdown && winning != null &&
                          winning.any((w) => w.value == card.value && w.suit == card.suit);
                      final cardScale = (isLocal ? 0.75 : (game.players.length > 5 ? 0.40 : 0.48)) * (isLocal ? 1.0 : shrink);
                      final discarding = game.isDiscardingCard(playerId, cardIdx);
                      final cardWidget = _winningGlow(
                        isWinner: isWinner,
                        isShowdown: isShowdown,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2 * s),
                          child: _spiedCard(
                            spied: !faceUp && game.isCardSpied(game.localPlayerId, playerId, cardIdx),
                            scale: s,
                            // 6+1: the card that goes fades and rises before it is removed.
                            child: AnimatedSlide(
                              offset: discarding ? const Offset(0, -0.35) : Offset.zero,
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeIn,
                              child: AnimatedOpacity(
                                opacity: discarding ? 0.25 : 1.0,
                                duration: const Duration(milliseconds: 600),
                                child: CardWidget(
                                  card: card,
                                  // Espía: the local player sees this one card of an opponent.
                                  isFaceUp: faceUp || game.isCardSpied(game.localPlayerId, playerId, cardIdx),
                                  scale: cardScale,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                      return isPreFlop
                          ? _DealtCardAnimation(
                              key: ValueKey('deal_${game.roundCounter}_$cardIdx'),
                              dealIndex: cardIdx >= 2 ? 0 : dealIndex,
                              child: cardWidget,
                            )
                          : cardWidget;
                    }),
                  );

                  final swapping = game.isChaosSwapping && !livePlayer.isFolded;

                  final wrappedRow = AnimatedScale(
                    scale: swapping ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: AnimatedOpacity(
                      opacity: swapping ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: row,
                    ),
                  );

                  // Same widget folded or not (switching wrappers rebuilt the cards and
                  // replayed the deal animation); every fold plays its own throw.
                  return _FoldAnimator(
                    key: ValueKey('fold_$playerId'),
                    folded: livePlayer.isFolded,
                    direction: foldToward,
                    scale: s,
                    child: wrappedRow,
                  );
                },
              ),
            ],
          ),
        );

        if (!isWinner) return seat;
        // Winner ribbon over the top edge until the next hand is dealt.
        return Stack(
          clipBehavior: Clip.none,
          children: [
            seat,
            Positioned(
              top: -9 * s,
              left: 0,
              right: 0,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  builder: (context, t, child) => Transform.scale(scale: t, child: child),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 7 * s, vertical: 1.5 * s),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFD4AF37)]),
                      borderRadius: BorderRadius.circular(8 * s),
                      boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.6), blurRadius: 8 * s)],
                    ),
                    child: Text(
                      'GANADOR +$winAmount',
                      style: TextStyle(color: Colors.black, fontSize: 8 * s, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoleBadge(BuildContext context, String playerId, double s) {
    return Consumer<GameProvider>(
      builder: (context, game, child) {
        final idx = game.players.indexWhere((p) => p.id == playerId);
        if (idx < 0) return const SizedBox.shrink();

        if (idx == game.dealerIndex && idx == game.smallBlindIndex) {
          return Container(
            width: 26 * s,
            height: 16 * s,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10 * s),
            ),
            child: Center(
              child: Text('D/SB', style: TextStyle(color: Colors.black, fontSize: 7 * s, fontWeight: FontWeight.bold)),
            ),
          );
        }
        if (idx == game.dealerIndex) {
          return Container(
            width: 16 * s,
            height: 16 * s,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('D', style: TextStyle(color: Colors.black, fontSize: 9 * s, fontWeight: FontWeight.bold)),
            ),
          );
        }
        if (idx == game.smallBlindIndex) {
          return Container(
            width: 16 * s,
            height: 16 * s,
            decoration: const BoxDecoration(
              color: Colors.lightBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('SB', style: TextStyle(color: Colors.white, fontSize: 7 * s, fontWeight: FontWeight.bold)),
            ),
          );
        }
        if (idx == game.bigBlindIndex) {
          return Container(
            width: 16 * s,
            height: 16 * s,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('BB', style: TextStyle(color: Colors.white, fontSize: 7 * s, fontWeight: FontWeight.bold)),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}


/// Shown while the client is trying to get back into the room.
