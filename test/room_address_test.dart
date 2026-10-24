import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/services/room_address.dart';

void main() {
  test('copied address round-trips', () {
    final a = RoomAddress.parse(const RoomAddress('192.168.1.50', 47474).toString())!;
    expect(a.host, '192.168.1.50');
    expect(a.port, 47474);
  });

  test('understands what people actually paste', () {
    final cases = {
      '192.168.100.3:54718': ('192.168.100.3', 54718),
      'IP: 192.168.100.3 : 54718': ('192.168.100.3', 54718),
      'Únete a mi sala 😄 192.168.1.20:47474 contraseña 123': ('192.168.1.20', 47474),
      '  10.0.0.7 47474 ': ('10.0.0.7', 47474),
      '192.168.1.20': ('192.168.1.20', RoomAddress.defaultPort),
    };
    cases.forEach((text, expected) {
      final a = RoomAddress.parse(text);
      expect(a, isNotNull, reason: text);
      expect((a!.host, a.port), expected, reason: text);
    });
  });

  test('rejects text without an address', () {
    expect(RoomAddress.parse('hola'), isNull);
    expect(RoomAddress.parse('999.1.1.1:47474'), isNull);
    expect(RoomAddress.parse(''), isNull);
  });
}
