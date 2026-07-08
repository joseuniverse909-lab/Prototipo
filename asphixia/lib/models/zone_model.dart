import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum ZoneState { free, claimed, multiplier, forbidden }

extension ZoneStateInfo on ZoneState {
  String get label {
    switch (this) {
      case ZoneState.free:
        return 'Libre';
      case ZoneState.claimed:
        return 'Claimeada';
      case ZoneState.multiplier:
        return 'Multiplicador';
      case ZoneState.forbidden:
        return 'Prohibida';
    }
  }

  Color get color {
    switch (this) {
      case ZoneState.free:
        return const Color(0xFF9EA3AA);
      case ZoneState.claimed:
        return const Color(0xFF14B85A);
      case ZoneState.multiplier:
        return const Color(0xFFE11931);
      case ZoneState.forbidden:
        return Colors.black;
    }
  }

  double get defaultPointsPerHour {
    switch (this) {
      case ZoneState.multiplier:
        return 0.10;
      case ZoneState.claimed:
        return 0.05;
      case ZoneState.free:
      case ZoneState.forbidden:
        return 0;
    }
  }

  String get rule {
    switch (this) {
      case ZoneState.free:
        return 'Disponible para claimear';
      case ZoneState.claimed:
        return 'Gana 0.05 puntos/h para su dueno';
      case ZoneState.multiplier:
        return 'Duplica los puntos obtenidos';
      case ZoneState.forbidden:
        return 'Se elimina del mapa';
    }
  }
}

class Zone {
  final String id;
  final String ownerId;
  final String ownerName;
  final String name;
  final List<LatLng> points;
  final ZoneState state;
  final double pointsPerHour;
  final int laps;
  final double bestSpeedMetersPerSecond;

  Zone({
    required this.id,
    required this.ownerId,
    this.ownerName = '',
    required this.name,
    required this.points,
    required this.state,
    required this.pointsPerHour,
    this.laps = 0,
    this.bestSpeedMetersPerSecond = 0,
  });

  double get priorityScore {
    return bestSpeedMetersPerSecond + (laps * 0.35);
  }

  Color get fillColor {
    if (state == ZoneState.multiplier) {
      return const Color(0xFFE11931);
    }

    return state.color;
  }

  Zone copyWith({
    String? id,
    String? ownerId,
    String? ownerName,
    String? name,
    List<LatLng>? points,
    ZoneState? state,
    double? pointsPerHour,
    int? laps,
    double? bestSpeedMetersPerSecond,
  }) {
    final nextState = state ?? this.state;

    return Zone(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      name: name ?? this.name,
      points: points ?? this.points,
      state: nextState,
      pointsPerHour: pointsPerHour ?? nextState.defaultPointsPerHour,
      laps: laps ?? this.laps,
      bestSpeedMetersPerSecond:
          bestSpeedMetersPerSecond ?? this.bestSpeedMetersPerSecond,
    );
  }

  factory Zone.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    final parsedPoints = rawPoints is List
        ? rawPoints
              .whereType<Map>()
              .map(
                (point) => LatLng(
                  (point['lat'] as num?)?.toDouble() ?? 0,
                  (point['lng'] as num?)?.toDouble() ?? 0,
                ),
              )
              .toList()
        : <LatLng>[];
    final parsedState = ZoneState.values.firstWhere(
      (state) => state.name == json['state'],
      orElse: () => ZoneState.free,
    );

    return Zone(
      id: json['id']?.toString() ?? '',
      ownerId: json['ownerId']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      points: parsedPoints,
      state: parsedState,
      pointsPerHour:
          (json['pointsPerHour'] as num?)?.toDouble() ??
          parsedState.defaultPointsPerHour,
      laps: (json['laps'] as num?)?.toInt() ?? 0,
      bestSpeedMetersPerSecond:
          (json['bestSpeedMetersPerSecond'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'name': name,
      'points': [
        for (final point in points)
          {'lat': point.latitude, 'lng': point.longitude},
      ],
      'state': state.name,
      'pointsPerHour': pointsPerHour,
      'laps': laps,
      'bestSpeedMetersPerSecond': bestSpeedMetersPerSecond,
      'priorityScore': priorityScore,
    };
  }
}
