class Reward {
  final String id;
  final String name;
  final String description;
  final int cost;
  final bool claimed;

  const Reward({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    this.claimed = false,
  });

  Reward copyWith({bool? claimed}) {
    return Reward(
      id: id,
      name: name,
      description: description,
      cost: cost,
      claimed: claimed ?? this.claimed,
    );
  }

  factory Reward.fromJson(Map<String, dynamic> json) {
    return Reward(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      cost: (json['cost'] as num?)?.toInt() ?? 0,
      claimed: json['claimed'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'cost': cost,
      'claimed': claimed,
    };
  }
}
