import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/p2p_service.dart';
import '../../services/logger_service.dart';
import '../../providers/game_provider.dart';
import '../../models/game_state.dart';
import 'game_table_screen.dart';
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

  void _startScanning() {
    final p2p = widget.useFirebase ? widget.p2pService! : context.read<GameProvider>().p2pService;

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
      // No navigate here - wait for ASSIGN_SEAT or JOIN_REJECTED
    });

    _messageSub = p2p.onMessageReceived.listen((msg) async {
      final type = msg['type'];
      if (type == 'JOIN_REJECTED') {
        final reason = msg['reason'] as String? ?? '';
        AppLogger().log('🚫 JOIN_REJECTED recibido: $reason');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(reason == 'password' ? 'Contraseña incorrecta' : 'Error al unirse'),
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
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const GameTableScreen(isMultiplayer: true, isHost: false)),
          );
        }
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
    GameMode mode = GameMode.diceDash;
    if (parts.length >= 5) {
      final modeStr = parts[4];
      if (modeStr == 'texasHoldem') mode = GameMode.texasHoldem;
      else if (modeStr == 'blackjack') mode = GameMode.blackjack;
    }
    return _RoomInfo(
      name: name,
      playerCount: playerCount,
      maxPlayers: maxPlayers,
      hasPassword: hasPassword,
      started: started,
      gameMode: mode,
      endpointId: '',
    );
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14 * s),
          side: const BorderSide(color: Colors.amber, width: 2),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(20 * s),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Unirse a ${room.name}', style: TextStyle(color: Colors.amber, fontSize: 16 * s, fontWeight: FontWeight.bold)),
                SizedBox(height: 16 * s),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: Colors.white, fontSize: 14 * s),
                  textInputAction: requirePassword ? TextInputAction.next : TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Tu nombre',
                    labelStyle: TextStyle(color: Colors.white54, fontSize: 13 * s),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(8 * s)),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.amber), borderRadius: BorderRadius.circular(8 * s)),
                  ),
                ),
                if (requirePassword) ...[
                  SizedBox(height: 12 * s),
                  TextField(
                    controller: passController,
                    obscureText: true,
                    style: TextStyle(color: Colors.white, fontSize: 14 * s),
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      labelStyle: TextStyle(color: Colors.white54, fontSize: 13 * s),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(8 * s)),
                      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.amber), borderRadius: BorderRadius.circular(8 * s)),
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
      ),
    );
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _connectionSub?.cancel();
    _messageSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = (MediaQuery.of(context).size.shortestSide / 400).clamp(0.75, 1.35);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.read<GameProvider>().p2pService.stopDiscovery();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LobbyScreen()),
          );
        }
      },
      child: Scaffold(
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
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LobbyScreen()),
                        );
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
                            _onRoomTapped(room);
                          });
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  String _gameModeLabel(GameMode mode) {
    switch (mode) {
      case GameMode.texasHoldem: return '♠️ Texas Hold\'em';
      case GameMode.blackjack: return '🃏 21 Black Jack';
      default: return '🎲 Poker Dice Dash';
    }
  }
}

// Top-level helper for _RoomCard
String _gameModeLabel(GameMode mode) {
  switch (mode) {
    case GameMode.texasHoldem: return '♠️ Texas Hold\'em';
    case GameMode.blackjack: return '🃏 21 Black Jack';
    default: return '🎲 Poker Dice Dash';
  }
}

class _RoomInfo {
  final String name;
  final int playerCount;
  final int maxPlayers;
  final bool hasPassword;
  final bool started;
  final GameMode gameMode;
  String endpointId;

  _RoomInfo({
    required this.name,
    required this.playerCount,
    required this.maxPlayers,
    required this.hasPassword,
    required this.started,
    required this.gameMode,
    required this.endpointId,
  });

  _RoomInfo copyWith({String? endpointId}) {
    return _RoomInfo(
      name: name,
      playerCount: playerCount,
      maxPlayers: maxPlayers,
      hasPassword: hasPassword,
      started: started,
      gameMode: gameMode,
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
                      SizedBox(height: 2 * s),
                      Text(
                        _gameModeLabel(room.gameMode),
                        style: TextStyle(color: Colors.white54, fontSize: 10 * s),
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
