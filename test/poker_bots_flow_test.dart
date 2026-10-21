import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/game_state.dart';
import 'package:poker_dice_dash/providers/game_provider.dart';
import 'package:poker_dice_dash/services/p2p_service.dart';
import 'package:poker_dice_dash/services/poker_bot_ai.dart';

void main() {
  setUpAll(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      messenger.setMockMethodCallHandler(MethodChannel(ch), (call) async => null);
    }
  });

  for (final mode in [GameMode.texasHoldem, GameMode.diceDash]) {
    for (final difficulty in BotDifficulty.values) {
      // The new bot brain must keep hands flowing: no freezes, no illegal raises.
      testWidgets('$mode with ${difficulty.name} bots plays several hands', (tester) async {
        final game = GameProvider(p2pService: P2PService())
          ..setHost(true)
          ..setMultiplayer(false)
          ..setGameMode(mode)
          ..setBotCount(5)
          ..setBotDifficulty(difficulty);
        game.resetGame();
        final startRound = game.roundCounter;
        for (var tick = 0; tick < 6000 && game.roundCounter < startRound + 4; tick++) {
          await tester.pump(const Duration(milliseconds: 100));
          final idx = game.state.currentPlayerIndex;
          if (idx >= 0 && idx < game.players.length && game.players[idx].id == game.localPlayerId &&
              game.centralMessage == null && !game.isBetting) {
            if (game.state.status == GameStatus.diceTurn) game.rollDice();
            if (game.state.status == GameStatus.betting) game.call(game.localPlayerId);
          }
          for (final p in game.players) {
            expect(p.chipBalance, greaterThanOrEqualTo(0), reason: '${p.name} went negative');
          }
        }
        expect(game.roundCounter, greaterThanOrEqualTo(startRound + 4), reason: 'hands stopped advancing');
        game.exitGame();
        game.dispose();
        await tester.pump(const Duration(seconds: 10));
      }, timeout: const Timeout(Duration(minutes: 3)));
    }
  }
}
