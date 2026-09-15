import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../../../core/config/client_config.dart';
import '../../../core/services/aws_sigv4_signer.dart';
import '../../../core/services/location_service.dart';
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
  final LocationService? locationService;
  final AwsSigV4Signer _signer;

  bool _isBroadcasting = true;
  Timer? _telemetryTicker;
  StreamSubscription<PositionData>? _locationSub;
  MqttServerClient? _mqttClient;
  bool _isMqttConnected = false;

  final _telemetryController = StreamController<List<ConvoyPeer>>.broadcast();
  Stream<List<ConvoyPeer>> get convoyStream => _telemetryController.stream;

  final _alertController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;

  bool get isBroadcasting => _isBroadcasting;
  bool get isMqttConnected => _isMqttConnected;

  // Base simulation state
  double _progress = 0.5;
  final double _speedKmh = 78.0;
  final double _headingDeg = 42.0;

  IotTelemetryService({
    required this.config,
    this.locationService,
  }) : _signer = AwsSigV4Signer(
          region: config.region,
          endpoint: config.iot.endpoint,
        ) {
    startTelemetry();
  }

  /// Initialize connection to AWS IoT Core MQTT Broker over WebSockets
  Future<bool> connectMqtt({
    required String accessKeyId,
    required String secretKey,
    String? sessionToken,
  }) async {
    try {
      final presignedUrl = _signer.generatePresignedWebSocketUrl(
        accessKeyId: accessKeyId,
        secretKey: secretKey,
        sessionToken: sessionToken,
      );

      final clientId = 'groupnav_pilot_${DateTime.now().millisecondsSinceEpoch}';
      final client = MqttServerClient.withPort(
        presignedUrl,
        clientId,
        443,
      );

      client.useWebSocket = true;
      client.port = 443;
      client.logging(on: kDebugMode);
      client.keepAlivePeriod = 30;
      client.autoReconnect = true;

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean();
      client.connectionMessage = connMessage;

      final status = await client.connect();
      if (status?.state == MqttConnectionState.connected) {
        _mqttClient = client;
        _isMqttConnected = true;
        debugPrint('[IotTelemetryService] AWS IoT Core MQTT connected successfully.');

        // Subscribe to pack alerts
        client.subscribe('groupnav/packs/+/alerts', MqttQos.atLeastOnce);

        client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
          for (final msg in messages) {
            final recMess = msg.payload as MqttPublishMessage;
            final payloadStr = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
            try {
              final jsonMap = jsonDecode(payloadStr) as Map<String, dynamic>;
              _alertController.add(jsonMap);
            } catch (_) {}
          }
        });

        return true;
      }
    } catch (e) {
      debugPrint('[IotTelemetryService] MQTT connection error: $e');
    }

    _isMqttConnected = false;
    return false;
  }

  void setBroadcasting(bool value) {
    _isBroadcasting = value;
    if (_isBroadcasting) {
      startTelemetry();
    } else {
      _telemetryTicker?.cancel();
      _locationSub?.cancel();
    }
  }

  void startTelemetry() {
    _telemetryTicker?.cancel();
    _locationSub?.cancel();

    if (locationService != null && locationService!.mode == LocationMode.hardware) {
      _startHardwareLocationStreaming();
    } else {
      startSimulation();
    }
  }

  void _startHardwareLocationStreaming() {
    _locationSub = locationService!.positionStream.listen((pos) {
      if (!_isBroadcasting) return;

      final leader = ConvoyPeer(
        callsign: 'Leader: Apex (You)',
        latitude: pos.latitude,
        longitude: pos.longitude,
        altitude: pos.altitude,
        speedKmh: pos.speedKmh,
        headingDeg: pos.headingDeg,
        relativeOffsetMeters: 0,
        isLeader: true,
        beaconColorHex: '#0066FF',
        monikerTag: 'HQ',
      );

      _telemetryController.add([leader]);

      // Publish live telemetry packet to AWS IoT Core topic
      final packet = createPacket(
        riderId: 'apex-lead',
        callsign: 'Apex',
        position: LatLng(pos.latitude, pos.longitude),
        speedKmh: pos.speedKmh,
        headingDeg: pos.headingDeg,
      );
      publishTelemetry(packet);
    });
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

      // Publish packet
      final packet = createPacket(
        riderId: 'apex-lead',
        callsign: 'Apex',
        position: currentPos,
        speedKmh: _speedKmh,
        headingDeg: _headingDeg,
      );
      publishTelemetry(packet);
    });
  }

  /// Publish a TelemetryPacket to AWS IoT Core topic: `groupnav/{riderId}/telemetry`
  void publishTelemetry(TelemetryPacket packet) {
    if (_mqttClient != null && _isMqttConnected) {
      try {
        final topic = 'groupnav/${packet.riderId}/telemetry';
        final builder = MqttClientPayloadBuilder();
        builder.addString(jsonEncode(packet.toJson()));
        _mqttClient!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      } catch (e) {
        debugPrint('[IotTelemetryService] Publish telemetry error: $e');
      }
    }
  }

  /// Broadcast a Quick Convoy Alert (Regroup, Refuel, Issue, Custom) to AWS IoT Core
  void publishAlert({
    required String packId,
    required String alertType,
    String? callsign,
    String? message,
  }) {
    final alertData = {
      'packId': packId,
      'alertType': alertType,
      'callsign': callsign ?? 'Apex',
      'message': message ?? 'Alert triggered',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Emit locally immediately for instantaneous UI reaction
    _alertController.add(alertData);

    if (_mqttClient != null && _isMqttConnected) {
      try {
        final topic = 'groupnav/packs/$packId/alerts';
        final builder = MqttClientPayloadBuilder();
        builder.addString(jsonEncode(alertData));
        _mqttClient!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
        debugPrint('[IotTelemetryService] Published alert to $topic: $alertData');
      } catch (e) {
        debugPrint('[IotTelemetryService] Publish alert error: $e');
      }
    }
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
    _locationSub?.cancel();
    _mqttClient?.disconnect();
    _telemetryController.close();
    _alertController.close();
  }
}
