import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logger_service.dart';

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

  /// Failed plays this session. A broken audio stack (e.g. Linux without a working
  /// GStreamer decoder or sound server) can block the UI thread inside the plugin, and every
  /// retry leaves another stuck pipeline: after [maxFailures] the game stays silent.
  static const int maxFailures = 3;
  int _failures = 0;
  bool get audioBroken => _failures >= maxFailures;

  @visibleForTesting
  void debugResetFailures() => _failures = 0;

  @visibleForTesting
  void recordFailure(Object error) {
    _failures++;
    if (_failures == maxFailures) {
      AppLogger().log('Sonido desactivado en esta sesion: el audio fallo $maxFailures veces ($error)');
      dispose();
    }
  }

  /// Game sounds are short effects: they mix with the user's music (Spotify, etc.) instead of
  /// taking the audio focus, which made Android pause other apps on every card.
  static final AudioContext mixContext =
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();

  static bool get _mobile =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  AudioPlayer _newPlayer() {
    final p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    if (_mobile) {
      p.setAudioContext(mixContext).catchError((Object e) => AppLogger().log('AudioContext: $e'));
    }
    // Plugin errors also arrive on the event stream, not only as thrown exceptions.
    p.eventStream.listen((_) {}, onError: (Object e) => recordFailure(e));
    return p;
  }

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
    if (!enabled || audioBroken) return;
    debugLog?.add(file);
    try {
      final player = _players.putIfAbsent(file, _newPlayer);
      await player.stop();
      await player.play(AssetSource('sounds/$file'));
    } catch (e) {
      recordFailure(e); // sound is non-critical, but do not keep hammering a broken stack
    }
  }

  // Community cards come out ~half a second apart and must not cut each other off,
  // so they rotate through a small pool instead of the single per-file player.
  final List<AudioPlayer> _flipPool = [];
  int _flipNext = 0;

  Future<void> cardFlip() async {
    if (!enabled || audioBroken) return;
    debugLog?.add('cardflip');
    try {
      if (_flipPool.isEmpty) {
        for (var i = 0; i < 3; i++) {
          _flipPool.add(_newPlayer());
        }
      }
      final player = _flipPool[_flipNext++ % _flipPool.length];
      await player.stop();
      await player.play(AssetSource('sounds/cardfold.mp3'));
    } catch (e) {
      recordFailure(e);
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
