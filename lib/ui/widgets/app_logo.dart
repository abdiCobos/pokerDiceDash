import 'package:flutter/material.dart';

import 'app_icon_painter.dart';

/// Menu logo drawn in code: the app icon's artwork on a round felt emblem
/// with a wooden rail, plus the title in the bundled casino font.
/// [size] is the emblem diameter; the title scales with it.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showTagline;

  const AppLogo({super.key, required this.size, this.showTagline = true});

  @override
  Widget build(BuildContext context) {
    final rail = size * 0.045;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF3E2410),
            border: Border.all(color: const Color(0xFF2A1708), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: size * 0.12, spreadRadius: size * 0.01),
            ],
          ),
          padding: EdgeInsets.all(rail),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.6), width: size * 0.012),
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: AppIconPainter(AppIconLayer.background)),
                  // The artwork lives in the 66/108 safe circle: zoom it to fill the emblem.
                  Transform.scale(
                    scale: 1.35,
                    child: CustomPaint(painter: AppIconPainter(AppIconLayer.foreground)),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: size * 0.08),
        _Title(text: 'POKER DICE DASH', fontSize: size * 0.17),
        if (showTagline) ...[
          SizedBox(height: size * 0.03),
          Text(
            'CASINO DE BOLSILLO',
            style: TextStyle(
              color: const Color(0xFFD4AF37),
              fontSize: size * 0.065,
              fontWeight: FontWeight.w600,
              letterSpacing: size * 0.025,
            ),
          ),
        ],
      ],
    );
  }
}

/// Gold gradient lettering with a dark outline, like a casino sign.
class _Title extends StatelessWidget {
  final String text;
  final double fontSize;

  const _Title({required this.text, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontFamily: 'AlfaSlabOne', fontSize: fontSize, letterSpacing: fontSize * 0.04, height: 1.1);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Stack(
        children: [
          // Outline + drop shadow.
          Text(
            text,
            style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = fontSize * 0.14
                ..strokeJoin = StrokeJoin.round
                ..color = const Color(0xFF2A1708),
              shadows: [Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: fontSize * 0.25, offset: Offset(0, fontSize * 0.08))],
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF3C4), Color(0xFFFFD54F), Color(0xFFD4AF37), Color(0xFFB8860B)],
              stops: [0.0, 0.35, 0.7, 1.0],
            ).createShader(rect),
            child: Text(text, style: style.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
