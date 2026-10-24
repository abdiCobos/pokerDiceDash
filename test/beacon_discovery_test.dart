import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/services/p2p_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('beacon datagrams: ours are parsed, anything else is ignored', () {
    final ok = P2PService.parseBeacon(
      utf8.encode(jsonEncode({'app': P2PService.beaconApp, 'v': 1, 'name': 'UAdeO|1/4|0|0|blackjack', 'port': 47474})),
      '192.168.1.20',
    );
    expect(ok, isNotNull);
    expect(ok!.endpointId, '192.168.1.20:47474', reason: 'same id as mDNS, so the list does not show the room twice');
    expect(ok.endpointName, 'UAdeO|1/4|0|0|blackjack');

    expect(P2PService.parseBeacon(utf8.encode('hola'), '1.2.3.4'), isNull);
    expect(P2PService.parseBeacon(utf8.encode(jsonEncode({'app': 'otra', 'name': 'x', 'port': 1})), '1.2.3.4'), isNull);
    expect(P2PService.parseBeacon(utf8.encode(jsonEncode({'app': P2PService.beaconApp, 'name': 'x', 'port': 0})), '1.2.3.4'), isNull);
  });

  test('a room is found through the UDP beacon even without mDNS', () async {
    final host = P2PService();
    final client = P2PService();
    addTearDown(() async {
      await client.dispose();
      await host.dispose();
    });
    // In unit tests the nsd plugin is missing: only the beacon can find the room.
    final found = client.onDeviceFound.firstWhere((d) => d.port == host.hostPort);
    await client.startDiscovery('player');
    await host.startAdvertising('Beacon test|1/4|0|0|texasHoldem');
    final device = await found.timeout(const Duration(seconds: 10));
    expect(device.endpointName, 'Beacon test|1/4|0|0|texasHoldem');
    expect(device.port, host.hostPort);
  });
}
