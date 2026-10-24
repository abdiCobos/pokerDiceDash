import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/game_state.dart';
import 'package:poker_dice_dash/providers/game_provider.dart';
import 'package:poker_dice_dash/services/p2p_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      m.setMockMethodCallHandler(MethodChannel(ch), (call) async => null);
    }
  });

  test('someone who joins mid-hand never gets a turn without cards', () async {
    final p2p = P2PService()..preferredPort = 47557;
    final g = GameProvider(p2pService: p2p)
      ..setHost(true)
      ..setMultiplayer(true)
      ..setGameMode(GameMode.texasHoldem)
      ..setPlayerName('Ana');
    addTearDown(() async {
      g.exitGame();
      g.dispose();
      await p2p.dispose();
    });
    g.assignSeatToClient('10.0.0.2:5000', playerName: 'Carla', token: 'a');
    g.startMatch();
    expect(g.state.status, GameStatus.betting);
    g.assignSeatToClient('10.0.0.3:5000', playerName: 'Luis', token: 'b'); // arrives mid-hand
    final late = g.players.last.id;
    expect(g.players.last.hand, isEmpty);

    final start = g.roundCounter;
    for (var i = 0; i < 400 && g.roundCounter == start && g.state.status != GameStatus.finished; i++) {
      final ci = g.state.currentPlayerIndex;
      if (ci >= 0 && ci < g.players.length) {
        expect(g.players[ci].id, isNot(late), reason: 'the newcomer has no cards in this hand');
        if (g.state.status == GameStatus.betting && !g.isBetting) g.call(g.players[ci].id);
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }, timeout: const Timeout(Duration(seconds: 60)));
}
