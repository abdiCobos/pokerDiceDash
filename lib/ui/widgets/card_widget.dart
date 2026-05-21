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

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final autoScale = (screenW / 800).clamp(0.55, 1.3);
    final effectiveScale = scale * autoScale;

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
      child: isFaceUp
          ? Image.asset(
              card.assetPath,
              width: cardWidth * scale,
              height: cardHeight * scale,
              fit: BoxFit.cover,
            )
          : Image.asset(
              'assets/images/cards/cardBack_red5.png',
              width: cardWidth * scale,
              height: cardHeight * scale,
              fit: BoxFit.cover,
            ),
    );
  }
}
