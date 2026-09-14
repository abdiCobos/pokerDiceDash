import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  Future<void> _play(String file) async {
    final player = AudioPlayer();
    try {
      await player.play(AssetSource('sounds/$file'));
      player.onPlayerComplete.listen((_) => player.dispose());
      Future.delayed(const Duration(seconds: 4), () {
        try { player.dispose(); } catch (_) {}
      });
    } catch (_) {
      player.dispose();
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
}
