import 'dart:async';

import 'package:flutter/material.dart';

import '../../providers/game_provider.dart';
import '../../l10n/l10n.dart';

/// LAN poker: the last seconds of a turn ("Te quedan 9 s"), so nobody is surprised when
/// the host plays for them. Hidden while there is plenty of time.
class TurnClock extends StatefulWidget {
  final GameProvider game;
  final double scale;
  static const int showFrom = 15;

  const TurnClock({super.key, required this.game, this.scale = 1.0});

  @override
  State<TurnClock> createState() => _TurnClockState();
}

class _TurnClockState extends State<TurnClock> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final left = g.turnSecondsLeft;
    if (left == null || left > TurnClock.showFrom) return const SizedBox.shrink();
    final ci = g.state.currentPlayerIndex;
    final player = g.players[ci];
    final mine = player.id == g.localPlayerId;
    final s = widget.scale;
    return Positioned(
      top: 88 * s,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 5 * s),
            decoration: BoxDecoration(
              color: (left <= 5 ? Colors.red.shade800 : Colors.black).withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12 * s),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, color: Colors.amber, size: 15 * s),
                SizedBox(width: 6 * s),
                Text(
                  mine ? context.t.turnClockMine('$left') : context.t.turnClockOther(player.name, '$left'),
                  style: TextStyle(color: Colors.white, fontSize: 12 * s, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
