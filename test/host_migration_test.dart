import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/blackjack_models.dart';
import 'package:poker_dice_dash/models/game_state.dart';
import 'package:poker_dice_dash/providers/blackjack_provider.dart';
import 'package:poker_dice_dash/providers/game_provider.dart';
import 'package:poker_dice_dash/services/p2p_service.dart';

/// Waits (real time) until [cond] holds, or fails after [timeout].
Future<void> waitFor(bool Function() cond, {Duration timeout = const Duration(seconds: 30), String? reason}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('timed out: ${reason ?? ''}');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// One simulated device. Every device gets its own port, as if each had its own IP.
class _Device {
  final String name;
  final P2PService p2p;
  late final GameProvider lobby = GameProvider(p2pService: p2p);
  BlackjackProvider? bj;
  bool _closed = false;

  _Device(this.name, int port) : p2p = P2PService()..preferredPort = port;

  /// Closes the app without telling anybody (crash, battery, swiped away).
  Future<void> crash() async {
    if (_closed) return;
    _closed = true;
    bj?.dispose();
    lobby.dispose();
    await p2p.dispose();
  }
}

int _nextPort = 47800;

/// Host + two clients over real TCP sockets on 127.0.0.1, wired like the app does.
Future<List<_Device>> _room(GameMode mode) async {
  final devices = [for (final n in ['Ana', 'Beto', 'Carla']) _Device(n, _nextPort++)];
  addTearDown(() async {
    for (final d in devices) {
      d.lobby.exitGame();
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    for (final d in devices) {
      await d.crash();
    }
  });
  final host = devices[0];
  host.lobby
    ..setHost(true)
    ..setMultiplayer(true)
    ..setGameMode(mode)
    ..setPlayerName('Ana')
    ..setRoomMetadata('Bellagio', 'secreto');
  await host.p2p.startAdvertising('Bellagio|1/4|1|0|${mode.name}');
  if (mode == GameMode.blackjack) {
    host.bj = BlackjackProvider()..initMultiplayer(asHost: true, hostName: 'Ana', p2p: host.p2p, lobby: host.lobby);
  }
  for (final c in devices.skip(1)) {
    c.lobby
      ..setHost(false)
      ..setMultiplayer(true)
      ..setPlayerName(c.name);
    final assigned = c.p2p.onMessageReceived.firstWhere((m) => m['type'] == 'ASSIGN_SEAT');
    expect(await c.p2p.connectToHost('127.0.0.1', host.p2p.hostPort!), isTrue);
    final ep = '127.0.0.1:${host.p2p.hostPort}';
    await c.p2p.sendMessage(ep, {
      'type': 'JOIN_REQUEST',
      'playerName': c.name,
      'password': 'secreto',
      'token': c.lobby.playerToken,
      'endpointId': ep,
      'listenPort': c.p2p.preferredPort,
    });
    final seat = await assigned.timeout(const Duration(seconds: 5));
    c.lobby.localPlayerId = seat['playerId'] as String;
    if (mode == GameMode.blackjack) {
      c.bj = BlackjackProvider()..initMultiplayer(asHost: false, p2p: c.p2p, lobby: c.lobby);
    }
  }
  return devices;
}

int _chipsAndPot(GameProvider g) => g.players.fold<int>(0, (n, p) => n + p.chipBalance) + g.pot;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      messenger.setMockMethodCallHandler(MethodChannel(ch), (call) async => null);
    }
  });

  test('poker: the host leaves mid-hand, the first heir keeps the room and the bets come back', () async {
    final d = await _room(GameMode.texasHoldem);
    final ana = d[0].lobby, beto = d[1].lobby, carla = d[2].lobby;
    ana.startMatch();
    await waitFor(() => beto.heirs.length == 2 && carla.heirs.length == 2, reason: 'roster on both clients');
    expect(beto.heirs.first.name, 'Beto', reason: 'heirs follow the seat order');
    await waitFor(() => carla.players.any((p) => p.isLocal && p.hand.isNotEmpty), reason: 'first hand dealt');
    // Blinds are in: chips + pot is what everybody owns.
    await waitFor(() => beto.pot > 0, reason: 'blinds on the client');
    final carlaSeat = carla.localPlayerId;
    final total = _chipsAndPot(beto);
    final roundsBefore = beto.roundCounter;

    ana.exitGame();
    await waitFor(() => beto.isHost, reason: 'Beto inherits the room');
    expect(beto.connectionNotice, contains('tú tienes la mesa'));
    expect(_chipsAndPot(beto), total, reason: 'the bets of the called-off hand went back to their owners');
    await waitFor(() => !carla.isConnectionLost, reason: 'Carla reconnects to Beto');
    expect(carla.localPlayerId, carlaSeat, reason: 'Carla keeps her seat');
    await waitFor(() => beto.players.firstWhere((p) => p.id == carlaSeat).isAway == false, reason: 'Carla is back');
    expect(carla.roomClosed, isFalse);

    // A new hand is dealt by Beto and reaches Carla with her own cards.
    await waitFor(() => beto.roundCounter > roundsBefore, reason: 'Beto deals a new hand');
    String cards(List<dynamic> hand) => hand.map((c) => c.toMap().toString()).join(',');
    await waitFor(
        () =>
            cards(carla.players.firstWhere((p) => p.isLocal).hand) ==
            cards(beto.players.firstWhere((p) => p.id == carlaSeat).hand),
        reason: 'Carla holds the cards Beto dealt her');
    expect(beto.players.firstWhere((p) => p.id == carlaSeat).hand, isNotEmpty);
    // Ana left on purpose: her seat no longer plays.
    expect(beto.players.firstWhere((p) => p.id == '0').isFolded, isTrue);
    expect(beto.players.where((p) => p.isLocal).single.id, beto.localPlayerId);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('poker: the host app dies without a word, the room still moves on', () async {
    final d = await _room(GameMode.diceDash);
    final ana = d[0].lobby, beto = d[1].lobby, carla = d[2].lobby;
    ana.startMatch();
    await waitFor(() => carla.heirs.length == 2, reason: 'roster');
    await waitFor(() => beto.players.isNotEmpty && beto.players.every((p) => p.hand.isNotEmpty || p.isLocal),
        reason: 'first hand on Beto');
    final total = _chipsAndPot(beto);

    await d[0].crash();
    await waitFor(() => beto.isHost, reason: 'Beto inherits after the old host stops answering');
    await waitFor(() => !carla.isConnectionLost && !carla.isHost, reason: 'Carla joins Beto');
    // Nothing lost: chips + whatever is still in play adds up to the same total.
    expect(_chipsAndPot(beto), total, reason: 'bets are returned, not lost');
    // The old host's seat stays (away) in case it comes back.
    expect(beto.players.firstWhere((p) => p.id == '0').isAway, isTrue);
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('blackjack: the host leaves, the heir runs the table and refunds the bets', () async {
    final d = await _room(GameMode.blackjack);
    final ana = d[0], beto = d[1], carla = d[2];
    await waitFor(() => carla.bj!.players.length == 4, reason: 'everyone at the table');
    ana.bj!.startMatch();
    await waitFor(() => beto.bj!.phase == BlackjackPhase.betting, reason: 'betting');
    beto.bj!.placeBet(beto.bj!.localPlayerId, 100);
    await waitFor(() => ana.bj!.players.firstWhere((p) => p.id == beto.lobby.localPlayerId).totalBet == 100,
        reason: 'bet reached the host');
    await waitFor(() => beto.bj!.localPlayer.totalBet == 100, reason: 'bet seen by Beto');

    ana.lobby.exitGame();
    await waitFor(() => beto.bj!.isHost, reason: 'Beto takes the table');
    expect(beto.bj!.players.any((p) => p.id == '0'), isFalse, reason: 'the host left on purpose');
    expect(beto.bj!.localPlayer.chipBalance, 1000, reason: 'the bet of the called-off round came back');
    expect(beto.bj!.phase, BlackjackPhase.betting);
    await waitFor(() => carla.bj!.players.length == 3 && !carla.lobby.isConnectionLost,
        reason: 'Carla gets the new table from Beto');
    await waitFor(() => !beto.bj!.awaySeats.contains(carla.lobby.localPlayerId), reason: 'Carla is back at the table');
    // Carla can still play: her bet reaches Beto.
    carla.bj!.placeBet(carla.bj!.localPlayerId, 50);
    await waitFor(() => beto.bj!.players.firstWhere((p) => p.id == carla.lobby.localPlayerId).totalBet == 50,
        reason: 'Carla bets on the new host');
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('with only one player left the room still closes (nobody to play with)', () async {
    final host = _Device('Ana', _nextPort++);
    final client = _Device('Beto', _nextPort++);
    addTearDown(() async {
      await client.crash();
      await host.crash();
    });
    host.lobby
      ..setHost(true)
      ..setMultiplayer(true)
      ..setGameMode(GameMode.texasHoldem)
      ..setPlayerName('Ana');
    await host.p2p.startAdvertising('x|1/4|0|0|texasHoldem');
    client.lobby
      ..setHost(false)
      ..setMultiplayer(true)
      ..setPlayerName('Beto');
    expect(await client.p2p.connectToHost('127.0.0.1', host.p2p.hostPort!), isTrue);
    final ep = '127.0.0.1:${host.p2p.hostPort}';
    await client.p2p.sendMessage(ep, {
      'type': 'JOIN_REQUEST',
      'playerName': 'Beto',
      'password': '',
      'token': client.lobby.playerToken,
      'endpointId': ep,
    });
    await waitFor(() => host.lobby.players.length == 2, reason: 'seated');
    host.lobby.startMatch();
    await waitFor(() => client.lobby.heirs.length == 1, reason: 'roster');
    host.lobby.exitGame();
    await waitFor(() => client.lobby.roomClosed, reason: 'room closed');
    expect(client.lobby.isHost, isFalse);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
