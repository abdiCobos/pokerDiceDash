import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/blackjack_models.dart';
import '../../models/card_model.dart';
import '../../providers/blackjack_provider.dart';
import '../widgets/card_widget.dart';
import 'lobby_screen.dart';

class BlackjackTableScreen extends StatefulWidget {
  const BlackjackTableScreen({super.key});

  @override
  State<BlackjackTableScreen> createState() => _BlackjackTableScreenState();
}

class _BlackjackTableScreenState extends State<BlackjackTableScreen> with TickerProviderStateMixin {
  late double _s;
  late double _screenW;
  late double _screenH;
  final Map<String, AnimationController> _cardAnimControllers = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    _screenW = size.width;
    _screenH = size.height;
    _s = (_screenW / 400).clamp(0.8, 1.8);
  }

  AnimationController _getCardAnim(String playerId, int cardIndex) {
    final key = '${playerId}_$cardIndex';
    if (!_cardAnimControllers.containsKey(key)) {
      final ctrl = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
      ctrl.forward();
      _cardAnimControllers[key] = ctrl;
    }
    return _cardAnimControllers[key]!;
  }

  @override
  void dispose() {
    for (final c in _cardAnimControllers.values) {
      c.dispose();
    }
    _cardAnimControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          for (final c in _cardAnimControllers.values) { c.dispose(); }
          _cardAnimControllers.clear();
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
                  bj.initSinglePlayer(botCount: 0);
                  return const Center(child: CircularProgressIndicator());
                }
                final dealer = bj.dealer;
                final humans = bj.humanPlayers;
                return Column(
                  children: [
                    // Dealer area - top
                    SizedBox(height: _screenH * 0.01),
                    if (dealer != null) _buildDealerArea(dealer, bj),

                    // Center - message
                    Expanded(
                      child: bj.message != null
                          ? Center(
                              child: Container(
                                margin: EdgeInsets.symmetric(horizontal: 20 * _s),
                                padding: EdgeInsets.all(14 * _s),
                                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12 * _s), border: Border.all(color: Colors.amber)),
                                child: Text(bj.message!, style: TextStyle(color: Colors.amber, fontSize: 14 * _s), textAlign: TextAlign.center),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    // New round button
                    if (bj.phase == BlackjackPhase.roundEnd)
                      Padding(
                        padding: EdgeInsets.only(bottom: 4 * _s),
                        child: ElevatedButton(
                          onPressed: bj.newRound,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: EdgeInsets.symmetric(horizontal: 24 * _s, vertical: 12 * _s)),
                          child: Text('Nueva Ronda', style: TextStyle(fontSize: 16 * _s, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),

                    // Player areas - bottom
                    ...humans.map((p) => _buildPlayerArea(p, bj)),

                    // Mode badge
                    Padding(
                      padding: EdgeInsets.only(bottom: 4 * _s),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10 * _s, vertical: 4 * _s),
                        decoration: BoxDecoration(color: Colors.green.shade800, borderRadius: BorderRadius.circular(6 * _s)),
                        child: Text('21 Black Jack', style: TextStyle(color: Colors.white, fontSize: 11 * _s, fontWeight: FontWeight.bold)),
                      ),
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

  Widget _buildDealerArea(BlackjackPlayer dealer, BlackjackProvider bj) {
    final showAll = bj.phase == BlackjackPhase.dealerTurn || bj.phase == BlackjackPhase.roundEnd;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, color: Colors.redAccent, size: 16 * _s),
            SizedBox(width: 4 * _s),
            Text(dealer.name, style: TextStyle(color: Colors.redAccent, fontSize: 14 * _s, fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 2 * _s),
        Text(showAll ? '${dealer.handValue}' : '?', style: TextStyle(color: Colors.white70, fontSize: 12 * _s)),
        SizedBox(height: 4 * _s),
        SizedBox(
          height: 90 * _s,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: dealer.hand.asMap().entries.map((e) {
              final isFirst = e.key == 0;
              final faceUp = showAll || !isFirst;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 3 * _s),
                child: faceUp
                    ? SizedBox(width: 60 * _s, height: 84 * _s, child: _AnimatedCard(controller: _getCardAnim(dealer.id, e.key), card: e.value, scale: _s * 0.5))
                    : Container(
                        width: 60 * _s, height: 84 * _s,
                        decoration: BoxDecoration(color: Colors.blue.shade900, borderRadius: BorderRadius.circular(6), image: const DecorationImage(image: AssetImage('assets/images/cards/cardBack_red5.png'), fit: BoxFit.cover)),
                      ),
              );
            }).toList(),
          ),
        ),
        if (dealer.isBlackjack && showAll)
          Text('🃏 BLACKJACK!', style: TextStyle(color: Colors.amber, fontSize: 13 * _s, fontWeight: FontWeight.bold)),
        Divider(color: Colors.white10, height: 8 * _s),
      ],
    );
  }

  Widget _buildPlayerArea(BlackjackPlayer player, BlackjackProvider bj) {
    final isCurrentPlayer = bj.humanPlayers.isNotEmpty &&
        bj.currentPlayerIndex < bj.humanPlayers.length &&
        bj.humanPlayers[bj.currentPlayerIndex].id == player.id;
    final isBetting = bj.phase == BlackjackPhase.betting;
    final isPlayerTurn = bj.phase == BlackjackPhase.playerTurn && isCurrentPlayer && !player.isStanding;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8 * _s, vertical: 3 * _s),
      padding: EdgeInsets.all(8 * _s),
      decoration: BoxDecoration(
        color: isPlayerTurn ? Colors.amber.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10 * _s),
        border: isPlayerTurn ? Border.all(color: Colors.amber, width: 2.5) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.name, style: TextStyle(color: isPlayerTurn ? Colors.amber : Colors.white70, fontSize: 14 * _s, fontWeight: FontWeight.bold)),
                    Text('Fichas: ${player.chipBalance}', style: TextStyle(color: Colors.greenAccent, fontSize: 11 * _s)),
                  ],
                ),
              ),
              if (player.betAmount > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10 * _s, vertical: 4 * _s),
                  decoration: BoxDecoration(color: Colors.amber.shade800, borderRadius: BorderRadius.circular(6 * _s)),
                  child: Text('Apuesta: ${player.betAmount}', style: TextStyle(color: Colors.white, fontSize: 12 * _s, fontWeight: FontWeight.bold)),
                ),
              if (player.isBlackjack) Text(' 🃏 BJ!', style: TextStyle(color: Colors.amber, fontSize: 13 * _s, fontWeight: FontWeight.bold)),
              if (player.isBusted) Text(' 💥 BUST', style: TextStyle(color: Colors.red, fontSize: 13 * _s, fontWeight: FontWeight.bold)),
              if (player.isStanding && !player.isBusted && !player.isBlackjack) Text(' ✋ ${player.handValue}', style: TextStyle(color: Colors.green, fontSize: 13 * _s)),
            ],
          ),
          SizedBox(height: 4 * _s),
          SizedBox(
            height: 84 * _s,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: player.hand.asMap().entries.map((e) => Padding(
                padding: EdgeInsets.symmetric(horizontal: 3 * _s),
                child: SizedBox(
                  width: 60 * _s, height: 84 * _s,
                  child: _AnimatedCard(controller: _getCardAnim(player.id, e.key), card: e.value, scale: _s * 0.5),
                ),
              )).toList(),
            ),
          ),
          SizedBox(height: 4 * _s),
          if (isBetting && player.isLocal)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [10, 25, 50, 100, 200].map((amt) => Padding(
                padding: EdgeInsets.symmetric(horizontal: 3 * _s),
                child: Material(
                  color: player.chipBalance >= amt ? Colors.amber.shade700 : Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(20 * _s),
                  child: InkWell(
                    onTap: player.chipBalance >= amt ? () => bj.placeBet(player.id, amt) : null,
                    borderRadius: BorderRadius.circular(20 * _s),
                    child: Container(
                      width: 46 * _s, height: 32 * _s,
                      alignment: Alignment.center,
                      child: Text('$amt', style: TextStyle(color: Colors.white, fontSize: 13 * _s, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              )).toList(),
            ),
          if (isPlayerTurn && player.isLocal)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Material(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8 * _s),
                  child: InkWell(
                    onTap: () => bj.hit(player.id),
                    borderRadius: BorderRadius.circular(8 * _s),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 20 * _s, vertical: 10 * _s),
                      child: Text('PEDIR', style: TextStyle(color: Colors.white, fontSize: 14 * _s, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                SizedBox(width: 12 * _s),
                Material(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(8 * _s),
                  child: InkWell(
                    onTap: () => bj.stand(player.id),
                    borderRadius: BorderRadius.circular(8 * _s),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 20 * _s, vertical: 10 * _s),
                      child: Text('PLANTAR', style: TextStyle(color: Colors.white, fontSize: 14 * _s, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          if (isPlayerTurn && !player.isLocal)
            Text('Pensando...', style: TextStyle(color: Colors.white38, fontSize: 12 * _s)),
        ],
      ),
    );
  }
}

class _AnimatedCard extends StatelessWidget {
  final CardModel card;
  final double scale;
  final AnimationController controller;
  const _AnimatedCard({super.key, required this.controller, required this.card, required this.scale});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(controller.value),
          child: Opacity(opacity: controller.value, child: child),
        );
      },
      child: CardWidget(card: card, scale: scale, isFaceUp: true),
    );
  }
}
