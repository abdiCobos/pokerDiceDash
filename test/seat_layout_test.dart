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

    for (final size in sizes) {
      for (final dice in [true, false]) {
        test('${size.width.toInt()}x${size.height.toInt()} dice=$dice bets and pot stay clear', () {
          final obstacles = SeatLayout.fixedObstacles(size, diceMode: dice);
          final pot = SeatLayout.potRect(size);
          final localBet = SeatLayout.localBetRect(size);
          for (final o in obstacles.skip(2)) {
            expect(pot.overlaps(o), isFalse, reason: 'pot overlaps $o');
          }
          expect(localBet.overlaps(pot), isFalse);
          for (var n = 1; n <= 7; n++) {
            final rects = SeatLayout.placeOpponents(size: size, opponents: n, diceMode: dice).rects;
            final bets = <Rect>[];
            var inline = 0;
            for (var i = 0; i < n; i++) {
              final others = [for (var j = 0; j < n; j++) if (j != i) rects[j]];
              final bet = SeatLayout.betRect(size: size, seat: rects[i], otherSeats: others, diceMode: dice, placedBets: bets);
              if (bet == null) {
                inline++; // shown inside the seat instead
                continue;
              }
              expect(bet.overlaps(rects[i]), isFalse, reason: 'n=$n bet $i covers its own seat');
              for (final o in [...obstacles, pot, localBet, ...others]) {
                expect(bet.overlaps(o), isFalse, reason: 'n=$n bet $i ($bet) overlaps $o');
              }
              bets.add(bet);
            }
            for (var i = 0; i < bets.length; i++) {
              for (var j = i + 1; j < bets.length; j++) {
                expect(bets[i].overlaps(bets[j]), isFalse, reason: 'n=$n bets $i and $j overlap');
              }
            }
            // Every bet fits on the felt up to 5 opponents (4 on the smallest phones).
            if (n <= (size.width < 700 ? 4 : 5)) expect(inline, 0, reason: 'n=$n had $inline bets without a spot');
          }
        });
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
