import 'dart:math' as math;
import 'dart:ui';

/// Result of [SeatLayout.placeOpponents].
class SeatLayoutResult {
  /// One rectangle per opponent, ordered clockwise starting from the seat
  /// at the local player's left (left column bottom->top, top row left->right,
  /// right column top->bottom).
  final List<Rect> rects;

  /// Shrink factor (0.5 - 1.0) applied to the seat contents so they fit.
  final double scale;

  /// False only when even the minimum scale could not avoid overlaps.
  final bool fits;

  /// The felt oval drawn under the seats (decorative, seats may sit on its rail).
  final Rect table;

  const SeatLayoutResult({required this.rects, required this.scale, required this.fits, this.table = Rect.zero});
}

/// Pure geometry helpers that place the opponents' seats around the table
/// without overlapping each other, the local seat, the community cards,
/// the header or the on-screen controls.
///
/// Preferred layout: seats evenly spaced (by arc length) along the upper half
/// of an ellipse around the table, from the local player's left, over the top,
/// to their right. The set is shrunk until nothing overlaps.
///
/// Fallback when the ellipse cannot fit: the free space is split in a left
/// column, a right column and a top row (between the columns, above the
/// community cards), seats distributed symmetrically.
class SeatLayout {
  static const double gap = 4.0;
  static const double minScale = 0.5;

  /// Scale derived from BOTH dimensions. A phone in landscape is wide but short.
  static double tableScale(Size size) =>
      math.min(size.width / 800, size.height / 400).clamp(0.5, 1.3).toDouble();

  /// Same factor [CardWidget] applies internally to every card.
  static double cardAutoScale(double width) => (width / 800).clamp(0.55, 1.3).toDouble();

  static double opponentCardBase(int totalPlayers) => totalPlayers > 5 ? 0.40 : 0.48;

  /// Size of one opponent seat at shrink = 1.
  static Size opponentSeatSize({required double s, required double autoScale, required int totalPlayers}) {
    final base = opponentCardBase(totalPlayers);
    final cardW = 80 * base * autoScale;
    final cardH = 112 * base * autoScale;
    final w = math.max(2 * (cardW + 4 * s) + 10 * s, 96 * s);
    final h = 44 * s + cardH;
    return Size(w, h);
  }

  static Size localSeatSize({required double s, required double autoScale}) {
    final w = 2 * (80 * 0.75 * autoScale + 4 * s) + 10 * s;
    final h = 53 * s + 112 * 0.75 * autoScale;
    return Size(w, h);
  }

  static double communityWidth(double autoScale) => 5 * (80 * 0.65 * autoScale + 4);

  /// Widgets of the table that opponents must never cover (used by tests too).
  static List<Rect> fixedObstacles(Size size, {required bool diceMode}) {
    final w = size.width;
    final h = size.height;
    final s = tableScale(size);
    final a = cardAutoScale(w);
    final local = localSeatSize(s: s, autoScale: a);
    final commW = communityWidth(a);
    return [
      Rect.fromLTRB(0, 0, w, 46 * s), // header
      Rect.fromLTRB(w / 2 - local.width / 2, h - local.height, w / 2 + local.width / 2, h), // local seat
      Rect.fromLTRB(w / 2 - commW / 2, h * 0.35, w / 2 + commW / 2, h * 0.35 + 84 * s), // community cards
      Rect.fromLTRB(w * 0.05, h - h * 0.06 - 56 * s, w * 0.05 + 270 * s, h - h * 0.06), // action panel
      Rect.fromLTRB(w - w * 0.03 - 150 * s, h - h * 0.04 - 48 * s, w - w * 0.03, h - h * 0.04), // roll button
      Rect.fromLTRB(w - w * 0.03 - 150 * s, h - h * 0.28 - 36 * s, w - w * 0.03, h - h * 0.28), // start button
      if (diceMode)
        Rect.fromLTRB(w * 0.25, h - h * 0.28 - 40 * s, w * 0.25 + 100 * s, h - h * 0.28), // dice
    ];
  }

  static int _capacity(double length, double item) {
    if (item <= 0 || length <= 0) return 0;
    return math.max(0, ((length + gap) / (item + gap)).floor());
  }

  static List<double> _spread(double lo, double hi, int n) {
    if (n <= 0) return const [];
    final span = hi - lo;
    return [for (var i = 0; i < n; i++) lo + span * (i + 0.5) / n];
  }

  static SeatLayoutResult placeOpponents({
    required Size size,
    required int opponents,
    required bool diceMode,
  }) {
    if (opponents <= 0) {
      return SeatLayoutResult(rects: const [], scale: 1.0, fits: true, table: tableRect(size, diceMode: diceMode));
    }
    final oval = _placeOnEllipse(size: size, opponents: opponents, diceMode: diceMode);
    if (oval != null) return oval;
    final cols = _placeInColumns(size: size, opponents: opponents, diceMode: diceMode);
    return SeatLayoutResult(rects: cols.rects, scale: cols.scale, fits: cols.fits, table: tableRect(size, diceMode: diceMode));
  }

  /// Felt oval: spans the table between the side seats and tucks under the local seat.
  static Rect tableRect(Size size, {required bool diceMode}) {
    final w = size.width;
    final h = size.height;
    final s = tableScale(size);
    final a = cardAutoScale(w);
    final local = localSeatSize(s: s, autoScale: a);
    final top = 46 * s + 34 * s;
    final bottom = math.max(top + 80 * s, h - local.height * 0.45);
    final side = math.max(40 * s, w * 0.09);
    return Rect.fromLTRB(side, top, w - side, bottom);
  }

  static SeatLayoutResult? _placeOnEllipse({
    required Size size,
    required int opponents,
    required bool diceMode,
  }) {
    final w = size.width;
    final h = size.height;
    final s = tableScale(size);
    final a = cardAutoScale(w);
    final base = opponentSeatSize(s: s, autoScale: a, totalPlayers: opponents + 1);
    final obstacles = fixedObstacles(size, diceMode: diceMode).skip(1).toList(); // header handled by yTop
    final header = 46 * s;
    final actionTop = h - h * 0.06 - 56 * s;
    final rollTop = h - h * 0.04 - 48 * s;
    final startTop = h - h * 0.28 - 36 * s;
    final screen = Offset.zero & size;

    for (var k = 1.0; k >= minScale - 1e-9; k *= 0.94) {
      final sw = base.width * k;
      final sh = base.height * k;
      final yTop = header + gap + sh / 2;
      final cy = math.min(actionTop, math.min(rollTop, startTop)) - gap - sh / 2;
      final rx = w / 2 - 6 - sw / 2;
      final ry = cy - yTop;
      if (rx <= 0 || ry <= 0) continue;

      final rects = [
        for (final c in _ellipseArcPoints(Offset(w / 2, cy), rx, ry, opponents))
          Rect.fromCenter(center: c, width: sw, height: sh),
      ];
      var ok = true;
      for (var i = 0; i < rects.length && ok; i++) {
        final r = rects[i];
        if (!(screen.contains(r.topLeft) && screen.contains(r.bottomRight))) ok = false;
        for (var j = i + 1; j < rects.length && ok; j++) {
          if (r.inflate(gap / 2).overlaps(rects[j].inflate(gap / 2))) ok = false;
        }
        for (final o in obstacles) {
          if (ok && r.overlaps(o)) ok = false;
        }
      }
      if (ok) {
        return SeatLayoutResult(rects: rects, scale: k, fits: true, table: tableRect(size, diceMode: diceMode));
      }
    }
    return null;
  }

  /// [n] points evenly spaced by arc length on the upper half of the ellipse,
  /// ordered left -> top -> right (clockwise from the local player's left).
  static List<Offset> _ellipseArcPoints(Offset c, double rx, double ry, int n) {
    const steps = 360;
    final pts = <Offset>[];
    final cum = <double>[0];
    for (var i = 0; i <= steps; i++) {
      final t = math.pi + math.pi * i / steps;
      pts.add(Offset(c.dx + rx * math.cos(t), c.dy + ry * math.sin(t)));
      if (i > 0) cum.add(cum.last + (pts[i] - pts[i - 1]).distance);
    }
    final total = cum.last;
    final out = <Offset>[];
    var j = 0;
    for (var i = 0; i < n; i++) {
      final target = total * (i + 0.5) / n;
      while (j < steps && cum[j + 1] < target) {
        j++;
      }
      final seg = cum[j + 1] - cum[j];
      final f = seg <= 0 ? 0.0 : (target - cum[j]) / seg;
      out.add(Offset.lerp(pts[j], pts[j + 1], f)!);
    }
    return out;
  }

  static SeatLayoutResult _placeInColumns({
    required Size size,
    required int opponents,
    required bool diceMode,
  }) {
    final w = size.width;
    final h = size.height;
    final s = tableScale(size);
    final a = cardAutoScale(w);
    final base = opponentSeatSize(s: s, autoScale: a, totalPlayers: opponents + 1);

    final header = 46 * s;
    final commHalf = communityWidth(a) / 2;
    final commTop = h * 0.35;
    final actionTop = h - h * 0.06 - 56 * s;
    final rollTop = h - h * 0.04 - 48 * s;
    final startTop = h - h * 0.28 - 36 * s;

    final colRight = math.min(w / 2 - commHalf - gap * 2, diceMode ? w * 0.25 - gap : double.infinity);
    final leftX = [6.0, colRight];
    final rightX = [w - colRight, w - 6.0];
    final colTop = header + gap;
    final leftBottom = actionTop - gap;
    final rightBottom = math.min(rollTop, startTop) - gap;
    final topX = [colRight + gap, w - colRight - gap];
    final topBand = [colTop, commTop - gap];

    var k = 1.0;
    var sides = 0;
    var top = opponents;
    var ok = false;
    late double sw;
    late double sh;
    while (true) {
      sw = base.width * k;
      sh = base.height * k;
      final capL = (leftX[1] - leftX[0]) >= sw ? _capacity(leftBottom - colTop, sh) : 0;
      final capR = (rightX[1] - rightX[0]) >= sw ? _capacity(rightBottom - colTop, sh) : 0;
      final capT = (topBand[1] - topBand[0]) >= sh ? _capacity(topX[1] - topX[0], sw) : 0;
      final sideCap = math.min(capL, capR);
      sides = math.min(opponents ~/ 3, sideCap);
      top = opponents - 2 * sides;
      while (top > capT && sides < sideCap) {
        sides++;
        top = opponents - 2 * sides;
      }
      ok = top >= 0 && top <= capT;
      if (ok || k <= minScale + 1e-9) break;
      k = math.max(minScale, k * 0.93);
    }

    if (!ok) {
      // Last resort: spread everything on one row; FittedBox in the widget keeps it readable.
      final rects = [
        for (final x in _spread(6, w - 6, opponents))
          Rect.fromCenter(center: Offset(x, (topBand[0] + topBand[1]) / 2), width: sw, height: sh),
      ];
      return SeatLayoutResult(rects: rects, scale: k, fits: false);
    }

    final rects = <Rect>[];
    final leftCx = (leftX[0] + leftX[1]) / 2;
    final rightCx = (rightX[0] + rightX[1]) / 2;
    final topCy = (topBand[0] + topBand[1]) / 2;
    for (final y in _spread(colTop, leftBottom, sides).reversed) {
      rects.add(Rect.fromCenter(center: Offset(leftCx, y), width: sw, height: sh));
    }
    for (final x in _spread(topX[0], topX[1], top)) {
      rects.add(Rect.fromCenter(center: Offset(x, topCy), width: sw, height: sh));
    }
    for (final y in _spread(colTop, rightBottom, sides)) {
      rects.add(Rect.fromCenter(center: Offset(rightCx, y), width: sw, height: sh));
    }
    return SeatLayoutResult(rects: rects, scale: k, fits: true);
  }
}
