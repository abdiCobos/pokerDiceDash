import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/game_provider.dart';
import '../../services/logger_service.dart';
import '../../services/p2p_service.dart';
import '../../providers/blackjack_provider.dart';
import '../../models/game_state.dart';
import '../../services/sound_service.dart';
import '../widgets/app_icon_painter.dart';
import '../widgets/app_logo.dart';
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
  bool _showMultiplayer = false;
  GameMode _selectedMode = GameMode.diceDash;
  int _bjBotCount = 2;
  int _pokerBotCount = 3;
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _roomPasswordController = TextEditingController();
  final TextEditingController _playerNameController = TextEditingController();

  static const _playerNamePref = 'player_name';

  @override
  void initState() {
    super.initState();
    _loadPlayerName();
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

  /// The name chosen in Ajustes pre-fills every "Tu nombre" field.
  Future<void> _loadPlayerName() async {
    try {
      final name = (await SharedPreferences.getInstance()).getString(_playerNamePref);
      if (name != null && name.isNotEmpty && mounted && _playerNameController.text.isEmpty) {
        setState(() => _playerNameController.text = name);
      }
    } catch (_) {}
  }

  Future<void> _askPermissions() async {
    // Permissions are handled by the nearby_connections plugin internally.
    // The AndroidManifest.xml has all required permissions declared.
  }

  Future<void> _requestHardwarePermissions() async {
    // Bluetooth permissions are no longer needed for F-Droid TCP mode.
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
                        'Crear Sala',
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

  void _showBlackjackConfigDialog(double s) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
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
                        'Configurar Partida',
                        style: TextStyle(color: Colors.amber, fontSize: 18 * s, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16 * s),
                      TextField(
                        controller: _playerNameController,
                        style: TextStyle(color: Colors.white, fontSize: 14 * s),
                        textInputAction: TextInputAction.done,
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
                      SizedBox(height: 16 * s),
                      Text('Cantidad de bots', style: TextStyle(color: Colors.white54, fontSize: 13 * s)),
                      SizedBox(height: 8 * s),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.amber),
                            onPressed: () {
                              if (_bjBotCount > 0) {
                                setDialogState(() => _bjBotCount--);
                              }
                            },
                          ),
                          SizedBox(width: 16 * s),
                          Text('$_bjBotCount', style: TextStyle(color: Colors.white, fontSize: 20 * s, fontWeight: FontWeight.bold)),
                          SizedBox(width: 16 * s),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.amber),
                            onPressed: () {
                              if (_bjBotCount < 5) {
                                setDialogState(() => _bjBotCount++);
                              }
                            },
                          ),
                        ],
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
                              final pName = _playerNameController.text.trim();
                              if (pName.isNotEmpty) {
                                context.read<GameProvider>().setPlayerName(pName);
                              }
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChangeNotifierProvider(
                                    create: (_) => BlackjackProvider()..initSinglePlayer(
                                      botCount: _bjBotCount,
                                      playerName: pName.isEmpty ? 'Yo' : pName,
                                    ),
                                    child: const BlackjackTableScreen(),
                                  ),
                                ),
                              );
                            },
                            child: Text('Jugar', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13 * s)),
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

  void _showPokerConfigDialog(double s, GameMode mode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final modeName = mode == GameMode.diceDash ? 'Dice Dash' : "Texas Hold'em";
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
                        'Configurar $modeName',
                        style: TextStyle(color: Colors.amber, fontSize: 18 * s, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16 * s),
                      TextField(
                        controller: _playerNameController,
                        style: TextStyle(color: Colors.white, fontSize: 14 * s),
                        textInputAction: TextInputAction.done,
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
                      SizedBox(height: 16 * s),
                      Text('Cantidad de bots (1 - 6)', style: TextStyle(color: Colors.white54, fontSize: 13 * s)),
                      SizedBox(height: 8 * s),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.amber),
                            onPressed: () {
                              if (_pokerBotCount > 1) {
                                setDialogState(() => _pokerBotCount--);
                              }
                            },
                          ),
                          SizedBox(width: 16 * s),
                          Text('$_pokerBotCount', style: TextStyle(color: Colors.white, fontSize: 20 * s, fontWeight: FontWeight.bold)),
                          SizedBox(width: 16 * s),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.amber),
                            onPressed: () {
                              if (_pokerBotCount < 6) {
                                setDialogState(() => _pokerBotCount++);
                              }
                            },
                          ),
                        ],
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
                              final game = context.read<GameProvider>();
                              game.setHost(true);
                              game.setMultiplayer(false);
                              game.setGameMode(mode);
                              game.setBotCount(_pokerBotCount);
                              if (_playerNameController.text.trim().isNotEmpty) {
                                game.setPlayerName(_playerNameController.text.trim());
                              }
                              AppLogger().event('practice_mode_selected', params: {'mode': mode.name, 'bots': _pokerBotCount.toString()});
                              game.resetGame();
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const GameTableScreen()),
                              );
                            },
                            child: Text('Jugar', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13 * s)),
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

  void _startHostingInternal(String roomName, String password) {
    setState(() => _isHosting = true);
    final game = context.read<GameProvider>();
    final p2p = game.p2pService;

    game.setHost(true);
    game.setMultiplayer(true);
    game.setGameMode(_selectedMode);
    AppLogger().event('create_room', params: {'mode': _selectedMode.name, 'transport': 'tcp_local'});
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
            create: (_) => BlackjackProvider()..initMultiplayer(
              asHost: true,
              hostName: _playerNameController.text.trim().isEmpty ? 'Host' : _playerNameController.text.trim(),
              p2p: p2p,
              lobby: game,
            ),
            child: const BlackjackTableScreen(isMultiplayer: true, isHost: true),
          ),
        ),
      ).then((_) {
        if (mounted) setState(() => _isHosting = false);
        p2p.stopAdvertising();
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

  void startDiscovering() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RoomListScreen()),
    );
  }

  Future<bool> _onWillPop() async {
    if (_showMultiplayer) {
      setState(() => _showMultiplayer = false);
      return false;
    }
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('¿Salir del juego?', style: TextStyle(color: Colors.amber)),
        content: const Text('¿Estás seguro que quieres salir de la aplicación?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final s = (size.shortestSide / 400).clamp(0.75, 1.35).toDouble();

    return WillPopScope(
      onWillPop: _onWillPop,
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
            child: LayoutBuilder(
              builder: (context, c) {
                final landscape = c.maxWidth > c.maxHeight * 1.05;
                final options = ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 460 * s),
                  child: _showMultiplayer ? _buildMultiplayerOptions(s) : _buildMainOptions(s),
                );
                if (landscape) {
                  // PC, tablets and phones on their side: logo left, options right. No scrolling.
                  final logo = (c.maxHeight * 0.58).clamp(120.0, 420.0);
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 12 * s),
                    child: Row(
                      children: [
                        Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: AppLogo(size: logo)))),
                        SizedBox(width: 24 * s),
                        Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: SizedBox(width: 460 * s, child: options)))),
                      ],
                    ),
                  );
                }
                final logo = (c.maxHeight * 0.26).clamp(110.0, 300.0).toDouble();
                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 16 * s),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppLogo(size: logo),
                        SizedBox(height: 28 * s),
                        options,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainOptions(double s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModeTile(
          scale: s,
          title: 'Dice Dash',
          subtitle: 'Póker con dados y caos',
          accent: const Color(0xFFFAC775),
          onAccent: const Color(0xFF633806),
          icon: Icons.casino,
          onTap: () => _showPokerConfigDialog(s, GameMode.diceDash),
        ),
        SizedBox(height: 10 * s),
        _ModeTile(
          scale: s,
          title: "Texas Hold'em",
          subtitle: 'El póker clásico',
          accent: const Color(0xFFF7C1C1),
          onAccent: const Color(0xFF791F1F),
          glyph: CustomPaint(size: Size.square(24 * s), painter: const SpadePainter(Color(0xFF791F1F))),
          onTap: () => _showPokerConfigDialog(s, GameMode.texasHoldem),
        ),
        SizedBox(height: 10 * s),
        _ModeTile(
          scale: s,
          title: 'Blackjack',
          subtitle: 'Gánale al crupier',
          accent: const Color(0xFFC0DD97),
          onAccent: const Color(0xFF27500A),
          symbol: '21',
          onTap: () => _showBlackjackConfigDialog(s),
        ),
        SizedBox(height: 16 * s),
        Row(
          children: [
            Expanded(
              child: _PillButton(
                scale: s,
                label: 'Jugar en red',
                icon: Icons.wifi,
                filled: true,
                onTap: () => setState(() => _showMultiplayer = true),
              ),
            ),
            SizedBox(width: 10 * s),
            _PillButton(scale: s, icon: Icons.help_outline, tooltip: 'Cómo jugar', onTap: () => _showHowToPlay(s)),
            SizedBox(width: 10 * s),
            _PillButton(scale: s, icon: Icons.settings_outlined, tooltip: 'Ajustes', onTap: () => _showSettings(s)),
          ],
        ),
      ],
    );
  }

  Widget _buildMultiplayerOptions(double s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12 * s),
          child: Row(
            children: [
              Icon(Icons.wifi, color: const Color(0xFFFFD54F), size: 20 * s),
              SizedBox(width: 8 * s),
              Text('Jugar en red', style: TextStyle(color: Colors.white, fontSize: 18 * s, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        _ModeTile(
          scale: s,
          title: _isHosting ? 'Esperando...' : 'Crear sala',
          subtitle: 'Los demás se unen a tu partida',
          accent: const Color(0xFFFAC775),
          onAccent: const Color(0xFF633806),
          icon: Icons.add_circle_outline,
          busy: _isHosting,
          onTap: _isHosting ? null : startHosting,
        ),
        SizedBox(height: 10 * s),
        _ModeTile(
          scale: s,
          title: 'Unirse a sala',
          subtitle: 'Busca partidas en tu Wi-Fi o entra por IP',
          accent: const Color(0xFFB5D4F4),
          onAccent: const Color(0xFF0C447C),
          icon: Icons.login,
          onTap: startDiscovering,
        ),
        SizedBox(height: 10 * s),
        Text(
          'Todos los dispositivos deben estar en la misma red Wi-Fi.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 11.5 * s),
        ),
        SizedBox(height: 12 * s),
        _PillButton(
          scale: s,
          label: 'Volver',
          icon: Icons.arrow_back,
          onTap: () => setState(() => _showMultiplayer = false),
        ),
      ],
    );
  }

  void _showHowToPlay(double s) {
    Widget section(String title, Color color, List<String> lines) => Padding(
          padding: EdgeInsets.only(bottom: 12 * s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15 * s)),
              SizedBox(height: 4 * s),
              for (final l in lines)
                Padding(
                  padding: EdgeInsets.only(bottom: 2 * s),
                  child: Text('• $l', style: TextStyle(color: Colors.white, fontSize: 13 * s, height: 1.35)),
                ),
            ],
          ),
        );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF07160D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16 * s),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
        ),
        title: Text('Cómo jugar', style: TextStyle(color: const Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 18 * s)),
        content: SizedBox(
          width: 420 * s,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                section("Texas Hold'em", const Color(0xFFF7C1C1), [
                  'Recibes 2 cartas; en la mesa salen 5 comunitarias (flop, turn y river).',
                  'En cada ronda puedes retirarte (FOLD), igualar (CALL/CHECK) o subir (RAISE).',
                  'Gana la mejor jugada de 5 cartas entre tus 2 y las 5 de la mesa.',
                ]),
                section('Dice Dash', const Color(0xFFFAC775), [
                  "Como Texas Hold'em, pero antes de cada acción lanzas 2 dados.",
                  'Suma 7: el bote crece un 30 %.',
                  'Doble 1: ¡INTERCAMBIO! Las manos de todos se mezclan y se reparten de nuevo.',
                ]),
                section('Blackjack', const Color(0xFFC0DD97), [
                  'Apuesta y acércate a 21 sin pasarte. El As vale 1 u 11.',
                  'PEDIR toma carta, PLANTAR se queda, DOBLAR duplica la apuesta con una carta más, DIVIDIR separa una pareja.',
                  'Blackjack paga 3 a 2, el crupier se planta en 17 y 5 cartas sin pasarte (5-Card Charlie) ganan.',
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Entendido', style: TextStyle(color: const Color(0xFFFFD54F), fontSize: 14 * s)),
          ),
        ],
      ),
    );
  }

  void _showSettings(double s) {
    final nameCtrl = TextEditingController(text: _playerNameController.text);
    var sound = SoundService().enabled;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF07160D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16 * s),
            side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
          ),
          title: Text('Ajustes', style: TextStyle(color: const Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 18 * s)),
          content: SizedBox(
            width: 360 * s,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  maxLength: 16,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Tu nombre',
                    labelStyle: TextStyle(color: Colors.white70),
                    counterStyle: TextStyle(color: Colors.white38),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFD54F))),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: const Color(0xFFFFD54F),
                  title: const Text('Sonido', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Cartas, fichas y dados', style: TextStyle(color: Colors.white54)),
                  value: sound,
                  onChanged: (v) => setLocal(() => sound = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                setState(() => _playerNameController.text = name);
                await SoundService().setEnabled(sound);
                try {
                  await (await SharedPreferences.getInstance()).setString(_playerNamePref, name);
                } catch (_) {}
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guardar', style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A game mode (or room action) as a casino tile: icon chip, name, tagline.
/// Lights up on hover (PC) and focus (keyboard).
class _ModeTile extends StatefulWidget {
  final double scale;
  final String title;
  final String subtitle;
  final Color accent;
  final Color onAccent;
  final IconData? icon;
  final String? symbol;
  final Widget? glyph;
  final bool busy;
  final VoidCallback? onTap;

  const _ModeTile({
    required this.scale,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onAccent,
    this.icon,
    this.symbol,
    this.glyph,
    this.busy = false,
    required this.onTap,
  });

  @override
  State<_ModeTile> createState() => _ModeTileState();
}

class _ModeTileState extends State<_ModeTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    final lit = _hover && widget.onTap != null;
    return AnimatedScale(
      scale: lit ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (v) => setState(() => _hover = v),
          onFocusChange: (v) => setState(() => _hover = v),
          borderRadius: BorderRadius.circular(14 * s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 10 * s),
            decoration: BoxDecoration(
              color: const Color(0xFF07160D).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(14 * s),
              border: Border.all(
                color: lit ? const Color(0xFFFFD54F) : const Color(0xFFD4AF37).withValues(alpha: 0.35),
                width: lit ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: lit ? const Color(0xFFFFD54F).withValues(alpha: 0.3) : Colors.black45,
                  blurRadius: lit ? 14 * s : 6 * s,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44 * s,
                  height: 44 * s,
                  decoration: BoxDecoration(color: widget.accent, borderRadius: BorderRadius.circular(10 * s)),
                  alignment: Alignment.center,
                  child: widget.busy
                      ? SizedBox(
                          width: 20 * s,
                          height: 20 * s,
                          child: CircularProgressIndicator(strokeWidth: 2, color: widget.onAccent),
                        )
                      : widget.glyph ??
                          (widget.icon != null
                          ? Icon(widget.icon, color: widget.onAccent, size: 26 * s)
                          : Text(
                              widget.symbol ?? '',
                              style: TextStyle(color: widget.onAccent, fontSize: 22 * s, fontWeight: FontWeight.w900),
                            )),
                ),
                SizedBox(width: 12 * s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.title,
                          style: TextStyle(color: Colors.white, fontSize: 17 * s, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2 * s),
                      Text(widget.subtitle, style: TextStyle(color: Colors.white60, fontSize: 12 * s)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: lit ? const Color(0xFFFFD54F) : Colors.white38, size: 24 * s),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded gold pill: filled for the main action, outlined for icon buttons.
class _PillButton extends StatelessWidget {
  final double scale;
  final String? label;
  final IconData icon;
  final String? tooltip;
  final bool filled;
  final VoidCallback onTap;

  const _PillButton({
    required this.scale,
    this.label,
    required this.icon,
    this.tooltip,
    this.filled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = scale;
    const gold = Color(0xFFD4AF37);
    final child = Material(
      color: filled ? gold : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: gold, width: filled ? 0 : 1.5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: label == null ? 12 * s : 18 * s, vertical: 11 * s),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20 * s, color: filled ? const Color(0xFF412402) : const Color(0xFFFFD54F)),
              if (label != null) ...[
                SizedBox(width: 8 * s),
                Text(
                  label!,
                  style: TextStyle(
                    color: filled ? const Color(0xFF412402) : const Color(0xFFFFD54F),
                    fontSize: 15 * s,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}
