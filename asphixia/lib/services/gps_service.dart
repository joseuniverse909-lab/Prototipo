import 'package:geolocator/geolocator.dart';

class GpsService {
  static Future<Position> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('El GPS esta desactivado.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Permiso de ubicacion denegado.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicacion denegado permanentemente.');
    }

    final accuracyStatus = await Geolocator.getLocationAccuracy();
    if (accuracyStatus == LocationAccuracyStatus.reduced) {
      throw Exception(
        'Activa la ubicacion precisa para claimear zonas y registrar actividad.',
      );
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
  }

  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    );
  }

  static double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  static double calculateSpeed(Position start, Position end) {
    final distance = calculateDistance(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
    final time = end.timestamp.difference(start.timestamp).inSeconds.toDouble();
    return time > 0 ? distance / time : 0;
  }
}
