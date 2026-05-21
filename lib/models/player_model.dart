import 'card_model.dart';

class PlayerModel {
  final String id;
  final String name;
  int chipBalance;
  List<CardModel> hand;
  bool isLocal;
  bool isFolded;
  bool isBankrupt;

  PlayerModel({
    required this.id,
    required this.name,
    this.chipBalance = 1000,
    this.hand = const [],
    this.isLocal = false,
    this.isFolded = false,
    this.isBankrupt = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'chipBalance': chipBalance,
    'isLocal': isLocal,
    'isFolded': isFolded,
    'isBankrupt': isBankrupt,
    'hand': hand.map((c) => c.toJson()).toList(),
  };

  factory PlayerModel.fromJson(Map<String, dynamic> json) => PlayerModel(
    id: json['id'],
    name: json['name'],
    chipBalance: json['chipBalance'] ?? 1000,
    isLocal: json['isLocal'] ?? false,
    isFolded: json['isFolded'] ?? false,
    isBankrupt: json['isBankrupt'] ?? false,
    hand: (json['hand'] as List<dynamic>?)
            ?.map((c) => CardModel.fromJson(c))
            .toList() ??
        [],
  );

  Map<String, dynamic> toMap() => toJson();

  factory PlayerModel.fromMap(Map<String, dynamic> map) =>
      PlayerModel.fromJson(map);
}
