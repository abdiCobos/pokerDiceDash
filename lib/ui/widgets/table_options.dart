import 'package:flutter/material.dart';

import '../../services/game_settings.dart';

/// Gear button for the table headers.
class TableOptionsButton extends StatelessWidget {
  final double scale;
  final bool poker;
  final VoidCallback onExit;

  const TableOptionsButton({super.key, required this.scale, required this.poker, required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Opciones',
      child: Material(
        color: Colors.black38,
        shape: CircleBorder(side: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.6))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => showTableOptions(context, scale: scale, poker: poker, onExit: onExit),
          child: Padding(
            padding: EdgeInsets.all(7 * scale),
            child: Icon(Icons.settings, color: const Color(0xFFFFD54F), size: 20 * scale),
          ),
        ),
      ),
    );
  }
}

/// In-table options: sound, game speed, odds helper (poker), screen awake, leave.
Future<void> showTableOptions(
  BuildContext context, {
  required double scale,
  required bool poker,
  required VoidCallback onExit,
}) {
  final s = scale;
  final settings = GameSettings();
  Widget toggle(String title, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      activeThumbColor: const Color(0xFFFFD54F),
      secondary: Icon(icon, color: const Color(0xFFD4AF37), size: 22 * s),
      title: Text(title, style: TextStyle(color: Colors.white, fontSize: 14 * s, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.white54, fontSize: 11.5 * s)),
      value: value,
      onChanged: onChanged,
    );
  }

  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF07160D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16 * s),
        side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440 * s),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20 * s, 16 * s, 20 * s, 12 * s),
          child: ListenableBuilder(
            listenable: settings,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings, color: const Color(0xFFFFD54F), size: 22 * s),
                    SizedBox(width: 8 * s),
                    Text('Opciones',
                        style: TextStyle(color: const Color(0xFFFFD54F), fontSize: 18 * s, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    // Up here (not at the bottom) so it is reachable without scrolling on phones.
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onExit();
                      },
                      icon: Icon(Icons.logout, size: 18 * s),
                      label: Text('Salir de la mesa', style: TextStyle(fontSize: 13 * s, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                toggle('Sonido', 'Cartas, fichas y dados', settings.sound ? Icons.volume_up : Icons.volume_off,
                    settings.sound, settings.setSound),
                if (GameSettings.fastGameAvailable)
                  toggle('Juego rápido', 'Los bots piensan y el crupier reparte más rápido', Icons.speed,
                      settings.fastGame, settings.setFastGame),
                if (poker)
                  toggle('Mostrar mi probabilidad', 'Ayuda: tu % de ganar la mano en tu asiento', Icons.percent,
                      settings.showOdds, settings.setShowOdds),
                toggle('Pantalla siempre encendida', 'No se apaga mientras estás en la mesa', Icons.light_mode,
                    settings.keepAwake, settings.setKeepAwake),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
