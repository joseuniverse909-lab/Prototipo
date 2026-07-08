enum ValidationStatus {
  pending,
  approved,
  rejected,
}

extension ValidationStatusInfo on ValidationStatus {
  String get label {
    switch (this) {
      case ValidationStatus.pending:
        return 'Pendiente';
      case ValidationStatus.approved:
        return 'Aprobada';
      case ValidationStatus.rejected:
        return 'Rechazada';
    }
  }
}

class ValidationPhoto {
  final String id;
  final String userId;
  final String userName;
  final String localPath;
  final String imageBase64;
  final String note;
  final DateTime createdAt;
  final ValidationStatus status;
  final int awardedPoints;

  const ValidationPhoto({
    required this.id,
    required this.userId,
    required this.userName,
    required this.localPath,
    this.imageBase64 = '',
    required this.note,
    required this.createdAt,
    this.status = ValidationStatus.pending,
    this.awardedPoints = 0,
  });

  ValidationPhoto copyWith({
    String? id,
    String? userId,
    String? userName,
    String? localPath,
    String? imageBase64,
    String? note,
    DateTime? createdAt,
    ValidationStatus? status,
    int? awardedPoints,
  }) {
    return ValidationPhoto(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      localPath: localPath ?? this.localPath,
      imageBase64: imageBase64 ?? this.imageBase64,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      awardedPoints: awardedPoints ?? this.awardedPoints,
    );
  }

  factory ValidationPhoto.fromJson(Map<String, dynamic> json) {
    return ValidationPhoto(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      localPath: json['localPath']?.toString() ?? '',
      imageBase64: json['imageBase64']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
              DateTime.now(),
      status: ValidationStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => ValidationStatus.pending,
      ),
      awardedPoints: (json['awardedPoints'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'localPath': localPath,
      'imageBase64': imageBase64,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'awardedPoints': awardedPoints,
    };
  }
}
