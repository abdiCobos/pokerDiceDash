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
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  final List<_RoomInfo> _rooms = [];
  StreamSubscription? _deviceSub;
  StreamSubscription<String>? _connectionSub;
  StreamSubscription? _messageSub;
  bool _isConnecting = false;

  String? _pendingName;
  String? _pendingPassword;

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
    final p2p = context.read<GameProvider>().p2pService;
    AppLogger().log('ROOMLIST: scanning');

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
          setState(() => _isConnecting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(reason == 'password' ? 'Contraseña incorrecta' : (reason == 'room_full' ? 'La sala está llena' : 'Error al unirse')),
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
          setState(() => _isConnecting = false);
          if (modeStr == 'blackjack') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider(
                  create: (_) => BlackjackProvider()..initMultiplayer(asHost: false),
                  child: const BlackjackTableScreen(isMultiplayer: true, isHost: false),
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

  void _onRoomTapped(_RoomInfo room) {
    if (room.playerCount >= room.maxPlayers || _isConnecting) return;
    _showJoinDialog(room, requirePassword: room.hasPassword);
  }

  void _showJoinDialog(_RoomInfo room, {bool requirePassword = false}) {
    final s = (MediaQuery.of(context).size.shortestSide / 400).clamp(0.75, 1.35);
    final nameController = TextEditingController(text: _pendingName ?? '');
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
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.4))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                ),
              ),
              if (requirePassword) ...[
                SizedBox(height: 12 * s),
                TextField(
                  controller: passController,
                  obscureText: true,
                  style: TextStyle(color: Colors.white, fontSize: 14 * s),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    labelStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.4))),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
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
                      setState(() => _isConnecting = true);
                      _pendingName = nameController.text.trim().isEmpty ? 'Jugador' : nameController.text.trim();
                      _pendingPassword = requirePassword ? passController.text.trim() : '';
                      final p2p = context.read<GameProvider>().p2pService;
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

  void _showDirectIpDialog() {
    final s = (MediaQuery.of(context).size.shortestSide / 400).clamp(0.75, 1.35);
    final ipController = TextEditingController();
    final portController = TextEditingController();
    final nameController = TextEditingController(text: _pendingName ?? '');
    final passController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14 * s), side: const BorderSide(color: Colors.amber, width: 2)),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(20 * s),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.router, color: Colors.amber, size: 22 * s),
                    SizedBox(width: 8 * s),
                    Text('Conexión Directa por IP', style: TextStyle(color: Colors.amber, fontSize: 16 * s, fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 14 * s),
                TextField(
                  controller: ipController,
                  style: TextStyle(color: Colors.white, fontSize: 14 * s),
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: 'IP del Host (ej: 192.168.1.50)',
                    labelStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.4))),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                  ),
                ),
                SizedBox(height: 10 * s),
                TextField(
                  controller: portController,
                  style: TextStyle(color: Colors.white, fontSize: 14 * s),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Puerto (ej: 54321)',
                    labelStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.4))),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                  ),
                ),
                SizedBox(height: 10 * s),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: Colors.white, fontSize: 14 * s),
                  decoration: InputDecoration(
                    labelText: 'Tu nombre',
                    labelStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.4))),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                  ),
                ),
                SizedBox(height: 10 * s),
                TextField(
                  controller: passController,
                  obscureText: true,
                  style: TextStyle(color: Colors.white, fontSize: 14 * s),
                  decoration: InputDecoration(
                    labelText: 'Contraseña (opcional)',
                    labelStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.4))),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                  ),
                ),
                SizedBox(height: 18 * s),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancelar', style: TextStyle(color: Colors.white54, fontSize: 13 * s)),
                    ),
                    SizedBox(width: 8 * s),
                    TextButton(
                      onPressed: () async {
                        final host = ipController.text.trim();
                        final port = int.tryParse(portController.text.trim());
                        if (host.isEmpty || port == null || port <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor ingresa una IP y puerto válidos')),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        setState(() => _isConnecting = true);
                        _pendingName = nameController.text.trim().isEmpty ? 'Jugador' : nameController.text.trim();
                        _pendingPassword = passController.text.trim();
                        final p2p = context.read<GameProvider>().p2pService;
                        final ok = await p2p.connectToHost(host, port);
                        if (!ok && mounted) {
                          setState(() => _isConnecting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No se pudo conectar al Host. Verifica la IP y el Firewall.')),
                          );
                        }
                      },
                      child: Text('Conectar', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13 * s)),
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

  void _showHelpDialog() {
    final s = (MediaQuery.of(context).size.shortestSide / 400).clamp(0.75, 1.35);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14 * s), side: const BorderSide(color: Colors.amber)),
        title: Row(
          children: [
            Icon(Icons.help_outline, color: Colors.amber, size: 22 * s),
            SizedBox(width: 8 * s),
            Text('Ayuda de Conexión', style: TextStyle(color: Colors.amber, fontSize: 16 * s)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _helpItem('1. Misma Red Wi-Fi', 'Todos los dispositivos deben estar conectados al mismo Wi-Fi o punto de acceso (zona Wi-Fi móvil).', s),
              SizedBox(height: 10 * s),
              _helpItem('2. Firewall en Windows / PC', 'Si la PC es el Host, asegúrate de permitir que la app acceda a la red a través del Firewall de Windows.', s),
              SizedBox(height: 10 * s),
              _helpItem('3. Conexión por IP Directa', 'Si el descubrimiento automático no encuentra la sala, el Host verá su IP en pantalla. Usa el botón "Conectar por IP" para conectarte directamente.', s),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  Widget _helpItem(String title, String desc, double s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13 * s)),
        SizedBox(height: 2 * s),
        Text(desc, style: TextStyle(color: Colors.white70, fontSize: 11 * s)),
      ],
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
      if (modeStr == 'texasHoldem') {
        mode = GameMode.texasHoldem;
      } else if (modeStr == 'blackjack') {
        mode = GameMode.blackjack;
      }
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
        foregroundColor: Colors.white,
        title: Text('Salas disponibles', style: TextStyle(fontSize: 16 * s, color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.amber),
            tooltip: 'Ayuda',
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Direct IP Connection Banner
          Container(
            margin: EdgeInsets.all(12 * s),
            padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 10 * s),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12 * s),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_tethering, color: Colors.amber, size: 24 * s),
                SizedBox(width: 10 * s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('¿No ves la sala en la lista?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12 * s)),
                      Text('Conéctate escribiendo la IP del Host', style: TextStyle(color: Colors.white60, fontSize: 10 * s)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showDirectIpDialog,
                  icon: const Icon(Icons.login, size: 16),
                  label: const Text('Por IP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 8 * s),
                    textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12 * s),
                  ),
                ),
              ],
            ),
          ),
          if (_isConnecting)
            Container(
              padding: EdgeInsets.symmetric(vertical: 8 * s),
              color: Colors.amber.withValues(alpha: 0.2),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
                  SizedBox(width: 10),
                  Text('Conectando a la sala...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          Expanded(
            child: _rooms.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.amber)),
                        SizedBox(height: 16 * s),
                        Text(
                          'Buscando salas automáticamente...\nAsegúrate de que ambos dispositivos estén en la misma red Wi-Fi',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 13 * s),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 12 * s),
                    itemCount: _rooms.length,
                    itemBuilder: (context, index) => _RoomCard(room: _rooms[index], s: s, onTap: () => _onRoomTapped(_rooms[index])),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber,
        child: const Icon(Icons.refresh, color: Colors.black),
        onPressed: () {
          setState(() => _rooms.clear());
          final p2p = context.read<GameProvider>().p2pService;
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

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1A2E),
      margin: EdgeInsets.only(bottom: 8 * s),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10 * s)),
      child: ListTile(
        onTap: room.playerCount < room.maxPlayers ? onTap : null,
        leading: Icon(
          room.gameMode == GameMode.texasHoldem
              ? Icons.style
              : (room.gameMode == GameMode.blackjack ? Icons.casino : Icons.sports_esports),
          color: room.gameMode == GameMode.texasHoldem
              ? Colors.red
              : (room.gameMode == GameMode.blackjack ? Colors.green : Colors.amber),
          size: 28 * s,
        ),
        title: Text(room.name, style: TextStyle(color: Colors.amber, fontSize: 14 * s, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              room.started ? 'En juego' : 'Esperando jugadores',
              style: TextStyle(color: room.started ? Colors.orange : Colors.green, fontSize: 10 * s),
            ),
            Text(
              '${room.playerCount}/${room.maxPlayers} jugadores${room.hasPassword ? " • CON CONTRASEÑA" : ""}',
              style: TextStyle(color: Colors.white54, fontSize: 10 * s),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
      ),
    );
  }
}
