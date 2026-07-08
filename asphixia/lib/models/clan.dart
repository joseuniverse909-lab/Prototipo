class Clan {
  final String id;
  final String name;
  final String ownerId;
  final List<String> memberIds;
  final List<String> pendingMemberIds;
  final bool isPrivate;
  final String requirement;
  final int points;
  final int eventPoints;

  const Clan({
    required this.id,
    required this.name,
    this.ownerId = '',
    this.memberIds = const [],
    this.pendingMemberIds = const [],
    this.isPrivate = false,
    this.requirement = '',
    this.points = 0,
    this.eventPoints = 0,
  });

  int get totalPoints => points + eventPoints;

  Clan copyWith({
    String? id,
    String? name,
    String? ownerId,
    List<String>? memberIds,
    List<String>? pendingMemberIds,
    bool? isPrivate,
    String? requirement,
    int? points,
    int? eventPoints,
  }) {
    return Clan(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      memberIds: memberIds ?? this.memberIds,
      pendingMemberIds: pendingMemberIds ?? this.pendingMemberIds,
      isPrivate: isPrivate ?? this.isPrivate,
      requirement: requirement ?? this.requirement,
      points: points ?? this.points,
      eventPoints: eventPoints ?? this.eventPoints,
    );
  }

  factory Clan.fromJson(Map<String, dynamic> json) {
    return Clan(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      ownerId: json['ownerId']?.toString() ?? '',
      memberIds:
          (json['memberIds'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      pendingMemberIds:
          (json['pendingMemberIds'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      isPrivate: json['isPrivate'] == true,
      requirement: json['requirement']?.toString() ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      eventPoints: (json['eventPoints'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'pendingMemberIds': pendingMemberIds,
      'isPrivate': isPrivate,
      'requirement': requirement,
      'points': points,
      'eventPoints': eventPoints,
    };
  }
}
