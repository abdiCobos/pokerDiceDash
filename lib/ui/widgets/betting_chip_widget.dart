import 'package:flutter/material.dart';

class BettingChipWidget extends StatelessWidget {
  final String chipType;
  final double size;

  const BettingChipWidget({
    super.key,
    this.chipType = 'RedWhite',
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/chips/chip${chipType}_side.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
          Image.asset(
            'assets/images/chips/chip$chipType.png',
            width: size * 0.85,
            height: size * 0.85,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
