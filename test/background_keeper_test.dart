import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/services/background_keeper.dart';
import 'package:poker_dice_dash/services/p2p_service.dart';

/// Android keeps a LAN game alive with a foreground service: it must start when a room
/// opens and stop when it closes (flutter test runs as Android).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('io.github.abdicobos.pokerdicedash/keep_alive'),
      (call) async {
        calls.add(call.method);
        return true;
      },
    );
  });

  test('opening a room starts the keep-alive service once, closing it stops it', () async {
    final host = P2PService();
    await host.startAdvertising('Sala|1/4|0|0|texasHoldem');
    await host.updateServiceName('Sala|2/4|0|0|texasHoldem'); // renaming must not start it again
    expect(calls, ['start']);
    expect(BackgroundKeeper.running, isTrue);
    await host.disconnectAll();
    expect(calls, ['start', 'stop']);
    expect(BackgroundKeeper.running, isFalse);
    await host.dispose();
  });

  test('a client that joins a room keeps the game alive too', () async {
    final host = P2PService();
    final client = P2PService();
    await host.startAdvertising('Sala|1/4|0|0|texasHoldem');
    await host.disconnectAll(); // only the client's own start/stop matters below
    await host.startAdvertising('Sala|1/4|0|0|texasHoldem');
    calls.clear();
    await BackgroundKeeper.stop();
    calls.clear();
    expect(await client.connectToHost('127.0.0.1', host.hostPort!), isTrue);
    expect(calls, ['start']);
    await client.dispose();
    expect(calls, ['start', 'stop']);
    await host.dispose();
  });
}
