import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/p2p_service.dart';
import '../../services/room_address.dart';

/// Host waiting room: the room's IP:port with a copy button, so it can be pasted into
/// WhatsApp (or any chat) and then into "Por IP" on the other devices.
class HostAddressChip extends StatelessWidget {
  final int? port;
  final double scale;
  final String label;

  const HostAddressChip({super.key, required this.port, required this.scale, this.label = 'IP de la sala'});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return FutureBuilder<String?>(
      future: P2PService.getLocalIpAddress(),
      builder: (context, snapshot) {
        final ip = snapshot.data;
        final address = ip == null || port == null ? null : RoomAddress(ip, port!);
        return Material(
          color: Colors.black54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12 * s),
            side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12 * s),
            onTap: address == null
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: address.toString()));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copiado: $address. Pégalo en WhatsApp y los demás lo pegan en «Por IP».'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 5 * s),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi, color: Colors.amber, size: 14 * s),
                  SizedBox(width: 6 * s),
                  Text(
                    '$label: ${address ?? '...'}',
                    style: TextStyle(color: Colors.amber, fontSize: 11 * s, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8 * s),
                  Icon(Icons.copy, color: Colors.amber, size: 14 * s),
                  SizedBox(width: 3 * s),
                  Text('Copiar', style: TextStyle(color: Colors.amber, fontSize: 10 * s)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
