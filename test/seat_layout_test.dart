import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/ui/layout/seat_layout.dart';

void main() {
  const sizes = [
    Size(640, 360),
    Size(740, 360),
    Size(800, 360),
    Size(851, 393),
    Size(915, 412),
    Size(1024, 768),
    Size(1280, 720),
    Size(1920, 1080),
  ];

  group('SeatLayout.placeOpponents', () {
    for (final size in sizes) {
      for (final dice in [true, false]) {
        for (var n = 1; n <= 7; n++) {
          test('${size.width.toInt()}x${size.height.toInt()} dice=$dice opponents=$n has no overlaps', () {
            final result = SeatLayout.placeOpponents(size: size, opponents: n, diceMode: dice);
            expect(result.rects.length, n);
            expect(result.fits, isTrue);

            final screen = Offset.zero & size;
            final obstacles = SeatLayout.fixedObstacles(size, diceMode: dice);
            for (var i = 0; i < n; i++) {
              final a = result.rects[i];
              expect(screen.contains(a.topLeft) && screen.contains(a.bottomRight), isTrue,
                  reason: 'seat $i is outside the screen: $a');
              for (var j = i + 1; j < n; j++) {
                expect(a.overlaps(result.rects[j]), isFalse, reason: 'seats $i and $j overlap');
              }
              for (final o in obstacles) {
                expect(a.overlaps(o), isFalse, reason: 'seat $i overlaps obstacle $o');
              }
            }
          });
        }
      }
    }

    test('zero opponents returns an empty layout', () {
      final r = SeatLayout.placeOpponents(size: const Size(800, 360), opponents: 0, diceMode: false);
      expect(r.rects, isEmpty);
      expect(r.fits, isTrue);
    });

    test('scale uses the tighter dimension', () {
      expect(SeatLayout.tableScale(const Size(851, 393)) < 1.0, isTrue);
      expect(SeatLayout.tableScale(const Size(1920, 1080)), 1.3);
    });
  });
}
