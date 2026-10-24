import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/game_state.dart';
import 'package:poker_dice_dash/providers/game_provider.dart';
import 'package:poker_dice_dash/services/p2p_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      messenger.setMockMethodCallHandler(MethodChannel(ch), (call) async => null);
    }
  });

  for (final mode in [GameMode.texasHoldem, GameMode.diceDash]) {
    test('single player after a LAN game as a client: you sit in your own seat (${mode.name})', () {
      final g = GameProvider(p2pService: P2PService());
      addTearDown(g.dispose);
      // A LAN game as a client: the host gave us seat 2.
      g
        ..setHost(false)
        ..setMultiplayer(true)
        ..setPlayerName('Carla');
      g.localPlayerId = '2';
      g.exitGame();

      // Back in the menu: single player, as the lobby does it.
      g
        ..setHost(true)
        ..setMultiplayer(false)
        ..setGameMode(mode)
        ..setBotCount(3)
        ..resetGame();

      expect(g.localPlayerId, '0');
      final me = g.players.firstWhere((p) => p.id == g.localPlayerId);
      expect(me.name, 'Carla');
      expect(me.isLocal, isTrue);
      expect(me.isBot, isFalse);
      expect(g.players.where((p) => p.isLocal), hasLength(1), reason: 'only one seat is "you"');
      expect(g.players.where((p) => !p.isBot && !p.isLocal), isEmpty, reason: 'no human ghost to wait for');
    });
  }

  test('a new LAN room starts clean: no bets or blinds left from the practice table', () async {
    final p2p = P2PService()..preferredPort = 47556;
    final g = GameProvider(p2pService: p2p)
      ..setHost(true)
      ..setMultiplayer(true)
      ..setGameMode(GameMode.texasHoldem);
    addTearDown(() async {
      g.dispose();
      await p2p.dispose();
    });
    g.assignSeatToClient('10.0.0.2:5000', playerName: 'Carla', token: 'a');
    g.assignSeatToClient('10.0.0.3:5000', playerName: 'Luis', token: 'b');
    expect(g.state.status, GameStatus.waitingPlayers);
    expect([for (final p in g.players) g.getPlayerBet(p.id)], everyElement(0));
    expect(g.pot, 0);
  });
}
