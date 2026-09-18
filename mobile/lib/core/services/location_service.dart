import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationMode {
  hardware,
  simulation,
}

class PositionData {
  final double latitude;
  final double longitude;
  final double altitude;
  final double speedKmh;
  final double headingDeg;
  final double accuracyMeters;
  final DateTime timestamp;

  const PositionData({
    required this.latitude,
    required this.longitude,
    this.altitude = 0.0,
    this.speedKmh = 0.0,
    this.headingDeg = 0.0,
    this.accuracyMeters = 5.0,
    required this.timestamp,
  });

  LatLng get toLatLng => LatLng(latitude, longitude);

  @override
  String toString() =>
      'PositionData(lat: ${latitude.toStringAsFixed(4)}, lng: ${longitude.toStringAsFixed(4)}, speed: ${speedKmh.toStringAsFixed(1)} km/h, hdg: ${headingDeg.toStringAsFixed(0)}°)';
}

/// Simulated Waypoint Coordinates along "Skyline Summit" (matching stitch mockups)
final List<LatLng> kSimulationRoute = [
  const LatLng(37.7680, -122.4280),
  const LatLng(37.7705, -122.4255),
  const LatLng(37.7730, -122.4225),
  const LatLng(37.7749, -122.4194),
  const LatLng(37.7780, -122.4150),
  const LatLng(37.7815, -122.4110),
  const LatLng(37.7850, -122.4070),
];

abstract class ILocationEngine {
  Stream<PositionData> get positionStream;
  Future<bool> initialize();
  void dispose();
}

class HardwareLocationEngine implements ILocationEngine {
  final StreamController<PositionData> _controller = StreamController<PositionData>.broadcast();
  StreamSubscription<Position>? _sub;

  @override
  Stream<PositionData> get positionStream => _controller.stream;

  @override
  Future<bool> initialize() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Location services disabled on device.');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Location permissions denied.');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Location permissions denied forever.');
        return false;
      }

      // Immediately emit last known position if available for instantaneous fix
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          final speedKmh = (lastPos.speed.clamp(0.0, 300.0) * 3.6);
          _controller.add(
            PositionData(
              latitude: lastPos.latitude,
              longitude: lastPos.longitude,
              altitude: lastPos.altitude,
              speedKmh: speedKmh,
              headingDeg: lastPos.heading,
              accuracyMeters: lastPos.accuracy,
              timestamp: lastPos.timestamp,
            ),
          );
        }
      } catch (_) {}

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2, // 2 meters movement delta
      );

      _sub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position pos) {
          final speedKmh = (pos.speed.clamp(0.0, 300.0) * 3.6);
          _controller.add(
            PositionData(
              latitude: pos.latitude,
              longitude: pos.longitude,
              altitude: pos.altitude,
              speedKmh: speedKmh,
              headingDeg: pos.heading,
              accuracyMeters: pos.accuracy,
              timestamp: pos.timestamp,
            ),
          );
        },
        onError: (err) {
          debugPrint('[LocationService] GPS stream error: $err');
        },
      );

      return true;
    } catch (e) {
      debugPrint('[LocationService] Hardware init exception: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}

class SimulationLocationEngine implements ILocationEngine {
  final StreamController<PositionData> _controller = StreamController<PositionData>.broadcast();
  Timer? _ticker;
  double _progress = 0.5;

  @override
  Stream<PositionData> get positionStream => _controller.stream;

  @override
  Future<bool> initialize() async {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      _progress = (_progress + 0.005) % 1.0;
      final latLng = _interpolatePosition(_progress);
      _controller.add(
        PositionData(
          latitude: latLng.latitude,
          longitude: latLng.longitude,
          altitude: 312.0,
          speedKmh: 78.0,
          headingDeg: 42.0,
          accuracyMeters: 3.0,
          timestamp: DateTime.now(),
        ),
      );
    });
    return true;
  }

  LatLng _interpolatePosition(double t) {
    if (kSimulationRoute.isEmpty) return const LatLng(37.7749, -122.4194);
    final totalSegments = kSimulationRoute.length - 1;
    final scaled = t * totalSegments;
    final index = scaled.floor().clamp(0, totalSegments - 1);
    final fraction = scaled - index;

    final p1 = kSimulationRoute[index];
    final p2 = kSimulationRoute[index + 1];

    final lat = p1.latitude + (p2.latitude - p1.latitude) * fraction;
    final lng = p1.longitude + (p2.longitude - p1.longitude) * fraction;
    return LatLng(lat, lng);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.close();
  }
}

class LocationService {
  LocationMode _mode;
  ILocationEngine _engine;
  final StreamController<PositionData> _unifiedController = StreamController<PositionData>.broadcast();
  StreamSubscription<PositionData>? _engineSub;
  PositionData? _lastPosition;

  LocationService({LocationMode initialMode = LocationMode.hardware})
      : _mode = initialMode,
        _engine = initialMode == LocationMode.hardware
            ? HardwareLocationEngine()
            : SimulationLocationEngine() {
    _startCurrentEngine();
  }

  LocationMode get mode => _mode;
  Stream<PositionData> get positionStream => _unifiedController.stream;
  PositionData? get currentPosition => _lastPosition;

  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  Future<void> setMode(LocationMode newMode) async {
    if (_mode == newMode) return;
    _mode = newMode;
    await _switchEngine(newMode == LocationMode.hardware
        ? HardwareLocationEngine()
        : SimulationLocationEngine());
  }

  Future<void> _switchEngine(ILocationEngine newEngine) async {
    await _engineSub?.cancel();
    _engine.dispose();
    _engine = newEngine;
    await _startCurrentEngine();
  }

  Future<void> _startCurrentEngine() async {
    final success = await _engine.initialize();
    if (!success && _mode == LocationMode.hardware) {
      debugPrint('[LocationService] Hardware GPS unavailable, falling back to Simulation mode.');
      _mode = LocationMode.simulation;
      _engine = SimulationLocationEngine();
      await _engine.initialize();
    }

    _engineSub = _engine.positionStream.listen((data) {
      _lastPosition = data;
      _unifiedController.add(data);
    });
  }

  void dispose() {
    _engineSub?.cancel();
    _engine.dispose();
    _unifiedController.close();
  }
}
