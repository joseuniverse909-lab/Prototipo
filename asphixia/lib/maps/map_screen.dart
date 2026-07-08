import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:latlong2/latlong.dart';

import '../models/game_event.dart';
import '../models/zone_model.dart';
import '../screens/account_settings_screen.dart';
import '../screens/admin_panel_screen.dart';
import '../screens/activity_screen.dart';
import '../screens/clans_screen.dart';
import '../screens/photo_report_screen.dart';
import '../screens/points_screen.dart';
import '../screens/reward_screen.dart';
import '../services/admin_service.dart';
import '../services/game_state_service.dart';
import '../services/gps_service.dart';
import '../services/zone_priority_service.dart';
import '../zones/zone_polygon.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _currentPosition;
  String? _locationError;
  ZoneState _newZoneState = ZoneState.free;
  int _selectedTab = 0;
  bool _isDrawingZone = false;
  bool _isRecordingPerimeter = false;
  final List<LatLng> _draftPoints = [];
  final List<LatLng> _routePoints = [];
  final Set<String> _claimedThisSession = {};
  double _routeDistanceMeters = 0;
  String? _activeClaimZoneId;
  StreamSubscription? _perimeterSubscription;
  StreamSubscription? _liveLocationSubscription;

  static const List<ZoneState> _paintableStates = [
    ZoneState.free,
    ZoneState.claimed,
    ZoneState.multiplier,
  ];

  User? get _user => FirebaseAuth.instance.currentUser;
  bool get _isAdmin => AdminService.isAdmin(_user);

  @override
  void initState() {
    super.initState();
    _loadLocation();
    _startLiveLocation();
  }

  @override
  void dispose() {
    _perimeterSubscription?.cancel();
    _liveLocationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    try {
      final pos = await GpsService.getCurrentLocation();
      if (!mounted) return;

      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
        _locationError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _locationError = error.toString();
        _currentPosition = const LatLng(-33.4489, -70.6693);
      });
    }
  }

  Future<void> _startLiveLocation() async {
    try {
      await GpsService.getCurrentLocation();
      _liveLocationSubscription = GpsService.getPositionStream().listen(
        _handleLivePosition,
        onError: (Object error) {
          if (!mounted) return;
          setState(() => _locationError = error.toString());
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _locationError = error.toString());
    }
  }

  void _handleLivePosition(Position position) {
    final next = LatLng(position.latitude, position.longitude);
    final previous = _currentPosition;

    if (previous != null) {
      final segment = GpsService.calculateDistance(
        previous.latitude,
        previous.longitude,
        next.latitude,
        next.longitude,
      );
      if (segment < 120) _routeDistanceMeters += segment;
    }

    _routePoints.add(next);
    if (_routePoints.length > 400) _routePoints.removeAt(0);
    _checkZoneClaim(next);

    if (!mounted) return;
    setState(() {
      _currentPosition = next;
      _locationError = null;
    });
  }

  void _checkZoneClaim(LatLng position) {
    final candidateZones = GameStateService.zones.value.where(
      (zone) =>
          zone.points.length >= 3 &&
          zone.state != ZoneState.forbidden &&
          zone.ownerId != GameStateService.currentUserId &&
          !_claimedThisSession.contains(zone.id) &&
          _isPointInsidePolygon(position, zone.points),
    );
    final zone = candidateZones.isEmpty ? null : candidateZones.first;

    if (zone == null) {
      _activeClaimZoneId = null;
      _routeDistanceMeters = 0;
      _routePoints.clear();
      return;
    }

    if (_activeClaimZoneId != zone.id) {
      _activeClaimZoneId = zone.id;
      _routeDistanceMeters = 0;
      _routePoints
        ..clear()
        ..add(position);
      return;
    }

    final perimeter = _polygonPerimeter(zone.points);
    if (perimeter <= 0 || _routeDistanceMeters < perimeter * 0.85) return;

    final start = _routePoints.first;
    final closedLoopDistance = GpsService.calculateDistance(
      start.latitude,
      start.longitude,
      position.latitude,
      position.longitude,
    );
    if (closedLoopDistance > 30) return;

    final elapsedSeconds = _routePoints.length * 2;
    final speed = elapsedSeconds == 0
        ? 0.0
        : _routeDistanceMeters / elapsedSeconds;
    _claimedThisSession.add(zone.id);
    GameStateService.claimZone(zone, speedMetersPerSecond: speed);
  }

  bool _isPointInsidePolygon(LatLng point, List<LatLng> polygon) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;
      final intersects =
          ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) *
                      (point.latitude - yi) /
                      ((yj - yi).abs() < 0.000001 ? 0.000001 : yj - yi) +
                  xi);
      if (intersects) inside = !inside;
    }
    return inside;
  }

  double _polygonPerimeter(List<LatLng> points) {
    var meters = 0.0;
    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];
      meters += GpsService.calculateDistance(
        current.latitude,
        current.longitude,
        next.latitude,
        next.longitude,
      );
    }
    return meters;
  }

  void _addDraftPoint(LatLng latlng) {
    if (!_isAdmin) return;
    setState(() => _draftPoints.add(latlng));
  }

  void _finishDraftZone() {
    if (!_isAdmin || _draftPoints.length < 3) return;

    final ownerId = _newZoneState == ZoneState.claimed
        ? _user?.uid ?? 'local-user'
        : '';
    final ownerName = _newZoneState == ZoneState.claimed
        ? _user?.displayName ?? _user?.email ?? 'Jugador'
        : '';
    final speed = 2.5 + (GameStateService.zones.value.length * 0.2);
    final laps = GameStateService.zones.value.length % 4;
    final zoneCount = GameStateService.zones.value.length + 1;

    GameStateService.saveZone(
      Zone(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ownerId: ownerId,
        ownerName: ownerName,
        name: '${_newZoneState.label} $zoneCount',
        points: List.of(_draftPoints),
        state: _newZoneState,
        pointsPerHour: _newZoneState.defaultPointsPerHour,
        laps: laps,
        bestSpeedMetersPerSecond: speed,
      ),
    );

    setState(() {
      _draftPoints.clear();
      _isDrawingZone = false;
      _isRecordingPerimeter = false;
    });
  }

  void _cycleLastZoneState() {
    final zones = GameStateService.zones.value;
    if (!_isAdmin || zones.isEmpty) return;

    final zone = zones.last;
    const states = _paintableStates;
    final nextState = states[(states.indexOf(zone.state) + 1) % states.length];

    GameStateService.saveZone(
      zone.copyWith(
        name: '${nextState.label} ${zones.length}',
        state: nextState,
        ownerId: nextState == ZoneState.claimed ? _user?.uid : '',
        ownerName: nextState == ZoneState.claimed
            ? _user?.displayName ?? _user?.email ?? 'Jugador'
            : '',
      ),
    );
  }

  void _deleteLastZone() {
    final zones = GameStateService.zones.value;
    if (!_isAdmin || zones.isEmpty) return;
    GameStateService.deleteZone(zones.last.id);
  }

  void _saveEvent(GameEvent event) {
    GameStateService.saveEvent(event);
  }

  void _deleteEvent(String eventId) {
    GameStateService.deleteEvent(eventId);
  }

  void _changeZoneState(String zoneId, ZoneState state) {
    final zones = GameStateService.zones.value;
    final index = zones.indexWhere((zone) => zone.id == zoneId);
    if (index == -1) return;

    if (state == ZoneState.forbidden) {
      GameStateService.deleteZone(zoneId);
      return;
    }

    GameStateService.saveZone(
      zones[index].copyWith(
        state: state,
        ownerId: state == ZoneState.claimed ? _user?.uid : '',
        ownerName: state == ZoneState.claimed
            ? _user?.displayName ?? _user?.email ?? 'Jugador'
            : '',
      ),
    );
  }

  void _simulateZoneChallenge() {
    final zones = GameStateService.zones.value;
    if (!_isAdmin || zones.isEmpty) return;

    final zone = zones.last;
    final challengerSpeed = zone.bestSpeedMetersPerSecond + 0.45;
    final challengerLaps = zone.laps + 1;
    final wins = ZonePriorityService.challengerWins(
      currentBestSpeed: zone.bestSpeedMetersPerSecond,
      currentLaps: zone.laps,
      challengerSpeed: challengerSpeed,
      challengerLaps: challengerLaps,
    );

    if (!wins) return;

    GameStateService.saveZone(
      zone.copyWith(
        ownerId: _user?.uid ?? 'local-user',
        ownerName: _user?.displayName ?? _user?.email ?? 'Jugador',
        state: ZoneState.claimed,
        laps: challengerLaps,
        bestSpeedMetersPerSecond: challengerSpeed,
      ),
    );
  }

  void _toggleDrawing() {
    if (!_isAdmin) return;
    setState(() {
      _isDrawingZone = !_isDrawingZone;
      _isRecordingPerimeter = false;
      if (!_isDrawingZone) _draftPoints.clear();
    });
  }

  Future<void> _togglePerimeterRecording() async {
    if (!_isAdmin) return;

    if (_isRecordingPerimeter) {
      await _perimeterSubscription?.cancel();
      _perimeterSubscription = null;
      setState(() => _isRecordingPerimeter = false);
      return;
    }

    setState(() {
      _draftPoints.clear();
      _isDrawingZone = false;
      _isRecordingPerimeter = true;
    });

    _perimeterSubscription = GpsService.getPositionStream().listen((position) {
      if (!mounted) return;
      setState(() {
        _draftPoints.add(LatLng(position.latitude, position.longitude));
      });
    });
  }

  Future<void> _openAdminPanel() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminPanelScreen(
          events: GameStateService.events.value,
          zones: GameStateService.zones.value,
          onSaveEvent: _saveEvent,
          onDeleteEvent: _deleteEvent,
          onZoneStateChanged: _changeZoneState,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    GameStateService.resetSession();
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildMapPage(),
      const ClansScreen(),
      const ActivityScreen(),
      const PointsScreen(),
      const RewardScreen(),
      const PhotoReportScreen(),
      const AccountSettingsScreen(),
      if (_isAdmin)
        AdminPanelScreen(
          events: GameStateService.events.value,
          zones: GameStateService.zones.value,
          onSaveEvent: _saveEvent,
          onDeleteEvent: _deleteEvent,
          onZoneStateChanged: _changeZoneState,
        ),
    ];

    final titles = [
      'Aphixia',
      'Clanes',
      'Actividad',
      'Puntos',
      'Recompensas',
      'Fotos',
      'Cuenta',
      if (_isAdmin) 'Admin',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedTab]),
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: 'Panel admin',
              onPressed: _openAdminPanel,
              icon: const Icon(Icons.admin_panel_settings),
            ),
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedTab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.map), label: 'Mapa'),
          const NavigationDestination(
            icon: Icon(Icons.shield),
            label: 'Clanes',
          ),
          const NavigationDestination(
            icon: Icon(Icons.directions_run),
            label: 'Actividad',
          ),
          const NavigationDestination(icon: Icon(Icons.stars), label: 'Puntos'),
          const NavigationDestination(
            icon: Icon(Icons.card_giftcard),
            label: 'Premios',
          ),
          const NavigationDestination(
            icon: Icon(Icons.photo_camera),
            label: 'Fotos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Cuenta',
          ),
          if (_isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings),
              label: 'Admin',
            ),
        ],
      ),
      floatingActionButton: _selectedTab == 0 && _isAdmin
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'draw',
                  tooltip: 'Dibujar zona',
                  onPressed: _toggleDrawing,
                  child: Icon(_isDrawingZone ? Icons.close : Icons.polyline),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'record',
                  tooltip: 'Recorrer perimetro',
                  onPressed: _togglePerimeterRecording,
                  child: Icon(
                    _isRecordingPerimeter ? Icons.pause : Icons.route,
                  ),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'finish',
                  tooltip: 'Guardar perimetro',
                  onPressed: _draftPoints.length >= 3 ? _finishDraftZone : null,
                  child: const Icon(Icons.check),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'challenge',
                  tooltip: 'Simular prioridad',
                  onPressed: _simulateZoneChallenge,
                  child: const Icon(Icons.speed),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'edit',
                  tooltip: 'Cambiar estado',
                  onPressed: _cycleLastZoneState,
                  child: const Icon(Icons.palette),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'delete',
                  tooltip: 'Eliminar zona',
                  onPressed: _deleteLastZone,
                  child: const Icon(Icons.delete),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildMapPage() {
    final center = _currentPosition;

    return center == null
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              ValueListenableBuilder<List<Zone>>(
                valueListenable: GameStateService.zones,
                builder: (context, zones, _) {
                  return FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 15,
                      onTap: (tapPosition, latlng) {
                        if (_isDrawingZone) _addDraftPoint(latlng);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.asphixia',
                      ),
                      for (final zone in zones) ZonePolygon(zone: zone),
                      if (_draftPoints.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _draftPoints,
                              color: Colors.cyanAccent,
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                      if (_routePoints.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              color: Colors.lightBlueAccent,
                              strokeWidth: 3,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: center,
                            width: 60,
                            height: 60,
                            child: const Icon(
                              Icons.person_pin_circle,
                              color: Colors.blue,
                              size: 40,
                            ),
                          ),
                          for (var i = 0; i < _draftPoints.length; i++)
                            Marker(
                              point: _draftPoints[i],
                              width: 34,
                              height: 34,
                              child: CircleAvatar(
                                backgroundColor: Colors.cyanAccent,
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: ValueListenableBuilder<List<GameEvent>>(
                  valueListenable: GameStateService.events,
                  builder: (context, events, _) => _MapStatusPanel(
                    events: events,
                    selectedState: _newZoneState,
                    draftPoints: _draftPoints.length,
                    isDrawingZone: _isDrawingZone,
                    isRecordingPerimeter: _isRecordingPerimeter,
                    onStateChanged: _isAdmin
                        ? (state) => setState(() => _newZoneState = state)
                        : null,
                  ),
                ),
              ),
              if (_locationError != null)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Material(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _locationError!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          );
  }
}

class _MapStatusPanel extends StatelessWidget {
  final List<GameEvent> events;
  final ZoneState selectedState;
  final int draftPoints;
  final bool isDrawingZone;
  final bool isRecordingPerimeter;
  final ValueChanged<ZoneState>? onStateChanged;

  const _MapStatusPanel({
    required this.events,
    required this.selectedState,
    required this.draftPoints,
    required this.isDrawingZone,
    required this.isRecordingPerimeter,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final runningEvents = events.where((event) => event.isRunning).toList();

    return Material(
      color: Colors.black.withAlpha(210),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final state in ZoneState.values) _LegendItem(state: state),
              ],
            ),
            if (onStateChanged != null) ...[
              const SizedBox(height: 10),
              Text(
                isRecordingPerimeter
                    ? 'Grabando recorrido: $draftPoints puntos'
                    : isDrawingZone
                    ? 'Dibujo manual: toca el mapa para agregar vertices ($draftPoints)'
                    : 'Elige estado y activa dibujo o recorrido',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final state in _MapScreenState._paintableStates)
                    ChoiceChip(
                      selected: selectedState == state,
                      label: Text(state.label),
                      avatar: CircleAvatar(backgroundColor: state.color),
                      onSelected: (_) => onStateChanged?.call(state),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text(
              runningEvents.isEmpty
                  ? 'Sin eventos activos'
                  : 'Evento activo: ${runningEvents.first.name} (+${runningEvents.first.bonusPoints})',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final ZoneState state;

  const _LegendItem({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: state.color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Colors.white30),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          state.label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}
