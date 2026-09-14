import 'dart:async';
import 'package:latlong2/latlong.dart';
import '../../../core/config/client_config.dart';
import '../models/convoy_peer.dart';
import '../models/telemetry_packet.dart';

/// Simulated Waypoint Coordinates along "Skyline Summit" (matching mockups)
final List<LatLng> kSkylineSummitRoute = [
  const LatLng(37.7680, -122.4280),
  const LatLng(37.7705, -122.4255),
  const LatLng(37.7730, -122.4225),
  const LatLng(37.7749, -122.4194), // Center checkpoint
  const LatLng(37.7780, -122.4150),
  const LatLng(37.7815, -122.4110),
  const LatLng(37.7850, -122.4070),
];

class IotTelemetryService {
  final ClientConfig config;
  bool _isBroadcasting = true;
  Timer? _telemetryTicker;

  final _telemetryController = StreamController<List<ConvoyPeer>>.broadcast();
  Stream<List<ConvoyPeer>> get convoyStream => _telemetryController.stream;

  bool get isBroadcasting => _isBroadcasting;

  // Base simulation state
  double _progress = 0.5; // Starts near center checkpoint
  final double _speedKmh = 78.0;
  final double _headingDeg = 42.0;

  IotTelemetryService({required this.config}) {
    startSimulation();
  }

  void setBroadcasting(bool value) {
    _isBroadcasting = value;
    if (_isBroadcasting) {
      startSimulation();
    } else {
      _telemetryTicker?.cancel();
    }
  }

  void startSimulation() {
    _telemetryTicker?.cancel();
    _telemetryTicker = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!_isBroadcasting) return;

      _progress = (_progress + 0.005) % 1.0;
      final currentPos = _interpolatePosition(_progress);
      final viperPos = _interpolatePosition((_progress + 0.015) % 1.0);
      final ghostPos = _interpolatePosition((_progress - 0.012 + 1.0) % 1.0);

      final peers = [
        // 1. Leader (Apex - Flagship Pilot)
        ConvoyPeer(
          callsign: 'Leader: Apex',
          latitude: currentPos.latitude,
          longitude: currentPos.longitude,
          altitude: 312.0,
          speedKmh: _speedKmh,
          headingDeg: _headingDeg,
          relativeOffsetMeters: 0,
          isLeader: true,
          beaconColorHex: '#0066FF',
          monikerTag: 'HQ',
        ),

        // 2. Peer 1: Viper (+120m ahead)
        ConvoyPeer(
          callsign: 'Viper',
          latitude: viperPos.latitude,
          longitude: viperPos.longitude,
          altitude: 315.0,
          speedKmh: 72.0,
          headingDeg: 38.0,
          relativeOffsetMeters: 120.0,
          isLeader: false,
          beaconColorHex: '#00C48C',
          monikerTag: '+120m',
        ),

        // 3. Peer 2: Ghost (-85m trailing)
        ConvoyPeer(
          callsign: 'Ghost',
          latitude: ghostPos.latitude,
          longitude: ghostPos.longitude,
          altitude: 308.0,
          speedKmh: 68.0,
          headingDeg: 45.0,
          relativeOffsetMeters: -85.0,
          isLeader: false,
          beaconColorHex: '#FF9500',
          monikerTag: '-85m',
        ),
      ];

      _telemetryController.add(peers);
    });
  }

  /// Linear interpolation between waypoints along route
  LatLng _interpolatePosition(double t) {
    if (kSkylineSummitRoute.isEmpty) return const LatLng(37.7749, -122.4194);
    final totalSegments = kSkylineSummitRoute.length - 1;
    final scaled = t * totalSegments;
    final index = scaled.floor().clamp(0, totalSegments - 1);
    final fraction = scaled - index;

    final p1 = kSkylineSummitRoute[index];
    final p2 = kSkylineSummitRoute[index + 1];

    final lat = p1.latitude + (p2.latitude - p1.latitude) * fraction;
    final lng = p1.longitude + (p2.longitude - p1.longitude) * fraction;
    return LatLng(lat, lng);
  }

  /// Package telemetry packet for AWS IoT Core publishing
  TelemetryPacket createPacket({
    required String riderId,
    required String callsign,
    required LatLng position,
    required double speedKmh,
    required double headingDeg,
  }) {
    return TelemetryPacket(
      riderId: riderId,
      callsign: callsign,
      packId: '804',
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: 312.0,
      speedKmh: speedKmh,
      headingDeg: headingDeg,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void dispose() {
    _telemetryTicker?.cancel();
    _telemetryController.close();
  }
}
