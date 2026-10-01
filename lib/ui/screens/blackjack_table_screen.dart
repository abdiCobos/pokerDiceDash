import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/blackjack_models.dart';
import '../../models/card_model.dart';
import '../../providers/blackjack_provider.dart';
import '../../services/p2p_service.dart';
import '../widgets/card_widget.dart';
import '../widgets/player_seat_card.dart';
import 'lobby_screen.dart';

class BlackjackTableScreen extends StatefulWidget {
  final bool isMultiplayer;
  final bool isHost;
  const BlackjackTableScreen({super.key, this.isMultiplayer = false, this.isHost = true});

  @override
  State<BlackjackTableScreen> createState() => _BlackjackTableScreenState();
}

class _BlackjackTableScreenState extends State<BlackjackTableScreen> with TickerProviderStateMixin {
  late double _s;
  late double _screenH;
  final Map<String, AnimationController> _cardAnims = {};
  double _betSliderValue = 50;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    _screenH = size.height;
    // Base scale using height since landscape height is the constraining dimension
    _s = (_screenH / 390).clamp(0.72, 1.25);
  }

  AnimationController _animFor(String key) {
    if (!_cardAnims.containsKey(key)) {
      final ctrl = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
      ctrl.forward();
      _cardAnims[key] = ctrl;
    }
    return _cardAnims[key]!;
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    for (final c in _cardAnims.values) {
      c.dispose();
    }
    _cardAnims.clear();
    super.dispose();
  }

  Future<void> _confirmExit() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('¿Abandonar partida?', style: TextStyle(color: Colors.amber)),
        content: const Text('¿Estás seguro que quieres salir de la mesa?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if ((shouldPop ?? false) && mounted) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      for (final c in _cardAnims.values) {
        c.dispose();
      }
      _cardAnims.clear();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LobbyScreen()));
    }
  }

  void _onNewRound(BlackjackProvider bj) {
    for (final c in _cardAnims.values) {
      c.dispose();
    }
    _cardAnims.clear();
    bj.newRound();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF052915),
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -0.3),
              radius: 1.15,
              colors: [Color(0xFF0F6838), Color(0xFF0A4D28), Color(0xFF052312)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: SafeArea(
            child: Consumer<BlackjackProvider>(
              builder: (context, bj, child) {
                if (bj.players.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amber));
                }
                return _buildLandscapeTable(bj);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeTable(BlackjackProvider bj) {
    final isWaiting = bj.phase == BlackjackPhase.waiting;
    if (isWaiting) {
      return Column(
        children: [
          _buildHeader(bj),
          Expanded(child: _buildWaitingRoom(bj)),
        ],
      );
    }

    final dealer = bj.dealer;
    final activePlayers = bj.activePlayers; // all players (local + bots)
    final localPlayer = bj.localPlayer;
    final isBetting = bj.phase == BlackjackPhase.betting;
    final isPlayerTurn = bj.phase == BlackjackPhase.playerTurn;
    final isRoundEnd = bj.phase == BlackjackPhase.roundEnd;

    final localTurn = isPlayerTurn && _isCurrentPlayer(localPlayer, bj);
    final localNeedsBet = isBetting && localPlayer.totalBet == 0;

    return Column(
      children: [
        // 1. Top bar: Back button, deck count, table title, chip balance
        _buildHeader(bj),

        // 2. Main Felt Area: Dealer at top, subtle table rules watermark, all player seats
        Expanded(
          child: Stack(
            children: [
              // Subtle casino felt watermark text
              Positioned(
                top: 48 * _s,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'BLACKJACK PAGA 3 A 2  •  CRUPIER SE PLANTA EN 17  •  5-CARD CHARLIE',
                    style: TextStyle(
                      color: Colors.amber.withValues(alpha: 0.18),
                      fontSize: 9.5 * _s,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              ),

              // Dealer section at top-center
              if (dealer != null)
                Positioned(
                  top: 2 * _s,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildDealerSection(dealer, bj)),
                ),

              // Player Seats arranged across the felt (ALL on screen, NO scroll carousel!)
              Positioned(
                bottom: 4 * _s,
                left: 8 * _s,
                right: 8 * _s,
                child: _buildPlayerSeatsRow(activePlayers, bj),
              ),
            ],
          ),
        ),

        // 3. Bottom Control Dock
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12 * _s, vertical: 4 * _s),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            border: Border(top: BorderSide(color: Colors.amber.withValues(alpha: 0.25))),
          ),
          child: _buildBottomControls(bj, localPlayer, localNeedsBet, localTurn, isRoundEnd),
        ),
      ],
    );
  }

  // ─── 1. HEADER BAR ───────────────────────────────────────

  Widget _buildHeader(BlackjackProvider bj) {
    final local = bj.localPlayer;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * _s, vertical: 3 * _s),
      color: Colors.black.withValues(alpha: 0.40),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: _confirmExit,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8 * _s, vertical: 4 * _s),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(6 * _s),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, color: Colors.white70, size: 16 * _s),
                  SizedBox(width: 4 * _s),
                  Text('Salir', style: TextStyle(color: Colors.white70, fontSize: 11 * _s)),
                ],
              ),
            ),
          ),
          SizedBox(width: 12 * _s),
          // Deck count
          Icon(Icons.style, color: Colors.amber.withValues(alpha: 0.7), size: 16 * _s),
          SizedBox(width: 4 * _s),
          Text(
            'Mazo: ${bj.state.deck.length}',
            style: TextStyle(color: Colors.white70, fontSize: 11 * _s, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          // Table Title Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12 * _s, vertical: 3 * _s),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12 * _s),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('♠ ', style: TextStyle(color: Colors.amber, fontSize: 11 * _s)),
                Text(
                  'BLACKJACK',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 11 * _s,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                Text(' ♠', style: TextStyle(color: Colors.amber, fontSize: 11 * _s)),
              ],
            ),
          ),
          const Spacer(),
          // Bankroll indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8 * _s, vertical: 3 * _s),
              decoration: BoxDecoration(
                color: Colors.green.shade900.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8 * _s),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monetization_on, color: Colors.greenAccent, size: 14 * _s),
                  SizedBox(width: 4 * _s),
                  Text(
                    '\$${local.chipBalance}',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 12 * _s, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── 2. DEALER SECTION ───────────────────────────────────

  Widget _buildDealerSection(BlackjackPlayer dealer, BlackjackProvider bj) {
    final showAll = bj.phase == BlackjackPhase.dealerTurn || bj.phase == BlackjackPhase.roundEnd;
    final hand = dealer.hands.isEmpty ? BlackjackHand() : dealer.hands[0];
    final isCurrentTurn = bj.phase == BlackjackPhase.dealerTurn;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14 * _s, vertical: 4 * _s),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12 * _s),
        border: Border.all(
          color: isCurrentTurn ? Colors.amber : Colors.redAccent.withValues(alpha: 0.4),
          width: isCurrentTurn ? 2.0 : 1.0,
        ),
        boxShadow: isCurrentTurn
            ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 1)]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dealer label row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_pin, color: Colors.redAccent, size: 15 * _s),
              SizedBox(width: 4 * _s),
              Text(
                'CRUPIER',
                style: TextStyle(
                  color: Colors.redAccent.shade100,
                  fontSize: 11 * _s,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              if (hand.cards.isNotEmpty) ...[
                SizedBox(width: 8 * _s),
                if (showAll)
                  _handValueBadge(hand.handValue, hand.isBusted, hand.isBlackjack)
                else
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6 * _s, vertical: 2 * _s),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(6 * _s),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      '${_singleCardValue(hand)} + ?',
                      style: TextStyle(color: Colors.white70, fontSize: 10 * _s, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ],
          ),
          SizedBox(height: 3 * _s),
          // Dealer cards
          if (hand.cards.isNotEmpty)
            _buildCardRow(
              cards: hand.cards,
              playerId: dealer.id,
              handIdx: 0,
              showFace: true,
              hideSecondCard: !showAll,
              cardScale: 0.65,
              overlapStep: 22.0,
            ),
        ],
      ),
    );
  }

  // ─── 3. ALL PLAYER SEATS ROW (NO CAROUSEL) ──────────────

  Widget _buildPlayerSeatsRow(List<BlackjackPlayer> players, BlackjackProvider bj) {
    if (players.isEmpty) return const SizedBox.shrink();

    final count = players.length;
    // Responsive card scale based on seat count
    final cardScale = (count >= 5 ? 0.56 : (count >= 4 ? 0.62 : 0.68)) * _s;
    final cardOverlap = (count >= 5 ? 16.0 : (count >= 4 ? 18.0 : 22.0)) * _s;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: players.map((p) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: count > 4 ? 2.0 * _s : 4.0 * _s),
            child: _buildSeatCard(
              player: p,
              bj: bj,
              cardScale: cardScale,
              cardOverlap: cardOverlap,
              isCompact: count >= 5,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSeatCard({
    required BlackjackPlayer player,
    required BlackjackProvider bj,
    required double cardScale,
    required double cardOverlap,
    required bool isCompact,
  }) {
    final isCurrent = _isCurrentPlayer(player, bj);
    final status = _getPlayerStatus(player, bj);
    final isLocal = player.isLocal;
    final showCards = bj.phase != BlackjackPhase.betting && bj.phase != BlackjackPhase.waiting;

    Color borderColor;
    Color bgColor;
    if (isCurrent) {
      borderColor = Colors.amber;
      bgColor = Colors.amber.withValues(alpha: 0.16);
    } else if (status == PlayerSeatStatus.busted) {
      borderColor = Colors.redAccent.withValues(alpha: 0.5);
      bgColor = Colors.red.withValues(alpha: 0.15);
    } else if (status == PlayerSeatStatus.winner || status == PlayerSeatStatus.blackjack || status == PlayerSeatStatus.charlie) {
      borderColor = const Color(0xFFD4AF37);
      bgColor = const Color(0xFFD4AF37).withValues(alpha: 0.18);
    } else if (isLocal) {
      borderColor = const Color(0xFFD4AF37).withValues(alpha: 0.6);
      bgColor = Colors.black.withValues(alpha: 0.42);
    } else {
      borderColor = Colors.white24;
      bgColor = Colors.black.withValues(alpha: 0.35);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.all(isCompact ? 4.0 * _s : 6.0 * _s),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10 * _s),
        border: Border.all(
          color: borderColor,
          width: isCurrent ? 2.2 : (isLocal ? 1.5 : 1.0),
        ),
        boxShadow: isCurrent
            ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 1.5)]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player header: Icon, Name, Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (player.isBot)
                Text('🤖', style: TextStyle(fontSize: 10 * _s))
              else if (isLocal)
                Text('★ ', style: TextStyle(color: Colors.amber, fontSize: 11 * _s, fontWeight: FontWeight.bold)),
              Flexible(
                child: Text(
                  player.name,
                  style: TextStyle(
                    color: isLocal ? const Color(0xFFD4AF37) : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: (isCompact ? 10.5 : 12.0) * _s,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCurrent) ...[
                SizedBox(width: 3 * _s),
                Container(
                  width: 6 * _s,
                  height: 6 * _s,
                  decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
          SizedBox(height: 2 * _s),

          // Chips & Bet row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '\$${player.chipBalance}',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: (isCompact ? 9.5 : 10.5) * _s,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (player.totalBet > 0) ...[
                SizedBox(width: 4 * _s),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4 * _s, vertical: 1 * _s),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade900,
                    borderRadius: BorderRadius.circular(4 * _s),
                  ),
                  child: Text(
                    '\$${player.totalBet}',
                    style: TextStyle(color: Colors.white, fontSize: 9 * _s, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 4 * _s),

          // Cards Area
          if (showCards && player.hands.isNotEmpty) ...[
            ...player.hands.asMap().entries.map((e) {
              final hIdx = e.key;
              final hand = e.value;
              final isActiveHand = hIdx == player.activeHandIndex && isCurrent;

              return Container(
                margin: EdgeInsets.only(bottom: 2 * _s),
                padding: player.hands.length > 1 ? EdgeInsets.all(2 * _s) : EdgeInsets.zero,
                decoration: isActiveHand
                    ? BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6 * _s),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      )
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (player.hands.length > 1)
                      Text(
                        isActiveHand ? '▶ M${hIdx + 1}' : 'M${hIdx + 1}',
                        style: TextStyle(
                          color: isActiveHand ? Colors.amber : Colors.white54,
                          fontSize: 9 * _s,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    _buildCardRow(
                      cards: hand.cards,
                      playerId: player.id,
                      handIdx: hIdx,
                      showFace: true,
                      cardScale: cardScale,
                      overlapStep: cardOverlap,
                    ),
                    SizedBox(height: 2 * _s),
                    if (hand.cards.isNotEmpty)
                      _handValueBadge(hand.handValue, hand.isBusted, hand.isBlackjack, charlie: hand.isCharlie),
                  ],
                ),
              );
            }),
          ] else ...[
            // Empty placeholder during betting phase
            Container(
              height: 65 * cardScale,
              alignment: Alignment.center,
              child: Text(
                player.totalBet > 0 ? 'Listo' : 'Apostando...',
                style: TextStyle(color: Colors.white30, fontSize: 10 * _s),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 4. CARD ROW WITH DEAL ANIMATION ─────────────────────

  Widget _buildCardRow({
    required List<CardModel> cards,
    required String playerId,
    required int handIdx,
    required bool showFace,
    bool hideSecondCard = false,
    double cardScale = 0.65,
    double overlapStep = 20.0,
  }) {
    if (cards.isEmpty) return const SizedBox.shrink();

    final cardW = CardWidget.cardWidth * cardScale;
    final cardH = CardWidget.cardHeight * cardScale;
    final totalW = cardW + (cards.length - 1) * overlapStep;

    return SizedBox(
      height: cardH,
      width: totalW,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: cards.asMap().entries.map((e) {
          final idx = e.key;
          final faceUp = showFace && !(hideSecondCard && idx == 1);
          return Positioned(
            left: idx * overlapStep,
            child: _AnimatedSlideIn(
              controller: _animFor('$playerId-${handIdx}_$idx'),
              card: e.value,
              scale: cardScale,
              faceUp: faceUp,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── 5. BOTTOM CONTROLS DOCK ─────────────────────────────

  Widget _buildBottomControls(
    BlackjackProvider bj,
    BlackjackPlayer? localPlayer,
    bool localNeedsBet,
    bool localTurn,
    bool isRoundEnd,
  ) {
    if (isRoundEnd) {
      return _buildRoundEndControls(bj);
    }

    if (localNeedsBet && localPlayer != null) {
      return _buildHorizontalBettingDock(localPlayer, bj);
    }

    if (localTurn && localPlayer != null) {
      return _buildHorizontalActionButtons(localPlayer, bj);
    }

    // Status message when waiting for others / dealer
    String statusText = 'Partida en curso...';
    if (bj.phase == BlackjackPhase.dealing) {
      statusText = 'Repartiendo cartas...';
    } else if (bj.phase == BlackjackPhase.dealerTurn) {
      statusText = '🎩 Turno del Crupier... jugando mano';
    } else if (bj.phase == BlackjackPhase.playerTurn) {
      final active = bj.activePlayers;
      if (active.isNotEmpty && bj.currentPlayerIndex < active.length) {
        final current = active[bj.currentPlayerIndex];
        statusText = '🤖 Turno de ${current.name}... pensando jugada';
      }
    } else if (bj.phase == BlackjackPhase.betting) {
      statusText = 'Esperando apuestas de los jugadores...';
    }

    return Container(
      height: 44 * _s,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14 * _s,
            height: 14 * _s,
            child: const CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
          ),
          SizedBox(width: 10 * _s),
          Text(
            statusText,
            style: TextStyle(color: Colors.amber.shade200, fontSize: 13 * _s, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ─── 6. HORIZONTAL BETTING DOCK ──────────────────────────

  Widget _buildHorizontalBettingDock(BlackjackPlayer player, BlackjackProvider bj) {
    final maxBet = player.chipBalance.toDouble();
    if (maxBet <= 0) return const SizedBox.shrink();
    _betSliderValue = _betSliderValue.clamp(10, maxBet);

    return Row(
      children: [
        // Quick Bet Chips
        Wrap(
          spacing: 6 * _s,
          children: [25, 50, 100, 200, 500].where((v) => v <= maxBet).map((amt) {
            final isSelected = _betSliderValue.round() == amt;
            return GestureDetector(
              onTap: () => setState(() => _betSliderValue = amt.toDouble()),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10 * _s, vertical: 6 * _s),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.amber.shade700 : Colors.black45,
                  borderRadius: BorderRadius.circular(14 * _s),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.amber.withValues(alpha: 0.4),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Text(
                  '\$$amt',
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: 11 * _s,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        SizedBox(width: 12 * _s),

        // Slider & Bet Amount
        Expanded(
          child: Row(
            children: [
              Text(
                'APUESTA:',
                style: TextStyle(color: Colors.amber, fontSize: 11 * _s, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 6 * _s),
              Text(
                '\$${_betSliderValue.round()}',
                style: TextStyle(color: Colors.white, fontSize: 16 * _s, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.amber,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.amber,
                    overlayColor: Colors.amber.withValues(alpha: 0.2),
                    trackHeight: 3 * _s,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7 * _s),
                  ),
                  child: Slider(
                    min: 10,
                    max: maxBet,
                    divisions: ((maxBet - 10) / 10).round().clamp(1, 100),
                    value: _betSliderValue,
                    onChanged: (v) => setState(() => _betSliderValue = (v / 10).round() * 10.0),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(width: 10 * _s),

        // APOSTAR button
        ElevatedButton(
          onPressed: () => bj.placeBet(player.id, _betSliderValue.round()),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade600,
            foregroundColor: Colors.black,
            padding: EdgeInsets.symmetric(horizontal: 24 * _s, vertical: 10 * _s),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10 * _s)),
            elevation: 4,
          ),
          child: Text(
            'APOSTAR',
            style: TextStyle(fontSize: 13 * _s, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
        ),
      ],
    );
  }

  // ─── 7. HORIZONTAL ACTION BUTTONS (PEDIR, PLANTAR, DOBLAR, DIVIDIR) ──

  Widget _buildHorizontalActionButtons(BlackjackPlayer player, BlackjackProvider bj) {
    final hand = player.currentHand;
    final canDouble = hand.cards.length == 2 && !hand.isDoubledDown && player.chipBalance >= hand.betAmount;
    final canSplit = player.canSplit && player.chipBalance >= hand.betAmount;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pedir (Hit)
        _actionButton(
          label: 'PEDIR',
          icon: Icons.add_card,
          color: Colors.green.shade700,
          onTap: () => bj.hit(player.id),
        ),
        SizedBox(width: 10 * _s),

        // Plantar (Stand)
        _actionButton(
          label: 'PLANTAR',
          icon: Icons.pan_tool,
          color: Colors.red.shade700,
          onTap: () => bj.stand(player.id),
        ),

        // Doblar (Double Down)
        if (canDouble) ...[
          SizedBox(width: 10 * _s),
          _actionButton(
            label: 'DOBLAR',
            icon: Icons.double_arrow,
            color: Colors.orange.shade700,
            onTap: () => bj.doubleDown(player.id),
          ),
        ],

        // Dividir (Split)
        if (canSplit) ...[
          SizedBox(width: 10 * _s),
          _actionButton(
            label: 'DIVIDIR',
            icon: Icons.call_split,
            color: Colors.blue.shade700,
            onTap: () => bj.splitPair(player.id),
          ),
        ],
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10 * _s),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10 * _s),
        child: Container(
          constraints: BoxConstraints(minWidth: 100 * _s),
          padding: EdgeInsets.symmetric(horizontal: 14 * _s, vertical: 8 * _s),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18 * _s),
              SizedBox(width: 6 * _s),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12 * _s,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 8. ROUND END CONTROLS ───────────────────────────────

  Widget _buildRoundEndControls(BlackjackProvider bj) {
    return Row(
      children: [
        // Message Banner
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14 * _s, vertical: 8 * _s),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10 * _s),
              border: Border.all(color: Colors.amber, width: 1.5),
            ),
            child: Text(
              bj.message ?? 'Ronda finalizada.',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 12 * _s,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        SizedBox(width: 16 * _s),
        // Nueva Ronda Button
        ElevatedButton.icon(
          onPressed: () => _onNewRound(bj),
          icon: Icon(Icons.replay, size: 18 * _s),
          label: Text('Nueva Ronda', style: TextStyle(fontSize: 13 * _s, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 22 * _s, vertical: 11 * _s),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10 * _s)),
            elevation: 4,
          ),
        ),
      ],
    );
  }

  // ─── 9. WAITING ROOM (MULTIPLAYER) ───────────────────────

  Widget _buildWaitingRoom(BlackjackProvider bj) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.people, size: 40 * _s, color: Colors.white24),
        SizedBox(height: 6 * _s),
        Text('Esperando jugadores... (${bj.activePlayers.length})',
            style: TextStyle(color: Colors.white70, fontSize: 14 * _s)),
        if (widget.isHost)
          FutureBuilder<String?>(
            future: P2PService.getLocalIpAddress(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Container(
                  margin: EdgeInsets.symmetric(vertical: 6 * _s),
                  padding: EdgeInsets.symmetric(horizontal: 14 * _s, vertical: 5 * _s),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(10 * _s),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'Tu IP para conexión directa: ${snapshot.data}',
                    style: TextStyle(color: Colors.amber, fontSize: 11 * _s, fontWeight: FontWeight.bold),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        SizedBox(height: 10 * _s),
        if (widget.isHost && bj.activePlayers.isNotEmpty)
          ElevatedButton(
            onPressed: bj.startMatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              padding: EdgeInsets.symmetric(horizontal: 28 * _s, vertical: 10 * _s),
            ),
            child: Text('Iniciar Partida',
                style: TextStyle(fontSize: 14 * _s, color: Colors.black, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────

  Widget _handValueBadge(int value, bool isBusted, bool isBlackjack, {bool charlie = false}) {
    Color bg;
    String text;

    if (isBusted) {
      bg = Colors.red.shade800;
      text = 'BUST $value';
    } else if (isBlackjack) {
      bg = const Color(0xFFD4AF37);
      text = 'BJ! 21';
    } else if (charlie) {
      bg = Colors.teal.shade700;
      text = '5CC $value';
    } else {
      bg = Colors.blue.shade800;
      text = '$value';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6 * _s, vertical: 1.5 * _s),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8 * _s),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10 * _s,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _singleCardValue(BlackjackHand hand) {
    if (hand.cards.isEmpty) return '?';
    final v = hand.cards[0].value;
    switch (v) {
      case 'A':
        return '11';
      case 'K':
      case 'Q':
      case 'J':
        return '10';
      default:
        return v;
    }
  }

  bool _isCurrentPlayer(BlackjackPlayer player, BlackjackProvider bj) {
    if (bj.phase != BlackjackPhase.playerTurn) return false;
    final active = bj.activePlayers;
    if (active.isEmpty || bj.currentPlayerIndex >= active.length) return false;
    return active[bj.currentPlayerIndex].id == player.id;
  }

  PlayerSeatStatus _getPlayerStatus(BlackjackPlayer player, BlackjackProvider bj) {
    if (bj.phase == BlackjackPhase.waiting || bj.phase == BlackjackPhase.betting) {
      return PlayerSeatStatus.waiting;
    }
    final hand = player.hands.isNotEmpty ? player.hands[0] : null;
    if (hand == null) return PlayerSeatStatus.waiting;
    if (hand.isBusted) return PlayerSeatStatus.busted;
    if (hand.isBlackjack) return PlayerSeatStatus.blackjack;
    if (hand.isCharlie) return PlayerSeatStatus.charlie;
    if (hand.isStanding) return PlayerSeatStatus.standing;
    if (_isCurrentPlayer(player, bj)) return PlayerSeatStatus.active;
    return PlayerSeatStatus.waiting;
  }
}

// ─── ANIMATED CARD SLIDE-IN ────────────────────────────────

class _AnimatedSlideIn extends StatelessWidget {
  final CardModel card;
  final double scale;
  final AnimationController controller;
  final bool faceUp;
  const _AnimatedSlideIn({
    required this.controller,
    required this.card,
    required this.scale,
    this.faceUp = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -20 * (1 - Curves.easeOutBack.transform(controller.value))),
          child: Opacity(opacity: controller.value.clamp(0.0, 1.0), child: child),
        );
      },
      child: CardWidget(
        card: card,
        isFaceUp: faceUp,
        scale: scale,
      ),
    );
  }
}
