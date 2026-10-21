import 'dart:math';

import 'package:flutter/material.dart';
import '../../models/card_model.dart';

class CardWidget extends StatelessWidget {
  final CardModel card;
  final bool isFaceUp;
  final VoidCallback? onTap;
  final double scale;

  static const double cardWidth = 80;
  static const double cardHeight = 112;

  const CardWidget({
    super.key,
    required this.card,
    required this.isFaceUp,
    this.onTap,
    this.scale = 1.0,
  });

  /// Extra factor every card gets from the screen width. Layouts that reserve
  /// space for cards must multiply by it (the card box is `cardWidth * scale * autoScale`).
  static double autoScaleOf(BuildContext context) =>
      (MediaQuery.of(context).size.width / 800).clamp(0.55, 1.3).toDouble();

  @override
  Widget build(BuildContext context) {
    final effectiveScale = scale * autoScaleOf(context);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: cardWidth * effectiveScale,
        height: cardHeight * effectiveScale,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            final tiltAnimation = Tween<double>(
              begin: isFaceUp ? 0.15 : -0.15,
              end: 0.0,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
            );

            return AnimatedBuilder(
              animation: tiltAnimation,
              builder: (context, child) {
                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(tiltAnimation.value),
                  alignment: Alignment.center,
                  child: child,
                );
              },
              child: child,
            );
          },
          child: _buildCardContent(),
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    if (!isFaceUp) {
      // Drawn in code: the PNG back had a white/grey rim that looked like a bad crop on the felt.
      return const CustomPaint(
        key: ValueKey<bool>(false),
        painter: CardBackPainter(),
        size: Size.infinite,
      );
    }
    return Container(
      key: ValueKey<bool>(isFaceUp),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // Fill the card's box (it already includes the screen auto-scale), like the back does.
      child: Image.asset(
        card.assetPath,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// Card back in the app's style (same as the icon): red, gold inner border,
/// diamond lattice. Fills its box edge to edge with rounded corners.
class CardBackPainter extends CustomPainter {
  const CardBackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.1));
    // Rounded shadow (a BoxShadow on the box would be square).
    canvas.drawShadow(Path()..addRRect(r.shift(const Offset(1.5, 2))), Colors.black, 3, false);
    canvas.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD84343), Color(0xFFC62828), Color(0xFF9E1C1C)],
        ).createShader(Offset.zero & size),
    );
    final inner = r.deflate(w * 0.09);
    canvas.save();
    canvas.clipRRect(inner);
    final lattice = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = max(0.6, w * 0.012);
    final step = w * 0.14;
    final h = size.height;
    for (var x = -h; x < w + h; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + h, h), lattice);
      canvas.drawLine(Offset(x + h, 0), Offset(x, h), lattice);
    }
    canvas.restore();
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, w * 0.025)
        ..color = const Color(0xFFFFE082),
    );
    // Thin dark edge so the card separates from a red/dark background.
    canvas.drawRRect(
      r.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant CardBackPainter oldDelegate) => false;
}
