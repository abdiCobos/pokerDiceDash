import 'dart:math';

/// The cockfight of the cantina: a random Dice Dash event between hands. Two cartoon roosters
/// box (gloves, no blood), one is the favourite, everyone can bet on one of them, and the
/// winner leaves with a well-dressed hen and a cigar. The host decides everything; clients
/// get it in the state snapshot.
enum CockFightPhase { betting, fighting, result }

class CockFight {
  /// Rooster sprites (`assets/images/gallos/<kind>_*.png`).
  static const kinds = ['colorado', 'giro'];

  /// Ring names: one for the red rooster, one for the light one.
  static const redNames = ['El Colorado', 'El Canelo', 'El Huracán', 'El Charro', 'El Tequilero', 'El Bravo'];
  static const lightNames = ['El Giro', 'El Cenizo', 'El Güero', 'El Pinto', 'El Relámpago', 'El Mariachi'];

  static const bets = [50, 100, 200];

  /// Total returned per chip bet: the favourite pays less, the underdog much more.
  static const favoritePays = 1.5;
  static const underdogPays = 3.0;

  /// Chance that the favourite wins.
  static const favoriteWins = 0.65;

  /// The announcement ("¡Pelea de gallos! Apuesta a tu favorito") before the bets open.
  static const announceTime = Duration(milliseconds: 3000);
  static const bettingTime = Duration(seconds: 12);

  /// Length of the fight animation (walk in, punches, K.O., the hen, walk off).
  static const fightTime = Duration(seconds: 14);
  /// The result, then the ring leaves the screen ([exitAt] into it) before the next hand.
  static const resultTime = Duration(milliseconds: 4600);
  static const exitAt = Duration(milliseconds: 3400);

  /// Seeds the punch sequence so every device plays the same fight.
  final int seed;

  /// Ring names of rooster 0 and 1 (rooster 0 wears red gloves, rooster 1 blue).
  final List<String> fighters;

  /// 0 or 1.
  final int favorite;

  CockFightPhase phase;

  /// Set when the fight starts.
  int? winner;

  /// playerId -> (rooster, chips). Chips 0 = the player passed.
  final Map<String, (int, int)> wagers;

  /// playerId -> chips paid back (only winners), set at the result.
  final Map<String, int> payouts;

  CockFight({
    required this.seed,
    required this.fighters,
    required this.favorite,
    this.phase = CockFightPhase.betting,
    this.winner,
    Map<String, (int, int)>? wagers,
    Map<String, int>? payouts,
  }) : wagers = wagers ?? {},
       payouts = payouts ?? {};

  factory CockFight.random(Random rng) {
    return CockFight(
      seed: rng.nextInt(1 << 30),
      fighters: [redNames[rng.nextInt(redNames.length)], lightNames[rng.nextInt(lightNames.length)]],
      favorite: rng.nextInt(2),
    );
  }

  double paysFor(int rooster) => rooster == favorite ? favoritePays : underdogPays;

  /// Chips returned for a winning bet (stake included).
  int payout(int rooster, int chips) => (chips * paysFor(rooster)).round();

  int? wagerRooster(String playerId) => wagers[playerId]?.$1;
  int wagerChips(String playerId) => wagers[playerId]?.$2 ?? 0;
  bool hasDecided(String playerId) => wagers.containsKey(playerId);

  Map<String, dynamic> toMap() => {
    'seed': seed,
    'fighters': fighters,
    'favorite': favorite,
    'phase': phase.name,
    'winner': winner,
    'wagers': {
      for (final e in wagers.entries) e.key: [e.value.$1, e.value.$2],
    },
    'payouts': payouts,
  };

  static CockFight? fromMap(Object? m) {
    if (m is! Map) return null;
    try {
      return CockFight(
        seed: m['seed'] as int,
        fighters: [for (final f in m['fighters'] as List) f as String],
        favorite: m['favorite'] as int,
        phase: CockFightPhase.values.firstWhere((p) => p.name == m['phase'], orElse: () => CockFightPhase.betting),
        winner: m['winner'] as int?,
        wagers: {
          for (final e in (m['wagers'] as Map).entries)
            e.key as String: ((e.value as List)[0] as int, (e.value as List)[1] as int),
        },
        payouts: {for (final e in (m['payouts'] as Map).entries) e.key as String: e.value as int},
      );
    } catch (_) {
      return null;
    }
  }
}
