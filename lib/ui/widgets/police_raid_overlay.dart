import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../l10n/l10n.dart';
import '../../models/police_raid.dart';
import '../../providers/game_provider.dart';

/// The garito's police raid over the Dice Dash table: the lights go out, the patrol's red and
/// blue flash through the room, the lookout shouts, and everyone decides in secret. Then the
/// comandante (or nobody: a false alarm), the outcomes, the next day's paper and, for whoever
/// ends up behind bars playing alone, the cell. Everything comes from [GameProvider.raid].
class PoliceRaidOverlay extends StatefulWidget {
  final GameProvider game;
  final double scale;
  const PoliceRaidOverlay({super.key, required this.game, required this.scale});

  static const gold = Color(0xFFFFD54F);
  static const paper = Color(0xFFF1E7CF);

  @override
  State<PoliceRaidOverlay> createState() => _PoliceRaidOverlayState();
}

class _PoliceRaidOverlayState extends State<PoliceRaidOverlay> with TickerProviderStateMixin {
  /// Drives the flashing lights and the shaking title.
  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(seconds: 1))
    ..repeat();
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
    ..forward();
  late final AnimationController _out = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  /// Time since the overlay opened, from the frame clock (so it follows the app's own time).
  late final Ticker _ticker = createTicker((d) => _now = d);
  Duration _now = Duration.zero;
  Duration _phaseAt = Duration.zero;
  RaidPhase? _phase;
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    _onPhase();
  }

  @override
  void didUpdateWidget(covariant PoliceRaidOverlay old) {
    super.didUpdateWidget(old);
    _onPhase();
  }

  void _onPhase() {
    final r = widget.game.raid;
    if (r == null || r.phase == _phase) return;
    _phase = r.phase;
    _phaseAt = _now;
    _exitTimer?.cancel();
    // The lights come back on just before the table does (the jail scene, when it follows
    // the reveal, keeps the room dark).
    final me = widget.game.localPlayerId;
    final Duration? until = switch (r.phase) {
      RaidPhase.reveal when !widget.game.isMultiplayer && r.jailed(me) && widget.game.isJailed(me) => null,
      RaidPhase.reveal => PoliceRaid.revealTimeFor(r.real),
      RaidPhase.jail => PoliceRaid.jailTime,
      _ => null,
    };
    if (until != null) {
      _exitTimer = Timer(until - const Duration(milliseconds: 750), () {
        if (mounted) _out.forward();
      });
    }
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _ticker.dispose();
    _clock.dispose();
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  double get _phaseSeconds => (_now - _phaseAt).inMilliseconds / 1000;

  @override
  Widget build(BuildContext context) {
    final r = widget.game.raid!;
    final s = widget.scale;
    return AnimatedBuilder(
      animation: Listenable.merge([_clock, _in, _out]),
      builder: (context, _) {
        final fade = _in.value * (1 - _out.value);
        if (fade <= 0) return const SizedBox.shrink();
        final edge = MediaQueryData.fromView(View.of(context)).padding;
        final lightsOn = r.phase != RaidPhase.jail && (r.phase != RaidPhase.reveal || r.real == true);
        return Opacity(
          opacity: fade,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Lights out: the whole screen, notch and system bars included; taps stop here.
              Positioned(
                left: -edge.left,
                right: -edge.right,
                top: -edge.top,
                bottom: -edge.bottom,
                child: GestureDetector(
                  onTap: () {},
                  child: ColoredBox(
                    color: r.phase == RaidPhase.jail ? const Color(0xFF0B0B0D) : const Color(0xE6070507),
                  ),
                ),
              ),
              if (lightsOn)
                Positioned(
                  left: -edge.left,
                  right: -edge.right,
                  top: -edge.top,
                  bottom: -edge.bottom,
                  child: IgnorePointer(
                    child: _PoliceLights(t: _clock.value, strong: r.phase == RaidPhase.alarm),
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12 * s, 8 * s, 12 * s, 8 * s),
                  child: switch (r.phase) {
                    RaidPhase.alarm => _Alarm(t: _clock.value, since: _phaseSeconds, scale: s),
                    RaidPhase.deciding => _Deciding(game: widget.game, raid: r, scale: s),
                    RaidPhase.scapegoat => _Scapegoat(game: widget.game, raid: r, scale: s),
                    RaidPhase.reveal => _Reveal(game: widget.game, raid: r, scale: s, since: _phaseSeconds),
                    RaidPhase.jail => _Jail(since: _phaseSeconds, scale: s),
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Red and blue washes from both sides, alternating like a patrol's light bar.
class _PoliceLights extends StatelessWidget {
  final double t;
  final bool strong;
  const _PoliceLights({required this.t, required this.strong});

  @override
  Widget build(BuildContext context) {
    final phase = (t * 3) % 1; // three flashes a second
    final red = phase < 0.5;
    final pulse = sin(phase * 2 * pi).abs();
    final a = (strong ? 0.75 : 0.45) * (0.5 + 0.5 * pulse);
    return Row(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (red ? const Color(0xFFE53935) : const Color(0xFF1E5BFF)).withValues(alpha: a),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  (red ? const Color(0xFF1E5BFF) : const Color(0xFFE53935)).withValues(alpha: a),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _portrait(String name, double size) => Image.asset(
  'assets/images/redada/$name.png',
  width: size,
  height: size,
  fit: BoxFit.fill,
  filterQuality: FilterQuality.none,
  gaplessPlayback: true,
);

/// A speech bubble next to a portrait.
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
        color: const Color(0xEE1B1412),
        borderRadius: BorderRadius.circular(10 * s),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12 * s, fontWeight: FontWeight.w600, height: 1.25),
      ),
    );
  }
}

class _Alarm extends StatelessWidget {
  final double t;
  final double since;
  final double scale;
  const _Alarm({required this.t, required this.since, required this.scale});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final shake = sin(t * 2 * pi * 9) * 3 * s;
    final slide = Curves.easeOutBack.transform((since / 0.6).clamp(0.0, 1.0));
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: Offset(-200 * s * (1 - slide), 0),
            child: _portrait((t * 4).floor() % 2 == 0 ? 'vigia_shout' : 'vigia_idle', 120 * s),
          ),
          SizedBox(width: 14 * s),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.translate(
                  offset: Offset(shake, 0),
                  child: Text(
                    context.t.raidAlarm,
                    style: TextStyle(
                      fontFamily: 'AlfaSlabOne',
                      fontSize: 40 * s,
                      color: const Color(0xFFFF5252),
                      shadows: const [
                        Shadow(color: Colors.black, offset: Offset(3, 3)),
                        Shadow(color: Color(0xFF1E5BFF), blurRadius: 18),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 6 * s),
                _Bubble(text: context.t.raidLookoutShout, scale: s),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Seconds left (counted on this device from when the phase began).
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
        width: 28 * s,
        height: 28 * s,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: v,
              strokeWidth: 3 * s,
              color: const Color(0xFFFF5252),
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

class _Deciding extends StatelessWidget {
  final GameProvider game;
  final PoliceRaid raid;
  final double scale;
  const _Deciding({required this.game, required this.raid, required this.scale});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final t = context.t;
    final me = game.localPlayerId;
    final mine = game.players.where((p) => p.id == me).firstOrNull;
    final chips = mine?.chipBalance ?? 0;
    final inIt = chips > 0 && !game.isJailed(me) && !(mine?.isBankrupt ?? true);
    final decided = raid.decided.contains(me);
    final canAct = inIt && !decided;
    final tip = raid.tips[me];
    final record = game.recordOf(me);
    final lookoutSays = tip == null ? t.raidMood(raid.mood) : (tip ? t.raidTipReal : t.raidTipFake);

    Widget action(IconData icon, String label, Color color, VoidCallback? onTap, {Widget? trailing}) => Padding(
      padding: EdgeInsets.only(bottom: 5 * s),
      child: Material(
        color: onTap == null ? Colors.white10 : color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(9 * s),
        child: InkWell(
          borderRadius: BorderRadius.circular(9 * s),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 6 * s),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 16 * s),
                SizedBox(width: 8 * s),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: 12 * s, fontWeight: FontWeight.w800),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );

    Widget chip(int amount) => Padding(
      padding: EdgeInsets.only(left: 4 * s),
      child: Material(
        color: const Color(0xFF2E7D32),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white, width: 1.5 * s),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: canAct && amount <= chips ? () => game.raidChoose(me, RaidChoice.bribe, amount) : null,
          child: SizedBox(
            width: 30 * s,
            height: 30 * s,
            child: Center(
              child: Opacity(
                opacity: amount <= chips ? 1 : 0.35,
                child: Text(
                  '$amount',
                  style: TextStyle(color: Colors.white, fontSize: 9.5 * s, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final chosen = raid.choices[me]?.$1;
    String status;
    if (!inIt) {
      status = t.raidOutOfIt;
    } else if (decided) {
      status = t.raidDecided;
    } else {
      status = '';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // The lookout, what he says, the tip, your record.
        SizedBox(
          width: 210 * s,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _portrait('vigia_idle', 96 * s),
              SizedBox(height: 6 * s),
              _Bubble(text: lookoutSays, scale: s, color: tip == null ? Colors.white : PoliceRaidOverlay.gold),
              SizedBox(height: 6 * s),
              if (tip == null && canAct && chips > PoliceRaid.tipCost + 10)
                OutlinedButton.icon(
                  onPressed: () => game.raidTip(me),
                  icon: Icon(Icons.payments_outlined, size: 14 * s),
                  label: Text(t.raidTip('${PoliceRaid.tipCost}'), style: TextStyle(fontSize: 11 * s)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PoliceRaidOverlay.gold,
                    side: const BorderSide(color: PoliceRaidOverlay.gold),
                    minimumSize: Size(0, 28 * s),
                    padding: EdgeInsets.symmetric(horizontal: 10 * s),
                  ),
                ),
              SizedBox(height: 6 * s),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${t.raidRecord}: ',
                    style: TextStyle(color: Colors.white70, fontSize: 10.5 * s),
                  ),
                  for (var i = 0; i < 5; i++)
                    Icon(
                      i < record ? Icons.star : Icons.star_border,
                      size: 12 * s,
                      color: i < record ? const Color(0xFFFF8A65) : Colors.white24,
                    ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: 14 * s),
        // What you do.
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Opacity(
                opacity: canAct ? 1 : (chosen == RaidChoice.bribe ? 1 : 0.5),
                child: action(
                  Icons.mail_outline,
                  chosen == RaidChoice.bribe ? '${t.raidBribe} · ${raid.choices[me]!.$2}' : t.raidBribe,
                  const Color(0xFF2E7D32),
                  null,
                  trailing: canAct
                      ? Row(mainAxisSize: MainAxisSize.min, children: [for (final b in PoliceRaid.bribes) chip(b)])
                      : null,
                ),
              ),
              for (final (choice, icon, label, color) in [
                (RaidChoice.hide, Icons.visibility_off_outlined, t.raidHide, const Color(0xFF5D4037)),
                (RaidChoice.flee, Icons.directions_run, t.raidFlee, const Color(0xFF1565C0)),
                (RaidChoice.snitch, Icons.record_voice_over_outlined, t.raidSnitch, const Color(0xFF6A1B9A)),
                (RaidChoice.surrender, Icons.back_hand_outlined, t.raidSurrender, const Color(0xFF8E2424)),
              ])
                Opacity(
                  opacity: canAct || chosen == choice ? 1 : 0.5,
                  child: action(
                    icon,
                    label,
                    color,
                    canAct ? () => game.raidChoose(me, choice, 0) : null,
                    trailing: chosen == choice
                        ? Icon(Icons.check_circle, color: PoliceRaidOverlay.gold, size: 16 * s)
                        : null,
                  ),
                ),
              SizedBox(height: 2 * s),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white70, fontSize: 11 * s),
                    ),
                  ),
                  _Countdown(key: ValueKey('d${raid.seed}'), total: PoliceRaid.decideTime, scale: s),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Scapegoat extends StatelessWidget {
  final GameProvider game;
  final PoliceRaid raid;
  final double scale;
  const _Scapegoat({required this.game, required this.raid, required this.scale});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final t = context.t;
    final me = game.localPlayerId;
    String nameOf(String? id) => game.players.where((p) => p.id == id).firstOrNull?.name ?? '?';
    final target = raid.scapegoatId;
    final isMe = target == me;
    final boss = raid.bossId;
    final price = 2 * PoliceRaid.priceFor(game.raid?.price ?? 0, game.recordOf(me));
    final chips = game.players.where((p) => p.id == me).firstOrNull?.chipBalance ?? 0;
    final decided = raid.scapegoatChoice != null;

    Widget option(String label, Color color, ScapegoatChoice c, {bool enabled = true}) => Padding(
      padding: EdgeInsets.only(bottom: 6 * s),
      child: FilledButton(
        onPressed: isMe && !decided && enabled ? () => game.raidScapegoat(me, c) : null,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          minimumSize: Size(double.infinity, 34 * s),
          padding: EdgeInsets.symmetric(horizontal: 10 * s),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12 * s, fontWeight: FontWeight.w800),
        ),
      ),
    );

    return Row(
      children: [
        _portrait('capo_point', 120 * s),
        SizedBox(width: 12 * s),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Bubble(
                text: boss == null ? t.raidAccuseNoBoss(nameOf(target)) : t.raidAccuse(nameOf(target)),
                scale: s,
                color: const Color(0xFFFF8A80),
              ),
              SizedBox(height: 10 * s),
              if (isMe) ...[
                // The price is only known to the host: the client sees "double" without the number.
                option(
                  game.raid?.price == null ? t.raidPayDouble('×2') : t.raidPayDouble('$price'),
                  const Color(0xFF2E7D32),
                  ScapegoatChoice.payDouble,
                  enabled: game.raid?.price == null || chips >= price,
                ),
                option(t.raidAccuseBack, const Color(0xFF6A1B9A), ScapegoatChoice.accuseBack),
                option(t.raidAcceptBlame, const Color(0xFF8E2424), ScapegoatChoice.acceptBlame),
              ] else
                Text(
                  t.raidBlamedOther(nameOf(target)),
                  style: TextStyle(color: Colors.white70, fontSize: 12 * s),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: _Countdown(key: ValueKey('s${raid.seed}'), total: PoliceRaid.scapegoatTime, scale: s),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Reveal extends StatelessWidget {
  final GameProvider game;
  final PoliceRaid raid;
  final double scale;
  final double since;
  const _Reveal({required this.game, required this.raid, required this.scale, required this.since});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final t = context.t;
    final me = game.localPlayerId;
    final real = raid.real ?? false;
    String nameOf(String id) => game.players.where((p) => p.id == id).firstOrNull?.name ?? '?';
    final myOutcome = raid.outcomes[me];
    final canCallLawyer = myOutcome?.$1 == RaidOutcome.jailed && game.lawyerAvailable(me);
    final fee = (raid.outcomes.isEmpty ? 0 : ((game.players.where((p) => p.id == me).firstOrNull?.chipBalance ?? 0)));
    final rows = raid.outcomes.entries.toList()..sort((a, b) => (a.key == me ? -1 : 0).compareTo(b.key == me ? -1 : 0));
    final paperIn = Curves.easeOutBack.transform(
      ((since - PoliceRaid.newspaperAt.inMilliseconds / 1000) / 0.6).clamp(0.0, 1.0),
    );
    final detained = [
      for (final e in raid.outcomes.entries)
        if (e.value.$1 == RaidOutcome.jailed || e.value.$1 == RaidOutcome.bossJailed) nameOf(e.key),
    ];
    final myPrice = raid.prices[me];

    final body = Row(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _portrait(
              real ? ((since * 3).floor() % 2 == 0 ? 'comandante_shout' : 'comandante_idle') : 'vigia_idle',
              104 * s,
            ),
            SizedBox(height: 6 * s),
            SizedBox(
              width: 170 * s,
              child: _Bubble(
                text: real ? t.raidReal : t.raidFake,
                scale: s,
                color: real ? const Color(0xFFFF8A80) : PoliceRaidOverlay.gold,
              ),
            ),
            if (real && myPrice != null) ...[
              SizedBox(height: 4 * s),
              Text(
                t.raidPrice('$myPrice'),
                style: TextStyle(color: Colors.white54, fontSize: 10 * s),
              ),
            ],
          ],
        ),
        SizedBox(width: 14 * s),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in rows.take(7))
                Container(
                  margin: EdgeInsets.only(bottom: 4 * s),
                  padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 4 * s),
                  decoration: BoxDecoration(
                    color: e.key == me ? const Color(0x33FFD54F) : Colors.white10,
                    borderRadius: BorderRadius.circular(7 * s),
                    border: e.key == me ? Border.all(color: PoliceRaidOverlay.gold.withValues(alpha: 0.7)) : null,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 70 * s,
                        child: Text(
                          nameOf(e.key),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white, fontSize: 11.5 * s, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          t.raidOutcome(e.value.$1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white70, fontSize: 11 * s),
                        ),
                      ),
                      Text(
                        e.value.$2 == 0 ? '—' : (e.value.$2 > 0 ? '+${e.value.$2}' : '${e.value.$2}'),
                        style: TextStyle(
                          color: e.value.$2 > 0
                              ? const Color(0xFF69F0AE)
                              : (e.value.$2 < 0 ? const Color(0xFFFF8A80) : Colors.white38),
                          fontSize: 12 * s,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              if (game.isMarked(me) && raid.choices[me]?.$1 == RaidChoice.snitch)
                Text(
                  t.raidRevenge,
                  style: TextStyle(color: const Color(0xFFFF8A65), fontSize: 11 * s, fontWeight: FontWeight.w700),
                ),
              if (myOutcome?.$1 == RaidOutcome.jailed && game.isMultiplayer)
                Text(
                  t.raidJailLan,
                  style: TextStyle(color: const Color(0xFFFF8A80), fontSize: 11 * s, fontWeight: FontWeight.w700),
                ),
              if (canCallLawyer) ...[SizedBox(height: 4 * s), _LawyerOffer(game: game, raid: raid, scale: s, fee: fee)],
            ],
          ),
        ),
      ],
    );

    return Stack(
      children: [
        body,
        if (real && paperIn > 0)
          Positioned.fill(
            child: Center(
              child: Transform.translate(
                offset: Offset(0, 300 * s * (1 - paperIn)),
                child: Transform.rotate(
                  angle: -0.06 * paperIn,
                  child: _Newspaper(detained: detained, scale: s),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LawyerOffer extends StatelessWidget {
  final GameProvider game;
  final PoliceRaid raid;
  final double scale;
  final int fee;
  const _LawyerOffer({required this.game, required this.raid, required this.scale, required this.fee});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final t = context.t;
    return Container(
      padding: EdgeInsets.all(6 * s),
      decoration: BoxDecoration(
        color: const Color(0xFF3E2A08),
        borderRadius: BorderRadius.circular(10 * s),
        border: Border.all(color: PoliceRaidOverlay.gold),
      ),
      child: Row(
        children: [
          _portrait('abogado_wink', 46 * s),
          SizedBox(width: 8 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.raidLawyerName,
                  style: TextStyle(color: PoliceRaidOverlay.gold, fontSize: 11 * s, fontWeight: FontWeight.w900),
                ),
                Text(
                  t.raidLawyerPitch,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white70, fontSize: 9.5 * s),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => game.raidLawyer(game.localPlayerId),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE6A100),
              foregroundColor: Colors.black,
              minimumSize: Size(0, 30 * s),
              padding: EdgeInsets.symmetric(horizontal: 10 * s),
            ),
            child: Text(
              t.raidLawyer('½'),
              style: TextStyle(fontSize: 11 * s, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _Newspaper extends StatelessWidget {
  final List<String> detained;
  final double scale;
  const _Newspaper({required this.detained, required this.scale});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final t = context.t;
    const ink = Color(0xFF231A12);
    return Container(
      width: 360 * s,
      padding: EdgeInsets.fromLTRB(16 * s, 10 * s, 16 * s, 12 * s),
      decoration: BoxDecoration(
        color: PoliceRaidOverlay.paper,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 24 * s, offset: Offset(4 * s, 8 * s)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.raidPaperName,
            style: TextStyle(fontFamily: 'AlfaSlabOne', color: ink, fontSize: 22 * s, letterSpacing: 2),
          ),
          Container(
            height: 2 * s,
            color: ink,
            margin: EdgeInsets.symmetric(vertical: 4 * s),
          ),
          Text(
            t.raidPaperReal,
            textAlign: TextAlign.center,
            style: TextStyle(color: ink, fontSize: 17 * s, fontWeight: FontWeight.w900, height: 1.1),
          ),
          SizedBox(height: 6 * s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A grainy photo: the comandante (or the lookout, for a false alarm).
              Container(
                color: const Color(0xFF6E6658),
                padding: EdgeInsets.all(2 * s),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    0.33, 0.33, 0.33, 0, 0, //
                    0.33, 0.33, 0.33, 0, 0, //
                    0.33, 0.33, 0.33, 0, 0, //
                    0, 0, 0, 1, 0,
                  ]),
                  child: _portrait('comandante_idle', 54 * s),
                ),
              ),
              SizedBox(width: 10 * s),
              Expanded(
                child: Text(
                  detained.isEmpty ? t.raidPaperNone : t.raidPaperDetained(detained.join(', ')),
                  style: TextStyle(color: ink, fontSize: 11.5 * s, height: 1.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Playing alone and behind bars: the cell, the sentence, then the years go by.
class _Jail extends StatelessWidget {
  final double since;
  final double scale;
  const _Jail({required this.since, required this.scale});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final t = context.t;
    final later = since > 2.6;
    return LayoutBuilder(
      builder: (context, c) => Stack(
        children: [
          // Bars.
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < 9; i++)
                  Container(
                    width: 9 * s,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF2C2F33), Color(0xFF8A9096), Color(0xFF3A3E43)]),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: c.maxHeight * 0.18,
            child: Container(height: 10 * s, color: const Color(0xFF5E646A)),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: c.maxHeight * 0.18,
            child: Container(height: 10 * s, color: const Color(0xFF5E646A)),
          ),
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: Container(
                key: ValueKey(later),
                padding: EdgeInsets.symmetric(horizontal: 22 * s, vertical: 12 * s),
                decoration: BoxDecoration(
                  color: const Color(0xEE0B0B0D),
                  borderRadius: BorderRadius.circular(10 * s),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      later ? t.raidYearsLater : t.raidSentence,
                      style: TextStyle(fontFamily: 'AlfaSlabOne', color: Colors.white, fontSize: 26 * s),
                    ),
                    if (later) ...[
                      SizedBox(height: 6 * s),
                      Text(
                        t.raidNewTable,
                        style: TextStyle(color: PoliceRaidOverlay.gold, fontSize: 13 * s, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
