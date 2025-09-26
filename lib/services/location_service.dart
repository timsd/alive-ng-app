import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'storage_service.dart';
import 'analytics_service.dart';

class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();

  LocationService._();

  final StorageService _storage = StorageService.instance;
  final AnalyticsService _analytics = AnalyticsService.instance;

  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  Placemark? _currentPlacemark;

  // Location settings
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // Update every 10 meters
  );

  // Initialize location service
  Future<bool> initialize() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _analytics.trackError('Location services disabled');
        return false;
      }

      // Check and request permissions
      final hasPermission = await _checkAndRequestPermissions();
      if (!hasPermission) {
        await _analytics.trackError('Location permission denied');
        return false;
      }

      // Get initial position
      await getCurrentPosition();

      await _analytics.trackEvent('location_service_initialized');
      return true;
    } catch (e) {
      await _analytics.trackError('Location service initialization failed',
          context: e.toString());
      return false;
    }
  }

  // Check and request location permissions
  Future<bool> _checkAndRequestPermissions() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Permission check error: $e');
      return false;
    }
  }

  // Get current position
  Future<Position?> getCurrentPosition({bool forceRefresh = false}) async {
    try {
      if (_currentPosition != null && !forceRefresh) {
        return _currentPosition;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _currentPosition = position;

      // Store position locally
      await _storePosition(position);

      // Get address information
      await _updatePlacemark(position);

      await _analytics.trackEvent('location_updated', parameters: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
      });

      return position;
    } catch (e) {
      await _analytics.trackError('Failed to get current position',
          context: e.toString());
      return null;
    }
  }

  // Start location tracking
  Future<bool> startLocationTracking() async {
    try {
      if (_positionSubscription != null) {
        return true; // Already tracking
      }

      final hasPermission = await _checkAndRequestPermissions();
      if (!hasPermission) {
        return false;
      }

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: _locationSettings,
      ).listen(
        (Position position) {
          _currentPosition = position;
          _storePosition(position);
          _updatePlacemark(position);
        },
        onError: (error) {
          _analytics.trackError('Location tracking error',
              context: error.toString());
        },
      );

      await _analytics.trackEvent('location_tracking_started');
      return true;
    } catch (e) {
      await _analytics.trackError('Failed to start location tracking',
          context: e.toString());
      return false;
    }
  }

  // Stop location tracking
  Future<void> stopLocationTracking() async {
    _positionSubscription?.cancel();
    _positionSubscription = null;

    await _analytics.trackEvent('location_tracking_stopped');
  }

  // Store position locally
  Future<void> _storePosition(Position position) async {
    try {
      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'heading': position.heading,
        'speed': position.speed,
        'timestamp': position.timestamp.toIso8601String(),
      };

      await _storage.setJson(StorageKeys.lastKnownLocation, locationData);

      // Store in location history (keep last 100 locations)
      final historyData = await _storage.getJsonList('location_history');
      final List<Map<String, dynamic>> history = historyData ?? [];
      history.add(locationData);

      if (history.length > 100) {
        history.removeRange(0, history.length - 100);
      }

      await _storage.setJsonList('location_history', history);
    } catch (e) {
      debugPrint('Error storing position: $e');
    }
  }

  // Update placemark information
  Future<void> _updatePlacemark(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        _currentPlacemark = placemarks.first;

        final placemarkData = {
          'name': _currentPlacemark!.name,
          'street': _currentPlacemark!.street,
          'locality': _currentPlacemark!.locality,
          'administrativeArea': _currentPlacemark!.administrativeArea,
          'country': _currentPlacemark!.country,
          'postalCode': _currentPlacemark!.postalCode,
          'timestamp': DateTime.now().toIso8601String(),
        };

        await _storage.setJson('current_placemark', placemarkData);
      }
    } catch (e) {
      debugPrint('Error updating placemark: $e');
    }
  }

  // Get last known position
  Future<Position?> getLastKnownPosition() async {
    try {
      if (_currentPosition != null) {
        return _currentPosition;
      }

      final locationData =
          await _storage.getJson(StorageKeys.lastKnownLocation);
      if (locationData != null) {
        return Position(
          latitude: locationData['latitude'],
          longitude: locationData['longitude'],
          timestamp: DateTime.parse(locationData['timestamp']),
          accuracy: locationData['accuracy'],
          altitude: locationData['altitude'],
          altitudeAccuracy: locationData['altitudeAccuracy'] ?? 0.0,
          heading: locationData['heading'],
          headingAccuracy: locationData['headingAccuracy'] ?? 0.0,
          speed: locationData['speed'],
          speedAccuracy: 0,
        );
      }

      return null;
    } catch (e) {
      debugPrint('Error getting last known position: $e');
      return null;
    }
  }

  // Get current address
  Future<String?> getCurrentAddress() async {
    try {
      if (_currentPlacemark != null) {
        return _formatAddress(_currentPlacemark!);
      }

      final position = await getCurrentPosition();
      if (position != null) {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          _currentPlacemark = placemarks.first;
          return _formatAddress(_currentPlacemark!);
        }
      }

      return null;
    } catch (e) {
      await _analytics.trackError('Failed to get current address',
          context: e.toString());
      return null;
    }
  }

  // Format address from placemark
  String _formatAddress(Placemark placemark) {
    final parts = <String>[];

    if (placemark.street?.isNotEmpty == true) {
      parts.add(placemark.street!);
    }
    if (placemark.locality?.isNotEmpty == true) {
      parts.add(placemark.locality!);
    }
    if (placemark.administrativeArea?.isNotEmpty == true) {
      parts.add(placemark.administrativeArea!);
    }
    if (placemark.country?.isNotEmpty == true) {
      parts.add(placemark.country!);
    }

    return parts.join(', ');
  }

  // Calculate distance between two positions
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // Calculate bearing between two positions
  double calculateBearing(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.bearingBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // Find nearby churches
  Future<List<ChurchLocation>> findNearbyChurches({
    double radiusInKm = 10.0,
    int limit = 20,
  }) async {
    try {
      final position = await getCurrentPosition();
      if (position == null) {
        return [];
      }

      // This would typically call an API to find nearby churches
      // For now, return mock data
      final churches = <ChurchLocation>[];

      // In a real implementation, you would:
      // 1. Call a places API (Google Places, Foursquare, etc.)
      // 2. Query your own database of churches
      // 3. Use a third-party church directory API

      await _analytics.trackEvent('nearby_churches_searched', parameters: {
        'radius_km': radiusInKm,
        'limit': limit,
        'results_count': churches.length,
      });

      return churches;
    } catch (e) {
      await _analytics.trackError('Failed to find nearby churches',
          context: e.toString());
      return [];
    }
  }

  // Check if user is within a geofence
  Future<bool> isWithinGeofence(
    double centerLatitude,
    double centerLongitude,
    double radiusInMeters,
  ) async {
    try {
      final position = await getCurrentPosition();
      if (position == null) {
        return false;
      }

      final distance = calculateDistance(
        position.latitude,
        position.longitude,
        centerLatitude,
        centerLongitude,
      );

      return distance <= radiusInMeters;
    } catch (e) {
      debugPrint('Error checking geofence: $e');
      return false;
    }
  }

  // Get location history
  Future<List<Map<String, dynamic>>> getLocationHistory() async {
    try {
      final data = await _storage.getJsonList('location_history');
      return data ?? [];
    } catch (e) {
      debugPrint('Error getting location history: $e');
      return [];
    }
  }

  // Clear location history
  Future<void> clearLocationHistory() async {
    try {
      await _storage.remove('location_history');
      await _storage.remove(StorageKeys.lastKnownLocation);
      await _storage.remove('current_placemark');

      await _analytics.trackEvent('location_history_cleared');
    } catch (e) {
      debugPrint('Error clearing location history: $e');
    }
  }

  // Check location permission status
  Future<LocationPermissionStatus> getPermissionStatus() async {
    try {
      final permission = await Geolocator.checkPermission();

      switch (permission) {
        case LocationPermission.denied:
          return LocationPermissionStatus.denied;
        case LocationPermission.deniedForever:
          return LocationPermissionStatus.deniedForever;
        case LocationPermission.whileInUse:
          return LocationPermissionStatus.whileInUse;
        case LocationPermission.always:
          return LocationPermissionStatus.always;
        default:
          return LocationPermissionStatus.denied;
      }
    } catch (e) {
      debugPrint('Error checking permission status: $e');
      return LocationPermissionStatus.denied;
    }
  }

  // Open location settings
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('Error opening location settings: $e');
      return false;
    }
  }

  // Open app settings
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('Error opening app settings: $e');
      return false;
    }
  }

  // Get location accuracy
  LocationAccuracy get currentAccuracy {
    return _currentPosition?.accuracy != null
        ? _getAccuracyLevel(_currentPosition!.accuracy)
        : LocationAccuracy.lowest;
  }

  LocationAccuracy _getAccuracyLevel(double accuracy) {
    if (accuracy <= 5) return LocationAccuracy.best;
    if (accuracy <= 10) return LocationAccuracy.high;
    if (accuracy <= 100) return LocationAccuracy.medium;
    if (accuracy <= 1000) return LocationAccuracy.low;
    return LocationAccuracy.lowest;
  }

  // Dispose resources
  void dispose() {
    stopLocationTracking();
  }
}

// Church Location model
class ChurchLocation {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? phone;
  final String? website;
  final String? denomination;
  final double? rating;
  final List<String>? services;
  final Map<String, String>? hours;

  ChurchLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phone,
    this.website,
    this.denomination,
    this.rating,
    this.services,
    this.hours,
  });

  factory ChurchLocation.fromJson(Map<String, dynamic> json) {
    return ChurchLocation(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      phone: json['phone'],
      website: json['website'],
      denomination: json['denomination'],
      rating: json['rating']?.toDouble(),
      services: json['services']?.cast<String>(),
      hours: json['hours']?.cast<String, String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'website': website,
      'denomination': denomination,
      'rating': rating,
      'services': services,
      'hours': hours,
    };
  }
}

// Location Permission Status
enum LocationPermissionStatus {
  denied,
  deniedForever,
  whileInUse,
  always,
}

// Location State
class LocationState {
  final Position? position;
  final Placemark? placemark;
  final LocationPermissionStatus permissionStatus;
  final bool isTracking;
  final String? error;

  LocationState({
    this.position,
    this.placemark,
    required this.permissionStatus,
    required this.isTracking,
    this.error,
  });

  LocationState copyWith({
    Position? position,
    Placemark? placemark,
    LocationPermissionStatus? permissionStatus,
    bool? isTracking,
    String? error,
  }) {
    return LocationState(
      position: position ?? this.position,
      placemark: placemark ?? this.placemark,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      isTracking: isTracking ?? this.isTracking,
      error: error ?? this.error,
    );
  }
}

// Riverpod providers
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService.instance;
});

final currentPositionProvider = FutureProvider<Position?>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  return await locationService.getCurrentPosition();
});

final currentAddressProvider = FutureProvider<String?>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  return await locationService.getCurrentAddress();
});

final locationPermissionProvider =
    FutureProvider<LocationPermissionStatus>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  return await locationService.getPermissionStatus();
});

final nearbyChurchesProvider =
    FutureProvider.family<List<ChurchLocation>, double>((ref, radius) async {
  final locationService = ref.read(locationServiceProvider);
  return await locationService.findNearbyChurches(radiusInKm: radius);
});

final locationHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  return await locationService.getLocationHistory();
});




