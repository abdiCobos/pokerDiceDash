import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/services/room_names.dart';

void main() {
  test('names fit the room metadata (no | separator, short enough for mDNS)', () {
    for (final n in [...RoomNames.common, RoomNames.rare]) {
      expect(n.contains('|'), isFalse, reason: n);
      expect(n.length, lessThanOrEqualTo(32), reason: n);
    }
  });

  test('never offers the same name twice in a row', () {
    final r = Random(1);
    var prev = RoomNames.pick(r);
    for (var i = 0; i < 500; i++) {
      final next = RoomNames.pick(r);
      expect(next, isNot(prev));
      prev = next;
    }
  });

  test('the wolves room is rare but does show up', () {
    final r = Random(7);
    var rare = 0;
    const n = 20000;
    for (var i = 0; i < n; i++) {
      if (RoomNames.pick(r) == RoomNames.rare) rare++;
    }
    expect(rare, greaterThan(0));
    expect(rare / n, lessThan(0.02));
  });
}
