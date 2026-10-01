import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  final Map<String, AudioPlayer> _players = {};

  Future<void> _play(String file) async {
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

  void cardMix() => _play('cardmix.ogg');
  void cardFold() => _play('cardfold.ogg');
  void cardPlace() => _play('cardfold.ogg');
  void caosCard() => _play('caosCardSound.ogg');
  void chipsRaise() => _play('chipsRaise.ogg');
  void chipsMultiply() => _play('chipsMultiply.ogg');
  void chipsWin() => _play('chipsWin.ogg');
  void diceRoll() => _play('dice.ogg');

  void dispose() {
    for (final p in _players.values) {
      try {
        p.dispose();
      } catch (_) {}
    }
    _players.clear();
  }
}
