import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/game_state.dart';
import 'package:poker_dice_dash/providers/game_provider.dart';
import 'package:poker_dice_dash/services/p2p_service.dart';

Future<void> waitFor(bool Function() cond, {Duration timeout = const Duration(seconds: 30), String? reason}) async {
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

  test('LAN poker: a player who does not act is played for after the turn time', () async {
    GameProvider.turnTimeout = const Duration(seconds: 3);
    addTearDown(() => GameProvider.turnTimeout = const Duration(seconds: 60));
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
      ..setPlayerName('Luis');
    addTearDown(() async {
      client.exitGame();
      host.exitGame();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      client.dispose();
      host.dispose();
      await clientP2p.dispose();
      await hostP2p.dispose();
    });
    await hostP2p.startAdvertising('t|1/4|0|0|texasHoldem');
    expect(await clientP2p.connectToHost('127.0.0.1', hostP2p.hostPort!), isTrue);
    final ep = '127.0.0.1:${hostP2p.hostPort}';
    await clientP2p.sendMessage(ep, {
      'type': 'JOIN_REQUEST',
      'playerName': 'Luis',
      'password': '',
      'token': client.playerToken,
      'endpointId': ep,
    });
    await waitFor(() => host.players.length == 2, reason: 'seated');
    host.startMatch();
    await waitFor(() => client.state.status == GameStatus.betting && client.turnSecondsLeft != null,
        reason: 'the client sees the turn clock');
    expect(client.turnSecondsLeft, lessThanOrEqualTo(3));

    // Nobody touches anything: the clock plays for whoever is idle and the hand ends.
    final idle = host.players[host.state.currentPlayerIndex].id;
    await waitFor(() => host.resultTitle != null, reason: 'the hand finishes on its own');
    expect(host.players.firstWhere((p) => p.id == idle).isFolded, isTrue,
        reason: 'they owed the big blind, so the clock folded for them');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a turn lasts one minute', () {
    expect(GameProvider.turnTimeout, const Duration(seconds: 60));
  });

  test('single player has no turn clock (take your time)', () {
    final g = GameProvider(p2pService: P2PService())
      ..setHost(true)
      ..setMultiplayer(false)
      ..setGameMode(GameMode.texasHoldem);
    addTearDown(g.dispose);
    expect(g.turnSecondsLeft, isNull);
  });
}
