import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/services/p2p_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('delivers JSON messages and keeps UTF-8 characters intact', () async {
    final host = P2PService();
    final client = P2PService();
    addTearDown(() async {
      await client.dispose();
      await host.dispose();
    });

    await host.startAdvertising('test-room');
    final port = host.hostPort!;
    final received = <Map<String, dynamic>>[];
    host.onMessageReceived.listen(received.add);

    expect(await client.connectToHost('127.0.0.1', port), isTrue);
    await client.sendMessage('127.0.0.1:$port', {'type': 'HELLO', 'name': 'Ñandú 🎲'});
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(received, hasLength(1));
    expect(received.first['name'], 'Ñandú 🎲');
    expect(received.first['_senderEndpointId'], isNotNull);
  });

  test('both sides are notified when a peer disconnects', () async {
    final host = P2PService();
    final client = P2PService();
    addTearDown(() async {
      await client.dispose();
      await host.dispose();
    });

    await host.startAdvertising('test-room');
    final hostSawDisconnect = host.onDisconnected.first;
    expect(await client.connectToHost('127.0.0.1', host.hostPort!), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(host.connectedEndpointCount, 1);

    await client.disconnectAll();
    await hostSawDisconnect.timeout(const Duration(seconds: 3));
    expect(host.connectedEndpointCount, 0);
  });

  test('client can reconnect to the last host', () async {
    final host = P2PService();
    final client = P2PService();
    addTearDown(() async {
      await client.dispose();
      await host.dispose();
    });

    await host.startAdvertising('test-room');
    expect(await client.connectToHost('127.0.0.1', host.hostPort!), isTrue);
    await client.disconnectAll();
    // disconnectAll also stops advertising on the client side only; the host keeps listening.
    expect(await client.reconnectToLastHost(), isTrue);
    expect(client.connectedEndpointCount, 1);
  });

  test('renaming the advertised room keeps the same TCP port', () async {
    final host = P2PService();
    addTearDown(host.dispose);

    await host.startAdvertising('room|1/4|0|0|texasHoldem');
    final port = host.hostPort;
    expect(port, isNotNull);
    await host.updateServiceName('room|2/4|0|0|texasHoldem');
    await host.updateServiceName('room|3/4|0|1|texasHoldem');
    expect(host.hostPort, port);
  });
}
