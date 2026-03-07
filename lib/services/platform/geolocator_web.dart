import 'dart:async';

enum LocationAccuracy { low, medium, high }
enum LocationPermission { denied, deniedForever, whileInUse, always }

class Position {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;
  final double altitude;
  final double heading;
  final double speed;
  final double altitudeAccuracy;
  final double headingAccuracy;
  final double speedAccuracy;
  Position({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
    required this.altitude,
    required this.heading,
    required this.speed,
    this.altitudeAccuracy = 0.0,
    this.headingAccuracy = 0.0,
    this.speedAccuracy = 0.0,
  });
}

class LocationSettings {
  final LocationAccuracy accuracy;
  final int? distanceFilter;
  const LocationSettings({this.accuracy = LocationAccuracy.medium, this.distanceFilter});
}

class Geolocator {
  static Future<bool> isLocationServiceEnabled() async {
    return false;
  }
  static Future<LocationPermission> checkPermission() async {
    return LocationPermission.denied;
  }
  static Future<LocationPermission> requestPermission() async {
    return LocationPermission.denied;
  }
  static Future<Position> getCurrentPosition() async {
    throw StateError('Not supported on web');
  }
  static Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    return const Stream.empty();
  }
}
