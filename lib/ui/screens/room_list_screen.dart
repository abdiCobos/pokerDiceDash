import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import 'game_table_screen.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  final List<_RoomInfo> _rooms = [];
  StreamSubscription? _deviceSub;
  StreamSubscription<String>? _connectionSub;

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  void _startScanning() {
    final p2p = context.read<GameProvider>().p2pService;

    _deviceSub = p2p.onDeviceFound.listen((device) {
      if (!mounted) return;
      final parsed = _parseRoomName(device.endpointName);
      if (parsed == null) return;
      setState(() {
        final existing = _rooms.indexWhere((r) => r.endpointId == device.endpointId);
        if (existing >= 0) {
          _rooms[existing] = parsed.copyWith(endpointId: device.endpointId);
        } else {
          _rooms.add(parsed.copyWith(endpointId: device.endpointId));
        }
      });
    });

    _connectionSub = p2p.onConnected.listen((endpointId) {
      if (!mounted) return;
      final room = _rooms.firstWhere((r) => r.endpointId == endpointId,
          orElse: () => _RoomInfo(name: '', playerCount: 0, maxPlayers: 4, hasPassword: false, started: false, endpointId: ''));
      if (room.hasPassword) {
        _showPasswordDialog(room);
      } else {
        _joinRoom(room);
      }
    });

    p2p.startDiscovery('player');
  }

  _RoomInfo? _parseRoomName(String raw) {
    final parts = raw.split('|');
    if (parts.length < 4) return null;
    final name = parts[0];
    final countParts = parts[1].split('/');
    final playerCount = int.tryParse(countParts[0]) ?? 0;
    final maxPlayers = int.tryParse(countParts[1]) ?? 4;
    final hasPassword = parts[2] == '1';
    final started = parts[3] == '1';
    return _RoomInfo(
      name: name,
      playerCount: playerCount,
      maxPlayers: maxPlayers,
      hasPassword: hasPassword,
      started: started,
      endpointId: '',
    );
  }

  void _showPasswordDialog(_RoomInfo room) {
    final s = (MediaQuery.of(context).size.width / 800).clamp(0.45, 1.3);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14 * s),
          side: const BorderSide(color: Colors.amber, width: 2),
        ),
        title: Text('Contraseña requerida', style: TextStyle(color: Colors.amber, fontSize: 16 * s, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${room.name} es privada.', style: TextStyle(color: Colors.white70, fontSize: 13 * s)),
            SizedBox(height: 12 * s),
            TextField(
              controller: controller,
              obscureText: true,
              style: TextStyle(color: Colors.white, fontSize: 14 * s),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                labelStyle: TextStyle(color: Colors.white54, fontSize: 13 * s),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(8 * s)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.amber), borderRadius: BorderRadius.circular(8 * s)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: Colors.white54, fontSize: 13 * s)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _joinRoom(room);
            },
            child: Text('Entrar', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13 * s)),
          ),
        ],
      ),
    );
  }

  void _joinRoom(_RoomInfo room) {
    final game = context.read<GameProvider>();
    game.setHost(false);
    game.setMultiplayer(true);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const GameTableScreen(isMultiplayer: true, isHost: false),
      ),
    );
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final s = (screenW / 800).clamp(0.45, 1.3);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [Color(0xFF0A4D28), Color(0xFF052915)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16 * s),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.amber, size: 24 * s),
                      onPressed: () {
                        context.read<GameProvider>().p2pService.stopDiscovery();
                        Navigator.pop(context);
                      },
                    ),
                    SizedBox(width: 8 * s),
                    Text('Salas Disponibles', style: TextStyle(color: Colors.amber, fontSize: 20 * s, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    SizedBox(width: 20 * s, height: 20 * s, child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2)),
                  ],
                ),
              ),
              Expanded(
                child: _rooms.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, color: Colors.white38, size: 48 * s),
                            SizedBox(height: 12 * s),
                            Text('Buscando salas...', style: TextStyle(color: Colors.white54, fontSize: 14 * s)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _rooms.length,
                        itemBuilder: (context, index) {
                          final room = _rooms[index];
                          return _RoomCard(room: room, s: s, onTap: () {
                            final p2p = context.read<GameProvider>().p2pService;
                            p2p.connectToDevice(room.endpointId);
                          });
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomInfo {
  final String name;
  final int playerCount;
  final int maxPlayers;
  final bool hasPassword;
  final bool started;
  String endpointId;

  _RoomInfo({
    required this.name,
    required this.playerCount,
    required this.maxPlayers,
    required this.hasPassword,
    required this.started,
    required this.endpointId,
  });

  _RoomInfo copyWith({String? endpointId}) {
    return _RoomInfo(
      name: name,
      playerCount: playerCount,
      maxPlayers: maxPlayers,
      hasPassword: hasPassword,
      started: started,
      endpointId: endpointId ?? this.endpointId,
    );
  }
}

class _RoomCard extends StatelessWidget {
  final _RoomInfo room;
  final double s;
  final VoidCallback onTap;

  const _RoomCard({required this.room, required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 4 * s),
      child: Material(
        color: room.started ? Colors.amber.withValues(alpha: 0.08) : Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10 * s),
        child: InkWell(
          onTap: room.playerCount < room.maxPlayers ? onTap : null,
          borderRadius: BorderRadius.circular(10 * s),
          child: Container(
            padding: EdgeInsets.all(14 * s),
            child: Row(
              children: [
                Icon(room.hasPassword ? Icons.lock : Icons.lock_open,
                    color: room.hasPassword ? Colors.redAccent : Colors.greenAccent,
                    size: 20 * s),
                SizedBox(width: 10 * s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(room.name, style: TextStyle(color: Colors.amber, fontSize: 14 * s, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2 * s),
                      Text(
                        room.started ? 'En juego' : 'Esperando',
                        style: TextStyle(color: room.started ? Colors.orange : Colors.green, fontSize: 10 * s),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 4 * s),
                  decoration: BoxDecoration(
                    color: room.playerCount >= room.maxPlayers ? Colors.red.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6 * s),
                  ),
                  child: Text(
                    '${room.playerCount}/${room.maxPlayers}',
                    style: TextStyle(
                      color: room.playerCount >= room.maxPlayers ? Colors.redAccent : Colors.greenAccent,
                      fontSize: 12 * s,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 8 * s),
                Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16 * s),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
