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

class _BlackjackTableScreenState extends State<BlackjackTableScreen> {
  late double _screenW, _screenH;
  late double _s;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    _screenW = size.width;
    _screenH = size.height;
    _s = (_screenW / 800).clamp(0.6, 1.4);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
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
                return Stack(
                  children: [
                    // Dealer section (top)
                    if (dealer != null)
                      Positioned(
                        top: _screenH * 0.02,
                        left: 0,
                        right: 0,
                        child: _DealerArea(player: dealer, phase: bj.phase, s: _s),
                      ),

                    // Message overlay
                    if (bj.message != null)
                      Positioned(
                        top: _screenH * 0.30,
                        left: _screenW * 0.05,
                        right: _screenW * 0.05,
                        child: Container(
                          padding: EdgeInsets.all(12 * _s),
                          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10 * _s)),
                          child: Text(bj.message!, style: TextStyle(color: Colors.amber, fontSize: 12 * _s), textAlign: TextAlign.center),
                        ),
                      ),

                    // Player section (bottom)
                    Positioned(
                      bottom: _screenH * 0.01,
                      left: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: humans.map((p) => _PlayerArea(
                          key: ValueKey(p.id),
                          player: p,
                          bj: bj,
                          screenW: _screenW,
                          s: _s,
                        )).toList(),
                      ),
                    ),

                    // Game mode badge
                    Positioned(top: _screenH * 0.01, right: 8 * _s, child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8 * _s, vertical: 4 * _s),
                      decoration: BoxDecoration(color: Colors.red.shade800, borderRadius: BorderRadius.circular(6 * _s)),
                      child: Text('21', style: TextStyle(color: Colors.white, fontSize: 10 * _s, fontWeight: FontWeight.bold)),
                    )),

                    // New round button
                    if (bj.phase == BlackjackPhase.roundEnd)
                      Positioned(
                        bottom: _screenH * 0.15,
                        left: _screenW * 0.25,
                        right: _screenW * 0.25,
                        child: ElevatedButton(
                          onPressed: bj.newRound,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: EdgeInsets.symmetric(vertical: 12 * _s)),
                          child: Text('Nueva Ronda', style: TextStyle(fontSize: 14 * _s, color: Colors.white)),
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
}

class _DealerArea extends StatelessWidget {
  final BlackjackPlayer player;
  final BlackjackPhase phase;
  final double s;
  const _DealerArea({required this.player, required this.phase, required this.s});

  @override
  Widget build(BuildContext context) {
    final showAll = phase == BlackjackPhase.dealerTurn || phase == BlackjackPhase.roundEnd;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(player.name, style: TextStyle(color: Colors.redAccent, fontSize: 12 * s, fontWeight: FontWeight.bold)),
        SizedBox(height: 2 * s),
        Text('${player.handValue}', style: TextStyle(color: Colors.white70, fontSize: 10 * s)),
        SizedBox(height: 4 * s),
        SizedBox(
          height: 70 * s,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: player.hand.asMap().entries.map((e) {
              final isFirst = e.key == 0;
              final faceUp = showAll || !isFirst;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 2 * s),
                child: faceUp
                    ? SizedBox(width: 50 * s, height: 70 * s, child: CardWidget(card: e.value, scale: s * 0.4, isFaceUp: true))
                    : Container(width: 50 * s, height: 70 * s, decoration: BoxDecoration(
                        color: Colors.blue.shade900, borderRadius: BorderRadius.circular(6),
                        image: const DecorationImage(image: AssetImage('assets/images/cards/cardBack_red5.png'), fit: BoxFit.cover),
                      )),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _PlayerArea extends StatelessWidget {
  final BlackjackPlayer player;
  final BlackjackProvider bj;
  final double screenW;
  final double s;
  const _PlayerArea({super.key, required this.player, required this.bj, required this.screenW, required this.s});

  @override
  Widget build(BuildContext context) {
    final isCurrentPlayer = bj.humanPlayers.isNotEmpty &&
        bj.currentPlayerIndex < bj.humanPlayers.length &&
        bj.humanPlayers[bj.currentPlayerIndex].id == player.id;
    final isBetting = bj.phase == BlackjackPhase.betting;
    final isPlayerTurn = bj.phase == BlackjackPhase.playerTurn && isCurrentPlayer;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4 * s, horizontal: 10 * s),
      padding: EdgeInsets.all(8 * s),
      decoration: BoxDecoration(
        color: isCurrentPlayer && bj.phase == BlackjackPhase.playerTurn
            ? Colors.amber.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10 * s),
        border: isCurrentPlayer && bj.phase == BlackjackPhase.playerTurn
            ? Border.all(color: Colors.amber, width: 2)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(player.name, style: TextStyle(color: isCurrentPlayer ? Colors.amber : Colors.white70, fontSize: 11 * s, fontWeight: FontWeight.bold)),
              if (player.betAmount > 0)
                Text('Apuesta: ${player.betAmount}', style: TextStyle(color: Colors.orange, fontSize: 10 * s)),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${player.handValue}', style: TextStyle(color: Colors.white, fontSize: 10 * s)),
                    Text('Fichas: ${player.chipBalance}', style: TextStyle(color: Colors.greenAccent, fontSize: 9 * s)),
                  ],
                ),
              ),
              if (player.isBlackjack) Text('🃏 BJ!', style: TextStyle(color: Colors.amber, fontSize: 11 * s, fontWeight: FontWeight.bold)),
              if (player.isBusted) Text('💥 BUST', style: TextStyle(color: Colors.red, fontSize: 11 * s, fontWeight: FontWeight.bold)),
              if (player.isStanding && !player.isBusted) Text('✋ STAND', style: TextStyle(color: Colors.green, fontSize: 10 * s)),
              SizedBox(width: 4 * s),
              SizedBox(
                height: 60 * s,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: player.hand.map((c) => Padding(
                    padding: EdgeInsets.symmetric(horizontal: 1 * s),
                    child: SizedBox(width: 42 * s, height: 60 * s, child: CardWidget(card: c, scale: s * 0.35, isFaceUp: true)),
                  )).toList(),
                ),
              ),
            ],
          ),
          if (isBetting && player.isLocal)
            Padding(
              padding: EdgeInsets.only(top: 4 * s),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [10, 25, 50, 100].map((amt) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2 * s),
                  child: _ChipButton(
                    label: '$amt',
                    enabled: player.chipBalance >= amt,
                    onTap: () => bj.placeBet(player.id, amt),
                    s: s,
                  ),
                )).toList(),
              ),
            ),
          if (isPlayerTurn && player.isLocal)
            Padding(
              padding: EdgeInsets.only(top: 4 * s),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionButton(label: 'PEDIR', color: Colors.green, s: s, onTap: () => bj.hit(player.id)),
                  SizedBox(width: 8 * s),
                  _ActionButton(label: 'PLANTAR', color: Colors.red, s: s, onTap: () => bj.stand(player.id)),
                ],
              ),
            ),
          if (isPlayerTurn && !player.isLocal)
            Padding(
              padding: EdgeInsets.only(top: 2 * s),
              child: Text('Pensando...', style: TextStyle(color: Colors.white38, fontSize: 9 * s)),
            ),
        ],
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final double s;
  const _ChipButton({required this.label, required this.enabled, required this.onTap, required this.s});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? Colors.amber.shade700 : Colors.grey.shade700,
      borderRadius: BorderRadius.circular(16 * s),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16 * s),
        child: Container(
          width: 40 * s, height: 28 * s,
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(color: Colors.white, fontSize: 11 * s, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final double s;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.color, required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(6 * s),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6 * s),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 6 * s),
          child: Text(label, style: TextStyle(color: Colors.white, fontSize: 11 * s, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
