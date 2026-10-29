import 'dart:math';

/// La redada of the garito: a random Dice Dash event between hands. Sirens, the lookout
/// shouts, and every player decides in secret: bribe the comandante, hide the chips, run,
/// snitch on the bosses or give up. Sometimes it is only a patrol passing by; sometimes the
/// boss blames one player. The host decides everything; clients get it in the snapshot,
/// with the secrets (real or not, the price, the other players' choices) hidden until the
/// reveal.
enum RaidPhase { alarm, deciding, scapegoat, reveal, jail }

enum RaidChoice { bribe, hide, flee, snitch, surrender }

enum ScapegoatChoice { payDouble, accuseBack, acceptBlame }

enum RaidOutcome {
  /// Real raid.
  bribed, // the envelope was enough
  bribeFailed, // not enough: envelope lost and searched
  hidden, // not searched
  found, // searched: half the chips confiscated
  escaped,
  caught, // caught running: 30 % confiscated
  snitched, // free, with a reward from the police
  jailed,
  lawyer, // jailed, but the lawyer got them out for half their chips
  scapegoatPaid,
  scapegoatWon, // accused the boss back and won the coin toss
  bossJailed, // the boss who lost the coin toss
  /// False alarm.
  wastedBribe,
  droppedChips, // ran for nothing and dropped some chips
  falseSurrender, // gave up in front of nobody
  nothing,
}

class PoliceRaid {
  static const announceTime = Duration(milliseconds: 3500);
  static const decideTime = Duration(seconds: 12);
  static const scapegoatTime = Duration(seconds: 7);
  static const revealTime = Duration(milliseconds: 8500);

  /// When the newspaper slides in, counted from the start of the reveal.
  static const newspaperAt = Duration(milliseconds: 5000);
  static const jailTime = Duration(milliseconds: 5500);

  static const bribes = [100, 200, 300];
  static const tipCost = 50;

  /// Chance that the police really come in (otherwise a patrol was only passing by).
  static const realChance = 0.6;
  static const scapegoatChance = 0.15;
  static const scapegoatChanceForSnitches = 0.5;

  /// Hands the bots take revenge after a player snitched.
  static const revengeHands = 6;

  /// Hands a jailed player sits out in a LAN game.
  static const jailHands = 2;

  /// Extra chips at the next table for someone who took the blame for the boss.
  static const favorChips = 500;

  final int seed;

  /// Secret until the reveal (null on clients before it).
  final bool? real;

  /// The comandante's base price, secret until the reveal (null on clients before it).
  final int? price;

  /// Public hint about the price: 0 = in a hurry (cheap), 1 = normal, 2 = in a bad mood.
  final int mood;

  RaidPhase phase;

  /// playerId -> (choice, bribe chips).
  final Map<String, (RaidChoice, int)> choices;

  /// Players who decided (others' choices stay hidden from each client until the reveal).
  final Set<String> decided;

  /// Players who paid the lookout; on clients only their own entry, with what he saw.
  final Map<String, bool> tips;

  /// Player blamed by the boss, the bot (or nobody: a boss outside the table) who blamed him.
  String? scapegoatId;
  String? bossId;
  ScapegoatChoice? scapegoatChoice;

  /// playerId -> (outcome, chips won or lost).
  final Map<String, (RaidOutcome, int)> outcomes;

  /// The comandante's price for each player at the reveal (base price + their record).
  final Map<String, int> prices;

  PoliceRaid({
    required this.seed,
    required this.real,
    required this.price,
    required this.mood,
    this.phase = RaidPhase.alarm,
    Map<String, (RaidChoice, int)>? choices,
    Set<String>? decided,
    Map<String, bool>? tips,
    this.scapegoatId,
    this.bossId,
    this.scapegoatChoice,
    Map<String, (RaidOutcome, int)>? outcomes,
    Map<String, int>? prices,
  }) : choices = choices ?? {},
       decided = decided ?? {},
       tips = tips ?? {},
       outcomes = outcomes ?? {},
       prices = prices ?? {};

  factory PoliceRaid.random(Random rng) {
    final price = 100 + 50 * rng.nextInt(9); // 100 .. 500
    return PoliceRaid(
      seed: rng.nextInt(1 << 30),
      real: rng.nextDouble() < realChance,
      price: price,
      mood: price <= 200 ? 0 : (price <= 350 ? 1 : 2),
    );
  }

  /// The price a player with [record] (bribes and snitching on file) must reach.
  static int priceFor(int base, int record) => base + 50 * record;

  bool get revealed => phase == RaidPhase.reveal || phase == RaidPhase.jail;

  bool jailed(String playerId) => outcomes[playerId]?.$1 == RaidOutcome.jailed;

  /// The snapshot for [forPlayerId] (null = the host's own full copy).
  Map<String, dynamic> toMap({String? forPlayerId, bool full = false}) {
    final open = full || revealed;
    return {
      'seed': seed,
      'real': open ? real : null,
      'price': open ? price : null,
      'mood': mood,
      'phase': phase.name,
      'choices': {
        for (final e in choices.entries)
          if (open || e.key == forPlayerId) e.key: [e.value.$1.index, e.value.$2],
      },
      'decided': decided.toList(),
      'tips': {
        for (final e in tips.entries)
          if (open || e.key == forPlayerId) e.key: e.value,
      },
      'scapegoat': scapegoatId,
      'boss': bossId,
      'scapegoatChoice': scapegoatChoice?.index,
      'outcomes': {for (final e in outcomes.entries) e.key: [e.value.$1.index, e.value.$2]},
      'prices': open ? prices : const <String, int>{},
    };
  }

  static PoliceRaid? fromMap(Object? m) {
    if (m is! Map) return null;
    try {
      final sc = m['scapegoatChoice'] as int?;
      return PoliceRaid(
        seed: m['seed'] as int,
        real: m['real'] as bool?,
        price: m['price'] as int?,
        mood: m['mood'] as int,
        phase: RaidPhase.values.firstWhere((p) => p.name == m['phase'], orElse: () => RaidPhase.alarm),
        choices: {
          for (final e in (m['choices'] as Map).entries)
            e.key as String: (RaidChoice.values[(e.value as List)[0] as int], (e.value as List)[1] as int),
        },
        decided: {for (final d in m['decided'] as List) d as String},
        tips: {for (final e in (m['tips'] as Map).entries) e.key as String: e.value as bool},
        scapegoatId: m['scapegoat'] as String?,
        bossId: m['boss'] as String?,
        scapegoatChoice: sc == null ? null : ScapegoatChoice.values[sc],
        outcomes: {
          for (final e in (m['outcomes'] as Map).entries)
            e.key as String: (RaidOutcome.values[(e.value as List)[0] as int], (e.value as List)[1] as int),
        },
        prices: {for (final e in (m['prices'] as Map).entries) e.key as String: e.value as int},
      );
    } catch (_) {
      return null;
    }
  }
}

/// Settles a raid: what happens to each player's chips. Pure, so it can be tested alone.
///
/// [chips] are the stacks at the start of the raid; [record] each player's file (bribes and
/// snitching); [coinWon] the coin toss of a scapegoat who accused the boss back; [lawyerFor]
/// the players whose lawyer got them out of jail.
Map<String, (RaidOutcome, int)> settleRaid({
  required PoliceRaid raid,
  required Map<String, int> chips,
  required Map<String, int> record,
  required Random rng,
  bool coinWon = false,
}) {
  final out = <String, (RaidOutcome, int)>{};
  int round10(double v) => (v / 10).round() * 10;
  final real = raid.real ?? false;
  final base = raid.price ?? 0;
  for (final e in chips.entries) {
    final id = e.key;
    final c = e.value;
    final (choice, bribe) = raid.choices[id] ?? (RaidChoice.hide, 0);
    final env = min(bribe, c);
    if (!real) {
      out[id] = switch (choice) {
        RaidChoice.bribe => (RaidOutcome.wastedBribe, -env),
        RaidChoice.flee => (RaidOutcome.droppedChips, -round10(c * 0.1)),
        RaidChoice.surrender => (RaidOutcome.falseSurrender, -round10(c * 0.2)),
        RaidChoice.hide || RaidChoice.snitch => (RaidOutcome.nothing, 0),
      };
      continue;
    }
    out[id] = switch (choice) {
      RaidChoice.bribe when env >= PoliceRaid.priceFor(base, record[id] ?? 0) => (RaidOutcome.bribed, -env),
      RaidChoice.bribe => (RaidOutcome.bribeFailed, -env - round10((c - env) * 0.5)),
      RaidChoice.hide => rng.nextBool() ? (RaidOutcome.hidden, 0) : (RaidOutcome.found, -round10(c * 0.5)),
      RaidChoice.flee => rng.nextDouble() < 0.6 ? (RaidOutcome.escaped, 0) : (RaidOutcome.caught, -round10(c * 0.3)),
      RaidChoice.surrender => (RaidOutcome.jailed, -c),
      RaidChoice.snitch => (RaidOutcome.snitched, 0),
    };
  }
  // The boss blames one player: that player's own choice no longer counts.
  final goat = raid.scapegoatId;
  if (real && goat != null && chips.containsKey(goat)) {
    final c = chips[goat]!;
    final twice = 2 * PoliceRaid.priceFor(base, record[goat] ?? 0);
    switch (raid.scapegoatChoice ?? ScapegoatChoice.acceptBlame) {
      case ScapegoatChoice.payDouble when c >= twice:
        out[goat] = (RaidOutcome.scapegoatPaid, -twice);
      case ScapegoatChoice.accuseBack when coinWon:
        out[goat] = (RaidOutcome.scapegoatWon, 0);
        final boss = raid.bossId;
        if (boss != null && chips.containsKey(boss)) out[boss] = (RaidOutcome.bossJailed, -chips[boss]!);
      default:
        out[goat] = (RaidOutcome.jailed, -c);
    }
  }
  // Whoever snitched gets half of what the police took from the others.
  final snitches = [for (final e in out.entries) if (e.value.$1 == RaidOutcome.snitched) e.key];
  if (snitches.isNotEmpty) {
    final seized = out.entries
        .where((e) => !snitches.contains(e.key) && e.value.$2 < 0 && e.value.$1 != RaidOutcome.bribed)
        .fold<int>(0, (a, e) => a - e.value.$2);
    final each = max(50, round10(seized * 0.5 / snitches.length));
    for (final s in snitches) {
      out[s] = (RaidOutcome.snitched, each);
    }
  }
  return out;
}
