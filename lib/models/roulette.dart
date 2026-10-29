import 'dart:math';

/// The casino's roulette: a random Dice Dash event between hands. A smiling croupier spins a
/// European wheel (0-36); everyone may place one bet: red or black, even or odd (pay x2) or a
/// single number (pays x36). Zero beats every outside bet. The host decides everything;
/// clients get it in the state snapshot.
enum RoulettePhase { betting, spinning, result }

enum RouletteBetKind { red, black, even, odd, number }

class RouletteBet {
  final RouletteBetKind kind;

  /// The number, for [RouletteBetKind.number].
  final int number;
  final int chips;
  const RouletteBet(this.kind, this.chips, [this.number = 0]);

  /// 0 chips: the player passed.
  bool get passed => chips == 0;

  bool wins(int n) => switch (kind) {
    RouletteBetKind.red => Roulette.isRed(n),
    RouletteBetKind.black => n != 0 && !Roulette.isRed(n),
    RouletteBetKind.even => n != 0 && n.isEven,
    RouletteBetKind.odd => n.isOdd,
    RouletteBetKind.number => n == number,
  };

  /// Chips returned when it wins (stake included).
  int get payout => chips * (kind == RouletteBetKind.number ? 36 : 2);

  /// Wire form: chips * 1000 + code (0 pass, 1 red, 2 black, 3 even, 4 odd, 10 + n number).
  int get code => passed
      ? 0
      : chips * 1000 +
            switch (kind) {
              RouletteBetKind.red => 1,
              RouletteBetKind.black => 2,
              RouletteBetKind.even => 3,
              RouletteBetKind.odd => 4,
              RouletteBetKind.number => 10 + number,
            };

  static RouletteBet? fromCode(int v) {
    if (v == 0) return const RouletteBet(RouletteBetKind.red, 0);
    final chips = v ~/ 1000;
    final c = v % 1000;
    if (c >= 10 && c <= 46) return RouletteBet(RouletteBetKind.number, chips, c - 10);
    if (c < 1 || c > 4) return null;
    return RouletteBet(RouletteBetKind.values[c - 1], chips);
  }

  @override
  bool operator ==(Object other) =>
      other is RouletteBet && other.kind == kind && other.number == number && other.chips == chips;

  @override
  int get hashCode => Object.hash(kind, number, chips);
}

class Roulette {
  /// European wheel order, clockwise from zero.
  static const wheel = [
    0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, //
    10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26,
  ];
  static const reds = {1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36};
  static bool isRed(int n) => reds.contains(n);

  static const bets = [50, 100, 200];

  static const announceTime = Duration(milliseconds: 3000);
  static const bettingTime = Duration(seconds: 12);

  /// The wheel spins, the ball slows down and drops into its pocket.
  static const spinTime = Duration(milliseconds: 7500);

  /// The result, then the scene leaves the screen ([exitAt] into it) before the next hand.
  static const resultTime = Duration(milliseconds: 4800);
  static const exitAt = Duration(milliseconds: 3700);

  /// Seeds the wheel's motion so every device shows the same spin.
  final int seed;
  RoulettePhase phase;

  /// The winning number: set when the wheel starts spinning (null before).
  int? number;

  /// playerId -> bet (0 chips = passed).
  final Map<String, RouletteBet> wagers;

  /// playerId -> chips paid back (winners only), set at the result.
  final Map<String, int> payouts;

  Roulette({
    required this.seed,
    this.phase = RoulettePhase.betting,
    this.number,
    Map<String, RouletteBet>? wagers,
    Map<String, int>? payouts,
  }) : wagers = wagers ?? {},
       payouts = payouts ?? {};

  factory Roulette.random(Random rng) => Roulette(seed: rng.nextInt(1 << 30));

  bool hasDecided(String playerId) => wagers.containsKey(playerId);

  Map<String, dynamic> toMap() => {
    'seed': seed,
    'phase': phase.name,
    'number': number,
    'bets': {for (final e in wagers.entries) e.key: e.value.code},
    'payouts': payouts,
  };

  static Roulette? fromMap(Object? m) {
    if (m is! Map) return null;
    try {
      return Roulette(
        seed: m['seed'] as int,
        phase: RoulettePhase.values.firstWhere((p) => p.name == m['phase'], orElse: () => RoulettePhase.betting),
        number: m['number'] as int?,
        wagers: {
          for (final e in (m['bets'] as Map).entries) e.key as String: RouletteBet.fromCode(e.value as int)!,
        },
        payouts: {for (final e in (m['payouts'] as Map).entries) e.key as String: e.value as int},
      );
    } catch (_) {
      return null;
    }
  }
}
