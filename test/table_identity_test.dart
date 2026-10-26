import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:poker_dice_dash/l10n/app_localizations.dart';
import 'package:poker_dice_dash/models/game_state.dart';
import 'package:poker_dice_dash/providers/game_provider.dart';
import 'package:poker_dice_dash/services/p2p_service.dart';
import 'package:poker_dice_dash/ui/screens/game_table_screen.dart';

/// Regression: one player's bet re-animated everybody's chips, and a fold rebuilt
/// the folding player's cards (replaying the deal) because seats and bets had no
/// stable identity on the table.
void main() {
  setUpAll(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global', 'wakelock_plus']) {
      messenger.setMockMethodCallHandler(MethodChannel(ch), (call) async => null);
    }
  });

  testWidgets('existing bets and seats keep their state when someone else acts', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    final game = GameProvider(p2pService: P2PService())
      ..setHost(true)
      ..setMultiplayer(false)
      ..setGameMode(GameMode.texasHoldem)
      ..setBotCount(5);
    game.resetGame(); // the menu deals before opening the table
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: game,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GameTableScreen(),
      ),
    ));

    // Wait for the blinds to be on the table.
    for (var i = 0; i < 100 && game.players.where((p) => game.getPlayerBet(p.id) > 0).length < 2; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final betting = [for (final p in game.players) if (game.getPlayerBet(p.id) > 0) p.id];
    expect(betting.length, greaterThanOrEqualTo(2));
    final watched = betting.first;
    Element stackOf(String id) => tester.element(find.descendant(
          of: find.byKey(ValueKey('betpos_$id')),
          matching: find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('bet_')),
        ));
    final watchedAmount = game.getPlayerBet(watched);
    final betBefore = stackOf(watched);
    final seatsBefore = {
      for (final p in game.players)
        if (p.id != game.localPlayerId) p.id: tester.element(find.byKey(ValueKey('fold_${p.id}'))),
    };
    final betsBefore = game.players.where((p) => game.getPlayerBet(p.id) > 0).length;

    // Let other players act (calls add new bets, folds change seats).
    var acted = false;
    for (var i = 0; i < 400 && !acted; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final betsNow = game.players.where((p) => game.getPlayerBet(p.id) > 0).length;
      acted = betsNow > betsBefore || game.players.any((p) => p.isFolded);
      final idx = game.state.currentPlayerIndex;
      if (idx >= 0 && idx < game.players.length && game.players[idx].id == game.localPlayerId) break;
    }
    expect(acted, isTrue, reason: 'no bot acted');

    if (game.getPlayerBet(watched) == watchedAmount) {
      expect(identical(stackOf(watched), betBefore), isTrue, reason: 'an unchanged bet was rebuilt (re-animated)');
    }
    for (final e in seatsBefore.entries) {
      final now = tester.element(find.byKey(ValueKey('fold_${e.key}')));
      expect(identical(now, e.value), isTrue, reason: 'seat ${e.key} cards were rebuilt');
    }

    game.exitGame();
    await tester.pumpWidget(const SizedBox());
    game.dispose();
    await tester.pump(const Duration(seconds: 10));
  });
}
