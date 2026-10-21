import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  final Map<String, AudioPlayer> _players = {};

  static const _prefKey = 'sound_enabled';

  /// Player setting (Ajustes). Persisted; every sound checks it.
  bool enabled = true;

  /// Tests set this to a list to record which sounds the game asked for.
  static List<String>? debugLog;

  Future<void> load() async {
    try {
      enabled = (await SharedPreferences.getInstance()).getBool(_prefKey) ?? true;
    } catch (_) {}
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    try {
      await (await SharedPreferences.getInstance()).setBool(_prefKey, value);
    } catch (_) {}
  }

  Future<void> _play(String file) async {
    if (!enabled) return;
    debugLog?.add(file);
    try {
      final player = _players.putIfAbsent(file, () {
        final p = AudioPlayer();
        p.setReleaseMode(ReleaseMode.stop);
        return p;
      });
      await player.stop();
      await player.play(AssetSource('sounds/$file'));
    } catch (_) {
      // Ignored: sound is non-critical
    }
  }

  // Community cards come out ~half a second apart and must not cut each other off,
  // so they rotate through a small pool instead of the single per-file player.
  final List<AudioPlayer> _flipPool = [];
  int _flipNext = 0;

  Future<void> cardFlip() async {
    if (!enabled) return;
    debugLog?.add('cardflip');
    try {
      if (_flipPool.isEmpty) {
        for (var i = 0; i < 3; i++) {
          _flipPool.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
        }
      }
      final player = _flipPool[_flipNext++ % _flipPool.length];
      await player.stop();
      await player.play(AssetSource('sounds/cardfold.mp3'));
    } catch (_) {
      // Ignored: sound is non-critical
    }
  }

  void cardMix() => _play('cardmix.mp3');
  void cardFold() => _play('cardfold.mp3');
  void cardPlace() => _play('cardfold.mp3');
  void caosCard() => _play('caosCardSound.mp3');
  void chipsRaise() => _play('chipsRaise.mp3');
  void chipsMultiply() => _play('chipsMultiply.mp3');
  void chipsWin() => _play('chipsWin.mp3');
  void diceRoll() => _play('dice.mp3');

  void dispose() {
    for (final p in _players.values) {
      try {
        p.dispose();
      } catch (_) {}
    }
    _players.clear();
    for (final p in _flipPool) {
      try {
        p.dispose();
      } catch (_) {}
    }
    _flipPool.clear();
  }
}
