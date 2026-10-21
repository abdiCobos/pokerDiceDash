import 'package:flutter/material.dart';

import '../../models/blackjack_models.dart';
import '../../models/dice_blackjack.dart';
import 'card_widget.dart';

/// Dice Dash "21" event panel, shown over the table to every player.
/// The event player bets and plays; everybody else watches the same hand.
class DiceBlackjackPanel extends StatefulWidget {
  final DiceBlackjack event;
  final bool isMine;
  final int freeChips;
  final double scale;
  final ValueChanged<int> onBet;
  final VoidCallback onSkip;
  final VoidCallback onHit;
  final VoidCallback onStand;

  const DiceBlackjackPanel({
    super.key,
    required this.event,
    required this.isMine,
    required this.freeChips,
    required this.scale,
    required this.onBet,
    required this.onSkip,
    required this.onHit,
    required this.onStand,
  });

  @override
  State<DiceBlackjackPanel> createState() => _DiceBlackjackPanelState();
}

class _DiceBlackjackPanelState extends State<DiceBlackjackPanel> {
  int _bet = 50;

  int get _max => DiceBlackjack.maxBetFor(widget.freeChips);

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final e = widget.event;
    final bet = _bet.clamp(DiceBlackjack.minBet, _max < DiceBlackjack.minBet ? DiceBlackjack.minBet : _max);
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 470 * s),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            width: 470 * s,
            padding: EdgeInsets.fromLTRB(16 * s, 10 * s, 16 * s, 12 * s),
            decoration: BoxDecoration(
              color: const Color(0xFF07160D).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(16 * s),
              border: Border.all(color: Colors.lightGreenAccent.withValues(alpha: 0.8), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.lightGreenAccent.withValues(alpha: 0.25), blurRadius: 20 * s)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.isMine ? '¡21! Tú contra el crupier' : '¡21! ${e.playerName} contra el crupier',
                  style: TextStyle(color: Colors.lightGreenAccent, fontSize: 16 * s, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 2 * s),
                Text(_subtitle(e), style: TextStyle(color: Colors.white60, fontSize: 11 * s)),
                SizedBox(height: 8 * s),
                if (e.stage != DiceBlackjackStage.betting || e.bet > 0) ...[
                  _row('Crupier', e.dealer, hideHole: e.holeHidden, s: s),
                  SizedBox(height: 6 * s),
                  _row(widget.isMine ? 'Tú' : e.playerName, e.player, s: s),
                  SizedBox(height: 8 * s),
                ],
                _controls(e, bet, s),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(DiceBlackjack e) {
    switch (e.stage) {
      case DiceBlackjackStage.betting:
        return widget.isMine
            ? 'Apuesta de tus fichas (${DiceBlackjack.minBet} a $_max). Blackjack paga 3 a 2.'
            : 'Esperando la apuesta de ${e.playerName}...';
      case DiceBlackjackStage.playing:
        return 'Apuesta: ${e.bet}';
      case DiceBlackjackStage.dealer:
        return 'Apuesta: ${e.bet} · juega el crupier';
      case DiceBlackjackStage.done:
        return e.skipped ? 'No hubo apuesta' : 'Apuesta: ${e.bet}';
    }
  }

  Widget _row(String who, BlackjackHand hand, {bool hideHole = false, required double s}) {
    final shownValue = hideHole && hand.cards.isNotEmpty
        ? BlackjackHand(cards: [hand.cards.first]).handValue
        : hand.handValue;
    return Row(
      children: [
        SizedBox(
          width: 90 * s,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(who, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: 12 * s, fontWeight: FontWeight.bold)),
              SizedBox(height: 3 * s),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7 * s, vertical: 2 * s),
                decoration: BoxDecoration(
                  color: shownValue > 21 ? Colors.red.shade700 : Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(8 * s),
                ),
                child: Text(
                  hideHole ? '$shownValue + ?' : (shownValue > 21 ? 'BUST $shownValue' : '$shownValue'),
                  style: TextStyle(color: Colors.white, fontSize: 11 * s, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 112 * 0.5 * CardWidget.autoScaleOf(context),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < hand.cards.length; i++)
                  Positioned(
                    left: i * 30.0 * s,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey('$who-$i-${hand.cards[i].value}${hand.cards[i].suit.index}-$hideHole'),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutBack,
                      builder: (context, t, child) =>
                          Opacity(opacity: t.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, -20 * s * (1 - t)), child: child)),
                      child: CardWidget(card: hand.cards[i], isFaceUp: !(hideHole && i == 1), scale: 0.5),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _pill(String label, Color color, VoidCallback onTap, double s, {bool filled = true}) {
    return Material(
      color: filled ? color : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: color, width: 1.5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 8 * s),
          child: Text(label, style: TextStyle(color: filled ? Colors.white : color, fontSize: 13 * s, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _controls(DiceBlackjack e, int bet, double s) {
    if (e.stage == DiceBlackjackStage.done) {
      final net = e.net;
      final color = e.skipped || net == 0 ? Colors.blueGrey : (net > 0 ? Colors.green.shade600 : Colors.red.shade700);
      final amount = e.skipped ? '' : (net > 0 ? '  +$net' : (net < 0 ? '  $net' : ''));
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 6 * s),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12 * s)),
        child: Text('${e.result}$amount', style: TextStyle(color: Colors.white, fontSize: 14 * s, fontWeight: FontWeight.w900)),
      );
    }
    if (!widget.isMine) {
      return Text(
        e.stage == DiceBlackjackStage.dealer ? 'Juega el crupier...' : 'Viendo la partida de ${e.playerName}...',
        style: TextStyle(color: Colors.white70, fontSize: 12 * s),
      );
    }
    if (e.stage == DiceBlackjackStage.betting) {
      final steps = [10, 25, 50, 100, 200].where((v) => v <= _max).toList();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6 * s,
            children: [
              // Own chips (Material ChoiceChip renders white on the app's light theme).
              for (final v in steps)
                InkWell(
                  borderRadius: BorderRadius.circular(16 * s),
                  onTap: () => setState(() => _bet = v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 6 * s),
                    decoration: BoxDecoration(
                      color: bet == v ? const Color(0xFFFFD54F) : const Color(0xFF0E2A1A),
                      borderRadius: BorderRadius.circular(16 * s),
                      border: Border.all(color: const Color(0xFFD4AF37)),
                    ),
                    child: Text('$v',
                        style: TextStyle(fontSize: 12 * s, fontWeight: FontWeight.bold, color: bet == v ? Colors.black : Colors.white)),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8 * s),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pill('No apostar', Colors.white54, widget.onSkip, s, filled: false),
              SizedBox(width: 10 * s),
              _pill('Apostar $bet', const Color(0xFF2E7D32), () => widget.onBet(bet), s),
            ],
          ),
        ],
      );
    }
    if (e.stage == DiceBlackjackStage.playing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill('PEDIR', const Color(0xFF2E7D32), widget.onHit, s),
          SizedBox(width: 12 * s),
          _pill('PLANTAR', const Color(0xFFC62828), widget.onStand, s),
        ],
      );
    }
    return Text('Juega el crupier...', style: TextStyle(color: Colors.white70, fontSize: 12 * s));
  }
}
