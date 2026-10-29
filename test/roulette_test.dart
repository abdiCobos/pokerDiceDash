import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/game_state.dart';
import 'package:poker_dice_dash/models/roulette.dart';
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

void humanPlays(GameProvider g) {
  final local = g.players.where((p) => p.isLocal).firstOrNull;
  if (local != null && local.chipBalance < 300 && g.state.status == GameStatus.finished && g.roulette == null) {
    g.debugSetChips(local.id, 1000);
  }
  final idx = g.state.currentPlayerIndex;
  if (idx < 0 || idx >= g.players.length || g.roulette != null) return;
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
  await tester.pump(const Duration(seconds: 30));
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

  test('the European wheel: 37 pockets, 18 red, zero beats every outside bet', () {
    expect(Roulette.wheel.toSet(), {for (var i = 0; i <= 36; i++) i});
    expect(Roulette.reds.length, 18);
    for (final kind in [RouletteBetKind.red, RouletteBetKind.black, RouletteBetKind.even, RouletteBetKind.odd]) {
      expect(RouletteBet(kind, 50).wins(0), isFalse, reason: '$kind loses on zero');
    }
    expect(const RouletteBet(RouletteBetKind.red, 50).wins(23), isTrue);
    expect(const RouletteBet(RouletteBetKind.black, 50).wins(23), isFalse);
    expect(const RouletteBet(RouletteBetKind.odd, 50).wins(23), isTrue);
    expect(const RouletteBet(RouletteBetKind.even, 50).wins(36), isTrue);
    expect(const RouletteBet(RouletteBetKind.number, 100, 0).wins(0), isTrue);
    expect(const RouletteBet(RouletteBetKind.red, 100).payout, 200);
    expect(const RouletteBet(RouletteBetKind.number, 50, 17).payout, 1800);
  });

  test('bets travel to the host and back unchanged', () {
    for (final b in [
      const RouletteBet(RouletteBetKind.red, 0),
      const RouletteBet(RouletteBetKind.black, 200),
      const RouletteBet(RouletteBetKind.odd, 50),
      const RouletteBet(RouletteBetKind.number, 100, 0),
      const RouletteBet(RouletteBetKind.number, 200, 36),
    ]) {
      final back = RouletteBet.fromCode(b.code)!;
      expect(back.passed, b.passed);
      if (!b.passed) expect(back, b);
    }
    expect(RouletteBet.fromCode(50005), isNull, reason: 'a broken bet is ignored');
    final r = Roulette.random(Random(1))
      ..number = 7
      ..phase = RoulettePhase.result;
    r.wagers['0'] = const RouletteBet(RouletteBetKind.number, 50, 7);
    r.payouts['0'] = 1800;
    final copy = Roulette.fromMap(r.toMap())!;
    expect(copy.number, 7);
    expect(copy.wagers['0'], r.wagers['0']);
    expect(copy.payouts, {'0': 1800});
    expect(Roulette.fromMap({'seed': 'x'}), isNull);
  });

  testWidgets('Dice Dash in the casino: bets, the spin, the payout, then the next hand', (tester) async {
    await GameSettings().setTheme(TableTheme.casino);
    final g = newGame(GameMode.diceDash, 3);
    g.debugRouletteNow();
    g.debugRouletteNumber = 23;
    for (var i = 0; i < 6000 && g.roulette == null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      humanPlays(g);
    }
    final r = g.roulette!;
    expect(r.phase, RoulettePhase.betting);
    expect(g.state.status, GameStatus.finished, reason: 'never in the middle of a hand');
    final me = g.localPlayerId;
    final before = chips(g);
    final mine = g.players.firstWhere((p) => p.id == me).chipBalance;
    g.placeRouletteBet(me, const RouletteBet(RouletteBetKind.number, 100, 23));
    expect(g.players.firstWhere((p) => p.id == me).chipBalance, mine - 100);
    g.placeRouletteBet(me, const RouletteBet(RouletteBetKind.red, 200));
    expect(r.wagers[me], const RouletteBet(RouletteBetKind.number, 100, 23), reason: 'one bet per spin');
    g.placeRouletteBet('1', const RouletteBet(RouletteBetKind.red, 30));
    expect(r.hasDecided('1'), isFalse, reason: 'only 50, 100 or 200');

    for (var i = 0; i < 600 && r.phase == RoulettePhase.betting; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(r.phase, RoulettePhase.spinning);
    expect(r.number, 23);
    for (var i = 0; i < 400 && r.phase == RoulettePhase.spinning; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(r.phase, RoulettePhase.result);
    expect(r.payouts[me], 3600, reason: 'straight up pays x36');
    var bets = 0, paid = 0;
    for (final e in r.wagers.entries) {
      bets += e.value.chips;
      if (!e.value.passed && e.value.wins(23)) {
        expect(r.payouts[e.key], e.value.payout);
      } else {
        expect(r.payouts.containsKey(e.key), isFalse);
      }
      paid += r.payouts[e.key] ?? 0;
    }
    expect(chips(g), before - bets + paid, reason: 'chips only move through bets and payouts');

    final round = g.roundCounter;
    for (var i = 0; i < 400 && g.roundCounter == round; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(g.roulette, isNull);
    expect(g.roundCounter, round + 1, reason: 'the next hand is dealt after the spin');
    await finish(tester, g);
  });

  testWidgets('the wheel spins as soon as everyone has decided', (tester) async {
    await GameSettings().setTheme(TableTheme.casino);
    final g = newGame(GameMode.diceDash, 1);
    g.debugRouletteNow();
    for (var i = 0; i < 6000 && g.roulette == null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      humanPlays(g);
    }
    final r = g.roulette!;
    for (var i = 0; i < 200 && r.wagers.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    g.placeRouletteBet(g.localPlayerId, const RouletteBet(RouletteBetKind.red, 0));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(r.phase, RoulettePhase.spinning);
    await finish(tester, g);
  });

  for (final (mode, theme) in [
    (GameMode.texasHoldem, TableTheme.casino),
    (GameMode.diceDash, TableTheme.cantina),
    (GameMode.diceDash, TableTheme.garito),
  ]) {
    testWidgets('no roulette in ${mode.name} with the ${theme.name} scene', (tester) async {
      await GameSettings().setTheme(theme);
      final g = newGame(mode, 3);
      g.debugRouletteNow();
      final start = g.roundCounter;
      for (var i = 0; i < 5000; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        humanPlays(g);
        expect(g.roulette, isNull);
      }
      expect(g.roundCounter, greaterThan(start + 1));
      await finish(tester, g);
    });
  }
}
