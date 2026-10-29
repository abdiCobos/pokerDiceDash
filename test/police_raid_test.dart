import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_dice_dash/models/game_state.dart';
import 'package:poker_dice_dash/models/police_raid.dart';
import 'package:poker_dice_dash/providers/game_provider.dart';
import 'package:poker_dice_dash/services/game_settings.dart';
import 'package:poker_dice_dash/services/p2p_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameProvider newGame(GameMode mode, int bots, {bool multiplayer = false}) {
  final g = GameProvider(p2pService: P2PService())
    ..setHost(true)
    ..setMultiplayer(multiplayer)
    ..setGameMode(mode)
    ..setBotCount(bots);
  g.resetGame();
  return g;
}

/// The local player rolls and checks/calls on their turn (never during a raid), and keeps
/// enough chips to be part of the raid.
void humanPlays(GameProvider g) {
  final local = g.players.where((p) => p.isLocal).firstOrNull;
  if (local != null &&
      local.chipBalance < 300 &&
      g.state.status == GameStatus.finished &&
      g.raid == null &&
      !g.isJailed(local.id)) {
    g.debugSetChips(local.id, 1000);
  }
  final idx = g.state.currentPlayerIndex;
  if (idx < 0 || idx >= g.players.length || g.raid != null) return;
  final me = g.players[idx];
  if (!me.isLocal || me.isFolded || g.isBetting || g.diceEventBusy || g.centralMessage != null) return;
  if (g.state.status == GameStatus.diceTurn) {
    g.rollDice();
  } else if (g.state.status == GameStatus.betting) {
    g.call(me.id);
  }
}

Future<void> untilRaid(WidgetTester tester, GameProvider g, RaidPhase phase) async {
  for (var i = 0; i < 6000 && g.raid?.phase != phase; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    humanPlays(g);
  }
  expect(g.raid?.phase, phase);
}

Future<void> finish(WidgetTester tester, GameProvider g) async {
  g.exitGame();
  g.dispose();
  await tester.pump(const Duration(seconds: 30));
}

PoliceRaid raid({required bool real, int price = 200}) => PoliceRaid(seed: 1, real: real, price: price, mood: 1)
  ..phase = RaidPhase.deciding;

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

  group('settling a raid', () {
    test('false alarm: wasted envelope, dropped chips, embarrassment; hiding costs nothing', () {
      final r = raid(real: false)
        ..choices['a'] = (RaidChoice.bribe, 300)
        ..choices['b'] = (RaidChoice.flee, 0)
        ..choices['c'] = (RaidChoice.surrender, 0)
        ..choices['d'] = (RaidChoice.hide, 0);
      final out = settleRaid(raid: r, chips: {'a': 1000, 'b': 1000, 'c': 1000, 'd': 1000}, record: {}, rng: Random(1));
      expect(out['a'], (RaidOutcome.wastedBribe, -300));
      expect(out['b'], (RaidOutcome.droppedChips, -100));
      expect(out['c'], (RaidOutcome.falseSurrender, -200));
      expect(out['d'], (RaidOutcome.nothing, 0));
    });

    test('the comandante takes the envelope only if it reaches his price (his price grows with the record)', () {
      final r = raid(real: true, price: 200)
        ..choices['a'] = (RaidChoice.bribe, 200)
        ..choices['b'] = (RaidChoice.bribe, 200)
        ..choices['c'] = (RaidChoice.bribe, 100);
      final out = settleRaid(
        raid: r,
        chips: {'a': 1000, 'b': 1000, 'c': 1000},
        record: {'b': 1}, // one bribe on file: 250 for him
        rng: Random(1),
      );
      expect(out['a'], (RaidOutcome.bribed, -200));
      expect(out['b'], (RaidOutcome.bribeFailed, -200 - 400), reason: 'envelope lost and half of the rest seized');
      expect(out['c']!.$1, RaidOutcome.bribeFailed);
    });

    test('paying the most is not always best: 300 is wasted when the price is 100... and too little at 500', () {
      final cheap = raid(real: true, price: 100)..choices['a'] = (RaidChoice.bribe, 300);
      final dear = raid(real: true, price: 500)..choices['a'] = (RaidChoice.bribe, 300);
      expect(settleRaid(raid: cheap, chips: {'a': 1000}, record: {}, rng: Random(1))['a'], (RaidOutcome.bribed, -300));
      expect(settleRaid(raid: dear, chips: {'a': 1000}, record: {}, rng: Random(1))['a']!.$1, RaidOutcome.bribeFailed);
    });

    test('surrender means jail and every chip; a snitch gets half of what the police seized', () {
      final r = raid(real: true)
        ..choices['rat'] = (RaidChoice.snitch, 0)
        ..choices['quit'] = (RaidChoice.surrender, 0);
      final out = settleRaid(raid: r, chips: {'rat': 800, 'quit': 1000}, record: {}, rng: Random(1));
      expect(out['quit'], (RaidOutcome.jailed, -1000));
      expect(out['rat'], (RaidOutcome.snitched, 500));
    });

    test('hiding and running are a gamble on a real raid', () {
      final seen = <RaidOutcome>{};
      for (var s = 0; s < 40; s++) {
        final r = raid(real: true)
          ..choices['h'] = (RaidChoice.hide, 0)
          ..choices['f'] = (RaidChoice.flee, 0);
        final out = settleRaid(raid: r, chips: {'h': 1000, 'f': 1000}, record: {}, rng: Random(s));
        seen..add(out['h']!.$1)..add(out['f']!.$1);
        if (out['h']!.$1 == RaidOutcome.found) expect(out['h']!.$2, -500);
        if (out['f']!.$1 == RaidOutcome.caught) expect(out['f']!.$2, -300);
      }
      expect(seen, containsAll([RaidOutcome.hidden, RaidOutcome.found, RaidOutcome.escaped, RaidOutcome.caught]));
    });

    test('the scapegoat: pay double, win the coin toss (the boss goes down) or take the blame', () {
      PoliceRaid blamed(ScapegoatChoice c) => raid(real: true, price: 200)
        ..choices['me'] = (RaidChoice.hide, 0)
        ..scapegoatId = 'me'
        ..bossId = 'boss'
        ..scapegoatChoice = c;
      final chips = {'me': 1000, 'boss': 900};
      expect(settleRaid(raid: blamed(ScapegoatChoice.payDouble), chips: chips, record: {}, rng: Random(1))['me'],
          (RaidOutcome.scapegoatPaid, -400));
      final won = settleRaid(raid: blamed(ScapegoatChoice.accuseBack), chips: chips, record: {}, rng: Random(1), coinWon: true);
      expect(won['me'], (RaidOutcome.scapegoatWon, 0));
      expect(won['boss'], (RaidOutcome.bossJailed, -900));
      final lost = settleRaid(raid: blamed(ScapegoatChoice.accuseBack), chips: chips, record: {}, rng: Random(1));
      expect(lost['me'], (RaidOutcome.jailed, -1000));
      expect(settleRaid(raid: blamed(ScapegoatChoice.acceptBlame), chips: chips, record: {}, rng: Random(1))['me'],
          (RaidOutcome.jailed, -1000));
    });
  });

  test('clients never see the secrets before the reveal: real or not, the price, the others\' choices', () {
    final r = raid(real: true, price: 350)
      ..choices['ana'] = (RaidChoice.bribe, 300)
      ..choices['luis'] = (RaidChoice.flee, 0)
      ..decided.addAll(['ana', 'luis'])
      ..tips['ana'] = true;
    final forLuis = PoliceRaid.fromMap(r.toMap(forPlayerId: 'luis'))!;
    expect(forLuis.real, isNull);
    expect(forLuis.price, isNull);
    expect(forLuis.choices.keys, ['luis']);
    expect(forLuis.tips, isEmpty);
    expect(forLuis.decided, {'ana', 'luis'});
    final forAna = PoliceRaid.fromMap(r.toMap(forPlayerId: 'ana'))!;
    expect(forAna.tips, {'ana': true});
    r.phase = RaidPhase.reveal;
    final open = PoliceRaid.fromMap(r.toMap(forPlayerId: 'luis'))!;
    expect(open.real, isTrue);
    expect(open.price, 350);
    expect(open.choices.keys, containsAll(['ana', 'luis']));
    expect(PoliceRaid.fromMap({'seed': 'x'}), isNull, reason: 'a broken message never crashes a client');
  });

  testWidgets('Dice Dash in the garito: sirens, decisions, the reveal, then the next hand', (tester) async {
    await GameSettings().setTheme(TableTheme.garito);
    final g = newGame(GameMode.diceDash, 3);
    g.debugRaidNow();
    g.debugRaidReal = true;
    await untilRaid(tester, g, RaidPhase.alarm);
    expect(g.state.status, GameStatus.finished, reason: 'never in the middle of a hand');
    await untilRaid(tester, g, RaidPhase.deciding);

    final me = g.localPlayerId;
    final before = {for (final p in g.players) p.id: p.chipBalance};
    g.raidTip(me);
    expect(g.raid!.tips[me], isTrue, reason: 'the lookout tells the truth');
    expect(g.players.firstWhere((p) => p.id == me).chipBalance, before[me]! - PoliceRaid.tipCost);
    g.raidChoose(me, RaidChoice.bribe, 300);
    g.raidChoose(me, RaidChoice.flee, 0);
    expect(g.raid!.choices[me], (RaidChoice.bribe, 300), reason: 'one decision per raid');

    final round = g.roundCounter;
    await untilRaid(tester, g, RaidPhase.reveal);
    final r = g.raid!;
    final caught = [for (final e in before.entries) if (e.value > 0) e.key];
    expect(r.outcomes.keys.toSet(), caught.toSet(), reason: 'everyone with chips is in it, the bots too');
    for (final p in g.players) {
      final paid = p.id == me ? PoliceRaid.tipCost : 0;
      final delta = r.outcomes[p.id]?.$2 ?? 0;
      expect(p.chipBalance, max(0, before[p.id]! - paid + delta), reason: '${p.name}: chips follow the outcome');
    }
    expect(g.recordOf(me), 1, reason: 'a bribe goes on file');

    for (var i = 0; i < 400 && g.roundCounter == round; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(g.raid, isNull);
    expect(g.roundCounter, round + 1, reason: 'the next hand is dealt after the raid');
    await finish(tester, g);
  });

  testWidgets('a snitch is on file and the mafia remembers for a few hands', (tester) async {
    await GameSettings().setTheme(TableTheme.garito);
    final g = newGame(GameMode.diceDash, 2);
    g.debugRaidNow();
    await untilRaid(tester, g, RaidPhase.deciding);
    g.raidChoose(g.localPlayerId, RaidChoice.snitch, 0);
    await untilRaid(tester, g, RaidPhase.reveal);
    expect(g.isMarked(g.localPlayerId), isTrue);
    expect(g.recordOf(g.localPlayerId), 2);
    final start = g.roundCounter;
    for (var i = 0; i < 20000 && g.roundCounter < start + PoliceRaid.revengeHands + 1; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      humanPlays(g);
    }
    expect(g.isMarked(g.localPlayerId), isFalse, reason: 'the grudge lasts ${PoliceRaid.revengeHands} hands');
    expect(g.recordOf(g.localPlayerId), 2, reason: 'the record stays');
    await finish(tester, g);
  });

  testWidgets('alone: surrender means jail, then a new table with 1000 each; the record stays', (tester) async {
    await GameSettings().setTheme(TableTheme.garito);
    final g = newGame(GameMode.diceDash, 3);
    g.debugRaidNow();
    g.debugRaidReal = true;
    await untilRaid(tester, g, RaidPhase.deciding);
    final me = g.localPlayerId;
    g.raidTip(me); // nothing on file from a tip
    g.raidChoose(me, RaidChoice.surrender, 0);
    await untilRaid(tester, g, RaidPhase.reveal);
    expect(g.raid!.outcomes[me]!.$1, RaidOutcome.jailed);
    expect(g.players.firstWhere((p) => p.id == me).chipBalance, 0);
    await untilRaid(tester, g, RaidPhase.jail);
    for (var i = 0; i < 400 && g.raid != null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(g.raid, isNull);
    expect(g.isJailed(me), isFalse);
    expect(g.matchWinnerId, isNull);
    await tester.pump(const Duration(milliseconds: 800));
    for (final p in g.players) {
      expect(p.chipBalance + g.getPlayerBet(p.id), 1000, reason: 'a new table: ${p.name} starts with 1000');
    }
    await finish(tester, g);
  });

  testWidgets('the lawyer gets you out once, for half of your chips', (tester) async {
    await GameSettings().setTheme(TableTheme.garito);
    final g = newGame(GameMode.diceDash, 2);
    g.debugRaidNow();
    g.debugRaidReal = true;
    await untilRaid(tester, g, RaidPhase.deciding);
    final me = g.localPlayerId;
    final had = g.players.firstWhere((p) => p.id == me).chipBalance;
    g.raidChoose(me, RaidChoice.surrender, 0);
    await untilRaid(tester, g, RaidPhase.reveal);
    expect(g.lawyerAvailable(me), isTrue);
    g.raidLawyer(me);
    expect(g.raid!.outcomes[me]!.$1, RaidOutcome.lawyer);
    expect(g.players.firstWhere((p) => p.id == me).chipBalance, had - (had / 20).round() * 10);
    expect(g.isJailed(me), isFalse);
    expect(g.lawyerAvailable(me), isFalse, reason: 'only once per table');
    for (var i = 0; i < 400 && g.raid != null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(g.raid?.phase, isNot(RaidPhase.jail), reason: 'no cell after the lawyer');
    await finish(tester, g);
  });

  testWidgets('the boss blames you: taking it means jail, and he owes you 500 at the next table', (tester) async {
    await GameSettings().setTheme(TableTheme.garito);
    final g = newGame(GameMode.diceDash, 3);
    g.debugRaidNow();
    g.debugRaidReal = true;
    g.debugScapegoat = true;
    await untilRaid(tester, g, RaidPhase.deciding);
    final me = g.localPlayerId;
    g.raidChoose(me, RaidChoice.hide, 0);
    await untilRaid(tester, g, RaidPhase.scapegoat);
    expect(g.raid!.scapegoatId, me);
    expect(g.raid!.bossId, isNotNull);
    g.raidScapegoat(me, ScapegoatChoice.acceptBlame);
    await untilRaid(tester, g, RaidPhase.reveal);
    expect(g.raid!.outcomes[me]!.$1, RaidOutcome.jailed);
    for (var i = 0; i < 600 && g.raid != null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 800));
    final mine = g.players.firstWhere((p) => p.id == me);
    expect(mine.chipBalance + g.getPlayerBet(me), 1000 + PoliceRaid.favorChips);
    await finish(tester, g);
  });

  test('LAN: a client surrenders over the network, sits out two hands and comes back with 1000', () async {
    await GameSettings().setTheme(TableTheme.garito);
    final hostP2p = P2PService()..preferredPort = 47950;
    final clientP2p = P2PService()..preferredPort = 47951;
    final ana = GameProvider(p2pService: hostP2p);
    final luis = GameProvider(p2pService: clientP2p);
    addTearDown(() async {
      ana.exitGame();
      luis.exitGame();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      ana.dispose();
      luis.dispose();
      await hostP2p.dispose();
      await clientP2p.dispose();
    });
    ana
      ..setHost(true)
      ..setMultiplayer(true)
      ..setGameMode(GameMode.diceDash)
      ..setPlayerName('Ana')
      ..setRoomMetadata('Garito', '');
    await hostP2p.startAdvertising('Garito|1/4|0|0|diceDash');
    luis
      ..setHost(false)
      ..setMultiplayer(true)
      ..setPlayerName('Luis');
    final assigned = clientP2p.onMessageReceived.firstWhere((m) => m['type'] == 'ASSIGN_SEAT');
    expect(await clientP2p.connectToHost('127.0.0.1', hostP2p.hostPort!), isTrue);
    final ep = '127.0.0.1:${hostP2p.hostPort}';
    await clientP2p.sendMessage(ep, {
      'type': 'JOIN_REQUEST',
      'playerName': 'Luis',
      'password': '',
      'token': luis.playerToken,
      'endpointId': ep,
      'listenPort': clientP2p.preferredPort,
    });
    final seat = await assigned.timeout(const Duration(seconds: 5));
    luis.localPlayerId = seat['playerId'] as String;
    final luisId = luis.localPlayerId;

    // Both humans roll and check/call on their turn (never during the raid).
    var stop = false;
    Future<void> drive() async {
      while (!stop) {
        // Ana (the host) never runs out, so the table does not reset everybody's chips.
        final host = ana.players.where((p) => p.id == ana.localPlayerId).firstOrNull;
        if (host != null && host.chipBalance < 300 && ana.state.status == GameStatus.finished && ana.raid == null) {
          ana.debugSetChips(host.id, 1000);
        }
        for (final g in [ana, luis]) {
          final idx = g.state.currentPlayerIndex;
          if (g.raid != null || idx < 0 || idx >= g.players.length) continue;
          final me = g.players[idx];
          if (me.id != g.localPlayerId || me.isFolded || g.isBetting || g.diceEventBusy) continue;
          if (g.state.status == GameStatus.diceTurn) g.rollDice();
          if (g.state.status == GameStatus.betting) g.call(me.id);
        }
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }

    Future<void> until(bool Function() cond, String reason, {int seconds = 90}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (!cond()) {
        if (DateTime.now().isAfter(end)) fail('timed out: $reason');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    ana.startMatch();
    ana.debugRaidNow();
    ana.debugRaidReal = true;
    unawaited(drive());
    await until(() => luis.raid?.phase == RaidPhase.deciding, 'the raid reaches the client');
    expect(luis.raid!.real, isNull, reason: 'the client does not know if it is real');
    expect(luis.raid!.price, isNull);
    luis.raidChoose(luisId, RaidChoice.surrender, 0);
    ana.raidChoose(ana.localPlayerId, RaidChoice.hide, 0);
    await until(() => luis.raid?.phase == RaidPhase.reveal, 'the reveal reaches the client');
    expect(luis.raid!.outcomes[luisId]!.$1, RaidOutcome.jailed, reason: 'the choice travelled to the host');
    await until(() => ana.raid == null, 'the raid ends');
    expect(ana.isJailed(luisId), isTrue);
    luis.rebuyLocalPlayer();
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(ana.players.firstWhere((p) => p.id == luisId).chipBalance, 0, reason: 'no rebuy from jail');
    await until(() => !ana.isJailed(luisId), 'Luis comes out of jail', seconds: 120);
    await until(() => ana.players.firstWhere((p) => p.id == luisId).hand.isNotEmpty, 'Luis is dealt in again');
    final back = ana.players.firstWhere((p) => p.id == luisId);
    expect(back.chipBalance + ana.getPlayerBet(luisId), 1000);
    stop = true;
  }, timeout: const Timeout(Duration(minutes: 5)));

  for (final (mode, theme) in [
    (GameMode.texasHoldem, TableTheme.garito),
    (GameMode.diceDash, TableTheme.cantina),
    (GameMode.diceDash, TableTheme.casino),
  ]) {
    testWidgets('no raid in ${mode.name} with the ${theme.name} scene', (tester) async {
      await GameSettings().setTheme(theme);
      final g = newGame(mode, 3);
      g.debugRaidNow();
      final start = g.roundCounter;
      for (var i = 0; i < 5000; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        humanPlays(g);
        expect(g.raid, isNull);
      }
      expect(g.roundCounter, greaterThan(start + 1));
      await finish(tester, g);
    });
  }
}
