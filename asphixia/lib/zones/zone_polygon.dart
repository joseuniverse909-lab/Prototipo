import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/zone_model.dart';

class ZonePolygon extends StatelessWidget {
  final Zone zone;

  const ZonePolygon({super.key, required this.zone});

  @override
  Widget build(BuildContext context) {
    final borderColor = switch (zone.state) {
      ZoneState.claimed => Colors.greenAccent,
      ZoneState.multiplier => Colors.redAccent,
      ZoneState.free => Colors.black54,
      ZoneState.forbidden => Colors.white24,
    };

    return PolygonLayer(
      polygons: [
        Polygon(
          points: zone.points,
          color: zone.fillColor.withAlpha(220),
          borderColor: borderColor,
          borderStrokeWidth: 4,
        ),
      ],
    );
  }
}
