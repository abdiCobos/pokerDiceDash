import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'logger_service.dart';
import 'sound_service.dart';

/// Where the tables and the menu are set: the plain green felt of the first version, or a
/// pixel-art scene (assets/images/cantina).
enum TableTheme {
  clasico('Clásico', 'Verde y simple'),
  cantina('Cantina mexicana', 'Papel picado y tequila'),
  garito('Garito clandestino', 'Mafia y dinero sucio');

  const TableTheme(this.label, this.description);
  final String label;
  final String description;
}

/// Player options shown in the in-table "Opciones" dialog (and partly in Ajustes).
/// Saved between sessions. Listen to it to react to changes mid-game.
class GameSettings extends ChangeNotifier {
  static final GameSettings _instance = GameSettings._();
  factory GameSettings() => _instance;
  GameSettings._();

  static const _fastKey = 'fast_game';
  static const _oddsKey = 'show_odds';
  static const _awakeKey = 'keep_awake';
  static const _themeKey = 'table_theme';

  bool _fastGame = false;
  bool _showOdds = false;
  bool _keepAwake = true;
  TableTheme _theme = TableTheme.cantina;

  /// Scene behind the menu and the tables (cantina unless the player picked another).
  TableTheme get theme => _theme;

  bool get sound => SoundService().enabled;

  /// Bots think and the dealer deals faster.
  bool get fastGame => _fastGame;

  /// Poker helper: shows your chance of winning the hand on your seat.
  bool get showOdds => _showOdds;

  /// Keep the screen on while sitting at a table.
  bool get keepAwake => _keepAwake;

  /// "Juego rápido" is hidden for now (the user did not like it). Flip this to
  /// bring it back: the toggle in table_options.dart and the pace below return.
  static const bool fastGameAvailable = false;

  /// Multiplier for bot "thinking" and dealing pauses.
  double get pace => (fastGameAvailable && _fastGame) ? 0.4 : 1.0;

  Duration scaled(Duration d) => Duration(milliseconds: (d.inMilliseconds * pace).round());

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _fastGame = p.getBool(_fastKey) ?? false;
      _showOdds = p.getBool(_oddsKey) ?? false;
      _keepAwake = p.getBool(_awakeKey) ?? true;
      final t = p.getString(_themeKey);
      _theme = TableTheme.values.firstWhere((v) => v.name == t, orElse: () => TableTheme.cantina);
    } catch (_) {}
    await SoundService().load();
  }

  Future<void> _save(String key, bool value) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(key, value);
    } catch (_) {}
  }

  Future<void> setSound(bool v) async {
    await SoundService().setEnabled(v);
    notifyListeners();
  }

  Future<void> setFastGame(bool v) async {
    _fastGame = v;
    notifyListeners();
    await _save(_fastKey, v);
  }

  Future<void> setShowOdds(bool v) async {
    _showOdds = v;
    notifyListeners();
    await _save(_oddsKey, v);
  }

  Future<void> setKeepAwake(bool v) async {
    _keepAwake = v;
    notifyListeners();
    applyWakelock(atTable: true);
    await _save(_awakeKey, v);
  }

  Future<void> setTheme(TableTheme t) async {
    if (t == _theme) return;
    _theme = t;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(_themeKey, t.name);
    } catch (_) {}
  }

  /// Tables call this on enter (atTable: true) and on leave (false).
  void applyWakelock({required bool atTable}) {
    // Fails asynchronously on desktops without the screensaver service (e.g. Linux without
    // xdg-desktop-portal): catch it on the future, a try/catch here would not see it.
    try {
      ((atTable && _keepAwake) ? WakelockPlus.enable() : WakelockPlus.disable())
          .catchError((Object e) => AppLogger().log('Wakelock no disponible: $e'));
    } catch (_) {}
  }
}
