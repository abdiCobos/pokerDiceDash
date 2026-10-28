import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/cock_fight.dart';
import 'package:poker_dice_dash/models/game_state.dart';
import 'package:poker_dice_dash/providers/game_provider.dart';
import 'package:poker_dice_dash/services/game_settings.dart';
import 'package:poker_dice_dash/services/p2p_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameProvider newGame(GameMode mode, int bots) {
  final g = GameProvider(p2pService: P2PService())
    ..setHost(true)
    ..setMultiplayer(false)
    ..setGameMode(mode)
    ..setBotCount(bots);
  g.resetGame();
  return g;
}

/// The local player rolls and checks/calls when it is their turn (never during a fight).
void humanPlays(GameProvider g) {
  // Keep the human able to bet (a fight needs someone with 50 chips).
  final local = g.players.where((p) => p.isLocal).firstOrNull;
  if (local != null && local.chipBalance < 300 && g.state.status == GameStatus.finished && g.cockFight == null) {
    g.debugSetChips(local.id, 1000);
  }
  final idx = g.state.currentPlayerIndex;
  if (idx < 0 || idx >= g.players.length || g.cockFight != null) return;
  final me = g.players[idx];
  if (!me.isLocal || me.isFolded || g.isBetting || g.diceEventBusy || g.centralMessage != null) return;
  if (g.state.status == GameStatus.diceTurn) {
    g.rollDice();
  } else if (g.state.status == GameStatus.betting) {
    g.call(me.id);
  }
}

int chips(GameProvider g) => g.players.fold<int>(0, (a, p) => a + p.chipBalance) + g.pot;

Future<void> finish(WidgetTester tester, GameProvider g) async {
  g.exitGame();
  g.dispose();
  await tester.pump(const Duration(seconds: 20));
}

void main() {
  setUpAll(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      messenger.setMockMethodCallHandler(MethodChannel(ch), (call) async => null);
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GameSettings().load();
  });
  tearDown(() => GameSettings().setTheme(TableTheme.casino));

  test('the favourite pays less than the underdog, stake included', () {
    final f = CockFight(seed: 1, fighters: const ['El Colorado', 'El Giro'], favorite: 1);
    expect(f.payout(1, 50), 75);
    expect(f.payout(0, 50), 150);
    expect(f.payout(1, 200), 300);
    expect(f.payout(0, 200), 600);
    expect(CockFight.bets, [50, 100, 200]);
    expect(CockFight.favoriteWins, greaterThan(0.5));
  });

  test('the fight travels to clients and back unchanged', () {
    final f = CockFight.random(Random(3))
      ..phase = CockFightPhase.result
      ..winner = 1;
    f.wagers['0'] = (1, 50);
    f.wagers['2'] = (0, 0);
    f.payouts['0'] = 150;
    final back = CockFight.fromMap(f.toMap())!;
    expect(back.fighters, f.fighters);
    expect(back.favorite, f.favorite);
    expect(back.phase, CockFightPhase.result);
    expect(back.winner, 1);
    expect(back.wagers, f.wagers);
    expect(back.payouts, f.payouts);
    expect(CockFight.fromMap(null), isNull);
    expect(CockFight.fromMap({'seed': 'x'}), isNull, reason: 'a broken message never crashes a client');
  });

  testWidgets('Dice Dash in the cantina: bets, the fight, the payout, then the next hand', (tester) async {
    await GameSettings().setTheme(TableTheme.cantina);
    final g = newGame(GameMode.diceDash, 3);
    g.debugCockFightNow();
    for (var i = 0; i < 4000 && g.cockFight == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      humanPlays(g);
    }
    final f = g.cockFight;
    expect(f, isNotNull, reason: 'the fight starts after the hand ends');
    expect(f!.phase, CockFightPhase.betting);
    expect(g.state.status, GameStatus.finished, reason: 'never in the middle of a hand');

    final me = g.localPlayerId;
    final before = chips(g);
    final myBefore = g.players.firstWhere((p) => p.id == me).chipBalance;
    g.placeCockBet(me, f.favorite, 50);
    expect(g.players.firstWhere((p) => p.id == me).chipBalance, myBefore - 50);
    g.placeCockBet(me, 1 - f.favorite, 100);
    g.placeCockBet('1', f.favorite, 20);
    expect(f.wagers['1']?.$2 == 20, isFalse, reason: 'only 50, 100 or 200');
    expect(f.wagerChips(me), 50, reason: 'one bet per fight');

    final round = g.roundCounter;
    for (var i = 0; i < 300 && g.cockFight?.phase == CockFightPhase.betting; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(f.phase, CockFightPhase.fighting);
    expect(f.winner, isNotNull);
    expect(f.wagers.length, g.players.length, reason: 'the bots decided too');

    for (var i = 0; i < 300 && g.cockFight?.phase == CockFightPhase.fighting; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(f.phase, CockFightPhase.result);
    var bets = 0, paid = 0;
    for (final e in f.wagers.entries) {
      final (rooster, amount) = e.value;
      bets += amount;
      if (amount > 0 && rooster == f.winner) {
        expect(f.payouts[e.key], f.payout(rooster, amount));
      } else {
        expect(f.payouts.containsKey(e.key), isFalse);
      }
      paid += f.payouts[e.key] ?? 0;
    }
    expect(chips(g), before - bets + paid, reason: 'chips only move through bets and payouts');

    for (var i = 0; i < 300 && g.roundCounter == round; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(g.cockFight, isNull);
    expect(g.roundCounter, round + 1, reason: 'the next hand is dealt after the fight');

    // Play on for a while: the table keeps moving and the next fight is 10-15 minutes away.
    final start = g.roundCounter;
    for (var i = 0; i < 2500; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      humanPlays(g);
      expect(g.cockFight, isNull);
    }
    expect(g.roundCounter, greaterThan(start + 2));
    await finish(tester, g);
  });

  testWidgets('the fight starts as soon as everyone has decided', (tester) async {
    await GameSettings().setTheme(TableTheme.cantina);
    final g = newGame(GameMode.diceDash, 1);
    g.debugCockFightNow();
    for (var i = 0; i < 4000 && g.cockFight == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      humanPlays(g);
    }
    final f = g.cockFight!;
    // Wait for the bot, then pass: no need to wait for the 12 s clock.
    for (var i = 0; i < 150 && f.wagers.length < 1; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    g.placeCockBet(g.localPlayerId, 0, 0);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(f.phase, CockFightPhase.fighting);
    await finish(tester, g);
  });

  for (final (mode, theme) in [
    (GameMode.texasHoldem, TableTheme.cantina),
    (GameMode.diceDash, TableTheme.casino),
    (GameMode.diceDash, TableTheme.garito),
  ]) {
    testWidgets('no cockfight in ${mode.name} with the ${theme.name} scene', (tester) async {
      await GameSettings().setTheme(theme);
      final g = newGame(mode, 3);
      g.debugCockFightNow();
      final start = g.roundCounter;
      for (var i = 0; i < 2500; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        humanPlays(g);
        expect(g.cockFight, isNull);
      }
      expect(g.roundCounter, greaterThan(start + 1));
      await finish(tester, g);
    });
  }
}
