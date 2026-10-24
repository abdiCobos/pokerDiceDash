import 'package:flutter/material.dart';

/// Short line at the top of a LAN table: reconnecting, or the room changing hands
/// ("El anfitrión salió…", "Ahora el anfitrión es…"). Never blocks the table.
class ConnectionBanner extends StatelessWidget {
  final String text;
  final bool warning;
  final double scale;

  const ConnectionBanner({super.key, required this.text, this.warning = true, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Positioned(
      top: 52 * s,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 6 * s),
            decoration: BoxDecoration(
              color: (warning ? Colors.orange.shade800 : const Color(0xFF1B5E20)).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12 * s),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 12 * s, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
