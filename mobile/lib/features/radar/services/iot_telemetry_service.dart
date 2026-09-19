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
import '../models/convoy_route.dart';
import '../models/telemetry_packet.dart';

class IotTelemetryService {
  final ClientConfig config;
  final LocationService? locationService;
  final AwsSigV4Signer _signer;

  bool _isBroadcasting = true;
  StreamSubscription<PositionData>? _locationSub;
  MqttServerClient? _mqttClient;
  bool _isMqttConnected = false;
  String _currentRiderId = '';
  String _currentCallsign = '';
  String _activePackCode = '';
  bool _isLeader = false;
  int _broadcastCount = 0;
  DateTime? _lastBroadcastTime;

  final Map<String, ConvoyPeer> _activePeers = {};

  final _telemetryController = StreamController<List<ConvoyPeer>>.broadcast();
  Stream<List<ConvoyPeer>> get convoyStream => _telemetryController.stream;

  final _alertController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;

  final _connectionStatusController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  final _routeUpdateController = StreamController<ConvoyRoute>.broadcast();
  Stream<ConvoyRoute> get routeUpdateStream => _routeUpdateController.stream;

  bool get isBroadcasting => _isBroadcasting;
  bool get isMqttConnected => _isMqttConnected;
  int get broadcastCount => _broadcastCount;
  DateTime? get lastBroadcastTime => _lastBroadcastTime;

  IotTelemetryService({
    required this.config,
    this.locationService,
  }) : _signer = AwsSigV4Signer(
          region: config.region,
          endpoint: config.iot.endpoint,
        ) {
    _startLocationStreaming();
  }

  void updateRiderIdentity({required String riderId, required String callsign, bool? isLeader}) {
    _currentRiderId = riderId;
    _currentCallsign = callsign;
    if (isLeader != null) {
      _isLeader = isLeader;
    }
  }

  void updateLeaderStatus(bool isLeader) {
    _isLeader = isLeader;
  }

  void updateActivePack(String packCode) {
    if (_activePackCode == packCode) return;
    final previousPack = _activePackCode;
    _activePackCode = packCode;

    // Clear remote peers from previous pack
    _activePeers.removeWhere((id, _) => id != _currentRiderId);
    _emitPeers();

    // Re-subscribe if connected
    if (_mqttClient != null && _isMqttConnected) {
      if (previousPack.isNotEmpty) {
        _mqttClient!.unsubscribe('groupnav/packs/$previousPack/telemetry');
        _mqttClient!.unsubscribe('groupnav/packs/$previousPack/alerts');
      }
      if (_activePackCode.isNotEmpty) {
        _mqttClient!.subscribe('groupnav/packs/$_activePackCode/telemetry', MqttQos.atLeastOnce);
        _mqttClient!.subscribe('groupnav/packs/$_activePackCode/alerts', MqttQos.atLeastOnce);
      }
    }
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
        _connectionStatusController.add(true);
        debugPrint('[IotTelemetryService] AWS IoT Core MQTT connected successfully.');

        // Subscribe to global and pack-specific telemetry and alerts
        client.subscribe('groupnav/+/telemetry', MqttQos.atLeastOnce);
        if (_activePackCode.isNotEmpty) {
          client.subscribe('groupnav/packs/$_activePackCode/telemetry', MqttQos.atLeastOnce);
          client.subscribe('groupnav/packs/$_activePackCode/alerts', MqttQos.atLeastOnce);
        }

        client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
          for (final msg in messages) {
            final recMess = msg.payload as MqttPublishMessage;
            final payloadStr = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

            try {
              final jsonMap = jsonDecode(payloadStr) as Map<String, dynamic>;

              if (msg.topic.contains('/alerts')) {
                _alertController.add(jsonMap);
              } else if (msg.topic.contains('/telemetry')) {
                _handleIncomingTelemetry(jsonMap);
              }
            } catch (_) {}
          }
        });

        return true;
      }
    } catch (e) {
      debugPrint('[IotTelemetryService] MQTT connection error: $e');
    }

    _isMqttConnected = false;
    _connectionStatusController.add(false);
    return false;
  }

  void _handleIncomingTelemetry(Map<String, dynamic> data) {
    try {
      if (data['action'] == 'route_change') {
        final routeJson = data['route'] as Map<String, dynamic>?;
        if (routeJson != null) {
          final route = ConvoyRoute.fromJson(routeJson);
          _routeUpdateController.add(route);
          debugPrint('[IotTelemetryService] Adopted leader route update: ${route.title}');
        }
        return;
      }

      final packet = TelemetryPacket.fromJson(data);
      if (packet.riderId == _currentRiderId) return; // Skip self

      final remotePeer = ConvoyPeer(
        callsign: packet.callsign,
        latitude: packet.latitude,
        longitude: packet.longitude,
        altitude: packet.altitude,
        speedKmh: packet.speedKmh,
        headingDeg: packet.headingDeg,
        relativeOffsetMeters: 0,
        isLeader: data['isLeader'] as bool? ?? false,
        beaconColorHex: '#00C48C',
        monikerTag: data['isLeader'] == true ? 'Lead' : 'Rider',
      );

      _activePeers[packet.riderId] = remotePeer;
      _emitPeers();
    } catch (_) {}
  }

  void setBroadcasting(bool value) {
    _isBroadcasting = value;
  }

  void _startLocationStreaming() {
    _locationSub?.cancel();
    if (locationService == null) return;

    _locationSub = locationService!.positionStream.listen((pos) {
      final displayCallsign = _currentCallsign.isNotEmpty ? _currentCallsign : 'Pilot';
      final selfPeer = ConvoyPeer(
        callsign: '$displayCallsign (You)',
        latitude: pos.latitude,
        longitude: pos.longitude,
        altitude: pos.altitude,
        speedKmh: pos.speedKmh,
        headingDeg: pos.headingDeg,
        relativeOffsetMeters: 0,
        isLeader: _isLeader,
        beaconColorHex: '#0066FF',
        monikerTag: _isLeader ? 'Lead' : 'Rider',
      );

      final effectiveRiderId = _currentRiderId.isNotEmpty ? _currentRiderId : 'self';
      _activePeers[effectiveRiderId] = selfPeer;
      _emitPeers();

      if (_isBroadcasting && _isMqttConnected) {
        final packet = TelemetryPacket(
          riderId: _currentRiderId,
          callsign: _currentCallsign,
          packId: _activePackCode.isNotEmpty ? _activePackCode : 'solo',
          latitude: pos.latitude,
          longitude: pos.longitude,
          altitude: pos.altitude,
          speedKmh: pos.speedKmh,
          headingDeg: pos.headingDeg,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        publishTelemetry(packet);
      }
    });
  }

  void _emitPeers() {
    if (_activePeers.isNotEmpty) {
      _telemetryController.add(_activePeers.values.toList());
    }
  }

  /// Publish a TelemetryPacket to AWS IoT Core
  void publishTelemetry(TelemetryPacket packet) {
    if (_mqttClient != null && _isMqttConnected) {
      try {
        final topic = _activePackCode.isNotEmpty
            ? 'groupnav/packs/$_activePackCode/telemetry'
            : 'groupnav/${packet.riderId}/telemetry';
        final builder = MqttClientPayloadBuilder();
        builder.addString(jsonEncode(packet.toJson()));
        _mqttClient!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
        _broadcastCount++;
        _lastBroadcastTime = DateTime.now();
      } catch (e) {
        debugPrint('[IotTelemetryService] Publish telemetry error: $e');
      }
    }
  }

  /// Broadcast a Convoy Navigation Route update to all connected riders (Leader only)
  void broadcastRoute(ConvoyRoute route) {
    final payload = {
      'action': 'route_change',
      'packId': _activePackCode,
      'riderId': _currentRiderId,
      'callsign': _currentCallsign,
      'route': route.toJson(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (_mqttClient != null && _isMqttConnected) {
      try {
        final topic = _activePackCode.isNotEmpty
            ? 'groupnav/packs/$_activePackCode/telemetry'
            : 'groupnav/$_currentRiderId/telemetry';
        final builder = MqttClientPayloadBuilder();
        builder.addString(jsonEncode(payload));
        _mqttClient!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
        _broadcastCount++;
        _lastBroadcastTime = DateTime.now();
        debugPrint('[IotTelemetryService] Broadcast route ${route.title} on MQTT topic $topic');
      } catch (e) {
        debugPrint('[IotTelemetryService] Publish route error: $e');
      }
    }
  }

  /// Broadcast a Quick Convoy Alert to AWS IoT Core
  void publishAlert({
    required String packId,
    required String alertType,
    String? callsign,
    String? message,
  }) {
    final alertData = {
      'packId': packId,
      'alertType': alertType,
      'callsign': callsign ?? _currentCallsign,
      'message': message ?? 'Alert triggered',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    _alertController.add(alertData);

    if (_mqttClient != null && _isMqttConnected) {
      try {
        final topic = 'groupnav/packs/$packId/alerts';
        final builder = MqttClientPayloadBuilder();
        builder.addString(jsonEncode(alertData));
        _mqttClient!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
        _broadcastCount++;
        _lastBroadcastTime = DateTime.now();
      } catch (e) {
        debugPrint('[IotTelemetryService] Publish alert error: $e');
      }
    }
  }

  String get activePackCode => _activePackCode;

  TelemetryPacket createPacket({
    required String riderId,
    required String callsign,
    required LatLng position,
    required double speedKmh,
    required double headingDeg,
    String? packId,
  }) {
    return TelemetryPacket(
      riderId: riderId,
      callsign: callsign,
      packId: packId ?? (_activePackCode.isNotEmpty ? _activePackCode : 'solo'),
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: 0.0,
      speedKmh: speedKmh,
      headingDeg: headingDeg,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void dispose() {
    _locationSub?.cancel();
    _mqttClient?.disconnect();
    _telemetryController.close();
    _alertController.close();
    _routeUpdateController.close();
    _connectionStatusController.close();
  }
}
