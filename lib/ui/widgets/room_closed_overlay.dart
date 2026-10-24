import 'package:flutter/material.dart';

/// Shown to LAN clients when the host closed the room (or never came back):
/// the table can no longer continue, so the only action is going back to the menu.
class RoomClosedOverlay extends StatelessWidget {
  final String message;
  final VoidCallback onExit;
  final double scale;

  const RoomClosedOverlay({super.key, required this.message, required this.onExit, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          width: 400 * s,
          padding: EdgeInsets.fromLTRB(20 * s, 16 * s, 20 * s, 14 * s),
          decoration: BoxDecoration(
            color: const Color(0xFF07160D).withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(16 * s),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.8), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, color: Colors.redAccent, size: 38 * s),
              SizedBox(height: 8 * s),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16 * s, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 14 * s),
              ElevatedButton.icon(
                onPressed: onExit,
                icon: Icon(Icons.home, size: 16 * s),
                label: Text('Volver al menú', style: TextStyle(fontSize: 13 * s, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 10 * s),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
