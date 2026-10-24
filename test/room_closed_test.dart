import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/game_state.dart';
import 'package:poker_dice_dash/providers/game_provider.dart';
import 'package:poker_dice_dash/services/p2p_service.dart';

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

  test('when the host leaves the table, every client is told the room is closed (no frozen table)', () async {
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
      'playerName': 'Luis',
      'password': '',
      'token': client.playerToken,
      'endpointId': ep,
    });
    await waitFor(() => host.players.length == 2, reason: 'client seated');
    host.startMatch();
    await waitFor(() => client.players.any((p) => p.hand.isNotEmpty), reason: 'first hand on the client');

    expect(client.roomClosed, isFalse);
    host.exitGame(); // the host goes back to the menu
    await waitFor(() => client.roomClosed, reason: 'client told the room is closed');
    expect(client.isConnectionLost, isFalse, reason: 'it must not keep trying to reconnect to a closed room');
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(client.isConnectionLost, isFalse, reason: 'the socket close after ROOM_CLOSED must not start a reconnect');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
