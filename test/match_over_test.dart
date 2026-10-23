import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/game_state.dart';
import 'package:poker_dice_dash/providers/game_provider.dart';
import 'package:poker_dice_dash/services/p2p_service.dart';

GameProvider localGame(int bots) {
  final g = GameProvider(p2pService: P2PService())
    ..setHost(true)
    ..setMultiplayer(false)
    ..setGameMode(GameMode.texasHoldem)
    ..setBotCount(bots);
  g.resetGame();
  return g;
}

/// Waits (real time) until [cond] holds, or fails after [timeout].
Future<void> waitFor(bool Function() cond, {Duration timeout = const Duration(seconds: 20), String? reason}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('timed out: ${reason ?? ''}');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      messenger.setMockMethodCallHandler(MethodChannel(ch), (call) async => null);
    }
  });

  testWidgets('heads-up against a bot: losing everything announces the winner, nobody is reset', (tester) async {
    final g = localGame(1);
    await tester.pump(const Duration(seconds: 1));
    final me = g.players.firstWhere((p) => p.id == g.localPlayerId);
    final bot = g.players.firstWhere((p) => p.isBot);
    g.debugSetChips(me.id, 0);
    g.debugSetChips(bot.id, 2000);
    g.shuffleAndDeal();
    expect(g.matchWinnerId, bot.id);
    expect(g.state.status, GameStatus.finished);
    expect(bot.chipBalance, 2000, reason: 'the winner keeps the chips while the announcement is up');
    final round = g.roundCounter;
    await tester.pump(const Duration(seconds: 30));
    expect(g.roundCounter, round, reason: 'no new hand until somebody chooses "Jugar otra vez"');
    expect(g.matchWinnerId, bot.id);

    g.restartMatch();
    expect(g.matchWinnerId, isNull);
    expect(g.players.every((p) => p.chipBalance == 1000), isTrue);
    await tester.pump(const Duration(seconds: 6));
    expect(g.roundCounter, greaterThan(round), reason: 'a new hand is dealt after the restart');
    expect(me.hand, hasLength(2));
    g.exitGame();
    g.dispose();
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('with several bots the match goes on: the busted human just sits out (RECOMPRAR)', (tester) async {
    final g = localGame(3);
    await tester.pump(const Duration(seconds: 1));
    final me = g.players.firstWhere((p) => p.id == g.localPlayerId);
    g.debugSetChips(me.id, 0);
    g.shuffleAndDeal();
    expect(g.matchWinnerId, isNull);
    expect(me.isBankrupt, isTrue);
    g.exitGame();
    g.dispose();
    await tester.pump(const Duration(seconds: 30));
  });

  test('LAN: the client sees who won the match and only the host can restart it', () async {
    final hostP2p = P2PService();
    final clientP2p = P2PService();
    final host = GameProvider(p2pService: hostP2p)
      ..setHost(true)
      ..setMultiplayer(true)
      ..setGameMode(GameMode.texasHoldem)
      ..setPlayerName('Ana');
    final client = GameProvider(p2pService: clientP2p)
      ..setHost(false)
      ..setMultiplayer(true)
      ..setPlayerName('Beto');
    addTearDown(() async {
      client.exitGame();
      host.exitGame();
      client.dispose();
      host.dispose();
      await clientP2p.dispose();
      await hostP2p.dispose();
    });
    await hostP2p.startAdvertising('test|1/4|0|0|texasHoldem');
    expect(await clientP2p.connectToHost('127.0.0.1', hostP2p.hostPort!), isTrue);
    final ep = '127.0.0.1:${hostP2p.hostPort}';
    await clientP2p.sendMessage(ep, {
      'type': 'JOIN_REQUEST',
      'playerName': 'Beto',
      'password': '',
      'token': client.playerToken,
      'endpointId': ep,
    });
    await waitFor(() => host.players.length == 2, reason: 'client seated');
    host.startMatch();
    await waitFor(() => client.players.length == 2 && client.players.any((p) => p.hand.isNotEmpty), reason: 'first hand on the client');

    final clientSeat = host.players.firstWhere((p) => p.id != host.localPlayerId).id;
    host.debugSetChips(clientSeat, 0);
    host.debugSetChips(host.localPlayerId, 2000);
    host.shuffleAndDeal();
    expect(host.matchWinnerId, host.localPlayerId);
    await waitFor(() => client.matchWinnerId == host.localPlayerId, reason: 'announcement on the client');

    client.restartMatch(); // not the host: nothing happens
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(host.matchWinnerId, host.localPlayerId);

    host.restartMatch();
    await waitFor(() => client.matchWinnerId == null, reason: 'restart reaches the client');
    await waitFor(() => client.players.every((p) => p.chipBalance <= 1000 && p.chipBalance >= 980), reason: 'chips back to 1000');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
