import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/blackjack_models.dart';
import '../../providers/blackjack_provider.dart';
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
  late double _screenW;
  late double _screenH;
  final Map<String, AnimationController> _cardAnims = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    _screenW = size.width;
    _screenH = size.height;
    _s = (_screenW / 400).clamp(0.8, 1.8);
  }

  AnimationController _animFor(String key) {
    if (!_cardAnims.containsKey(key)) {
      final ctrl = AnimationController(duration: const Duration(milliseconds: 280), vsync: this);
      ctrl.forward();
      _cardAnims[key] = ctrl;
    }
    return _cardAnims[key]!;
  }

  @override
  void dispose() {
    for (final c in _cardAnims.values) { c.dispose(); }
    _cardAnims.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          for (final c in _cardAnims.values) { c.dispose(); }
          _cardAnims.clear();
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LobbyScreen()));
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(center: Alignment.center, radius: 0.9, colors: [Color(0xFF0A4D28), Color(0xFF052915)]),
          ),
          child: SafeArea(
            child: Consumer<BlackjackProvider>(
              builder: (context, bj, child) {
                if (bj.players.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                final dealer = bj.dealer;
                final humans = bj.humanPlayers;
                final isWaiting = bj.phase == BlackjackPhase.waiting;

                // Local/single player: use simple column layout
    final useCircle = widget.isMultiplayer && humans.length > 1;
    final showBetOrActions = ((bj.phase == BlackjackPhase.betting || bj.phase == BlackjackPhase.playerTurn) && humans.any((p) => p.isLocal));
    return Column(
      children: [
        SizedBox(height: 4 * _s),
        if (bj.state.deck.isNotEmpty)
          Text('Mazo: ${bj.state.deck.length} / 312 cartas', style: TextStyle(color: Colors.white38, fontSize: 10 * _s)),
        if (dealer != null) _buildDealerArea(dealer, bj),
        Expanded(
          child: isWaiting
            ? _buildWaitingRoom(bj)
            : bj.message != null
              ? Center(child: _messageBox(bj))
              : useCircle
                ? _buildPlayerCircle(humans, bj)
                : _buildPlayerColumn(humans, bj),
        ),
        // Player controls fixed at bottom
        if (showBetOrActions)
          ...humans.where((p) => p.isLocal).map((p) => _buildBottomPlayerArea(p, bj)),
        if (bj.phase == BlackjackPhase.roundEnd && bj.isHost)
          Padding(
            padding: EdgeInsets.only(bottom: 4 * _s),
            child: ElevatedButton(onPressed: bj.newRound, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: EdgeInsets.symmetric(horizontal: 24 * _s, vertical: 12 * _s)), child: Text('Nueva Ronda', style: TextStyle(fontSize: 16 * _s, color: Colors.white, fontWeight: FontWeight.bold))),
          ),
      ],
    );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingRoom(BlackjackProvider bj) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.people, size: 48 * _s, color: Colors.white24),
        SizedBox(height: 8 * _s),
        Text('Esperando jugadores... (${bj.humanPlayers.length})',
          style: TextStyle(color: Colors.white54, fontSize: 14 * _s)),
        SizedBox(height: 16 * _s),
        if (widget.isHost && bj.humanPlayers.length >= 1)
          ElevatedButton(
            onPressed: () {
              bj.startMatch();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, padding: EdgeInsets.symmetric(horizontal: 32 * _s, vertical: 14 * _s)),
            child: Text('Iniciar Partida', style: TextStyle(fontSize: 16 * _s, color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        SizedBox(height: 12 * _s),
        ...bj.humanPlayers.map((p) => Padding(
          padding: EdgeInsets.symmetric(vertical: 4 * _s),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person, color: p.isLocal ? Colors.amber : Colors.white38, size: 18 * _s),
              SizedBox(width: 6 * _s),
              Text(p.name, style: TextStyle(color: p.isLocal ? Colors.amber : Colors.white54, fontSize: 13 * _s)),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildPlayerColumn(List<BlackjackPlayer> humans, BlackjackProvider bj) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: humans.map((p) => Padding(
          padding: EdgeInsets.only(bottom: 6 * _s),
          child: _buildPlayerArea(p, bj),
        )).toList(),
      ),
    );
  }

  Widget _messageBox(BlackjackProvider bj) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20 * _s),
      padding: EdgeInsets.all(14 * _s),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12 * _s), border: Border.all(color: Colors.amber)),
      child: Text(bj.message!, style: TextStyle(color: Colors.amber, fontSize: 14 * _s), textAlign: TextAlign.center),
    );
  }

  Widget _buildDealerArea(BlackjackPlayer dealer, BlackjackProvider bj) {
    final showAll = bj.phase == BlackjackPhase.dealerTurn || bj.phase == BlackjackPhase.roundEnd;
    final hand = dealer.hands.isEmpty ? BlackjackHand() : dealer.hands[0];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.person, color: Colors.redAccent, size: 16 * _s),
          SizedBox(width: 4 * _s),
          Text(dealer.name, style: TextStyle(color: Colors.redAccent, fontSize: 14 * _s, fontWeight: FontWeight.bold)),
        ]),
        SizedBox(height: 2 * _s),
        Text(showAll ? '${hand.handValue}' : (hand.cards.length == 2 ? '${_cardValue(hand.cards[0].value)} (+?)' : '?'),
          style: TextStyle(color: Colors.white70, fontSize: 12 * _s)),
        SizedBox(height: 2 * _s),
        _buildDealerCardsRow(hand, dealer.id, showAll),
        if (hand.isBlackjack && showAll) Text('BLACKJACK!', style: TextStyle(color: Colors.amber, fontSize: 13 * _s, fontWeight: FontWeight.bold)),
        Divider(color: Colors.white10, height: 4 * _s),
      ],
    );
  }

  Widget _buildDealerCardsRow(BlackjackHand hand, String dealerId, bool showAll) {
    const perRow = 5;
    final rows = <Widget>[];
    for (var i = 0; i < hand.cards.length; i += perRow) {
      final end = (i + perRow).clamp(0, hand.cards.length);
      final rowCards = hand.cards.sublist(i, end);
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: 2 * _s),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: rowCards.asMap().entries.map((e) {
            final cardIdx = i + e.key;
            final faceUp = showAll || cardIdx != 1;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 2 * _s),
              child: faceUp
                ? SizedBox(width: 65 * _s, height: 92 * _s, child: _AnimatedSlideIn(controller: _animFor('$dealerId-$cardIdx'), card: e.value, scale: _s * 0.5))
                : Container(width: 65 * _s, height: 92 * _s, decoration: BoxDecoration(color: Colors.blue.shade900, borderRadius: BorderRadius.circular(5 * _s), image: const DecorationImage(image: AssetImage('assets/images/cards/cardBack_red5.png'), fit: BoxFit.cover))),
            );
          }).toList(),
        ),
      ));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _buildPlayerCircle(List<BlackjackPlayer> humans, BlackjackProvider bj) {
    // Arrange players around a circle
    final radius = _screenW * 0.32;
    final centerX = _screenW / 2;
    final centerY = _screenH * 0.35;

    return Stack(
      children: humans.asMap().entries.map((e) {
        final idx = e.key;
        final player = e.value;
        // Position players around the top half of a circle
        final startAngle = -3.14 * 0.6; // ~ -108 degrees
        final endAngle = -3.14 * 0.03;   // ~  -5 degrees
        final total = humans.length;
        final angle = total == 1 ? -3.14 * 0.3 : startAngle + (endAngle - startAngle) * idx / (total - 1);

        final x = centerX + radius * math.cos(angle) - _screenW * 0.23;
        final y = centerY + radius * math.sin(angle);

        return Positioned(
          left: x,
          top: y,
          child: _buildPlayerArea(player, bj),
        );
      }).toList(),
    );
  }

  Widget _buildPlayerArea(BlackjackPlayer player, BlackjackProvider bj) {
    final isCurrent = bj.humanPlayers.isNotEmpty && bj.currentPlayerIndex < bj.humanPlayers.length && bj.humanPlayers[bj.currentPlayerIndex].id == player.id;
    final isPlayerTurn = bj.phase == BlackjackPhase.playerTurn && isCurrent;

    return Container(
      width: widget.isMultiplayer ? _screenW * 0.44 : _screenW * 0.88,
      padding: EdgeInsets.all(6 * _s),
      decoration: BoxDecoration(
        color: isPlayerTurn ? Colors.amber.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8 * _s),
        border: isPlayerTurn ? Border.all(color: Colors.amber, width: 2.5) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPlayerHeader(player, isPlayerTurn),
          SizedBox(height: 2 * _s),
          ...player.hands.asMap().entries.map((e) => _buildHandRow(player, e.key, e.value, isPlayerTurn, bj)),
          if (!player.isLocal && isPlayerTurn) Padding(
            padding: EdgeInsets.only(top: 2 * _s),
            child: Text('Pensando...', style: TextStyle(color: Colors.white38, fontSize: 12 * _s)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPlayerArea(BlackjackPlayer player, BlackjackProvider bj) {
    final isBetting = bj.phase == BlackjackPhase.betting;
    final isPlayerTurn = bj.phase == BlackjackPhase.playerTurn && bj.humanPlayers.isNotEmpty && bj.currentPlayerIndex < bj.humanPlayers.length && bj.humanPlayers[bj.currentPlayerIndex].id == player.id;

    return Container(
      width: _screenW,
      padding: EdgeInsets.symmetric(horizontal: 8 * _s, vertical: 6 * _s),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12 * _s)),
        border: Border(top: BorderSide(color: Colors.amber.withValues(alpha: 0.4), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPlayerHeader(player, isPlayerTurn),
          SizedBox(height: 4 * _s),
          if (isBetting) _buildBetChips(player, bj),
          if (isPlayerTurn) _buildActionButtons(player, bj),
        ],
      ),
    );
  }

  Widget _buildPlayerHeader(BlackjackPlayer player, bool isPlayerTurn) {
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(player.name, style: TextStyle(color: isPlayerTurn ? Colors.amber : Colors.white70, fontSize: 13 * _s, fontWeight: FontWeight.bold)),
        Text('Fichas: ${player.chipBalance}', style: TextStyle(color: Colors.greenAccent, fontSize: 10 * _s)),
      ])),
      if (player.totalBet > 0)
        Container(padding: EdgeInsets.symmetric(horizontal: 8 * _s, vertical: 3 * _s), decoration: BoxDecoration(color: Colors.amber.shade800, borderRadius: BorderRadius.circular(5 * _s)), child: Text('Apuesta: ${player.totalBet}', style: TextStyle(color: Colors.white, fontSize: 11 * _s, fontWeight: FontWeight.bold))),
      if (player.isBlackjack) Text(' BJ!', style: TextStyle(color: Colors.amber, fontSize: 12 * _s, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildHandRow(BlackjackPlayer player, int handIdx, BlackjackHand hand, bool isPlayerTurn, BlackjackProvider bj) {
    final showRunning = hand.cards.isNotEmpty && bj.phase != BlackjackPhase.betting && bj.phase != BlackjackPhase.roundEnd && bj.phase != BlackjackPhase.waiting;
    final numRows = (hand.cards.length + 2) ~/ 3;
    final isActiveHand = handIdx == player.activeHandIndex && isPlayerTurn;
    return Padding(
      padding: EdgeInsets.only(bottom: 2 * _s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 20 * _s,
            child: hand.cards.isNotEmpty && player.hands.length > 1 ? Text('M${handIdx + 1}', style: TextStyle(color: Colors.white38, fontSize: 10 * _s)) : const SizedBox.shrink(),
          ),
          SizedBox(
            height: (92 * _s + 2) * numRows,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: _buildCardRows(hand.cards, player.id, handIdx),
            ),
          ),
          SizedBox(width: 4 * _s),
          if (showRunning)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5 * _s, vertical: 2 * _s),
              decoration: BoxDecoration(
                color: isActiveHand ? Colors.amber.withValues(alpha: 0.3) : Colors.white10,
                borderRadius: BorderRadius.circular(4 * _s),
                border: hand.handValue > 21 ? Border.all(color: Colors.red, width: 1.5) : (isActiveHand ? Border.all(color: Colors.amber, width: 1.5) : null),
              ),
              child: Text(hand.isBusted ? 'B ${hand.handValue}' : '${hand.handValue}', style: TextStyle(color: hand.isBusted ? Colors.red : (isActiveHand ? Colors.amber : Colors.white), fontSize: 14 * _s, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildCardRows(List<Object?> cards, String playerId, int handIdx) {
    const perRow = 3;
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += perRow) {
      final end = (i + perRow).clamp(0, cards.length);
      final rowCards = cards.sublist(i, end);
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: 2 * _s),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: rowCards.asMap().entries.map((e) {
            final cardIdx = i + e.key;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 2 * _s),
              child: SizedBox(
                width: 65 * _s, height: 92 * _s,
                child: _AnimatedSlideIn(controller: _animFor('$playerId-${handIdx}_$cardIdx'), card: e.value, scale: _s * 0.5),
              ),
            );
          }).toList(),
        ),
      ));
    }
    return rows;
  }

  Widget _buildBetChips(BlackjackPlayer player, BlackjackProvider bj) {
    return Padding(
      padding: EdgeInsets.only(top: 2 * _s),
      child: Wrap(spacing: 4 * _s, runSpacing: 4 * _s, alignment: WrapAlignment.center, children: [10, 25, 50, 100, 200, 400].map((amt) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 2 * _s),
        child: Material(
          color: player.chipBalance >= amt ? Colors.amber.shade700 : Colors.grey.shade700,
          borderRadius: BorderRadius.circular(16 * _s),
          child: InkWell(
            onTap: player.chipBalance >= amt ? () => bj.placeBet(player.id, amt) : null,
            borderRadius: BorderRadius.circular(16 * _s),
            child: Container(width: 40 * _s, height: 28 * _s, alignment: Alignment.center, child: Text('$amt', style: TextStyle(color: Colors.white, fontSize: 11 * _s, fontWeight: FontWeight.bold))),
          ),
        ),
      )).toList()),
    );
  }

  Widget _buildActionButtons(BlackjackPlayer player, BlackjackProvider bj) {
    final canSplit = player.canSplit && player.chipBalance >= player.currentHand.betAmount;
    final hand = player.currentHand;
    final canDouble = hand.cards.length == 2 && !hand.isDoubledDown && player.chipBalance >= hand.betAmount;
    return Padding(
      padding: EdgeInsets.only(top: 2 * _s),
      child: Wrap(spacing: 4 * _s, runSpacing: 4 * _s, alignment: WrapAlignment.center, children: [
        _actionBtn('PEDIR', Colors.green, () => bj.hit(player.id)),
        _actionBtn('PLANTAR', Colors.red.shade700, () => bj.stand(player.id)),
        if (canDouble) _actionBtn('DOBLAR', Colors.orange.shade700, () => bj.doubleDown(player.id)),
        if (canSplit) _actionBtn('DIVIDIR', Colors.blue.shade700, () => bj.splitPair(player.id)),
      ]),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(5 * _s),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(5 * _s), child: Container(padding: EdgeInsets.symmetric(horizontal: 10 * _s, vertical: 6 * _s), child: Text(label, style: TextStyle(color: Colors.white, fontSize: 11 * _s, fontWeight: FontWeight.bold)))),
    );
  }

  int _cardValue(String val) {
    switch (val) {
      case 'A': return 11;
      case 'K': case 'Q': case 'J': return 10;
      default: return int.tryParse(val) ?? 0;
    }
  }
}

class _AnimatedSlideIn extends StatelessWidget {
  final dynamic card;
  final double scale;
  final AnimationController controller;
  const _AnimatedSlideIn({super.key, required this.controller, required this.card, required this.scale});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -30 * (1 - Curves.easeOutBack.transform(controller.value))),
          child: Opacity(opacity: controller.value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Image.asset(card.assetPath, width: 65 * scale, height: 92 * scale, fit: BoxFit.cover),
    );
  }
}
