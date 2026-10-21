import 'package:flutter/material.dart';

/// Draws the app icon artwork (felt, cards, die, gold dashes) on the
/// adaptive-icon grid (108 units, artwork inside the 66u safe circle).
/// Shared by the launcher icon generator (`tool/render_app_icon_test.dart`)
/// and the menu logo, so both always match.
enum AppIconLayer { full, background, foreground }

class AppIconPainter extends CustomPainter {
  final AppIconLayer layer;
  AppIconPainter(this.layer);

  late double u; // one adaptive-grid unit

  @override
  void paint(Canvas canvas, Size size) {
    u = size.width / 108;
    if (layer == AppIconLayer.full) {
      final clip = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.22));
      canvas.clipRRect(clip);
      _background(canvas, size);
      // Legacy icons show the whole canvas: zoom the artwork a bit.
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(1.28);
      canvas.translate(-size.width / 2, -size.height / 2);
      _foreground(canvas);
      canvas.restore();
    } else if (layer == AppIconLayer.background) {
      _background(canvas, size);
    } else {
      _foreground(canvas);
    }
  }

  void _background(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.15),
          radius: 0.75,
          colors: [Color(0xFF1A9655), Color(0xFF0E6B3A), Color(0xFF063A1D)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
    // Gold table rail ring, just outside the safe zone.
    final c = Offset(54 * u, 54 * u);
    canvas.drawCircle(
      c,
      40 * u,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * u
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      c,
      37.6 * u,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6 * u
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.25),
    );
  }

  void _foreground(Canvas canvas) {
    _dashes(canvas);
    _card(canvas, center: Offset(45 * u, 47 * u), angle: -0.36, faceUp: false);
    _card(canvas, center: Offset(56 * u, 45 * u), angle: 0.12, faceUp: true);
    _die(canvas, center: Offset(64 * u, 66 * u), side: 27 * u, angle: 0.22);
  }

  void _shadow(Canvas canvas, RRect r, double blur) {
    canvas.drawRRect(
      r.shift(Offset(0.8 * u, 1.6 * u)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  void _card(Canvas canvas, {required Offset center, required double angle, required bool faceUp}) {
    final w = 27 * u;
    final h = 38 * u;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: h), Radius.circular(3 * u));
    _shadow(canvas, r, 2.2 * u);
    if (!faceUp) {
      canvas.drawRRect(r, Paint()..color = const Color(0xFFC62828));
      canvas.drawRRect(
        r.deflate(2 * u),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9 * u
          ..color = const Color(0xFFFFE082),
      );
      // Diamond lattice on the back.
      final lattice = Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 0.5 * u;
      canvas.save();
      canvas.clipRRect(r.deflate(3 * u));
      for (var i = -8; i <= 8; i++) {
        final x = i * 4 * u;
        canvas.drawLine(Offset(x - h, -h), Offset(x + h, h), lattice);
        canvas.drawLine(Offset(x + h, -h), Offset(x - h, h), lattice);
      }
      canvas.restore();
    } else {
      canvas.drawRRect(r, Paint()..color = const Color(0xFFFDFBF5));
      canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.4 * u
          ..color = Colors.black12,
      );
      // Corner index "A" + big centre spade.
      final tp = TextPainter(
        text: TextSpan(
          text: 'A',
          style: TextStyle(fontFamily: 'Roboto', fontSize: 9 * u, fontWeight: FontWeight.w900, color: const Color(0xFF111111), height: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-w / 2 + 2.2 * u, -h / 2 + 2 * u));
      _spade(canvas, Offset(-w / 2 + 2.2 * u + tp.width / 2, -h / 2 + 13.5 * u), 4.2 * u);
      _spade(canvas, const Offset(0, 1.5) * u, 15 * u);
    }
    canvas.restore();
  }

  void _spade(Canvas canvas, Offset c, double size) {
    final p = Paint()..color = const Color(0xFF111111);
    final s = size;
    final path = Path()
      ..moveTo(c.dx, c.dy - s * 0.55)
      ..cubicTo(c.dx + s * 0.15, c.dy - s * 0.3, c.dx + s * 0.55, c.dy - s * 0.05, c.dx + s * 0.5, c.dy + s * 0.18)
      ..cubicTo(c.dx + s * 0.45, c.dy + s * 0.42, c.dx + s * 0.15, c.dy + s * 0.45, c.dx, c.dy + s * 0.25)
      ..cubicTo(c.dx - s * 0.15, c.dy + s * 0.45, c.dx - s * 0.45, c.dy + s * 0.42, c.dx - s * 0.5, c.dy + s * 0.18)
      ..cubicTo(c.dx - s * 0.55, c.dy - s * 0.05, c.dx - s * 0.15, c.dy - s * 0.3, c.dx, c.dy - s * 0.55)
      ..close();
    canvas.drawPath(path, p);
    final stem = Path()
      ..moveTo(c.dx, c.dy + s * 0.12)
      ..lineTo(c.dx + s * 0.2, c.dy + s * 0.55)
      ..lineTo(c.dx - s * 0.2, c.dy + s * 0.55)
      ..close();
    canvas.drawPath(stem, p);
  }

  void _dashes(Canvas canvas) {
    final gold = Paint()
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(colors: [Color(0x00FFD54F), Color(0xFFFFD54F)])
          .createShader(Rect.fromLTWH(26 * u, 0, 24 * u, 1));
    for (final (y, x0, width) in [(64.0, 31.0, 2.6), (70.5, 26.0, 3.2), (77.0, 30.0, 2.6)]) {
      gold.strokeWidth = width * u;
      canvas.drawLine(Offset(x0 * u, y * u), Offset(52 * u, (y + 1.2) * u), gold);
    }
  }

  void _die(Canvas canvas, {required Offset center, required double side, required double angle}) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: side, height: side), Radius.circular(side * 0.2));
    _shadow(canvas, r, 2.6 * u);
    canvas.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF5A4E), Color(0xFFD32F2F), Color(0xFF9A1B1B)],
        ).createShader(r.outerRect),
    );
    // Glossy top highlight.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-side / 2 + side * 0.08, -side / 2 + side * 0.06, side * 0.84, side * 0.38),
        Radius.circular(side * 0.16),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7 * u
        ..color = const Color(0xFFFFE082).withValues(alpha: 0.9),
    );
    final pip = Paint()..color = Colors.white;
    final d = side * 0.26;
    for (final o in [Offset(-d, -d), Offset(d, -d), Offset.zero, Offset(-d, d), Offset(d, d)]) {
      canvas.drawCircle(o, side * 0.095, pip);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A spade suit drawn as a path (some system fonts have no '♠' glyph).
class SpadePainter extends CustomPainter {
  final Color color;
  const SpadePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.45);
    final s = size.shortestSide * 0.95;
    final p = Paint()..color = color;
    final path = Path()
      ..moveTo(c.dx, c.dy - s * 0.55)
      ..cubicTo(c.dx + s * 0.15, c.dy - s * 0.3, c.dx + s * 0.55, c.dy - s * 0.05, c.dx + s * 0.5, c.dy + s * 0.18)
      ..cubicTo(c.dx + s * 0.45, c.dy + s * 0.42, c.dx + s * 0.15, c.dy + s * 0.45, c.dx, c.dy + s * 0.25)
      ..cubicTo(c.dx - s * 0.15, c.dy + s * 0.45, c.dx - s * 0.45, c.dy + s * 0.42, c.dx - s * 0.5, c.dy + s * 0.18)
      ..cubicTo(c.dx - s * 0.55, c.dy - s * 0.05, c.dx - s * 0.15, c.dy - s * 0.3, c.dx, c.dy - s * 0.55)
      ..close()
      ..moveTo(c.dx, c.dy + s * 0.12)
      ..lineTo(c.dx + s * 0.2, c.dy + s * 0.55)
      ..lineTo(c.dx - s * 0.2, c.dy + s * 0.55)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant SpadePainter oldDelegate) => oldDelegate.color != color;
}
