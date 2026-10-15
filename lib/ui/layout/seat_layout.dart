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

  const SeatLayoutResult({required this.rects, required this.scale, required this.fits});
}

/// Pure geometry helpers that place the opponents' seats around the table
/// without overlapping each other, the local seat, the community cards,
/// the header or the on-screen controls.
///
/// The free space is split in three regions: a left column, a right column
/// and a top row (between the columns, above the community cards). Seats are
/// distributed symmetrically (n ~/ 3 per side, the rest on top) and the whole
/// set is shrunk until every region has capacity for its seats.
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
    final h = 53 * s + cardH + 6 * s;
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
      return const SeatLayoutResult(rects: [], scale: 1.0, fits: true);
    }
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
