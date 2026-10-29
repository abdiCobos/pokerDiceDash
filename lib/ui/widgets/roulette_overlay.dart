import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../l10n/l10n.dart';
import '../../models/roulette.dart';
import '../../providers/game_provider.dart';

/// The casino's roulette over the Dice Dash table: a spotlight opens on the croupier and her
/// wheel, everyone bets, she launches the ball, it drops into a pocket, and the spotlight
/// closes again before the table comes back. Everything comes from [GameProvider.roulette].
class RouletteOverlay extends StatefulWidget {
  final GameProvider game;
  final double scale;
  const RouletteOverlay({super.key, required this.game, required this.scale});

  static const gold = Color(0xFFFFD54F);
  static const red = Color(0xFFC62828);
  static const black = Color(0xFF151518);
  static const green = Color(0xFF0F7A3D);

  static Color colorOf(int n) => n == 0 ? green : (Roulette.isRed(n) ? red : black);

  @override
  State<RouletteOverlay> createState() => _RouletteOverlayState();
}

class _RouletteOverlayState extends State<RouletteOverlay> with TickerProviderStateMixin {
  late final Ticker _ticker = createTicker((d) => setState(() => _now = d));
  Duration _now = Duration.zero;
  Duration _phaseAt = Duration.zero;
  RoulettePhase? _phase;

  /// Seconds into the spin when the overlay opened mid-spin (joined late): skip ahead.
  double _spinOffset = 0;
  late final AnimationController _out = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  Timer? _exitTimer;

  /// Chips picked on the board before choosing what to bet on.
  int _chip = Roulette.bets.first;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    final r = widget.game.roulette;
    // Joining after the announcement: no iris, no sign.
    if (r != null && r.phase != RoulettePhase.betting) _phaseAt = -const Duration(seconds: 30);
    _onPhase();
  }

  @override
  void didUpdateWidget(covariant RouletteOverlay old) {
    super.didUpdateWidget(old);
    _onPhase();
  }

  void _onPhase() {
    final r = widget.game.roulette;
    if (r == null || r.phase == _phase) return;
    final first = _phase == null;
    _phase = r.phase;
    if (!first || r.phase == RoulettePhase.betting) _phaseAt = _now;
    if (first && r.phase == RoulettePhase.spinning) _spinOffset = 2.5;
    if (r.phase == RoulettePhase.result) {
      _exitTimer?.cancel();
      _exitTimer = Timer(Roulette.exitAt, () {
        if (mounted) _out.forward();
      });
    }
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _ticker.dispose();
    _out.dispose();
    super.dispose();
  }

  double get _t => (_now - _phaseAt).inMilliseconds / 1000;
  double get _clock => _now.inMilliseconds / 1000;

  /// Croupier frame: smiles, blinks every few seconds, winks at you while you bet, launches
  /// the ball, laughs with the winners.
  String _croupier(Roulette r) {
    final local = widget.game.localPlayerId;
    if (r.phase == RoulettePhase.spinning && _t + _spinOffset < 1.1) return 'spin';
    if (r.phase == RoulettePhase.result && r.payouts.containsKey(local)) return 'laugh';
    if (r.phase == RoulettePhase.betting && _t > 0.8 && _t < 1.6) return 'wink';
    final cycle = _clock % 3.4;
    if (cycle > 3.22) return 'blink';
    return 'smile';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.game.roulette!;
    final s = widget.scale;
    return AnimatedBuilder(
      animation: _out,
      builder: (context, _) {
        final edge = MediaQueryData.fromView(View.of(context)).padding;
        final announce = Roulette.announceTime.inMilliseconds / 1000;
        // Iris in: the spotlight opens on the scene. Iris out: it closes, then the dark lifts.
        final open = r.phase == RoulettePhase.betting ? Curves.easeOutCubic.transform((_t / 0.9).clamp(0.0, 1.0)) : 1.0;
        final close = Curves.easeInCubic.transform((_out.value / 0.6).clamp(0.0, 1.0));
        final iris = open * (1 - close);
        final darkLeft = 1 - ((_out.value - 0.6) / 0.4).clamp(0.0, 1.0);
        final showSign = r.phase == RoulettePhase.betting && _t < announce;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -edge.left,
              right: -edge.right,
              top: -edge.top,
              bottom: -edge.bottom,
              child: GestureDetector(
                onTap: () {},
                child: Opacity(
                  opacity: darkLeft,
                  child: const ColoredBox(color: Color(0xFF07040A)),
                ),
              ),
            ),
            Positioned(
              left: -edge.left,
              right: -edge.right,
              top: -edge.top,
              bottom: -edge.bottom,
              child: ClipPath(
                clipper: _IrisClipper(iris),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: 0.9,
                          colors: [Color(0xFF5A1020), Color(0xFF2A0710), Color(0xFF12030A)],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: edge.left, right: edge.right, top: edge.top, bottom: edge.bottom),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(10 * s, 8 * s, 10 * s, 8 * s),
                        child: _scene(context, r, showSign),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _scene(BuildContext context, Roulette r, bool showSign) {
    final s = widget.scale;
    final t = context.t;
    final game = widget.game;
    final me = game.localPlayerId;
    final announce = Roulette.announceTime.inMilliseconds / 1000;
    final bob = sin(_clock * 2.2) * 1.5 * s;
    final speech = switch (r.phase) {
      RoulettePhase.betting => t.rouletteHello,
      RoulettePhase.spinning => t.rouletteNoMoreBets,
      RoulettePhase.result => r.payouts.containsKey(me) ? t.rouletteCongrats : t.rouletteHouseThanks,
    };
    return LayoutBuilder(
      builder: (context, c) {
        final wheelSize = min(c.maxHeight * 0.92, c.maxWidth * 0.36);
        return Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // The croupier.
                SizedBox(
                  width: c.maxWidth * 0.25,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.translate(
                        offset: Offset(0, bob),
                        child: Image.asset(
                          'assets/images/ruleta/crupier_${_croupier(r)}.png',
                          width: min(c.maxWidth * 0.22, c.maxHeight * 0.62),
                          height: min(c.maxWidth * 0.22, c.maxHeight * 0.62),
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.none,
                          gaplessPlayback: true,
                        ),
                      ),
                      SizedBox(height: 6 * s),
                      _Bubble(text: speech, scale: s),
                    ],
                  ),
                ),
                // The wheel.
                SizedBox(
                  width: wheelSize,
                  height: wheelSize,
                  child: CustomPaint(
                    painter: _WheelPainter(_wheelState(r), Localizations.localeOf(context).languageCode),
                  ),
                ),
                SizedBox(width: 10 * s),
                // The board (or what everyone bet, once the ball is rolling).
                Expanded(
                  child: r.phase == RoulettePhase.betting && !showSign
                      ? _board(context, r)
                      : (r.phase == RoulettePhase.betting ? const SizedBox() : _bets(context, r)),
                ),
              ],
            ),
            if (showSign)
              Positioned.fill(
                child: IgnorePointer(
                  child: _Marquee(
                    text: t.rouletteAnnounce,
                    drop: Curves.easeOutBack.transform(((_t - 0.5) / 0.6).clamp(0.0, 1.0)),
                    leave: ((_t - (announce - 0.5)) / 0.5).clamp(0.0, 1.0),
                    clock: _clock,
                    scale: s,
                  ),
                ),
              ),
            if (r.phase == RoulettePhase.result)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(child: _ResultBadge(roulette: r, game: game, scale: s)),
              ),
          ],
        );
      },
    );
  }

  /// Where the wheel and the ball are now (deterministic from the seed and the clock).
  _WheelState _wheelState(Roulette r) {
    final rng = Random(r.seed);
    final start = rng.nextDouble() * 2 * pi;
    final turns = 2 * pi * (1.2 + rng.nextDouble() * 0.6);
    const roll = 6.2; // seconds until the ball sits in its pocket
    if (r.phase == RoulettePhase.betting) {
      return _WheelState(wheel: start + _clock * 0.25, ball: null, ballRadius: 0);
    }
    final u = r.phase == RoulettePhase.result ? 1.0 : ((_t + _spinOffset) / roll).clamp(0.0, 1.0);
    final wheelAngle = start + turns * (1 - pow(1 - u, 2)).toDouble();
    final n = r.number ?? 0;
    final pocket = Roulette.wheel.indexOf(n) * 2 * pi / Roulette.wheel.length;
    final ballEnd = (start + turns) + pocket;
    // The ball runs the other way round the outer track, slows down and drops in.
    final ball = ballEnd - 2 * pi * 4.5 * pow(1 - u, 2.4).toDouble();
    final drop = ((u - 0.72) / 0.22).clamp(0.0, 1.0);
    final bounce = drop > 0 && drop < 1 ? 0.035 * sin(drop * pi * 3).abs() * (1 - drop) : 0.0;
    final radius = 0.86 - (0.86 - 0.66) * Curves.easeIn.transform(drop) + bounce;
    return _WheelState(wheel: wheelAngle, ball: ball, ballRadius: radius, settled: u >= 1, number: u >= 1 ? n : null);
  }

  Widget _board(BuildContext context, Roulette r) {
    final s = widget.scale;
    final t = context.t;
    final game = widget.game;
    final me = game.localPlayerId;
    final chips = game.players.where((p) => p.id == me).firstOrNull?.chipBalance ?? 0;
    final decided = r.hasDecided(me);
    final canBet = !decided && chips >= Roulette.bets.first;
    if (_chip > chips) _chip = Roulette.bets.lastWhere((b) => b <= chips, orElse: () => Roulette.bets.first);
    final mine = r.wagers[me];

    void bet(RouletteBet b) {
      game.placeRouletteBet(me, b);
      setState(() => _picking = false);
    }

    Widget pill(String label, Color color, RouletteBetKind kind) => Expanded(
      child: Padding(
        padding: EdgeInsets.all(3 * s),
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(8 * s),
          child: InkWell(
            borderRadius: BorderRadius.circular(8 * s),
            onTap: canBet ? () => bet(RouletteBet(kind, _chip)) : null,
            child: Container(
              height: 34 * s,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8 * s),
                border: Border.all(color: RouletteOverlay.gold.withValues(alpha: 0.7)),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(color: Colors.white, fontSize: 12.5 * s, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      ),
    );

    if (decided) {
      return Center(
        child: _Bubble(
          text: mine!.passed ? t.cockYouPassed : t.rouletteYourBet('${mine.chips}', _betName(t, mine)),
          scale: s,
          color: RouletteOverlay.gold,
        ),
      );
    }
    if (!canBet) {
      return Center(
        child: _Bubble(text: t.cockNoChips, scale: s),
      );
    }

    final chipRow = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${t.rouletteChip}: ',
          style: TextStyle(color: Colors.white70, fontSize: 11 * s),
        ),
        for (final b in Roulette.bets)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 3 * s),
            child: GestureDetector(
              onTap: b <= chips ? () => setState(() => _chip = b) : null,
              child: Opacity(
                opacity: b <= chips ? 1 : 0.3,
                child: Container(
                  width: (b == _chip ? 34 : 30) * s,
                  height: (b == _chip ? 34 : 30) * s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFB71C1C),
                    border: Border.all(
                      color: b == _chip ? RouletteOverlay.gold : Colors.white,
                      width: (b == _chip ? 3 : 2) * s,
                    ),
                    boxShadow: b == _chip
                        ? [BoxShadow(color: RouletteOverlay.gold.withValues(alpha: 0.6), blurRadius: 8 * s)]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$b',
                    style: TextStyle(color: Colors.white, fontSize: 9.5 * s, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    final bottom = Row(
      children: [
        TextButton(
          onPressed: () => bet(const RouletteBet(RouletteBetKind.red, 0)),
          style: TextButton.styleFrom(foregroundColor: Colors.white70, minimumSize: Size(0, 28 * s)),
          child: Text(t.cockPass, style: TextStyle(fontSize: 11.5 * s)),
        ),
        const Spacer(),
        _Countdown(key: ValueKey('rb${r.seed}'), total: Roulette.bettingTime, scale: s),
      ],
    );

    if (_picking) {
      // The number grid: zero, then 1-36 in three rows like the felt.
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _picking = false),
                icon: Icon(Icons.arrow_back, color: Colors.white70, size: 18 * s),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  '${t.roulettePickNumber} · $_chip',
                  style: TextStyle(color: RouletteOverlay.gold, fontSize: 12 * s, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _NumberCell(n: 0, scale: s, tall: true, onTap: () => bet(RouletteBet(RouletteBetKind.number, _chip, 0))),
              Expanded(
                child: Column(
                  children: [
                    for (var row = 0; row < 3; row++)
                      Row(
                        children: [
                          for (var col = 0; col < 12; col++)
                            Expanded(
                              child: _NumberCell(
                                n: col * 3 + (3 - row),
                                scale: s,
                                onTap: () => bet(RouletteBet(RouletteBetKind.number, _chip, col * 3 + (3 - row))),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 4 * s),
          bottom,
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chipRow,
        SizedBox(height: 6 * s),
        Row(
          children: [
            pill(t.rouletteRed, RouletteOverlay.red, RouletteBetKind.red),
            pill(t.rouletteBlack, RouletteOverlay.black, RouletteBetKind.black),
          ],
        ),
        Row(
          children: [
            pill(t.rouletteEven, const Color(0xFF283593), RouletteBetKind.even),
            pill(t.rouletteOdd, const Color(0xFF4527A0), RouletteBetKind.odd),
          ],
        ),
        Text(
          t.roulettePaysOutside,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 9.5 * s),
        ),
        Padding(
          padding: EdgeInsets.all(3 * s),
          child: OutlinedButton(
            onPressed: () => setState(() => _picking = true),
            style: OutlinedButton.styleFrom(
              foregroundColor: RouletteOverlay.gold,
              side: const BorderSide(color: RouletteOverlay.gold),
              minimumSize: Size(0, 32 * s),
            ),
            child: Text(
              '${t.rouletteNumber} · ${t.roulettePaysNumber}',
              style: TextStyle(fontSize: 11.5 * s, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        bottom,
      ],
    );
  }

  String _betName(AppLocalizations t, RouletteBet b) => switch (b.kind) {
    RouletteBetKind.red => t.rouletteRed,
    RouletteBetKind.black => t.rouletteBlack,
    RouletteBetKind.even => t.rouletteEven,
    RouletteBetKind.odd => t.rouletteOdd,
    RouletteBetKind.number => '${b.number}',
  };

  /// While the ball rolls (and at the result): what everyone bet, winners in gold.
  Widget _bets(BuildContext context, Roulette r) {
    final s = widget.scale;
    final t = context.t;
    final game = widget.game;
    final done = r.phase == RoulettePhase.result;
    final rows = r.wagers.entries.where((e) => !e.value.passed).toList();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in rows.take(7))
          Container(
            margin: EdgeInsets.only(bottom: 4 * s),
            padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 4 * s),
            decoration: BoxDecoration(
              color: e.key == game.localPlayerId ? const Color(0x33FFD54F) : Colors.white10,
              borderRadius: BorderRadius.circular(7 * s),
              border: done && r.payouts.containsKey(e.key) ? Border.all(color: RouletteOverlay.gold) : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    game.players.where((p) => p.id == e.key).firstOrNull?.name ?? '?',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: 11 * s, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${_betName(t, e.value)} · ${e.value.chips}',
                  style: TextStyle(color: Colors.white70, fontSize: 10.5 * s),
                ),
                if (done) ...[
                  SizedBox(width: 6 * s),
                  Text(
                    r.payouts.containsKey(e.key) ? '+${r.payouts[e.key]! - e.value.chips}' : '-${e.value.chips}',
                    style: TextStyle(
                      color: r.payouts.containsKey(e.key) ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80),
                      fontSize: 11 * s,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _IrisClipper extends CustomClipper<Path> {
  final double open;
  const _IrisClipper(this.open);

  @override
  Path getClip(Size size) {
    final r = sqrt(size.width * size.width + size.height * size.height) / 2 * open;
    return Path()..addOval(Rect.fromCircle(center: size.center(Offset.zero), radius: max(0.01, r)));
  }

  @override
  bool shouldReclip(_IrisClipper old) => old.open != open;
}

class _Bubble extends StatelessWidget {
  final String text;
  final double scale;
  final Color color;
  const _Bubble({required this.text, required this.scale, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 6 * s),
      decoration: BoxDecoration(
        color: const Color(0xEE1A0A10),
        borderRadius: BorderRadius.circular(10 * s),
        border: Border.all(color: RouletteOverlay.gold.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 11.5 * s, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  final Duration total;
  final double scale;
  const _Countdown({super.key, required this.total, required this.scale});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: total,
      builder: (context, v, _) => SizedBox(
        width: 26 * s,
        height: 26 * s,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: v,
              strokeWidth: 3 * s,
              color: RouletteOverlay.gold,
              backgroundColor: Colors.white12,
            ),
            Text(
              '${(v * total.inSeconds).ceil()}',
              style: TextStyle(color: Colors.white, fontSize: 10 * s, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberCell extends StatelessWidget {
  final int n;
  final double scale;
  final bool tall;
  final VoidCallback onTap;
  const _NumberCell({required this.n, required this.scale, required this.onTap, this.tall = false});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: tall ? 24 * s : null,
        height: tall ? 3 * 25 * s : 25 * s,
        margin: EdgeInsets.all(0.7 * s),
        decoration: BoxDecoration(
          color: RouletteOverlay.colorOf(n),
          borderRadius: BorderRadius.circular(3 * s),
          border: Border.all(color: Colors.white24, width: 0.6),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          child: Text(
            '$n',
            style: TextStyle(color: Colors.white, fontSize: 10 * s, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

/// The casino sign announcing the bets: gold frame with chasing bulbs, drops in and lifts away.
class _Marquee extends StatelessWidget {
  final String text;
  final double drop, leave, clock, scale;
  const _Marquee({
    required this.text,
    required this.drop,
    required this.leave,
    required this.clock,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return LayoutBuilder(
      builder: (context, c) => Opacity(
        opacity: 1 - leave,
        child: Transform.translate(
          offset: Offset(0, -c.maxHeight * (1 - drop) - c.maxHeight * 0.3 * leave),
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 26 * s, vertical: 14 * s),
              decoration: BoxDecoration(
                color: const Color(0xF0240812),
                borderRadius: BorderRadius.circular(14 * s),
                border: Border.all(color: RouletteOverlay.gold, width: 3 * s),
                boxShadow: [BoxShadow(color: const Color(0xFFFF4081).withValues(alpha: 0.5), blurRadius: 24 * s)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Bulbs(clock: clock, scale: s),
                  SizedBox(height: 6 * s),
                  Text(
                    text,
                    style: TextStyle(
                      fontFamily: 'AlfaSlabOne',
                      color: RouletteOverlay.gold,
                      fontSize: 30 * s,
                      shadows: const [
                        Shadow(color: Color(0xFFFF4081), blurRadius: 14),
                        Shadow(color: Colors.black, offset: Offset(2, 2)),
                      ],
                    ),
                  ),
                  SizedBox(height: 6 * s),
                  _Bulbs(clock: clock + 0.5, scale: s),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bulbs extends StatelessWidget {
  final double clock, scale;
  const _Bulbs({required this.clock, required this.scale});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final step = (clock * 6).floor();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 16; i++)
          Container(
            width: 7 * s,
            height: 7 * s,
            margin: EdgeInsets.symmetric(horizontal: 4 * s),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (i + step) % 3 == 0 ? const Color(0xFFFFF59D) : const Color(0xFF8D6E25),
              boxShadow: (i + step) % 3 == 0 ? [BoxShadow(color: const Color(0xFFFFF59D), blurRadius: 6 * s)] : null,
            ),
          ),
      ],
    );
  }
}

class _ResultBadge extends StatelessWidget {
  final Roulette roulette;
  final GameProvider game;
  final double scale;
  const _ResultBadge({required this.roulette, required this.game, required this.scale});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final t = context.t;
    final n = roulette.number ?? 0;
    final me = game.localPlayerId;
    final bet = roulette.wagers[me];
    final won = roulette.payouts[me];
    final line = won != null
        ? t.cockYouWon('${won - bet!.chips}')
        : (bet != null && !bet.passed ? t.cockYouLost('${bet.chips}') : '');
    final word = n == 0 ? t.rouletteZero : (Roulette.isRed(n) ? t.rouletteRedWord : t.rouletteBlackWord);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 22 * s, vertical: 10 * s),
        decoration: BoxDecoration(
          color: const Color(0xF0180812),
          borderRadius: BorderRadius.circular(16 * s),
          border: Border.all(color: RouletteOverlay.gold, width: 2.5),
          boxShadow: [BoxShadow(color: RouletteOverlay.gold.withValues(alpha: 0.4), blurRadius: 20 * s)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46 * s,
              height: 46 * s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: RouletteOverlay.colorOf(n),
                border: Border.all(color: RouletteOverlay.gold, width: 2.5 * s),
              ),
              alignment: Alignment.center,
              child: Text(
                '$n',
                style: TextStyle(fontFamily: 'AlfaSlabOne', color: Colors.white, fontSize: 20 * s),
              ),
            ),
            SizedBox(width: 12 * s),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word,
                  style: TextStyle(fontFamily: 'AlfaSlabOne', color: RouletteOverlay.gold, fontSize: 20 * s),
                ),
                if (line.isNotEmpty)
                  Text(
                    line,
                    style: TextStyle(
                      color: won != null ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80),
                      fontSize: 14 * s,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelState {
  final double wheel;
  final double? ball;
  final double ballRadius;
  final bool settled;
  final int? number;
  const _WheelState({
    required this.wheel,
    required this.ball,
    required this.ballRadius,
    this.settled = false,
    this.number,
  });
}

/// European wheel: wooden bowl, gold frets, 37 pockets, a cone with a gold turret, the ball.
class _WheelPainter extends CustomPainter {
  final _WheelState st;
  final String lang;
  _WheelPainter(this.st, this.lang);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final R = size.shortestSide / 2;
    final n = Roulette.wheel.length;
    final step = 2 * pi / n;
    // Wooden bowl and gold rim.
    canvas.drawCircle(
      c,
      R,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF6D3B1E), Color(0xFF3B1E0E)],
        ).createShader(Rect.fromCircle(center: c, radius: R)),
    );
    canvas.drawCircle(
      c,
      R * 0.95,
      Paint()
        ..color = const Color(0xFFB8892E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = R * 0.03,
    );
    // Ball track.
    canvas.drawCircle(c, R * 0.9, Paint()..color = const Color(0xFF2A1408));
    canvas.drawCircle(
      c,
      R * 0.82,
      Paint()
        ..color = const Color(0xFF8D6E25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = R * 0.012,
    );
    // Pockets.
    final rect = Rect.fromCircle(center: c, radius: R * 0.78);
    for (var i = 0; i < n; i++) {
      final num = Roulette.wheel[i];
      final a = st.wheel + i * step - pi / 2 - step / 2;
      final color = num == 0
          ? const Color(0xFF0F7A3D)
          : (Roulette.isRed(num) ? const Color(0xFFB71C1C) : const Color(0xFF151518));
      canvas.drawArc(rect, a, step, true, Paint()..color = color);
      final fret = Paint()
        ..color = const Color(0xFFD4AF37)
        ..strokeWidth = max(1, R * 0.008);
      canvas.drawLine(c + Offset(cos(a), sin(a)) * R * 0.55, c + Offset(cos(a), sin(a)) * R * 0.78, fret);
      // Number, upright towards the rim.
      final mid = a + step / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: '$num',
          style: TextStyle(color: Colors.white, fontSize: R * 0.052, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(c.dx + cos(mid) * R * 0.72, c.dy + sin(mid) * R * 0.72);
      canvas.rotate(mid + pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
    // Inner pocket ring and the cone.
    canvas.drawCircle(
      c,
      R * 0.62,
      Paint()
        ..color = const Color(0xFFD4AF37)
        ..style = PaintingStyle.stroke
        ..strokeWidth = R * 0.012,
    );
    canvas.drawCircle(
      c,
      R * 0.55,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF8A5530), Color(0xFF4A2512)],
        ).createShader(Rect.fromCircle(center: c, radius: R * 0.55)),
    );
    canvas.drawCircle(
      c,
      R * 0.55,
      Paint()
        ..color = const Color(0xFFB8892E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = R * 0.015,
    );
    // Gold turret: a cross that turns with the wheel.
    final gold = Paint()
      ..color = const Color(0xFFE6BE4A)
      ..strokeWidth = R * 0.05
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 4; k++) {
      final a = st.wheel + k * pi / 2;
      canvas.drawLine(c, c + Offset(cos(a), sin(a)) * R * 0.3, gold);
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * R * 0.3, R * 0.04, Paint()..color = const Color(0xFFFFE082));
    }
    canvas.drawCircle(c, R * 0.09, Paint()..color = const Color(0xFFFFE082));
    canvas.drawCircle(c, R * 0.05, Paint()..color = const Color(0xFFB8892E));
    // The ball.
    final b = st.ball;
    if (b != null) {
      final p = c + Offset(cos(b - pi / 2), sin(b - pi / 2)) * R * st.ballRadius;
      canvas.drawCircle(p + Offset(R * 0.01, R * 0.015), R * 0.042, Paint()..color = Colors.black45);
      canvas.drawCircle(
        p,
        R * 0.04,
        Paint()
          ..shader = RadialGradient(
            colors: const [Colors.white, Color(0xFFCFD8DC)],
            center: const Alignment(-0.4, -0.4),
          ).createShader(Rect.fromCircle(center: p, radius: R * 0.04)),
      );
    }
    // The winning pocket glows once the ball has settled.
    final win = st.number;
    if (st.settled && win != null) {
      final i = Roulette.wheel.indexOf(win);
      final a = st.wheel + i * step - pi / 2 - step / 2;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: R * 0.7),
        a,
        step,
        false,
        Paint()
          ..color = const Color(0xAAFFF59D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = R * 0.16,
      );
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) => true;
}
