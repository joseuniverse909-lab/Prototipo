class ClanMessage {
  final String id;
  final String clanId;
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;

  const ClanMessage({
    required this.id,
    required this.clanId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  factory ClanMessage.fromJson(Map<String, dynamic> json) {
    return ClanMessage(
      id: json['id']?.toString() ?? '',
      clanId: json['clanId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? 'Jugador',
      text: json['text']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clanId': clanId,
      'userId': userId,
      'userName': userName,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
