import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/game_provider.dart';
import '../../services/game_settings.dart';
import '../../services/logger_service.dart';
import '../../services/room_names.dart';
import '../../services/update_checker.dart';
import '../../app_version.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../../providers/blackjack_provider.dart';
import '../../models/game_state.dart';
import '../../services/poker_bot_ai.dart';
import '../../services/sound_service.dart';
import '../widgets/scene_background.dart';
import '../widgets/app_icon_painter.dart';
import '../widgets/app_logo.dart';
import 'game_table_screen.dart';
import 'blackjack_table_screen.dart';
import 'room_list_screen.dart';
import '../../l10n/l10n.dart';

class LobbyScreen extends StatefulWidget {
  /// Open directly on the "Jugar en red" options (coming back from the room list).
  final bool startInMultiplayer;

  const LobbyScreen({super.key, this.startInMultiplayer = false});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool _isHosting = false;
  late bool _showMultiplayer = widget.startInMultiplayer;
  GameMode _selectedMode = GameMode.diceDash;
  int _bjBotCount = 2;
  int _pokerBotCount = 3;
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _roomPasswordController = TextEditingController();
  final TextEditingController _playerNameController = TextEditingController();

  static const _playerNamePref = 'player_name';
  static const _difficultyPref = 'bot_difficulty';
  BotDifficulty _botDifficulty = BotDifficulty.normal;

  @override
  void initState() {
    super.initState();
    _loadPlayerName();
    _askPermissions();
    _requestHardwarePermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  /// Once per app start (and at most once a day): is there a newer release on GitHub?
  static bool _updateAsked = false;

  Future<void> _checkForUpdate() async {
    if (_updateAsked) return;
    _updateAsked = true;
    final update = await UpdateChecker.check();
    if (update == null || !mounted) return;
    final s = (MediaQuery.of(context).size.shortestSide / 400).clamp(0.75, 1.35).toDouble();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF07160D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16 * s),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
        ),
        title: Row(
          children: [
            Icon(Icons.system_update, color: const Color(0xFFFFD54F), size: 22 * s),
            SizedBox(width: 8 * s),
            Expanded(
              child: Text(context.t.updateTitle,
                  style: TextStyle(color: const Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 18 * s)),
            ),
          ],
        ),
        content: SizedBox(
          width: 380 * s,
          child: Text(
            context.t.updateBody(update.version, appVersion),
            style: TextStyle(color: Colors.white, fontSize: 14 * s, height: 1.35),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t.notNow, style: TextStyle(color: Colors.white54, fontSize: 14 * s)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await launchUrl(update.page, mode: LaunchMode.externalApplication).catchError((_) => false);
              if (!ok && mounted) {
                await Clipboard.setData(ClipboardData(text: update.page.toString()));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t.browserFailed)),
                );
              }
            },
            child: Text(context.t.download,
                style: TextStyle(color: const Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 14 * s)),
          ),
        ],
      ),
    );
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
      final diff = (await SharedPreferences.getInstance()).getString(_difficultyPref);
      final saved = BotDifficulty.values.where((d) => d.name == diff).firstOrNull;
      if (saved != null && mounted) setState(() => _botDifficulty = saved);
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
    _roomNameController.text = RoomNames.pick();
    _roomPasswordController.text = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final s = (MediaQuery.of(dialogCtx).size.shortestSide / 400).clamp(0.75, 1.35);
            return Dialog(
              backgroundColor: const Color(0xFF07160D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16 * s),
                side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
              ),
              // On PC the dialog would otherwise stretch across the whole window.
              child: Builder(builder: (_) {
                final nameField = TextField(
                  controller: _playerNameController,
                  style: TextStyle(color: Colors.white, fontSize: 14 * s),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.t.yourName,
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
                );
                final roomField = TextField(
                  controller: _roomNameController,
                  style: TextStyle(color: Colors.white, fontSize: 14 * s),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.t.roomName,
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
                );
                final passwordField = TextField(
                  controller: _roomPasswordController,
                  obscureText: true,
                  style: TextStyle(color: Colors.white, fontSize: 14 * s),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: context.t.passwordOptional,
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
                );
                final buttons = Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: Text(context.t.cancel, style: TextStyle(color: Colors.white54, fontSize: 13 * s)),
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
                      child: Text(context.t.create, style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13 * s)),
                    ),
                  ],
                );
                final title = Text(
                  context.t.createRoomTitle,
                  style: TextStyle(color: Colors.amber, fontSize: 18 * s, fontWeight: FontWeight.bold),
                );
                final screen = MediaQuery.of(dialogCtx).size;
                // Phones on their side are short: two columns so "Crear" shows without scrolling.
                if (screen.width > screen.height && screen.height < 560) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 760 * s),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20 * s, 14 * s, 20 * s, 8 * s),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          title,
                          SizedBox(height: 12 * s),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [nameField, SizedBox(height: 10 * s), _buildModeSelector(s, setDialogState)],
                                ),
                              ),
                              SizedBox(width: 16 * s),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [roomField, SizedBox(height: 10 * s), passwordField],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6 * s),
                          buttons,
                        ],
                      ),
                    ),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 520 * s),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20 * s),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        title,
                        SizedBox(height: 16 * s),
                        nameField,
                        SizedBox(height: 12 * s),
                        _buildModeSelector(s, setDialogState),
                        SizedBox(height: 12 * s),
                        roomField,
                        SizedBox(height: 12 * s),
                        passwordField,
                        SizedBox(height: 20 * s),
                        buttons,
                      ],
                    ),
                  ),
                );
              }),
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
              backgroundColor: const Color(0xFF07160D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16 * s),
                side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
              ),
              // On PC the dialog would otherwise stretch across the whole window.
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 520 * s),
                child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(20 * s),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.t.setupGame,
                        style: TextStyle(color: Colors.amber, fontSize: 18 * s, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16 * s),
                      TextField(
                        controller: _playerNameController,
                        style: TextStyle(color: Colors.white, fontSize: 14 * s),
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: context.t.yourName,
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
                      Text(context.t.botCount, style: TextStyle(color: Colors.white54, fontSize: 13 * s)),
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
                      if (_bjBotCount > 0) ...[
                        SizedBox(height: 12 * s),
                        _buildDifficultySelector(s, setDialogState),
                      ],
                      SizedBox(height: 20 * s),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: Text(context.t.cancel, style: TextStyle(color: Colors.white54, fontSize: 13 * s)),
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
                                      difficulty: _botDifficulty,
                                      playerName: pName.isEmpty ? context.t.defaultLocalName : pName,
                                    ),
                                    child: const BlackjackTableScreen(),
                                  ),
                                ),
                              );
                            },
                            child: Text(context.t.play, style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13 * s)),
                          ),
                        ],
                      ),
                    ],
                  ),
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
              backgroundColor: const Color(0xFF07160D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16 * s),
                side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
              ),
              // On PC the dialog would otherwise stretch across the whole window.
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 520 * s),
                child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(20 * s),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.t.setupMode(modeName),
                        style: TextStyle(color: Colors.amber, fontSize: 18 * s, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16 * s),
                      TextField(
                        controller: _playerNameController,
                        style: TextStyle(color: Colors.white, fontSize: 14 * s),
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: context.t.yourName,
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
                      Text(context.t.botCountRange, style: TextStyle(color: Colors.white54, fontSize: 13 * s)),
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
                      SizedBox(height: 12 * s),
                      _buildDifficultySelector(s, setDialogState),
                      SizedBox(height: 20 * s),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: Text(context.t.cancel, style: TextStyle(color: Colors.white54, fontSize: 13 * s)),
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
                              game.setBotDifficulty(_botDifficulty);
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
                            child: Text(context.t.play, style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13 * s)),
                          ),
                        ],
                      ),
                    ],
                  ),
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
      _playerNameController.text.trim().isEmpty ? context.t.defaultHostName : _playerNameController.text.trim(),
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
              hostName: _playerNameController.text.trim().isEmpty ? context.t.defaultHostName : _playerNameController.text.trim(),
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

  /// Fácil / Normal / Difícil, remembered between games.
  Widget _buildDifficultySelector(double s, StateSetter setDialogState) {
    return Column(
      children: [
        Text(context.t.botDifficulty, style: TextStyle(color: Colors.white54, fontSize: 13 * s)),
        SizedBox(height: 8 * s),
        Row(
          children: [
            for (final d in BotDifficulty.values) ...[
              if (d != BotDifficulty.easy) SizedBox(width: 8 * s),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20 * s),
                  onTap: () {
                    setState(() => _botDifficulty = d);
                    setDialogState(() {});
                    SharedPreferences.getInstance().then((p) => p.setString(_difficultyPref, d.name)).catchError((_) => false);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(vertical: 8 * s),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _botDifficulty == d ? const Color(0xFFD4AF37) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20 * s),
                      border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
                    ),
                    child: Text(
                      context.t.difficultyName(d),
                      style: TextStyle(
                        color: _botDifficulty == d ? const Color(0xFF412402) : const Color(0xFFFFD54F),
                        fontSize: 13 * s,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 6 * s),
        Text(context.t.difficultyHint(_botDifficulty), textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11.5 * s)),
      ],
    );
  }

  Widget _buildModeSelector(double s, StateSetter setDialogState) {
    Widget option(GameMode mode, String label, Color accent, Color onAccent, Widget glyph) {
      final selected = _selectedMode == mode;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12 * s),
            onTap: () {
              setState(() => _selectedMode = mode);
              setDialogState(() {});
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(vertical: 10 * s, horizontal: 6 * s),
              decoration: BoxDecoration(
                color: selected ? Color.lerp(const Color(0xFF07160D), accent, 0.16) : const Color(0xFF07160D),
                borderRadius: BorderRadius.circular(12 * s),
                border: Border.all(
                  color: selected ? accent : Colors.white24,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 34 * s,
                        height: 34 * s,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(8 * s)),
                        child: glyph,
                      ),
                      if (selected)
                        Positioned(
                          right: -6 * s,
                          top: -6 * s,
                          child: Container(
                            padding: EdgeInsets.all(1.5 * s),
                            decoration: BoxDecoration(color: onAccent, shape: BoxShape.circle),
                            child: Icon(Icons.check, size: 12 * s, color: accent),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 6 * s),
                  // Shrinks instead of cutting "Texas Hold'em" on narrow phones.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 12.5 * s,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t.gameMode, style: TextStyle(color: Colors.white54, fontSize: 13 * s)),
        SizedBox(height: 8 * s),
        Row(
          children: [
            option(GameMode.diceDash, 'Dice Dash', const Color(0xFFFAC775), const Color(0xFF633806),
                Icon(Icons.casino, color: const Color(0xFF633806), size: 22 * s)),
            SizedBox(width: 8 * s),
            option(GameMode.texasHoldem, "Texas Hold'em", const Color(0xFFF7C1C1), const Color(0xFF791F1F),
                CustomPaint(size: Size.square(20 * s), painter: const SpadePainter(Color(0xFF791F1F)))),
            SizedBox(width: 8 * s),
            option(GameMode.blackjack, 'Blackjack', const Color(0xFFC0DD97), const Color(0xFF27500A),
                Text('21', style: TextStyle(color: const Color(0xFF27500A), fontSize: 16 * s, fontWeight: FontWeight.w900))),
          ],
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
        title: Text(context.t.quitAppTitle, style: TextStyle(color: Colors.amber)),
        content: Text(context.t.quitAppBody, style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.t.cancel, style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.t.exit, style: TextStyle(color: Colors.red)),
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
        body: SceneBackground(
          shade: 0.12,
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
          subtitle: context.t.modeDiceDashSubtitle,
          accent: const Color(0xFFFAC775),
          onAccent: const Color(0xFF633806),
          icon: Icons.casino,
          onTap: () => _showPokerConfigDialog(s, GameMode.diceDash),
        ),
        SizedBox(height: 10 * s),
        _ModeTile(
          scale: s,
          title: "Texas Hold'em",
          subtitle: context.t.modeTexasSubtitle,
          accent: const Color(0xFFF7C1C1),
          onAccent: const Color(0xFF791F1F),
          glyph: CustomPaint(size: Size.square(24 * s), painter: const SpadePainter(Color(0xFF791F1F))),
          onTap: () => _showPokerConfigDialog(s, GameMode.texasHoldem),
        ),
        SizedBox(height: 10 * s),
        _ModeTile(
          scale: s,
          title: 'Blackjack',
          subtitle: context.t.modeBlackjackSubtitle,
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
                label: context.t.playLan,
                icon: Icons.wifi,
                filled: true,
                onTap: () => setState(() => _showMultiplayer = true),
              ),
            ),
            SizedBox(width: 10 * s),
            _PillButton(scale: s, icon: Icons.help_outline, tooltip: context.t.howToPlay, onTap: () => _showHowToPlay(s)),
            SizedBox(width: 10 * s),
            _PillButton(scale: s, icon: Icons.settings_outlined, tooltip: context.t.settings, onTap: () => _showSettings(s)),
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
              Text(context.t.playLan, style: TextStyle(color: Colors.white, fontSize: 18 * s, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        _ModeTile(
          scale: s,
          title: _isHosting ? context.t.waitingEllipsis : context.t.createRoom,
          subtitle: context.t.createRoomSubtitle,
          accent: const Color(0xFFFAC775),
          onAccent: const Color(0xFF633806),
          icon: Icons.add_circle_outline,
          busy: _isHosting,
          onTap: _isHosting ? null : startHosting,
        ),
        SizedBox(height: 10 * s),
        _ModeTile(
          scale: s,
          title: context.t.joinRoom,
          subtitle: context.t.joinRoomSubtitle,
          accent: const Color(0xFFB5D4F4),
          onAccent: const Color(0xFF0C447C),
          icon: Icons.login,
          onTap: startDiscovering,
        ),
        SizedBox(height: 10 * s),
        Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 4 * s),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10 * s)),
            child: Text(
              context.t.sameWifiNote,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 11.5 * s),
            ),
          ),
        ),
        SizedBox(height: 12 * s),
        _PillButton(
          scale: s,
          label: context.t.back,
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
        title: Text(context.t.howToPlay, style: TextStyle(color: const Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 18 * s)),
        content: SizedBox(
          width: 420 * s,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                section("Texas Hold'em", const Color(0xFFF7C1C1), [
                  context.t.howTexas1,
                  context.t.howTexas2,
                  context.t.howTexas3,
                ]),
                section('Dice Dash', const Color(0xFFFAC775), [
                  context.t.howDice1,
                  context.t.howDice2,
                  context.t.howDice3,
                  context.t.howDice4,
                ]),
                section('Blackjack', const Color(0xFFC0DD97), [
                  context.t.howBj1,
                  context.t.howBj2,
                  context.t.howBj3,
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t.gotIt, style: TextStyle(color: const Color(0xFFFFD54F), fontSize: 14 * s)),
          ),
        ],
      ),
    );
  }

  Future<void> _showSettings(double s) async {
    final nameCtrl = TextEditingController(text: _playerNameController.text);
    var sound = SoundService().enabled;
    var theme = GameSettings().theme;
    var language = GameSettings().language;
    var updates = await UpdateChecker.isEnabled();
    if (!mounted) return;
    final screen = MediaQuery.of(context).size;
    final landscape = screen.width > screen.height;
    showDialog(
      context: context,
      // The dialog is laid out for the design's text size: a bigger system font would push
      // the language row and the scene names out of it.
      builder: (ctx) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.0,
        child: StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          // Landscape phones are short: the content shrinks to fit. Portrait scrolls if needed.
          scrollable: !landscape,
          insetPadding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 16 * s),
          backgroundColor: const Color(0xFF07160D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16 * s),
            side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
          ),
          title: Text(context.t.settings, style: TextStyle(color: const Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 18 * s)),
          content: Builder(builder: (context) {
            final general = <Widget>[
              TextField(
                controller: nameCtrl,
                maxLength: 16,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: context.t.yourName,
                  labelStyle: TextStyle(color: Colors.white70),
                  counterText: '',
                  isDense: true,
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFD54F))),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                activeThumbColor: const Color(0xFFFFD54F),
                title: Text(context.t.sound, style: TextStyle(color: Colors.white)),
                subtitle: Text(context.t.soundSubtitle, style: TextStyle(color: Colors.white54)),
                value: sound,
                onChanged: (v) => setLocal(() => sound = v),
              ),
              if (UpdateChecker.availableInBuild)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  activeThumbColor: const Color(0xFFFFD54F),
                  title: Text(context.t.updateCheck, style: TextStyle(color: Colors.white)),
                  subtitle: Text(context.t.updateCheckSubtitle, style: TextStyle(color: Colors.white54)),
                  value: updates,
                  onChanged: (v) => setLocal(() => updates = v),
                ),
            ];
            final ambient = <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(context.t.scene, style: TextStyle(color: Colors.white, fontSize: 15 * s)),
              ),
              SizedBox(height: 8 * s),
              // Same height for every card, even when a name fits on one line.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final t in TableTheme.values) ...[
                      if (t != TableTheme.values.first) SizedBox(width: 10 * s),
                      Expanded(
                        child: _ThemeCard(
                          theme: t,
                          selected: t == theme,
                          scale: s,
                          onTap: () => setLocal(() => theme = t),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ];
            final languagePicker = <Widget>[
              SizedBox(height: 10 * s),
              Row(
                children: [
                  Text(context.t.language, style: TextStyle(color: Colors.white, fontSize: 15 * s)),
                  SizedBox(width: 10 * s),
                  for (final l in AppLanguage.values) ...[
                    if (l != AppLanguage.values.first) SizedBox(width: 8 * s),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20 * s),
                        onTap: () => setLocal(() => language = l),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: EdgeInsets.symmetric(vertical: 7 * s),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: language == l ? const Color(0xFFD4AF37) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20 * s),
                            border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              switch (l) {
                                AppLanguage.system => context.t.languageSystem,
                                // Each language in its own words, so anyone can find theirs.
                                AppLanguage.es => 'Español',
                                AppLanguage.en => 'English',
                              },
                              style: TextStyle(
                                color: language == l ? const Color(0xFF412402) : const Color(0xFFFFD54F),
                                fontSize: 12.5 * s,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ];
            final size = MediaQuery.of(context).size;
            // Landscape phones are short: name and sound on the left, the scenes on the right.
            if (size.width > size.height) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 640 * s,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [...general, ...languagePicker])),
                      SizedBox(width: 20 * s),
                      Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: ambient)),
                    ],
                  ),
                ),
              );
            }
            return SizedBox(
              width: 360 * s,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [...general, SizedBox(height: 6 * s), ...ambient, ...languagePicker],
              ),
            );
          }),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.t.cancel, style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                setState(() => _playerNameController.text = name);
                await SoundService().setEnabled(sound);
                await GameSettings().setTheme(theme);
                await GameSettings().setLanguage(language);
                await UpdateChecker.setEnabled(updates);
                try {
                  await (await SharedPreferences.getInstance()).setString(_playerNamePref, name);
                } catch (_) {}
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(context.t.save, style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
      // Outlined pills get a dark fill: the menu sits on the busy cantina background.
      color: filled ? gold : const Color(0xCC0C0806),
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

/// Ajustes: one scene to pick (a crop of its pixel-art backdrop, its name and a hint).
class _ThemeCard extends StatelessWidget {
  final TableTheme theme;
  final bool selected;
  final double scale;
  final VoidCallback onTap;

  const _ThemeCard({required this.theme, required this.selected, required this.scale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = scale;
    const gold = Color(0xFFFFD54F);
    return Material(
      color: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10 * s),
        side: BorderSide(color: selected ? gold : Colors.white24, width: selected ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 50 * s,
                  child: theme == TableTheme.clasico
                      ? DecoratedBox(
                          decoration: const BoxDecoration(gradient: SceneBackground.classicGradient),
                          child: Center(
                            child: Container(
                              width: 64 * s,
                              height: 30 * s,
                              decoration: BoxDecoration(
                                color: const Color(0xFF168A4E),
                                borderRadius: BorderRadius.circular(15 * s),
                                border: Border.all(color: const Color(0xFF3E2410), width: 3 * s),
                              ),
                            ),
                          ),
                        )
                      : Image.asset(
                          'assets/images/cantina/${theme.name}_bg_16x9.png',
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.35),
                          filterQuality: FilterQuality.none,
                        ),
                ),
                if (selected)
                  Positioned(
                    top: 4 * s,
                    right: 4 * s,
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: Icon(Icons.check_circle, color: gold, size: 16 * s),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(8 * s, 6 * s, 8 * s, 8 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t.themeName(theme),
                    maxLines: 2,
                    style: TextStyle(color: selected ? gold : Colors.white, fontSize: 12.5 * s, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2 * s),
                  Text(
                    context.t.themeDescription(theme),
                    maxLines: 2,
                    style: TextStyle(color: Colors.white54, fontSize: 10.5 * s),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
