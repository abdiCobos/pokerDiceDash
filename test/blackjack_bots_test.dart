import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/blackjack_models.dart';
import 'package:poker_dice_dash/providers/blackjack_provider.dart';
import 'package:poker_dice_dash/services/poker_bot_ai.dart';

void main() {
  // Regression: a bot that hit without finishing its hand never acted again
  // and the round froze on "Turno de <bot>... pensando jugada".
  testWidgets('bots always finish their turn and the round resolves', (tester) async {
    for (var round = 0; round < 24; round++) {
      // Every difficulty, so splits and doubles of the basic-strategy bots are exercised too.
      final bj = BlackjackProvider()
        ..initSinglePlayer(botCount: 4, difficulty: BotDifficulty.values[round % BotDifficulty.values.length]);
      bj.placeBet('0', 100);

      var resolved = false;
      var stood = false;
      for (var tick = 0; tick < 600; tick++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (bj.phase == BlackjackPhase.roundEnd) {
          resolved = true;
          break;
        }
        final active = bj.activePlayers;
        if (bj.phase == BlackjackPhase.playerTurn &&
            active[bj.currentPlayerIndex % active.length].isLocal &&
            !stood) {
          // A single tap, like a real player.
          stood = true;
          bj.stand('0');
        }
      }
      expect(resolved, isTrue, reason: 'round $round froze in phase ${bj.phase}');
      for (final p in bj.activePlayers) {
        for (final h in p.hands) {
          expect(h.isFinished, isTrue, reason: '${p.name} left an open hand');
        }
      }
    }
    // Let trailing delayed callbacks (sounds, animations) drain.
    await tester.pump(const Duration(seconds: 5));
  });
}
