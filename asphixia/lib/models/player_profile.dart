class PlayerProfile {
  final String id;
  final String name;
  final String email;
  final int points;
  final String clanId;
  final String role;

  const PlayerProfile({
    required this.id,
    required this.name,
    required this.email,
    this.points = 0,
    this.clanId = '',
    this.role = 'player',
  });

  PlayerProfile copyWith({
    String? id,
    String? name,
    String? email,
    int? points,
    String? clanId,
    String? role,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      points: points ?? this.points,
      clanId: clanId ?? this.clanId,
      role: role ?? this.role,
    );
  }

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      clanId: json['clanId']?.toString() ?? '',
      role: json['role']?.toString() ?? 'player',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'points': points,
      'clanId': clanId,
      'role': role,
    };
  }
}
