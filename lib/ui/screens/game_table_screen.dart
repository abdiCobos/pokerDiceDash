import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/card_model.dart';
import '../../models/game_state.dart';
import '../../models/player_model.dart';
import '../../providers/game_provider.dart';
import '../widgets/card_widget.dart';
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
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  final GlobalKey _localSeatKey = GlobalKey();
  final GlobalKey _potTextKey = GlobalKey();

  int _lastRollCounter = 0;
  bool _lastMustSwap = false;
  double _dieScale = 1.0;
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

  StreamSubscription<String>? _hostConnectionSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    _screenW = size.width;
    _screenH = size.height;
    _s = (_screenW / 800).clamp(0.45, 1.3);
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

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
    _hostConnectionSub?.cancel();
    _burnController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.reset();
    _shakeController.forward();
  }

  void _triggerBounce() {
    setState(() => _dieScale = 1.4);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _dieScale = 1.0);
    });
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
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LobbyScreen()),
          );
        }
      },
      child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [
              Color(0xFF0A4D28),
              Color(0xFF052915),
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<GameProvider>(
            builder: (context, game, child) {
              final diceChanged = game.rollCounter != _lastRollCounter;
              final mustSwapChanged = game.state.mustSwapHands && !_lastMustSwap;

              if (diceChanged) {
                _lastRollCounter = game.rollCounter;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _triggerShake();
                  _triggerBounce();
                });
              }

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
                _potFlyingAmount = game.pot;
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
                  _s = (w / 800).clamp(0.45, 1.3);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildHeader(game),
                      ..._buildPlayerSeats(players, game),
                      _buildCenterArea(game),
                      _buildControls(game),
                      if (game.state.status == GameStatus.betting)
                        _buildActionPanel(game),
                      if (_lastBurned != null)
                        _buildBurnedCardAnimation(),
                      if (game.centralMessage != null)
                        _CenteredStatusAlert(message: game.centralMessage!),
                      if (_showPotFlying && game.winnerId != null)
                        _buildPotFlyingAnimation(game),
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
          _PotText(key: _potTextKey, pot: game.pot, scale: _s),
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

  Widget _buildCenterArea(GameProvider game) {
    return Stack(
      children: [
        Positioned(
          top: _screenH * 0.35,
          left: 0,
          right: 0,
          child: Center(child: _buildCommunityCards(game)),
        ),
        Positioned(
          bottom: _screenH * 0.28,
          left: _screenW * 0.25,
          child: _buildDiceArea(game),
        ),
      ],
    );
  }

  List<Widget> _buildPlayerSeats(List<PlayerModel> players, GameProvider game) {
    final widgets = <Widget>[];
    final localId = game.localPlayerId;
    final localIdx = players.indexWhere((p) => p.id == localId);
    final opponents = players.where((p) => p.id != localId).toList();

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
        bottom: 0,
        left: 0,
        right: 0,
        child: Align(alignment: Alignment.bottomCenter, child: seat),
      ));
    }

    for (var i = 0; i < opponents.length && i < 3; i++) {
      final oppIdx = players.indexWhere((p) => p.id == opponents[i].id);
      final seat = _PlayerSeat(
        playerId: opponents[i].id,
        isLocal: false,
        isCurrentTurn: game.state.currentPlayerIndex == oppIdx,
        scale: _s,
      );

      if (i == 0) {
        widgets.add(Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Align(alignment: Alignment.topCenter, child: seat),
        ));
      } else if (i == 1) {
        widgets.add(Positioned(
          left: _screenW * 0.02,
          top: 0,
          bottom: 0,
          child: Align(alignment: Alignment.centerLeft, child: seat),
        ));
      } else if (i == 2) {
        widgets.add(Positioned(
          right: _screenW * 0.02,
          top: 0,
          bottom: 0,
          child: Align(alignment: Alignment.centerRight, child: seat),
        ));
      }
    }

    return widgets;
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
          children: List.generate(revealed, (i) {
            final card = i < cards.length
                ? cards[i]
                : CardModel(value: 'A', suit: Suit.spades);
            final isNew = i >= newCardsStart;
            final flopPosition = i >= newCardsStart ? i - newCardsStart : 0;
            final delayMs = isNew ? flopPosition * 400 : 0;

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

            if (isNew) {
              return _AnimatedPokerCard(
                key: ValueKey('slot_${i}_round_${game.roundCounter}'),
                delayMs: delayMs,
                child: cardWidget,
              );
            }
            return cardWidget;
          }),
        ),
        SizedBox(height: 3 * _s),
      ],
    );
  }

  Widget _buildDiceArea(GameProvider game) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final shake = _shakeAnimation.value;
        final offset = shake > 0 && shake < 1
            ? Offset(
                (shake * 9 * _s) * (shake < 0.5 ? 1 : -1),
                (shake * 5 * _s) * (shake < 0.33 ? 1 : shake < 0.66 ? -1 : 1),
              )
            : Offset.zero;

        return Transform.translate(
          offset: offset,
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDie(game.die1, isRed: true),
          SizedBox(width: 12 * _s),
          _buildDie(game.die2, isRed: false),
        ],
      ),
    );
  }

  Widget _buildDie(int value, {required bool isRed}) {
    final dieSize = 40 * _s;
    final assetName = isRed
        ? 'assets/images/dice/dieRed_border$value.png'
        : 'assets/images/dice/dieWhite_border$value.png';

    return AnimatedScale(
      scale: _dieScale,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: Container(
        width: dieSize,
        height: dieSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(dieSize * 0.18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(dieSize * 0.18),
          child: Image.asset(
            assetName,
            width: dieSize,
            height: dieSize,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: isRed ? Colors.red : Colors.white,
                child: Center(
                  child: Text(
                    '$value',
                    style: TextStyle(
                      color: isRed ? Colors.white : Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildControls(GameProvider game) {
    final activeIdx = game.state.currentPlayerIndex;
    final blocked = game.isBetting || game.isChaosSwapping || game.centralMessage != null;
    final isMyTurn = activeIdx >= 0 && activeIdx < game.players.length &&
        game.players[activeIdx].id == game.localPlayerId;
    final canRoll = game.state.status == GameStatus.diceTurn && (isMyTurn || !widget.isMultiplayer) && !blocked;

    final canStart = widget.isMultiplayer && widget.isHost &&
        game.players.length >= 2 && game.state.phase == PokerPhase.preFlop &&
        game.state.communityCards.isEmpty && game.state.status == GameStatus.waitingPlayers;

    return Stack(
      clipBehavior: Clip.none,
      children: [
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
    final blocked = game.isBetting || game.isChaosSwapping || game.centralMessage != null;
    if (!isMyTurn && widget.isMultiplayer) return const SizedBox.shrink();

    final currentBet = game.currentBet;
    final playerBet = game.getPlayerBet(activePlayer.id);
    final amountToCall = currentBet - playerBet;
    debugPrint('Apuesta de ${activePlayer.id}: $playerBet');
    final isAllInCall = amountToCall >= activePlayer.chipBalance;

    String callLabel;
    if (currentBet == 0) {
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
            children: isAllIn
                ? [
                    Text('ALL-IN - Solo lanza dados',
                        style: TextStyle(color: Colors.orange, fontSize: 11 * _s, fontWeight: FontWeight.bold)),
                  ]
                : [
              _ActionButton(
                label: 'FOLD',
                color: Colors.red,
                enabled: !blocked,
                onTap: !blocked ? () => game.fold(activePlayer.id) : null,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                label: callLabel,
                color: Colors.blue,
                enabled: !blocked,
                onTap: !blocked ? () => game.call(activePlayer.id) : null,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                label: 'RAISE',
                color: Colors.orange,
                enabled: !blocked && !isAllInCall,
                onTap: !blocked && !isAllInCall ? () => _showRaiseDialog(context, game, activePlayer.id) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPotFlyingAnimation(GameProvider game) {
    final winnerIdx = game.players.indexWhere((p) => p.id == game.winnerId);
    if (winnerIdx < 0) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
      builder: (context, t, child) {
        final width = MediaQuery.of(context).size.width;
        final height = MediaQuery.of(context).size.height;

        final startX = 60 * _s;
        final startY = 40 * _s;

        double endX = startX;
        double endY = startY;
        switch (winnerIdx) {
          case 0:
            endX = width / 2;
            endY = height - 120 * _s;
            break;
          case 1:
            endX = width / 2;
            endY = 80 * _s;
            break;
          case 2:
            endX = 60 * _s;
            endY = height / 2;
            break;
          case 3:
            endX = width - 60 * _s;
            endY = height / 2;
            break;
        }

        final x = startX + (endX - startX) * t;
        final y = startY + (endY - startY) * t;

        return Positioned(
          left: x,
          top: y,
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

class _AnimatedPokerCard extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const _AnimatedPokerCard({super.key, required this.child, this.delayMs = 0});

  @override
  State<_AnimatedPokerCard> createState() => _AnimatedPokerCardState();
}

void _showRaiseDialog(BuildContext context, GameProvider game, String playerId) {
  final playerIdx = game.players.indexWhere((p) => p.id == playerId);
  if (playerIdx < 0) return;
  final maxBalance = game.players[playerIdx].chipBalance;
  final amountToCall = game.currentBet - game.getPlayerBet(playerId);
  final s = (MediaQuery.of(context).size.width / 800).clamp(0.55, 1.3);
  final btnSize = (40 * s).clamp(32.0, 60.0);
  final btnFont = (10 * s).clamp(8.0, 13.0);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      int raiseAmount = 0;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14 * s),
              side: BorderSide(color: Colors.amber, width: 2),
            ),
            title: Text(
              'Subir Apuesta',
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16 * s),
              textAlign: TextAlign.center,
            ),
            content: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (amountToCall > 0)
                  Padding(
                    padding: EdgeInsets.only(bottom: 4 * s),
                    child: Text(
                      'Para Igualar: ${max(0, amountToCall)}',
                      style: TextStyle(color: Colors.blue, fontSize: 13 * s),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Text(
                  'Aumento: +$raiseAmount',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 26 * s,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4 * s),
                Text(
                  'Total: ${max(0, amountToCall + raiseAmount)}',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 15 * s,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 14 * s),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [10, 50, 100].map((amount) {
                    final canAdd = amountToCall + raiseAmount + amount <= maxBalance;
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4 * s),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: canAdd
                              ? () => setState(() => raiseAmount += amount)
                              : null,
                          borderRadius: BorderRadius.circular(btnSize * 0.4),
                          child: Container(
                            width: btnSize,
                            height: btnSize,
                            decoration: BoxDecoration(
                              color: canAdd ? Colors.amber : Colors.grey.shade700,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: canAdd ? Colors.amber.shade700 : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text('+$amount',
                                style: TextStyle(
                                  color: canAdd ? Colors.black : Colors.white54,
                                  fontSize: btnFont,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 8 * s),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      final allInRaise = maxBalance - amountToCall;
                      debugPrint('ALL IN tap: maxBalance=$maxBalance amountToCall=$amountToCall allInRaise=$allInRaise');
                      if (allInRaise > 0) {
                        setState(() => raiseAmount = allInRaise);
                      }
                    },
                    borderRadius: BorderRadius.circular(7 * s),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 7 * s),
                      decoration: BoxDecoration(
                        color: Colors.red.shade800,
                        borderRadius: BorderRadius.circular(7 * s),
                        border: Border.all(color: Colors.red, width: 1.5),
                      ),
                      child: Text('ALL IN',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12 * s),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16 * s),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text('Cancelar', style: TextStyle(color: Colors.white54, fontSize: 13 * s)),
                    ),
                    TextButton(
                      onPressed: raiseAmount > 0 && amountToCall + raiseAmount <= maxBalance
                          ? () {
                              Navigator.pop(dialogContext);
                              game.raise(playerId, raiseAmount);
                            }
                          : null,
                      child: Text('Confirmar',
                        style: TextStyle(
                          color: raiseAmount > 0 ? Colors.amber : Colors.white24,
                          fontWeight: FontWeight.bold,
                          fontSize: 13 * s,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
          padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 5 * s),
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
              fontSize: 10 * s,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _BetChipAnimation extends StatefulWidget {
  @override
  State<_BetChipAnimation> createState() => _BetChipAnimationState();
}

class _BetChipAnimationState extends State<_BetChipAnimation> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final s = (MediaQuery.of(context).size.width / 800).clamp(0.45, 1.3);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Positioned(
          left: 20 * s,
          bottom: t * 160 * s,
          child: Opacity(
            opacity: (1 - (t > 0.7 ? (t - 0.7) / 0.3 : 0)).clamp(0.0, 1.0).toDouble(),
            child: Image.asset(
              'assets/images/chips/chipRedWhite.png',
              width: 30 * s,
              height: 30 * s,
              errorBuilder: (context, error, stackTrace) => Icon(Icons.monetization_on, color: Colors.amber, size: 24 * s),
            ),
          ),
        );
      },
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
  const _PotText({super.key, required this.pot, this.scale = 1.0});

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
        padding: EdgeInsets.symmetric(horizontal: 14 * widget.scale, vertical: 6 * widget.scale),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12 * widget.scale),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 2),
          boxShadow: [
            BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on, color: Colors.amber, size: 22 * widget.scale),
            SizedBox(width: 6 * widget.scale),
            Text(
              '${widget.pot}',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 22 * widget.scale,
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
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _triggerAnimation();
  }

  @override
  void didUpdateWidget(covariant _AnimatedPokerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.key != widget.key) {
      _triggerAnimation();
    }
  }

  void _triggerAnimation() {
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward(from: 0.0);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
        child: widget.child,
      ),
    );
  }
}

class _DealtCardAnimation extends StatefulWidget {
  final int dealIndex;
  final Widget child;

  const _DealtCardAnimation({
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

    Future.delayed(Duration(milliseconds: widget.dealIndex * 200 + 300), () {
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

  const _PlayerSeat({
    required this.playerId,
    required this.isLocal,
    required this.isCurrentTurn,
    this.scale = 1.0,
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

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 5 * s, vertical: 3 * s),
          decoration: BoxDecoration(
            color: isCurrentTurn
                ? Colors.amber.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10 * s),
            border: Border.all(
              color: isCurrentTurn ? Colors.amber : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLocal)
                    Icon(Icons.person, color: Colors.amber, size: 11 * s),
                  _buildRoleBadge(context, playerId, s),
                  SizedBox(width: 3 * s),
                  Text(
                    player.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10 * s,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 3 * s),
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
                      fontSize: 9 * s,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4 * s),
              if (isLocal && player.isBankrupt)
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
                  final dealOrder = ((idx - dealerIdx - 1) % 4 + 4) % 4;
                  final isPreFlop = game.phase == PokerPhase.preFlop;
                  final winning = game.winningCards;
                  final isShowdown = game.phase == PokerPhase.showdown;

                  final row = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(livePlayer.hand.length, (cardIdx) {
                      final dealIndex = dealOrder + cardIdx * 4;
                      final card = livePlayer.hand[cardIdx];
                      final isWinner = isShowdown && winning != null &&
                          winning.any((w) => w.value == card.value && w.suit == card.suit);
                      final cardScale = isLocal ? 0.75 : 0.48;
                      final cardWidget = _winningGlow(
                        isWinner: isWinner,
                        isShowdown: isShowdown,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2 * s),
                          child: CardWidget(card: card, isFaceUp: faceUp, scale: cardScale),
                        ),
                      );
                      return isPreFlop
                          ? _DealtCardAnimation(dealIndex: dealIndex, child: cardWidget)
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

                  final result = Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (livePlayer.isFolded)
                        Opacity(opacity: 0.4, child: wrappedRow)
                      else
                        wrappedRow,
                      if (game.animatingBetPlayerId == playerId)
                        _BetChipAnimation(),
                    ],
                  );

                  return result;
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleBadge(BuildContext context, String playerId, double s) {
    return Consumer<GameProvider>(
      builder: (context, game, child) {
        final idx = game.players.indexWhere((p) => p.id == playerId);
        if (idx < 0) return const SizedBox.shrink();

        if (idx == game.dealerIndex) {
          return Container(
            width: 20 * s,
            height: 20 * s,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('D', style: TextStyle(color: Colors.black, fontSize: 10 * s, fontWeight: FontWeight.bold)),
            ),
          );
        }
        if (idx == game.smallBlindIndex) {
          return Container(
            width: 20 * s,
            height: 20 * s,
            decoration: const BoxDecoration(
              color: Colors.lightBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('SB', style: TextStyle(color: Colors.white, fontSize: 8 * s, fontWeight: FontWeight.bold)),
            ),
          );
        }
        if (idx == game.bigBlindIndex) {
          return Container(
            width: 20 * s,
            height: 20 * s,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('BB', style: TextStyle(color: Colors.white, fontSize: 8 * s, fontWeight: FontWeight.bold)),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
