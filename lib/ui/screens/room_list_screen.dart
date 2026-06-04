import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/p2p_service.dart';
import '../../services/logger_service.dart';
import '../../providers/game_provider.dart';
import '../../providers/blackjack_provider.dart';
import '../../models/game_state.dart';
import 'game_table_screen.dart';
import 'blackjack_table_screen.dart';
import 'lobby_screen.dart';

class RoomListScreen extends StatefulWidget {
  final bool useFirebase;
  final P2PService? p2pService;
  const RoomListScreen({super.key, this.useFirebase = false, this.p2pService});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  final List<_RoomInfo> _rooms = [];
  StreamSubscription? _deviceSub;
  StreamSubscription<String>? _connectionSub;
  StreamSubscription? _messageSub;

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _connectionSub?.cancel();
    _messageSub?.cancel();
    super.dispose();
  }

  void _startScanning() {
    final p2p = widget.useFirebase ? widget.p2pService! : context.read<GameProvider>().p2pService;
    AppLogger().log('ROOMLIST: scanning, useFirebase=${widget.useFirebase}');

    _deviceSub = p2p.onDeviceFound.listen((device) {
      if (!mounted) return;
      AppLogger().log('ROOMLIST: device found id=${device.endpointId} name=${device.endpointName}');
      final parsed = _parseRoomName(device.endpointName);
      if (parsed == null) {
        AppLogger().log('ROOMLIST: parseRoomName null for "${device.endpointName}"');
        return;
      }
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
      final game = context.read<GameProvider>();
      game.setHost(false);
      game.setMultiplayer(true);
      game.setPlayerName(_pendingName ?? 'Jugador');
      final pass = _pendingPassword ?? '';
      _pendingPassword = null;
      p2p.sendMessage(endpointId, {
        'type': 'JOIN_REQUEST',
        'playerName': _pendingName ?? 'Jugador',
        'password': pass,
        'endpointId': endpointId,
      });
    });

    _messageSub = p2p.onMessageReceived.listen((msg) async {
      final type = msg['type'];
      if (type == 'JOIN_REJECTED') {
        final reason = msg['reason'] as String? ?? '';
        AppLogger().log('JOIN_REJECTED: $reason');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(reason == 'password' ? 'Contrasena incorrecta' : 'Error al unirse'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        await p2p.disconnectAll();
        await p2p.stopDiscovery();
        await p2p.startDiscovery('player');
        return;
      }
      if (type == 'ASSIGN_SEAT') {
        final modeStr = msg['gameMode'] as String? ?? 'diceDash';
        AppLogger().log('ASSIGN_SEAT: mode=$modeStr');
        if (mounted) {
          if (modeStr == 'blackjack') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider(
                  create: (_) => BlackjackProvider()..initSinglePlayer(botCount: 0),
                  child: const BlackjackTableScreen(),
                ),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const GameTableScreen(isMultiplayer: true, isHost: false)),
            );
          }
        }
      }
    });

    p2p.startDiscovery('player');
  }

  String? _pendingName;
  String? _pendingPassword;

  void _onRoomTapped(_RoomInfo room) {
    if (room.playerCount >= room.maxPlayers) return;
    if (room.hasPassword) {
      _showJoinDialog(room, requirePassword: true);
    } else {
      _showJoinDialog(room);
    }
  }

  void _showJoinDialog(_RoomInfo room, {bool requirePassword = false}) {
    final s = (MediaQuery.of(context).size.shortestSide / 400).clamp(0.75, 1.35);
    final nameController = TextEditingController();
    final passController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14 * s), side: const BorderSide(color: Colors.amber, width: 2)),
        child: Padding(
          padding: EdgeInsets.all(20 * s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Entrar a ${room.name}', style: TextStyle(color: Colors.amber, fontSize: 16 * s, fontWeight: FontWeight.bold)),
              SizedBox(height: 16 * s),
              TextField(
                controller: nameController,
                style: TextStyle(color: Colors.white, fontSize: 14 * s),
                decoration: InputDecoration(
                  labelText: 'Tu nombre',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.4))),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.amber)),
                ),
              ),
              if (requirePassword) ...[
                SizedBox(height: 12 * s),
                TextField(
                  controller: passController,
                  obscureText: true,
                  style: TextStyle(color: Colors.white, fontSize: 14 * s),
                  decoration: InputDecoration(
                    labelText: 'Contrasena',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.4))),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.amber)),
                  ),
                ),
              ],
              SizedBox(height: 20 * s),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancelar', style: TextStyle(color: Colors.white54, fontSize: 13 * s)),
                  ),
                  SizedBox(width: 8 * s),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _pendingName = nameController.text.trim().isEmpty ? 'Jugador' : nameController.text.trim();
                      _pendingPassword = requirePassword ? passController.text.trim() : '';
                      final p2p = widget.useFirebase ? widget.p2pService! : context.read<GameProvider>().p2pService;
                      p2p.connectToDevice(room.endpointId);
                    },
                    child: Text('Entrar', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13 * s)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
    GameMode mode = GameMode.diceDash;
    if (parts.length >= 5) {
      final modeStr = parts[4];
      if (modeStr == 'texasHoldem') mode = GameMode.texasHoldem;
      else if (modeStr == 'blackjack') mode = GameMode.blackjack;
    }
    return _RoomInfo(name: name, playerCount: playerCount, maxPlayers: maxPlayers, hasPassword: hasPassword, started: started, gameMode: mode);
  }

  @override
  Widget build(BuildContext context) {
    final s = (MediaQuery.of(context).size.shortestSide / 400).clamp(0.75, 1.35);
    return Scaffold(
      backgroundColor: const Color(0xFF0A4D28),
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: Text('Salas disponibles', style: TextStyle(fontSize: 16 * s)),
        centerTitle: true,
      ),
      body: _rooms.isEmpty
          ? Center(child: Text('Buscando salas...\nAsegurate de que ambos dispositivos esten en la misma red', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14 * s)))
          : ListView.builder(
              padding: EdgeInsets.all(12 * s),
              itemCount: _rooms.length,
              itemBuilder: (context, index) => _RoomCard(room: _rooms[index], s: s, onTap: () => _onRoomTapped(_rooms[index])),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber,
        child: const Icon(Icons.refresh, color: Colors.black),
        onPressed: () {
          setState(() => _rooms.clear());
          final p2p = widget.useFirebase ? widget.p2pService! : context.read<GameProvider>().p2pService;
          p2p.stopDiscovery();
          p2p.startDiscovery('player');
        },
      ),
    );
  }
}

class _RoomInfo {
  final String endpointId;
  final String name;
  final int playerCount;
  final int maxPlayers;
  final bool hasPassword;
  final bool started;
  final GameMode gameMode;

  _RoomInfo({
    this.endpointId = '',
    required this.name,
    required this.playerCount,
    required this.maxPlayers,
    required this.hasPassword,
    required this.started,
    this.gameMode = GameMode.diceDash,
  });

  _RoomInfo copyWith({
    String? endpointId,
    String? name,
    int? playerCount,
    int? maxPlayers,
    bool? hasPassword,
    bool? started,
    GameMode? gameMode,
  }) => _RoomInfo(
    endpointId: endpointId ?? this.endpointId,
    name: name ?? this.name,
    playerCount: playerCount ?? this.playerCount,
    maxPlayers: maxPlayers ?? this.maxPlayers,
    hasPassword: hasPassword ?? this.hasPassword,
    started: started ?? this.started,
    gameMode: gameMode ?? this.gameMode,
  );
}

class _RoomCard extends StatelessWidget {
  final _RoomInfo room;
  final double s;
  final VoidCallback onTap;

  const _RoomCard({required this.room, required this.s, required this.onTap});

  String _gameModeIcon(GameMode mode) {
    switch (mode) {
      case GameMode.texasHoldem: return 'SP';
      case GameMode.blackjack: return '21';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1A2E),
      margin: EdgeInsets.only(bottom: 8 * s),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10 * s)),
      child: ListTile(
        onTap: room.playerCount < room.maxPlayers ? onTap : null,
        leading: room.gameMode != GameMode.diceDash
            ? Icon(
                room.gameMode == GameMode.texasHoldem ? Icons.style : Icons.casino,
                color: room.gameMode == GameMode.texasHoldem ? Colors.red : Colors.green,
                size: 28 * s,
              )
            : null,
        title: Text(room.name, style: TextStyle(color: Colors.amber, fontSize: 14 * s, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              room.started ? 'En juego' : 'Esperando',
              style: TextStyle(color: room.started ? Colors.orange : Colors.green, fontSize: 10 * s),
            ),
            Text(
              '${room.playerCount}/${room.maxPlayers} jugadores${room.hasPassword ? "  CONTRASENA" : ""}',
              style: TextStyle(color: Colors.white54, fontSize: 10 * s),
            ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16 * s),
      ),
    );
  }
}
