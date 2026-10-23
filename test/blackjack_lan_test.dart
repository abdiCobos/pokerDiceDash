import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/blackjack_models.dart';
import 'package:poker_dice_dash/models/card_model.dart';
import 'package:poker_dice_dash/models/game_state.dart';
import 'package:poker_dice_dash/providers/blackjack_provider.dart';
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

class _Side {
  final P2PService p2p = P2PService();
  late final GameProvider lobby = GameProvider(p2pService: p2p);
  final BlackjackProvider bj = BlackjackProvider();

  Future<void> close() async {
    bj.dispose();
    lobby.dispose();
    await p2p.dispose();
  }
}

/// Host + one client over real TCP sockets on 127.0.0.1, wired like the app does.
Future<(_Side, _Side)> _connect() async {
  final host = _Side();
  final client = _Side();
  host.lobby
    ..setHost(true)
    ..setMultiplayer(true)
    ..setGameMode(GameMode.blackjack)
    ..setPlayerName('Ana');
  await host.p2p.startAdvertising('test|1/4|0|0|blackjack');
  host.bj.initMultiplayer(asHost: true, hostName: 'Ana', p2p: host.p2p, lobby: host.lobby);

  client.lobby
    ..setHost(false)
    ..setMultiplayer(true)
    ..setPlayerName('Beto');
  final assigned = client.p2p.onMessageReceived.firstWhere((m) => m['type'] == 'ASSIGN_SEAT');
  expect(await client.p2p.connectToHost('127.0.0.1', host.p2p.hostPort!), isTrue);
  final ep = '127.0.0.1:${host.p2p.hostPort}';
  await client.p2p.sendMessage(ep, {
    'type': 'JOIN_REQUEST',
    'playerName': 'Beto',
    'password': '',
    'token': client.lobby.playerToken,
    'endpointId': ep,
  });
  final seat = await assigned.timeout(const Duration(seconds: 5));
  expect(seat['gameMode'], 'blackjack', reason: 'clients must be routed to the Blackjack table');
  client.bj.initMultiplayer(asHost: false, p2p: client.p2p, lobby: client.lobby);
  return (host, client);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // No audio plugin in unit tests: answer its channels with null (mDNS just fails and is skipped).
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      messenger.setMockMethodCallHandler(MethodChannel(ch), (call) async => null);
    }
  });

  test('host and client play a full round of Blackjack over the LAN', () async {
    final (host, client) = await _connect();
    addTearDown(() async {
      await client.close();
      await host.close();
    });

    // The client sees itself (and the host) at the table.
    await waitFor(() => client.bj.players.length == 3, reason: 'client snapshot');
    expect(client.bj.localPlayer.name, 'Beto');
    expect(client.bj.players.where((p) => p.isLocal).length, 1);

    host.bj.startMatch();
    await waitFor(() => client.bj.phase == BlackjackPhase.betting, reason: 'betting phase on client');

    // The host bets first: the deal must wait for the client.
    host.bj.placeBet('0', 100);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(host.bj.phase, BlackjackPhase.betting);

    client.bj.placeBet(client.bj.localPlayerId, 50); // sent as an intent
    await waitFor(() => host.bj.phase != BlackjackPhase.betting, reason: 'deal after both bets');

    // During play the client never learns the dealer's hole card.
    await waitFor(() => client.bj.phase == BlackjackPhase.playerTurn || client.bj.phase.index > BlackjackPhase.playerTurn.index,
        reason: 'player turn on client');
    final hostHole = host.bj.dealer!.hands[0].cards[1];
    if (client.bj.phase == BlackjackPhase.playerTurn) {
      final seen = client.bj.dealer!.hands[0].cards[1];
      expect(seen.value == hostHole.value && seen.suit == hostHole.suit && hostHole.value != '2', isFalse,
          reason: 'hole card leaked to the client');
    }

    // Each side stands on its own turn (the client through the network).
    final round = Completer<void>();
    var stoodHost = false, stoodClient = false;
    final ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final active = host.bj.activePlayers;
      if (host.bj.phase == BlackjackPhase.roundEnd) {
        if (!round.isCompleted) round.complete();
        return;
      }
      if (host.bj.phase != BlackjackPhase.playerTurn) return;
      final current = active[host.bj.currentPlayerIndex % active.length];
      if (current.id == '0' && !stoodHost) {
        stoodHost = true;
        host.bj.stand('0');
      } else if (current.id == client.bj.localPlayerId && !stoodClient) {
        stoodClient = true;
        client.bj.stand(client.bj.localPlayerId);
      }
    });
    addTearDown(ticker.cancel);
    await round.future.timeout(const Duration(seconds: 25));

    await waitFor(() => client.bj.phase == BlackjackPhase.roundEnd, reason: 'round end on client');
    expect(client.bj.roundOutcome[client.bj.localPlayerId], isNotNull, reason: 'client sees its own result');
    expect(client.bj.dealer!.hands[0].cards.length, host.bj.dealer!.hands[0].cards.length);
    final hostChips = host.bj.players.firstWhere((p) => p.id == client.bj.localPlayerId).chipBalance;
    expect(client.bj.localPlayer.chipBalance, hostChips);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('second round: the host waits again for the client bet', () async {
    final (host, client) = await _connect();
    addTearDown(() async {
      await client.close();
      await host.close();
    });
    await waitFor(() => client.bj.players.length == 3, reason: 'client snapshot');
    host.bj.startMatch();
    await waitFor(() => client.bj.phase == BlackjackPhase.betting, reason: 'betting phase on client');

    for (var round = 1; round <= 3; round++) {
      host.bj.placeBet('0', 50);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(host.bj.phase, BlackjackPhase.betting, reason: 'round $round dealt without the client bet');
      client.bj.placeBet(client.bj.localPlayerId, 50);
      await waitFor(() => host.bj.phase != BlackjackPhase.betting, reason: 'deal after both bets (round $round)');
      final ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (host.bj.phase != BlackjackPhase.playerTurn) return;
        final active = host.bj.activePlayers;
        final current = active[host.bj.currentPlayerIndex % active.length];
        if (current.id == '0') {
          host.bj.stand('0');
        } else if (current.id == client.bj.localPlayerId && client.bj.phase == BlackjackPhase.playerTurn) {
          client.bj.stand(client.bj.localPlayerId);
        }
      });
      await waitFor(() => host.bj.phase == BlackjackPhase.roundEnd, timeout: const Duration(seconds: 30), reason: 'round $round end');
      ticker.cancel();
      await waitFor(() => client.bj.phase == BlackjackPhase.roundEnd, reason: 'round $round end on client');
      host.bj.newRound();
      await waitFor(() => client.bj.phase == BlackjackPhase.betting, reason: 'round ${round + 1} betting on client');
    }
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('insurance over the LAN: the client insures, the host pays it 2:1', () async {
    final (host, client) = await _connect();
    addTearDown(() async {
      await client.close();
      await host.close();
    });
    await waitFor(() => client.bj.players.length == 3, reason: 'client snapshot');
    host.bj.startMatch();
    await waitFor(() => client.bj.phase == BlackjackPhase.betting, reason: 'betting phase on client');
    // Deal order: dealer, host, client, dealer, host, client -> dealer A + K (blackjack).
    CardModel c(String v, Suit s) => CardModel(value: v, suit: s);
    host.bj.debugStackDeck([
      c('A', Suit.spades), c('9', Suit.spades), c('9', Suit.clubs),
      c('K', Suit.hearts), c('7', Suit.spades), c('7', Suit.clubs),
    ]);
    host.bj.placeBet('0', 100);
    client.bj.placeBet(client.bj.localPlayerId, 100);
    await waitFor(() => client.bj.phase == BlackjackPhase.insurance, reason: 'insurance offered on the client');
    expect(client.bj.canInsure(client.bj.localPlayer), isTrue);
    expect(client.bj.dealer!.hands[0].cards[1].value, isNot('K'), reason: 'hole card leaked during insurance');
    client.bj.takeInsurance(client.bj.localPlayerId, true);
    await waitFor(() => host.bj.players.firstWhere((p) => p.id == client.bj.localPlayerId).insuranceBet == 50,
        reason: 'host received the insurance');
    host.bj.takeInsurance('0', false);
    await waitFor(() => client.bj.phase == BlackjackPhase.roundEnd, timeout: const Duration(seconds: 30), reason: 'round end');
    await waitFor(() => client.bj.localPlayer.chipBalance == 1000, reason: 'client chips after insurance');
    expect(client.bj.roundOutcome[client.bj.localPlayerId], 'SEGURO');
    expect(host.bj.players.firstWhere((p) => p.id == '0').chipBalance, 900);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a client that disappears does not freeze the table', () async {
    final (host, client) = await _connect();
    var clientClosed = false;
    addTearDown(() async {
      if (!clientClosed) await client.close();
      await host.close();
    });
    await waitFor(() => client.bj.players.length == 3);
    host.bj.startMatch();
    await waitFor(() => client.bj.phase == BlackjackPhase.betting);
    client.bj.placeBet(client.bj.localPlayerId, 50);
    await waitFor(() => host.bj.players.any((p) => p.id != '0' && !p.isDealer && p.totalBet > 0));

    // The client app dies before its turn (no LEAVE, no reconnect); the round must still finish.
    clientClosed = true;
    await client.close();
    await waitFor(() => host.bj.awaySeats.isNotEmpty, reason: 'host marks the seat away');
    host.bj.placeBet('0', 100);
    var stood = false;
    await waitFor(() {
      final active = host.bj.activePlayers;
      if (!stood && host.bj.phase == BlackjackPhase.playerTurn && active[host.bj.currentPlayerIndex % active.length].id == '0') {
        stood = true;
        host.bj.stand('0');
      }
      return host.bj.phase == BlackjackPhase.roundEnd;
    }, timeout: const Duration(seconds: 30), reason: 'round end with an away seat');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
