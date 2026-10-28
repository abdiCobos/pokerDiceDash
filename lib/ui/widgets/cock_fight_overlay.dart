import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../l10n/l10n.dart';
import '../../models/cock_fight.dart';
import '../../providers/game_provider.dart';

/// Full-screen cockfight over the Dice Dash table (cantina only): bets, the boxing match in
/// pixel art, and the result. Everything it shows comes from [GameProvider.cockFight].
///
/// It comes in like a cascade (velvet strips falling one after another, then the hanging
/// "¡Pelea de gallos!" sign) and leaves the same way, falling off the bottom of the screen,
/// so the table never comes back from one frame to the next.
class CockFightOverlay extends StatefulWidget {
  final GameProvider game;
  final double scale;
  const CockFightOverlay({super.key, required this.game, required this.scale});

  static const _gold = Color(0xFFFFD54F);

  @override
  State<CockFightOverlay> createState() => _CockFightOverlayState();
}

class _CockFightOverlayState extends State<CockFightOverlay> with TickerProviderStateMixin {
  static const _strips = 9;
  late final AnimationController _in = AnimationController(vsync: this, duration: CockFight.announceTime);
  late final AnimationController _out = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    // Joining in the middle of a fight: no announcement.
    if (widget.game.cockFight?.phase == CockFightPhase.betting) {
      _in.forward();
    } else {
      _in.value = 1;
    }
    _scheduleExit();
  }

  @override
  void didUpdateWidget(covariant CockFightOverlay old) {
    super.didUpdateWidget(old);
    _scheduleExit();
  }

  void _scheduleExit() {
    if (widget.game.cockFight?.phase != CockFightPhase.result || _exitTimer != null) return;
    _exitTimer = Timer(CockFight.exitAt, () {
      if (mounted) _out.forward();
    });
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  static double _seg(double t, double from, double length) => ((t - from) / length).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final f = widget.game.cockFight!;
    final announce = CockFight.announceTime.inMilliseconds / 1000;
    return AnimatedBuilder(
      animation: Listenable.merge([_in, _out]),
      builder: (context, _) {
        if (_out.isCompleted) return const SizedBox.shrink();
        final inT = _in.value * announce;
        final outT = _out.value;
        final content = _seg(inT, announce - 0.45, 0.45) * (1 - _seg(outT, 0, 0.25));
        return LayoutBuilder(
          builder: (context, c) {
            final h = c.maxHeight;
            final stripW = c.maxWidth / _strips;
            return Stack(
              children: [
                // Velvet strips falling in one after another (and out the same way); taps on the
                // table underneath never get through while they are up.
                for (var i = 0; i < _strips; i++)
                  Positioned(
                    left: i * stripW - 0.5,
                    width: stripW + 1,
                    top:
                        -h * (1 - Curves.easeOutCubic.transform(_seg(inT, i * 0.05, 0.35))) +
                        h * Curves.easeInCubic.transform(_seg(outT, 0.15 + i * 0.05, 0.4)),
                    height: h,
                    child: GestureDetector(
                      onTap: () {},
                      child: _Strip(scale: widget.scale),
                    ),
                  ),
                if (content > 0)
                  Opacity(
                    opacity: content,
                    child: Transform.scale(scale: 0.94 + 0.06 * content, child: _body(context, f)),
                  ),
                if (inT > 0.5 && inT < announce)
                  _Announcement(
                    drop: Curves.easeOutBack.transform(_seg(inT, 0.55, 0.55)),
                    leave: _seg(inT, announce - 0.5, 0.5),
                    height: h,
                    scale: widget.scale,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _body(BuildContext context, CockFight f) {
    final game = widget.game;
    final s = widget.scale;
    final t = context.t;
    final me = game.localPlayerId;
    final myChips = game.players.where((p) => p.id == me).firstOrNull?.chipBalance ?? 0;
    final betting = f.phase == CockFightPhase.betting;
    final decided = f.hasDecided(me);
    final canBet = betting && !decided && myChips >= CockFight.bets.first;

    Widget card(int rooster) =>
        _RoosterCard(fight: f, rooster: rooster, game: game, scale: s, canBet: canBet, myChips: myChips);

    final status = switch (f.phase) {
      CockFightPhase.betting when !decided && myChips < CockFight.bets.first => t.cockNoChips,
      CockFightPhase.betting when decided =>
        f.wagerChips(me) > 0 ? t.cockYourBet('${f.wagerChips(me)}', f.fighters[f.wagerRooster(me)!]) : t.cockYouPassed,
      CockFightPhase.betting => t.cockPrompt,
      CockFightPhase.fighting =>
        f.wagerChips(me) > 0 ? t.cockYourBet('${f.wagerChips(me)}', f.fighters[f.wagerRooster(me)!]) : '',
      CockFightPhase.result => t.cockNextHand,
    };

    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(10 * s, 6 * s, 10 * s, 6 * s),
            child: Column(
              children: [
                _TitlePill(text: t.cockTitle, scale: s),
                SizedBox(height: 4 * s),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 150 * s, child: card(0)),
                      SizedBox(width: 8 * s),
                      Expanded(
                        child: _Arena(fight: f, scale: s),
                      ),
                      SizedBox(width: 8 * s),
                      SizedBox(width: 150 * s, child: card(1)),
                    ],
                  ),
                ),
                SizedBox(height: 4 * s),
                SizedBox(
                  height: 34 * s,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (status.isNotEmpty)
                        Flexible(
                          child: Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white, fontSize: 13 * s, fontWeight: FontWeight.w600),
                          ),
                        ),
                      if (canBet) ...[
                        SizedBox(width: 12 * s),
                        OutlinedButton(
                          onPressed: () => game.placeCockBet(me, 0, 0),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: EdgeInsets.symmetric(horizontal: 18 * s),
                            minimumSize: Size(0, 30 * s),
                          ),
                          child: Text(t.cockPass, style: TextStyle(fontSize: 12 * s)),
                        ),
                      ],
                      // The clock starts when the announcement is over.
                      if (betting && _in.isCompleted) ...[
                        SizedBox(width: 12 * s),
                        _Countdown(key: ValueKey(f.seed), scale: s),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (f.phase == CockFightPhase.result)
          Positioned.fill(
            child: _ResultBanner(fight: f, game: game, scale: s),
          ),
      ],
    );
  }
}

/// One velvet strip of the curtain: deep red with a gold fringe at the bottom.
class _Strip extends StatelessWidget {
  final double scale;
  const _Strip({required this.scale});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF1E0705), Color(0xFF3B0F0A), Color(0xFF4A160E), Color(0xFF2A0A07)],
          stops: [0, 0.35, 0.6, 1],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 5 * s,
          decoration: BoxDecoration(
            color: const Color(0xFFB8892E),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 4 * s, offset: Offset(0, -1 * s))],
          ),
        ),
      ),
    );
  }
}

/// The hanging sign that announces the fight: drops in with a bounce, then lifts away when the
/// betting opens.
class _Announcement extends StatelessWidget {
  final double drop; // 0 -> 1 (with overshoot)
  final double leave; // 0 -> 1
  final double height;
  final double scale;
  const _Announcement({required this.drop, required this.leave, required this.height, required this.scale});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final t = context.t;
    Widget rooster(String kind, bool faceRight) => Transform.flip(
      flipX: !faceRight,
      child: Image.asset(
        'assets/images/gallos/${kind}_idle0.png',
        width: 78 * s,
        height: 78 * s,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
      ),
    );
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: 1 - leave,
          child: Transform.translate(
            offset: Offset(0, -height * (1 - drop) - height * 0.25 * leave),
            child: Transform.scale(
              scale: 1 - 0.3 * leave,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The ropes it hangs from.
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 3 * s, height: 30 * s, color: const Color(0xFF8D6E4A)),
                        SizedBox(width: 260 * s),
                        Container(width: 3 * s, height: 30 * s, color: const Color(0xFF8D6E4A)),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 22 * s, vertical: 12 * s),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF7A4522), Color(0xFF5A2F15)],
                        ),
                        borderRadius: BorderRadius.circular(10 * s),
                        border: Border.all(color: CockFightOverlay._gold, width: 3 * s),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 18 * s)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          rooster('colorado', true),
                          SizedBox(width: 10 * s),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t.cockTitle.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'AlfaSlabOne',
                                  color: CockFightOverlay._gold,
                                  fontSize: 30 * s,
                                  shadows: const [Shadow(color: Colors.black, offset: Offset(2, 2))],
                                ),
                              ),
                              SizedBox(height: 4 * s),
                              Text(
                                t.cockPrompt,
                                style: TextStyle(color: Colors.white, fontSize: 16 * s, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          SizedBox(width: 10 * s),
                          rooster('giro', false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitlePill extends StatelessWidget {
  final String text;
  final double scale;
  const _TitlePill({required this.text, required this.scale});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 4 * s),
        decoration: BoxDecoration(
          color: const Color(0xFF7A1E14),
          borderRadius: BorderRadius.circular(20 * s),
          border: Border.all(color: CockFightOverlay._gold, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 10 * s)],
        ),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontFamily: 'AlfaSlabOne',
            color: CockFightOverlay._gold,
            fontSize: 18 * s,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

/// Seconds left to bet (counted on this device from when the betting opened).
class _Countdown extends StatelessWidget {
  final double scale;
  const _Countdown({super.key, required this.scale});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: CockFight.bettingTime,
      builder: (context, v, _) => SizedBox(
        width: 26 * s,
        height: 26 * s,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: v,
              strokeWidth: 3 * s,
              color: CockFightOverlay._gold,
              backgroundColor: Colors.white12,
            ),
            Text(
              '${(v * CockFight.bettingTime.inSeconds).ceil()}',
              style: TextStyle(color: Colors.white, fontSize: 10 * s, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoosterCard extends StatelessWidget {
  final CockFight fight;
  final int rooster;
  final GameProvider game;
  final double scale;
  final bool canBet;
  final int myChips;
  const _RoosterCard({
    required this.fight,
    required this.rooster,
    required this.game,
    required this.scale,
    required this.canBet,
    required this.myChips,
  });

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final t = context.t;
    final f = fight;
    final fav = rooster == f.favorite;
    final accent = rooster == 0 ? const Color(0xFFE53935) : const Color(0xFF1E88E5);
    final won = f.phase == CockFightPhase.result && f.winner == rooster;
    final mult = f.paysFor(rooster);
    final multText = mult == mult.roundToDouble() ? mult.toStringAsFixed(0) : mult.toStringAsFixed(1);
    final backers = [
      for (final e in f.wagers.entries)
        if (e.value.$1 == rooster && e.value.$2 > 0)
          '${game.players.where((p) => p.id == e.key).firstOrNull?.name ?? '?'} ${e.value.$2}',
    ];
    final mine = f.wagerRooster(game.localPlayerId) == rooster && f.wagerChips(game.localPlayerId) > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.all(7 * s),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0E08).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12 * s),
        border: Border.all(
          color: won || mine ? CockFightOverlay._gold : accent.withValues(alpha: 0.7),
          width: won || mine ? 2.5 : 1.5,
        ),
        boxShadow: [if (won) BoxShadow(color: CockFightOverlay._gold.withValues(alpha: 0.5), blurRadius: 14 * s)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/gallos/${CockFight.kinds[rooster]}_idle0.png',
            width: 52 * s,
            height: 52 * s,
            filterQuality: FilterQuality.none,
            fit: BoxFit.contain,
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              f.fighters[rooster],
              style: TextStyle(color: Colors.white, fontSize: 13 * s, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 2 * s),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 1 * s),
            decoration: BoxDecoration(
              color: fav ? const Color(0xFF6D4C00) : const Color(0xFF0D4D5C),
              borderRadius: BorderRadius.circular(8 * s),
            ),
            child: Text(
              '${fav ? t.cockFavorite : t.cockUnderdog} · ${t.cockPays(multText)}',
              style: TextStyle(
                color: fav ? CockFightOverlay._gold : const Color(0xFF80DEEA),
                fontSize: 9 * s,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: 6 * s),
          if (canBet)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final b in CockFight.bets)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2 * s),
                    child: _ChipButton(
                      amount: b,
                      color: accent,
                      enabled: b <= myChips,
                      scale: s,
                      onTap: () => game.placeCockBet(game.localPlayerId, rooster, b),
                    ),
                  ),
              ],
            )
          else
            SizedBox(
              height: 28 * s,
              child: Center(
                child: Text(
                  backers.isEmpty ? '—' : backers.join(' · '),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white70, fontSize: 9 * s),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final int amount;
  final Color color;
  final bool enabled;
  final double scale;
  final VoidCallback onTap;
  const _ChipButton({
    required this.amount,
    required this.color,
    required this.enabled,
    required this.scale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: color,
        shape: CircleBorder(
          side: BorderSide(color: Colors.white, width: 2 * s),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 34 * s,
            height: 34 * s,
            child: Center(
              child: Text(
                '$amount',
                style: TextStyle(color: Colors.white, fontSize: 11 * s, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final CockFight fight;
  final GameProvider game;
  final double scale;
  const _ResultBanner({required this.fight, required this.game, required this.scale});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final t = context.t;
    final me = game.localPlayerId;
    final won = fight.payouts[me];
    final bet = fight.wagerChips(me);
    final line = won != null ? t.cockYouWon('${won - bet}') : (bet > 0 ? t.cockYouLost('$bet') : '');
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.3, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 26 * s, vertical: 12 * s),
          decoration: BoxDecoration(
            color: const Color(0xF0200F08),
            borderRadius: BorderRadius.circular(16 * s),
            border: Border.all(color: CockFightOverlay._gold, width: 2.5),
            boxShadow: [BoxShadow(color: CockFightOverlay._gold.withValues(alpha: 0.4), blurRadius: 20 * s)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.cockWins(fight.fighters[fight.winner ?? 0]),
                style: TextStyle(fontFamily: 'AlfaSlabOne', color: CockFightOverlay._gold, fontSize: 22 * s),
              ),
              if (line.isNotEmpty) ...[
                SizedBox(height: 4 * s),
                Text(
                  line,
                  style: TextStyle(
                    color: won != null ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80),
                    fontSize: 16 * s,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// --- The ring and the fight animation ----------------------------------------------------------

/// One sprite in the ring, in ring units (the ring image is 200 x 90).
class _Actor {
  final String asset;
  final double x; // centre
  final bool faceRight;
  final double dy;
  const _Actor(this.asset, this.x, this.faceRight, [this.dy = 0]);
}

class _Pop {
  final String text;
  final double x, y, size;
  final Color color;

  /// Pixel icons instead of text: 'heart' or 'star', [count] of them.
  final String? icon;
  final int count;
  const _Pop(this.text, this.x, this.y, this.size, this.color) : icon = null, count = 0;
  const _Pop.icons(this.icon, this.count, this.x, this.y, this.size) : text = '', color = Colors.transparent;
}

class _Scene {
  final List<_Actor> actors = [];
  final List<_Pop> pops = [];
}

class _Arena extends StatefulWidget {
  final CockFight fight;
  final double scale;
  const _Arena({required this.fight, required this.scale});

  @override
  State<_Arena> createState() => _ArenaState();
}

class _ArenaState extends State<_Arena> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _now = Duration.zero;
  Duration? _fightStart;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => setState(() => _now = d))..start();
    if (widget.fight.phase == CockFightPhase.fighting) _fightStart = Duration.zero;
  }

  @override
  void didUpdateWidget(covariant _Arena old) {
    super.didUpdateWidget(old);
    if (widget.fight.phase == CockFightPhase.fighting && _fightStart == null) _fightStart = _now;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  static String _r(int rooster, String frame) => 'assets/images/gallos/${CockFight.kinds[rooster]}_$frame.png';

  _Scene _scene() {
    final f = widget.fight;
    final scene = _Scene();
    final clock = _now.inMilliseconds / 1000.0;
    final bob = (clock * 2.5).floor() % 2;
    final start = _fightStart;
    if (f.phase == CockFightPhase.betting || start == null) {
      // Warming up in their corners.
      scene.actors
        ..add(_Actor(_r(0, 'idle$bob'), 44, true))
        ..add(_Actor(_r(1, 'idle${1 - bob}'), 156, false));
      return scene;
    }
    final t = (_now - start).inMilliseconds / 1000.0;
    if (f.phase == CockFightPhase.result || t >= 14) return scene; // they all left the ring
    final w = f.winner ?? f.favorite;
    final l = 1 - w;
    final walk = (t / 0.15).floor() % 2;
    double home(int r) => r == 0 ? 44 : 156;
    bool facesIn(int r) => r == 0;

    if (t < 1.2) {
      final k = t / 1.2;
      for (final r in [0, 1]) {
        final x = home(r) + (r == 0 ? 30.0 : -30.0) * k;
        scene.actors.add(_Actor(_r(r, 'walk$walk'), x, facesIn(r)));
      }
      return scene;
    }
    const fx = [74.0, 126.0];
    if (t < 6.6) {
      // Nine exchanges; the winner lands more of them, and always the last.
      final beat = ((t - 1.2) / 0.6).floor();
      final bt = (t - 1.2) - beat * 0.6;
      final rng = Random(f.seed + beat);
      final attacker = beat == 8 ? w : (rng.nextDouble() < 0.6 ? w : l);
      final defender = 1 - attacker;
      final hitting = bt < 0.28;
      for (final r in [0, 1]) {
        final dir = r == 0 ? 1.0 : -1.0;
        String frame;
        var x = fx[r];
        if (hitting && r == attacker) {
          frame = 'punch';
          x += 4 * dir;
        } else if (hitting && r == defender) {
          frame = 'hit';
          x -= 5 * dir;
        } else {
          frame = 'idle${(beat + r) % 2}';
        }
        scene.actors.add(_Actor(_r(r, frame), x, facesIn(r)));
      }
      if (hitting) {
        final words = ['¡PAF!', '¡PUM!', '¡ZAS!', '¡POW!'];
        scene.pops.add(
          _Pop(words[beat % words.length], 100 + (attacker == 0 ? 6 : -6), 22, 9, const Color(0xFFFFEB3B)),
        );
      }
      return scene;
    }
    final wx = fx[w];
    final lDir = l == 0 ? -1.0 : 1.0; // the loser flies towards its own corner
    if (t < 7.6) {
      final k = ((t - 6.6) / 0.5).clamp(0.0, 1.0);
      scene.actors
        ..add(_Actor(_r(w, t < 6.9 ? 'punch' : 'idle0'), wx, facesIn(w)))
        ..add(_Actor(_r(l, k < 1 ? 'hit' : 'ko'), fx[l] + lDir * 26 * k, facesIn(l), -10 * sin(k * pi)));
      scene.pops.add(_Pop('K.O.', 100, 18, 16 + 4 * k, const Color(0xFFFF5252)));
      return scene;
    }
    final lx = fx[l] + lDir * 26;
    // The loser: dizzy on the floor, then gets up and walks off to its corner (no harm done).
    if (t < 9.2) {
      scene.actors.add(_Actor(_r(l, 'ko'), lx, facesIn(l)));
      scene.pops.add(_Pop.icons('star', 3, lx, 40 + 2 * sin(t * 8), 7));
    } else if (t < 10.6) {
      final k = (t - 9.2) / 1.4;
      scene.actors.add(_Actor(_r(l, t < 9.6 ? 'dizzy' : 'walk$walk'), lx + lDir * 80 * max(0, k - 0.3), lDir > 0));
    }
    // The winner celebrates; the hen comes from his corner with the cigar.
    final wSide = w == 0 ? -1.0 : 1.0;
    final henStop = wx + wSide * 34;
    final henFrom = w == 0 ? -30.0 : 230.0;
    if (t < 9.4) {
      final hop = ((t * 4).floor() % 2 == 0) ? -3.0 : 0.0;
      scene.actors.add(_Actor(_r(w, 'celebrate'), wx, facesIn(w), hop));
      return scene;
    }
    if (t < 10.8) {
      final k = (t - 9.4) / 1.4;
      scene.actors
        ..add(_Actor(_r(w, 'idle$walk'), wx, !facesIn(w)))
        ..add(_Actor('assets/images/gallos/hen_walk$walk.png', henFrom + (henStop - henFrom) * k, w == 0));
      scene.pops.add(_Pop.icons('heart', 1, henFrom + (henStop - henFrom) * k, 8, 8));
      return scene;
    }
    if (t < 11.6) {
      scene.actors
        ..add(_Actor(_r(w, 'idle0'), wx, !facesIn(w)))
        ..add(_Actor('assets/images/gallos/hen_give.png', henStop, w == 0));
      return scene;
    }
    if (t < 12.4) {
      scene.actors
        ..add(_Actor(_r(w, 'cigar'), wx, !facesIn(w)))
        ..add(_Actor('assets/images/gallos/hen_hug.png', henStop - wSide * 8, w == 0));
      scene.pops.add(_Pop.icons('heart', 2, (wx + henStop) / 2, 8 - (t - 11.6) * 6, 9));
      return scene;
    }
    // Off they go together, the hen on his arm, out through his corner.
    final k = (t - 12.4) / 1.6;
    final shift = wSide * 140 * k;
    scene.actors
      ..add(_Actor(_r(w, 'walkc$walk'), wx + shift, w == 1))
      ..add(_Actor('assets/images/gallos/hen_walk$walk.png', henStop - wSide * 8 + shift, w == 1));
    scene.pops.add(_Pop.icons('heart', 1, (wx + henStop) / 2 + shift, 6 - k * 6, 9));
    return scene;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Keep the ring's 200 x 90 shape inside the space we get.
        final unit = min(c.maxWidth / 200, c.maxHeight / 90);
        final w = 200 * unit;
        final h = 90 * unit;
        final scene = _scene();
        const sprite = 60.0; // the 48 px sprites, a bit bigger than the ring's pixels
        const ground = 76.0; // feet line in ring units (feet sit at 43/48 of the sprite)
        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/gallos/ring.png',
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                  for (final a in scene.actors)
                    Positioned(
                      left: (a.x - sprite / 2) * unit,
                      top: (ground - sprite * 43 / 48 + a.dy) * unit,
                      width: sprite * unit,
                      height: sprite * unit,
                      child: Transform.flip(
                        flipX: !a.faceRight,
                        child: Image.asset(
                          a.asset,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.none,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  for (final p in scene.pops)
                    Positioned(
                      left: (p.x - 40) * unit,
                      width: 80 * unit,
                      top: p.y * unit,
                      child: Center(
                        child: p.icon != null
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < p.count; i++)
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 1.5 * unit),
                                      child: Image.asset(
                                        'assets/images/gallos/${p.icon}.png',
                                        width: p.size * unit,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.none,
                                      ),
                                    ),
                                ],
                              )
                            : Text(
                                p.text,
                                style: TextStyle(
                                  fontFamily: 'AlfaSlabOne',
                                  color: p.color,
                                  fontSize: p.size * unit,
                                  shadows: const [Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1, 1))],
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
