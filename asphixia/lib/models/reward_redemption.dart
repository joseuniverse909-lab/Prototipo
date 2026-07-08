enum RedemptionStatus { pending, delivered, rejected }

extension RedemptionStatusInfo on RedemptionStatus {
  String get label {
    switch (this) {
      case RedemptionStatus.pending:
        return 'Pendiente';
      case RedemptionStatus.delivered:
        return 'Entregada';
      case RedemptionStatus.rejected:
        return 'Rechazada';
    }
  }
}

class RewardRedemption {
  final String id;
  final String rewardId;
  final String rewardName;
  final String userId;
  final String userName;
  final int cost;
  final RedemptionStatus status;
  final String adminMessage;
  final DateTime createdAt;

  const RewardRedemption({
    required this.id,
    required this.rewardId,
    required this.rewardName,
    required this.userId,
    required this.userName,
    required this.cost,
    this.status = RedemptionStatus.pending,
    this.adminMessage = '',
    required this.createdAt,
  });

  RewardRedemption copyWith({RedemptionStatus? status, String? adminMessage}) {
    return RewardRedemption(
      id: id,
      rewardId: rewardId,
      rewardName: rewardName,
      userId: userId,
      userName: userName,
      cost: cost,
      status: status ?? this.status,
      adminMessage: adminMessage ?? this.adminMessage,
      createdAt: createdAt,
    );
  }

  factory RewardRedemption.fromJson(Map<String, dynamic> json) {
    return RewardRedemption(
      id: json['id']?.toString() ?? '',
      rewardId: json['rewardId']?.toString() ?? '',
      rewardName: json['rewardName']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      cost: (json['cost'] as num?)?.toInt() ?? 0,
      status: RedemptionStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => RedemptionStatus.pending,
      ),
      adminMessage: json['adminMessage']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rewardId': rewardId,
      'rewardName': rewardName,
      'userId': userId,
      'userName': userName,
      'cost': cost,
      'status': status.name,
      'adminMessage': adminMessage,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
