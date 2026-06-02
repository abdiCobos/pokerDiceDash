import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../services/logger_service.dart';
import '../../services/p2p_service.dart';
import '../../providers/blackjack_provider.dart';
import '../../models/game_state.dart';
import 'game_table_screen.dart';
import 'blackjack_table_screen.dart';
import 'room_list_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool _isHosting = false;
  bool _isGlobalHost = false;
  GameMode _selectedMode = GameMode.diceDash;
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

  void startHosting({bool global = false}) {
    _isGlobalHost = global;
    _showCreateRoomDialog();
  }

  void _showCreateRoomDialog() {
    _roomNameController.text = 'UAdeO';
    _roomPasswordController.text = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final s = (MediaQuery.of(dialogCtx).size.shortestSide / 400).clamp(0.75, 1.35);
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
                      Text(
                        _isGlobalHost ? 'Crear Sala Global' : 'Crear Sala Local',
                        style: TextStyle(color: Colors.amber, fontSize: 18 * s, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16 * s),
                      TextField(
                        controller: _playerNameController,
                        style: TextStyle(color: Colors.white, fontSize: 14 * s),
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Tu nombre',
                          labelStyle: TextStyle(color: Colors.white54, fontSize: 13 * s),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(8 * s),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.amber),
                            borderRadius: BorderRadius.circular(8 * s),
                          ),
                        ),
                      ),
                      SizedBox(height: 12 * s),
                      _buildModeSelector(s, setDialogState),
                      SizedBox(height: 12 * s),
                      TextField(
                        controller: _roomNameController,
                        style: TextStyle(color: Colors.white, fontSize: 14 * s),
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Nombre de la sala',
                          labelStyle: TextStyle(color: Colors.white54, fontSize: 13 * s),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(8 * s),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.amber),
                            borderRadius: BorderRadius.circular(8 * s),
                          ),
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
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(8 * s),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.amber),
                            borderRadius: BorderRadius.circular(8 * s),
                          ),
                        ),
                      ),
                      SizedBox(height: 20 * s),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: Text('Cancelar', style: TextStyle(color: Colors.white54, fontSize: 13 * s)),
                          ),
                          SizedBox(width: 8 * s),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(dialogCtx);
                              _startHostingInternal(
                                _roomNameController.text.trim().isEmpty
                                    ? '${Platform.localHostname}-Poker'
                                    : _roomNameController.text.trim(),
                                _roomPasswordController.text.trim(),
                                global: _isGlobalHost,
                              );
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
      },
    );
  }

  void _startHostingInternal(String roomName, String password, {bool global = false}) {
    setState(() => _isHosting = true);
    final game = context.read<GameProvider>();
    final p2p = global ? context.read<P2PService>() : game.p2pService;

    game.setHost(true);
    game.setMultiplayer(true);
    game.setGameMode(_selectedMode);
    AppLogger().event('create_room', params: {'mode': _selectedMode.name, 'transport': global ? 'firebase' : 'nearby'});
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

    if (_selectedMode == GameMode.blackjack) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) => BlackjackProvider()..initMultiplayer(asHost: true),
            child: const BlackjackTableScreen(isMultiplayer: true, isHost: true),
          ),
        ),
      ).then((_) {
        if (mounted) setState(() => _isHosting = false);
        if (global) p2p.stopAdvertising();
        p2p.disconnectAll();
      });
    } else {
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
  }

  String _buildRoomMetadata() {
    final game = context.read<GameProvider>();
    final hasPassword = _roomPasswordController.text.trim().isNotEmpty;
    final started = game.players.length >= 2;
    final count = game.players.length;
    final name = _roomNameController.text.trim().isEmpty
        ? '${Platform.localHostname}-Poker'
        : _roomNameController.text.trim();
    return '$name|$count/4|${hasPassword ? '1' : '0'}|${started ? '1' : '0'}|${_selectedMode.name}';
  }

  Widget _buildModeSelector(double s, StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Modo de juego', style: TextStyle(color: Colors.white54, fontSize: 13 * s)),
        SizedBox(height: 8 * s),
        Wrap(
          spacing: 8 * s,
          children: GameMode.values.map((mode) {
            final selected = _selectedMode == mode;
            String label;
            Color color;
            switch (mode) {
              case GameMode.diceDash:
                label = '🎲 Dice Dash';
                color = Colors.amber;
              case GameMode.texasHoldem:
                label = '♠️ Texas';
                color = Colors.red;
              case GameMode.blackjack:
                label = '🃏 21';
                color = Colors.green;
            }
            return ChoiceChip(
              label: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 11 * s)),
              selected: selected,
              selectedColor: color,
              backgroundColor: Colors.white10,
              onSelected: (v) {
                setState(() => _selectedMode = mode);
                setDialogState(() {});
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  void startDiscovering({bool useFirebase = false}) {
    final p2p = useFirebase ? context.read<P2PService>() : context.read<GameProvider>().p2pService;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => RoomListScreen(useFirebase: useFirebase, p2pService: p2p)),
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
                        AppLogger().event('practice_mode_selected', params: {'mode': 'dice_dash'});
                        game.resetGame();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const GameTableScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 18 * s),
                        textStyle: TextStyle(fontSize: 18 * s, fontWeight: FontWeight.bold),
                      ),
                      child: Text('Jugar Solo (Práctica)', style: TextStyle(fontSize: 18 * s)),
                    ),
                  ),
                  SizedBox(height: 16 * s),
                  SizedBox(
                    width: screenW * 0.75,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider(
                              create: (_) => BlackjackProvider()..initSinglePlayer(botCount: 0),
                              child: const BlackjackTableScreen(),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade800,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 18 * s),
                        textStyle: TextStyle(fontSize: 18 * s, fontWeight: FontWeight.bold),
                      ),
                      child: Text('21 Black Jack (Práctica)', style: TextStyle(fontSize: 18 * s)),
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
                        AppLogger().event('practice_mode_selected', params: {'mode': 'texas_holdem'});
                        game.resetGame();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const GameTableScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade800,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 18 * s),
                        textStyle: TextStyle(fontSize: 18 * s, fontWeight: FontWeight.bold),
                      ),
                      child: Text("Texas Hold'em (Práctica)", style: TextStyle(fontSize: 18 * s)),
                    ),
                  ),
                  SizedBox(height: 16 * s),
                  SizedBox(
                    width: screenW * 0.75,
                    child: ElevatedButton(
                      onPressed: _isHosting ? null : () => startHosting(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 18 * s),
                        textStyle: TextStyle(fontSize: 18 * s, fontWeight: FontWeight.bold),
                      ),
                      child: _isHosting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20 * s,
                                  height: 20 * s,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                      onPressed: () => startDiscovering(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 18 * s),
                        textStyle: TextStyle(fontSize: 18 * s, fontWeight: FontWeight.bold),
                      ),
                      child: Text('Unirse - Local', style: TextStyle(fontSize: 18 * s)),
                    ),
                  ),
                  SizedBox(height: 16 * s),
                  SizedBox(
                    width: screenW * 0.75,
                    child: ElevatedButton(
                      onPressed: _isHosting ? null : () => startHosting(global: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 18 * s),
                        textStyle: TextStyle(fontSize: 18 * s, fontWeight: FontWeight.bold),
                      ),
                      child: Text('Crear Sala Global', style: TextStyle(fontSize: 18 * s)),
                    ),
                  ),
                  SizedBox(height: 16 * s),
                  SizedBox(
                    width: screenW * 0.75,
                    child: ElevatedButton(
                      onPressed: () => startDiscovering(useFirebase: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 18 * s),
                        textStyle: TextStyle(fontSize: 18 * s, fontWeight: FontWeight.bold),
                      ),
                      child: Text('Unirse - Global', style: TextStyle(fontSize: 18 * s)),
                    ),
                  ),
                  if (_isHosting) ...[
                    SizedBox(height: 24 * s),
                    CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
                    SizedBox(height: 12 * s),
                    Text('Esperando jugadores...', style: TextStyle(color: Colors.white70, fontSize: 15 * s)),
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
