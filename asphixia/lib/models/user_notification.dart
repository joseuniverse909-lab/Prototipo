class UserNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final DateTime createdAt;

  const UserNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.createdAt,
  });

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    return UserNotification(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
