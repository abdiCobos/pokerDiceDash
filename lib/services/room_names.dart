import 'dart:math';

/// Default names offered when creating a room: famous casinos, Mexican cantinas
/// and one legendary underground game. The player can still type their own.
class RoomNames {
  static const common = [
    'Caesars Palace',
    'Excalibur',
    'Bellagio',
    'The Venetian',
    'MGM Grand',
    'Golden Nugget',
    'Flamingo',
    'Casino de Montecarlo',
    'Cantina: Guardería de maridos',
    'Cantina La Ópera',
    'Salón Tenampa',
    'El Gallo de Oro',
    'La Peninsular',
    // Molly Bloom's underground game, the one Tobey Maguire played at.
    "Molly's Game",
    'The Viper Room',
  ];

  /// Easter egg: shows up about once every 100 rooms.
  static const rare = 'Lobos buscando lobita auuu';
  static const rareChance = 0.01;

  static String? _last;

  /// A random name, never the same as the previous one.
  static String pick([Random? random]) {
    final r = random ?? Random();
    if (r.nextDouble() < rareChance && _last != rare) return _last = rare;
    String name;
    do {
      name = common[r.nextInt(common.length)];
    } while (name == _last);
    return _last = name;
  }
}
