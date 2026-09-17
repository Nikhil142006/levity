import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class SessionState {
  final bool isTracking;
  final String activityType;
  final double goalDistanceKm;
  final double currentDistanceKm;
  final List<LatLng> path;
  final bool turnaroundNotified;
  final LatLng? turnaroundLocation;

  SessionState({
    this.isTracking = false,
    this.activityType = 'Walking',
    this.goalDistanceKm = 0.0,
    this.currentDistanceKm = 0.0,
    this.path = const [],
    this.turnaroundNotified = false,
    this.turnaroundLocation,
  });

  SessionState copyWith({
    bool? isTracking,
    String? activityType,
    double? goalDistanceKm,
    double? currentDistanceKm,
    List<LatLng>? path,
    bool? turnaroundNotified,
    LatLng? turnaroundLocation,
  }) {
    return SessionState(
      isTracking: isTracking ?? this.isTracking,
      activityType: activityType ?? this.activityType,
      goalDistanceKm: goalDistanceKm ?? this.goalDistanceKm,
      currentDistanceKm: currentDistanceKm ?? this.currentDistanceKm,
      path: path ?? this.path,
      turnaroundNotified: turnaroundNotified ?? this.turnaroundNotified,
      turnaroundLocation: turnaroundLocation ?? this.turnaroundLocation,
    );
  }
}

class LocationNotifier extends Notifier<SessionState> {
  StreamSubscription<Position>? _positionStream;

  @override
  SessionState build() {
    ref.onDispose(() {
      _positionStream?.cancel();
    });
    return SessionState();
  }

  Future<bool> _handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
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
  }

  Future<void> startSession(String activityType, double goalKm) async {
    final hasPermission = await _handlePermission();
    if (!hasPermission) {
      throw Exception('Location permission denied');
    }

    state = state.copyWith(
      isTracking: true,
      activityType: activityType,
      goalDistanceKm: goalKm,
      currentDistanceKm: 0.0,
      path: [],
      turnaroundNotified: false,
    );

    // Get initial position
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      state = state.copyWith(path: [LatLng(position.latitude, position.longitude)]);
    } catch (e) {
      // Ignore initial position failure, stream will catch up
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1, // Update every 1 meter
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      final newPoint = LatLng(position.latitude, position.longitude);
      final currentPath = List<LatLng>.from(state.path);
      
      double newDistance = state.currentDistanceKm;
      if (currentPath.isNotEmpty) {
        final lastPoint = currentPath.last;
        final distanceMeters = Geolocator.distanceBetween(
          lastPoint.latitude, lastPoint.longitude,
          newPoint.latitude, newPoint.longitude
        );
        newDistance += (distanceMeters / 1000.0);
      }
      
      currentPath.add(newPoint);

      // Check turnaround (50% of goal)
      bool shouldNotify = state.turnaroundNotified;
      if (!shouldNotify && state.goalDistanceKm > 0 && newDistance >= (state.goalDistanceKm / 2)) {
        shouldNotify = true;
      }

      state = state.copyWith(
        path: currentPath,
        currentDistanceKm: newDistance,
        turnaroundNotified: shouldNotify,
        turnaroundLocation: (shouldNotify && state.turnaroundLocation == null) 
            ? LatLng(position.latitude, position.longitude) 
            : state.turnaroundLocation,
      );
    });
  }

  void stopSession() {
    _positionStream?.cancel();
    state = state.copyWith(isTracking: false);
  }
}

final locationSessionProvider = NotifierProvider<LocationNotifier, SessionState>(() {
  return LocationNotifier();
});
