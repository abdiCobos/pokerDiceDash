import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/blackjack_models.dart';
import 'package:poker_dice_dash/models/game_state.dart';
import 'package:poker_dice_dash/providers/blackjack_provider.dart';
import 'package:poker_dice_dash/providers/game_provider.dart';
import 'package:poker_dice_dash/services/p2p_service.dart';
import 'package:poker_dice_dash/services/sound_service.dart';

/// Every table must actually ask for its sounds (files are MP3: Windows/macOS
/// cannot decode the old OGG files).
void main() {
  final log = <String>[];

  setUpAll(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      messenger.setMockMethodCallHandler(MethodChannel(ch), (call) async => null);
    }
    SoundService.debugLog = log;
  });
  setUp(log.clear);
  tearDownAll(() => SoundService.debugLog = null);

  Future<void> playPoker(WidgetTester tester, GameMode mode, {bool foldEveryHand = false}) async {
    final game = GameProvider(p2pService: P2PService())
      ..setHost(true)
      ..setMultiplayer(false)
      ..setGameMode(mode)
      ..setBotCount(3);
    game.resetGame();
    final start = game.roundCounter;
    for (var tick = 0; tick < 4000 && game.roundCounter < start + 2; tick++) {
      await tester.pump(const Duration(milliseconds: 100));
      final idx = game.state.currentPlayerIndex;
      if (idx >= 0 && idx < game.players.length && game.players[idx].id == game.localPlayerId &&
          game.centralMessage == null && !game.isBetting) {
        if (game.state.status == GameStatus.diceTurn) game.rollDice();
        if (game.state.status == GameStatus.betting) {
          foldEveryHand ? game.fold(game.localPlayerId) : game.call(game.localPlayerId);
        }
      }
    }
    game.exitGame();
    game.dispose();
    await tester.pump(const Duration(seconds: 10));
  }

  testWidgets('Texas: deal, bets, fold and win sounds', (tester) async {
    await playPoker(tester, GameMode.texasHoldem);
    await playPoker(tester, GameMode.texasHoldem, foldEveryHand: true);
    expect(log, contains('cardmix.mp3'), reason: 'deal');
    expect(log, contains('chipsRaise.mp3'), reason: 'bets');
    expect(log, contains('cardfold.mp3'), reason: 'fold');
    expect(log, contains('chipsWin.mp3'), reason: 'win');
    expect(log.every((f) => !f.endsWith('.ogg')), isTrue);
  });

  testWidgets('Dice Dash: dice sound on every roll', (tester) async {
    await playPoker(tester, GameMode.diceDash);
    expect(log, contains('dice.mp3'));
    expect(log, contains('cardmix.mp3'));
  });

  testWidgets('Blackjack: bet, cards and result sounds', (tester) async {
    final bj = BlackjackProvider()..initSinglePlayer(botCount: 2);
    bj.placeBet('0', 100);
    var stood = false;
    for (var i = 0; i < 600 && bj.phase != BlackjackPhase.roundEnd; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final a = bj.activePlayers;
      if (!stood && bj.phase == BlackjackPhase.playerTurn && a[bj.currentPlayerIndex % a.length].isLocal) {
        stood = true;
        bj.stand('0');
      }
    }
    expect(log, contains('chipsRaise.mp3'), reason: 'bet');
    expect(log, contains('cardmix.mp3'), reason: 'cards');
    expect(log.any((f) => f == 'chipsWin.mp3' || f == 'cardfold.mp3'), isTrue, reason: 'result');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('sound off in Ajustes silences everything', (tester) async {
    SoundService().enabled = false;
    addTearDown(() => SoundService().enabled = true);
    SoundService().cardMix();
    SoundService().cardFlip();
    expect(log, isEmpty);
  });
}
