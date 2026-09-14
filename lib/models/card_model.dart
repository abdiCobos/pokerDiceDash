enum Suit { hearts, diamonds, clubs, spades }

class CardModel {
  final String value;
  final Suit suit;

  CardModel({
    required this.value,
    required this.suit,
  });

  String get assetPath {
    final suitCapitalized = suit.name[0].toUpperCase() + suit.name.substring(1);
    return 'assets/images/cards/card$suitCapitalized$value.png';
  }

  Map<String, dynamic> toJson() => {
    'value': value,
    'suit': suit.name,
  };

  Map<String, dynamic> toMap() => toJson();

  factory CardModel.fromJson(Map<String, dynamic> json) => CardModel(
    value: json['value'],
    suit: Suit.values.byName(json['suit']),
  );

  factory CardModel.fromMap(Map<String, dynamic> map) => CardModel.fromJson(map);
}
