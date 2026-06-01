import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../models/game_state.dart';
import 'game_table_screen.dart';
import 'room_list_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool _isHosting = false;
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _roomPasswordController = TextEditingController();
  final TextEditingController _playerNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _askPermissions();
    _requestHardwarePermissions();
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _roomPasswordController.dispose();
    _playerNameController.dispose();
    super.dispose();
  }

  Future<void> _askPermissions() async {
    // Permissions are handled by the nearby_connections plugin internally.
    // The AndroidManifest.xml has all required permissions declared.
  }

  Future<void> _requestHardwarePermissions() async {
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ].request();
  }

  void startHosting() {
    _showCreateRoomDialog();
  }

  void _showCreateRoomDialog() {
    _roomNameController.text = 'UAdeO';
    _roomPasswordController.text = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final s = (MediaQuery.of(ctx).size.shortestSide / 400).clamp(0.75, 1.35);
        return Dialog(
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
                  Text('Crear Sala', style: TextStyle(color: Colors.amber, fontSize: 18 * s, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16 * s),
                  TextField(
                    controller: _playerNameController,
                    style: TextStyle(color: Colors.white, fontSize: 14 * s),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Tu nombre',
                      labelStyle: TextStyle(color: Colors.white54, fontSize: 13 * s),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(8 * s)),
                      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.amber), borderRadius: BorderRadius.circular(8 * s)),
                    ),
                  ),
                  SizedBox(height: 12 * s),
                  TextField(
                    controller: _roomNameController,
                    style: TextStyle(color: Colors.white, fontSize: 14 * s),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Nombre de la sala',
                      labelStyle: TextStyle(color: Colors.white54, fontSize: 13 * s),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(8 * s)),
                      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.amber), borderRadius: BorderRadius.circular(8 * s)),
                    ),
                  ),
                  SizedBox(height: 12 * s),
                  TextField(
                    controller: _roomPasswordController,
                    obscureText: true,
                    style: TextStyle(color: Colors.white, fontSize: 14 * s),
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Contraseña (opcional)',
                      labelStyle: TextStyle(color: Colors.white54, fontSize: 13 * s),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(8 * s)),
                      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.amber), borderRadius: BorderRadius.circular(8 * s)),
                    ),
                  ),
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
                          _startHostingInternal(_roomNameController.text.trim().isEmpty ? '${Platform.localHostname}-Poker' : _roomNameController.text.trim(), _roomPasswordController.text.trim());
                        },
                        child: Text('Crear', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13 * s)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _startHostingInternal(String roomName, String password) {
    setState(() => _isHosting = true);
    final game = context.read<GameProvider>();
    final p2p = game.p2pService;

    game.setHost(true);
    game.setMultiplayer(true);
    game.setPlayerName(
      _playerNameController.text.trim().isEmpty ? 'Host' : _playerNameController.text.trim(),
    );
    game.setRoomMetadata(
      _roomNameController.text.trim().isEmpty
          ? '${Platform.localHostname}-Poker'
          : _roomNameController.text.trim(),
      password,
    );

    final metadata = _buildRoomMetadata();
    p2p.startAdvertising(metadata);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameTableScreen(isMultiplayer: true, isHost: true),
      ),
    ).then((_) {
      if (mounted) setState(() => _isHosting = false);
      p2p.stopAdvertising();
      p2p.disconnectAll();
    });
  }

  String _buildRoomMetadata() {
    final game = context.read<GameProvider>();
    final hasPassword = _roomPasswordController.text.trim().isNotEmpty;
    final started = game.players.length >= 2;
    final count = game.players.length;
    final name = _roomNameController.text.trim().isEmpty
        ? '${Platform.localHostname}-Poker'
        : _roomNameController.text.trim();
    return '$name|$count/4|${hasPassword ? '1' : '0'}|${started ? '1' : '0'}';
  }

  void startDiscovering() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RoomListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final s = (MediaQuery.of(context).size.shortestSide / 400).clamp(0.75, 1.35);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [
              Color(0xFF0A4D28),
              Color(0xFF052915),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/menulogo/menulogo.png',
                  width: screenW * 0.85,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 50 * s),
                SizedBox(
                  width: screenW * 0.75,
                  child: ElevatedButton(
                    onPressed: () {
                      final game = context.read<GameProvider>();
                      game.setHost(true);
                      game.setMultiplayer(false);
                      game.setGameMode(GameMode.diceDash);
                      game.resetGame();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GameTableScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 18 * s),
                      textStyle: TextStyle(
                        fontSize: 18 * s,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Text('Jugar Solo (Práctica)', style: TextStyle(fontSize: 18 * s)),
                  ),
                ),
                SizedBox(height: 16 * s),
                SizedBox(
                  width: screenW * 0.75,
                  child: ElevatedButton(
                    onPressed: () {
                      final game = context.read<GameProvider>();
                      game.setHost(true);
                      game.setMultiplayer(false);
                      game.setGameMode(GameMode.texasHoldem);
                      game.resetGame();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GameTableScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 18 * s),
                      textStyle: TextStyle(fontSize: 18 * s, fontWeight: FontWeight.bold),
                    ),
                    child: Text('Texas Hold\'em (Práctica)', style: TextStyle(fontSize: 18 * s)),
                  ),
                ),
                SizedBox(height: 16 * s),
                SizedBox(
                  width: screenW * 0.75,
                  child: ElevatedButton(
                    onPressed: _isHosting ? null : startHosting,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 18 * s),
                      textStyle: TextStyle(
                        fontSize: 18 * s,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: _isHosting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20 * s,
                                height: 20 * s,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 12 * s),
                              Text('Esperando jugadores...', style: TextStyle(fontSize: 16 * s)),
                            ],
                          )
                        : Text('Crear Sala (Host)', style: TextStyle(fontSize: 18 * s)),
                  ),
                ),
                SizedBox(height: 16 * s),
                SizedBox(
                  width: screenW * 0.75,
                  child: ElevatedButton(
                    onPressed: startDiscovering,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 18 * s),
                      textStyle: TextStyle(
                        fontSize: 18 * s,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Text('Unirse a Sala', style: TextStyle(fontSize: 18 * s)),
                  ),
                ),
                if (_isHosting) ...[
                  SizedBox(height: 24 * s),
                  CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
                  SizedBox(height: 12 * s),
                  Text(
                    'Esperando jugadores...',
                    style: TextStyle(color: Colors.white70, fontSize: 15 * s),
                  ),
                ],
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}
