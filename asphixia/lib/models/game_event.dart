enum GameEventType { clanWar, cleaningWar, speedCompetition, multiplierRush }

extension GameEventTypeInfo on GameEventType {
  String get label {
    switch (this) {
      case GameEventType.clanWar:
        return 'Guerra de clanes';
      case GameEventType.cleaningWar:
        return 'Guerra de limpieza';
      case GameEventType.speedCompetition:
        return 'Competencia de velocidad';
      case GameEventType.multiplierRush:
        return 'Zonas multiplicadoras';
    }
  }
}

class GameEvent {
  final String id;
  final String name;
  final GameEventType type;
  final String rules;
  final DateTime startsAt;
  final DateTime endsAt;
  final int bonusPoints;
  final bool isActive;
  final String? winningClanId;

  const GameEvent({
    required this.id,
    required this.name,
    required this.type,
    required this.rules,
    required this.startsAt,
    required this.endsAt,
    required this.bonusPoints,
    this.isActive = true,
    this.winningClanId,
  });

  Duration get duration => endsAt.difference(startsAt);

  bool get isRunning {
    final now = DateTime.now();
    return isActive && now.isAfter(startsAt) && now.isBefore(endsAt);
  }

  GameEvent copyWith({
    String? id,
    String? name,
    GameEventType? type,
    String? rules,
    DateTime? startsAt,
    DateTime? endsAt,
    int? bonusPoints,
    bool? isActive,
    String? winningClanId,
  }) {
    return GameEvent(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      rules: rules ?? this.rules,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      bonusPoints: bonusPoints ?? this.bonusPoints,
      isActive: isActive ?? this.isActive,
      winningClanId: winningClanId ?? this.winningClanId,
    );
  }

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: GameEventType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => GameEventType.cleaningWar,
      ),
      rules: json['rules']?.toString() ?? '',
      startsAt:
          DateTime.tryParse(json['startsAt']?.toString() ?? '') ??
          DateTime.now(),
      endsAt:
          DateTime.tryParse(json['endsAt']?.toString() ?? '') ??
          DateTime.now().add(const Duration(hours: 1)),
      bonusPoints: (json['bonusPoints'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] != false,
      winningClanId: json['winningClanId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'rules': rules,
      'startsAt': startsAt.toIso8601String(),
      'endsAt': endsAt.toIso8601String(),
      'bonusPoints': bonusPoints,
      'isActive': isActive,
      'winningClanId': winningClanId,
    };
  }
}
