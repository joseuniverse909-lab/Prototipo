import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/gps_service.dart';

enum ActivityMode { walk, jog, run }

extension ActivityModeInfo on ActivityMode {
  String get label {
    switch (this) {
      case ActivityMode.walk:
        return 'Caminata';
      case ActivityMode.jog:
        return 'Trote';
      case ActivityMode.run:
        return 'Carrera';
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityMode.walk:
        return Icons.directions_walk;
      case ActivityMode.jog:
        return Icons.directions_run;
      case ActivityMode.run:
        return Icons.speed;
    }
  }
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  ActivityMode _mode = ActivityMode.walk;
  bool _isActive = false;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _timer;
  Position? _lastPosition;
  double _distanceMeters = 0;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  String? _error;

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _toggleActivity() async {
    if (_isActive) {
      await _positionSubscription?.cancel();
      _timer?.cancel();
      setState(() => _isActive = false);
      return;
    }

    setState(() {
      _isActive = true;
      _distanceMeters = 0;
      _elapsed = Duration.zero;
      _startedAt = DateTime.now();
      _lastPosition = null;
      _error = null;
    });

    try {
      await GpsService.getCurrentLocation();
      _positionSubscription = GpsService.getPositionStream().listen(
        _onPosition,
        onError: (Object error) {
          if (mounted) setState(() => _error = error.toString());
        },
      );
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _startedAt == null) return;
        setState(() => _elapsed = DateTime.now().difference(_startedAt!));
      });
    } catch (error) {
      setState(() {
        _isActive = false;
        _error = error.toString();
      });
    }
  }

  void _onPosition(Position position) {
    final last = _lastPosition;
    if (last != null) {
      final segment = GpsService.calculateDistance(
        last.latitude,
        last.longitude,
        position.latitude,
        position.longitude,
      );
      if (segment < 120) _distanceMeters += segment;
    }
    _lastPosition = position;
    if (mounted) setState(() {});
  }

  String get _distanceLabel =>
      '${(_distanceMeters / 1000).toStringAsFixed(2)} km';

  String get _paceLabel {
    if (_distanceMeters < 1 || _elapsed.inSeconds == 0) return '--:--';
    final secondsPerKm = _elapsed.inSeconds / (_distanceMeters / 1000);
    final minutes = secondsPerKm ~/ 60;
    final seconds = (secondsPerKm % 60).round().toString().padLeft(2, '0');
    return '$minutes:$seconds/km';
  }

  String get _timeLabel {
    final minutes = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  int get _points => (_distanceMeters / 100).floor();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF111820),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              Icon(_mode.icon, size: 72, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                _mode.label,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isActive ? 'Actividad en curso' : 'Listo para empezar',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              SegmentedButton<ActivityMode>(
                segments: ActivityMode.values
                    .map(
                      (mode) => ButtonSegment(
                        value: mode,
                        icon: Icon(mode.icon),
                        label: Text(mode.label),
                      ),
                    )
                    .toList(),
                selected: {_mode},
                onSelectionChanged: (selected) {
                  setState(() => _mode = selected.first);
                },
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _toggleActivity,
                icon: Icon(_isActive ? Icons.stop : Icons.play_arrow),
                label: Text(_isActive ? 'Detener' : 'Empezar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricTile(label: 'Distancia', value: _distanceLabel),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(label: 'Ritmo', value: _paceLabel),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricTile(label: 'Tiempo', value: _timeLabel),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(label: 'Puntos', value: '$_points'),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A222E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
