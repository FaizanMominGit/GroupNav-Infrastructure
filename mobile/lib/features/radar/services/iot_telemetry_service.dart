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
    if (_currentRiderId.isNotEmpty && _currentRiderId != riderId) {
      _activePeers.remove(_currentRiderId);
    }
    _activePeers.remove('self');
    _currentRiderId = riderId;
    _currentCallsign = callsign;
    if (isLeader != null) {
      _isLeader = isLeader;
    }
    if (_activePeers.containsKey(riderId)) {
      final existing = _activePeers[riderId]!;
      _activePeers[riderId] = existing.copyWith(
        callsign: '$callsign (You)',
        isLeader: _isLeader,
        monikerTag: _isLeader ? 'Lead' : 'Rider',
      );
      _emitPeers();
    }
  }

  void updateLeaderStatus(bool isLeader) {
    _isLeader = isLeader;
  }

  void updateActivePack(String packCode) {
    if (_activePackCode == packCode) return;
    _activePackCode = packCode;

    // Clear remote peers from previous pack
    _activePeers.removeWhere((id, _) => id != _currentRiderId);
    _emitPeers();
  }

  bool _isConnecting = false;

  /// Initialize connection to AWS IoT Core MQTT Broker over WebSockets
  Future<bool> connectMqtt({
    required String accessKeyId,
    required String secretKey,
    String? sessionToken,
  }) async {
    // Guard against multiple simultaneous connection attempts
    if (_isConnecting) {
      debugPrint('[IotTelemetryService] Connection already in progress, skipping duplicate attempt.');
      return false;
    }
    _isConnecting = true;
    try {
      if (accessKeyId.isEmpty || secretKey.isEmpty) {
        debugPrint('[IotTelemetryService] Cannot connect MQTT: empty credentials.');
        _isConnecting = false;
        return false;
      }

      final presignedUrl = _signer.generatePresignedWebSocketUrl(
        accessKeyId: accessKeyId,
        secretKey: secretKey,
        sessionToken: sessionToken,
      );

      debugPrint('[IotTelemetryService] Connecting MQTT to AWS IoT Core...');
      debugPrint('[IotTelemetryService] Endpoint: ${config.iot.endpoint}');

      final clientId = 'groupnav_pilot_${DateTime.now().millisecondsSinceEpoch}';

      // mqtt_client's MqttWsConnection.connect() internally does:
      //   uri = Uri.parse(server)           → server MUST include wss:// scheme
      //   uri = uri.replace(port: port)     → injects the port number
      //   WebSocket.connect(uri.toString()) → connects
      //
      // In Dart, Uri.replace(port: 443) on a wss:// URI omits ":443" from
      // the string because 443 is the default WSS port. So the final URL is:
      //   wss://endpoint/mqtt?<sigv4-params>
      // which matches the SigV4-signed Host header "endpoint" exactly. ✅
      final client = MqttServerClient.withPort(
        presignedUrl, // full wss:// presigned URL — scheme required by mqtt_client
        clientId,
        443, // Dart omits :443 for wss:// (default port) → Host header correct
      );

      client.useWebSocket = true;
      client.port = 443;
      client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
      client.logging(on: kDebugMode);
      client.keepAlivePeriod = 30;
      client.autoReconnect = true;

      // AWS IoT Core requires MQTT protocol version 3.1.1 (ProtocolName='MQTT', version=4).
      // The default MqttConnectMessage uses MQTT 3.1 (MQIsdp/v3) which AWS rejects
      // by closing the WebSocket immediately after the CONNECT packet.
      final connMessage = MqttConnectMessage()
          .withProtocolName('MQTT')
          .withProtocolVersion(4)
          .withClientIdentifier(clientId)
          .startClean();
      client.connectionMessage = connMessage;

      debugPrint('[IotTelemetryService] Attempting MQTT connect...');
      final status = await client.connect();
      debugPrint('[IotTelemetryService] MQTT connect status: ${status?.state}');

      if (status?.state == MqttConnectionState.connected) {
        _mqttClient = client;
        _isMqttConnected = true;
        _connectionStatusController.add(true);
        debugPrint('[IotTelemetryService] AWS IoT Core MQTT connected successfully.');

        // Subscribe to global and pack-specific telemetry and alerts with wildcards
        client.subscribe('groupnav/+/telemetry', MqttQos.atLeastOnce);
        client.subscribe('groupnav/packs/+/telemetry', MqttQos.atLeastOnce);
        client.subscribe('groupnav/packs/+/alerts', MqttQos.atLeastOnce);
        client.subscribe('groupnav/+/routes', MqttQos.atLeastOnce);
        client.subscribe('groupnav/packs/+/routes', MqttQos.atLeastOnce);

        client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
          for (final msg in messages) {
            final recMess = msg.payload as MqttPublishMessage;
            final payloadStr = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
            debugPrint('[IotTelemetryService] RAW RECV: topic=${msg.topic} payload=$payloadStr');

            try {
              final jsonMap = jsonDecode(payloadStr) as Map<String, dynamic>;

              if (msg.topic.contains('/alerts')) {
                _alertController.add(jsonMap);
              } else if (msg.topic.contains('/telemetry')) {
                _handleIncomingTelemetry(jsonMap);
              }
            } catch (e, stack) {
              debugPrint('[IotTelemetryService] Error processing incoming MQTT message: $e\n$stack');
            }
          }
        });

        _isConnecting = false;
        return true;
      } else {
        debugPrint('[IotTelemetryService] MQTT connection did not reach connected state. Status: ${status?.state}');
      }
    } catch (e, stackTrace) {
      debugPrint('[IotTelemetryService] MQTT connection error: $e');
      debugPrint('[IotTelemetryService] Stack: $stackTrace');
    }

    _isMqttConnected = false;
    _isConnecting = false;
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(false);
    }
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
      if (packet.callsign == _currentCallsign) return; // Skip self

      final remotePeer = ConvoyPeer(
        callsign: packet.callsign,
        latitude: packet.latitude,
        longitude: packet.longitude,
        altitude: packet.altitude,
        speedKmh: packet.speedKmh,
        headingDeg: packet.headingDeg,
        relativeOffsetMeters: 0,
        isLeader: packet.isLeader,
        beaconColorHex: packet.isLeader ? '#FFB800' : '#00C48C',
        monikerTag: packet.isLeader ? 'Lead' : 'Rider',
      );

      _activePeers[packet.callsign] = remotePeer;
      _emitPeers();
    } catch (e, stack) {
      debugPrint('[IotTelemetryService] Error in _handleIncomingTelemetry: $e\n$stack');
    }
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

      final effectiveCallsign = displayCallsign;
      _activePeers[effectiveCallsign] = selfPeer;
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
          isLeader: _isLeader,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        publishTelemetry(packet);
      }
    });
  }

  void _emitPeers() {
    if (_activePeers.isEmpty) return;

    // Resolve self peer
    final selfKey = _activePeers.keys.firstWhere(
      (k) => _activePeers[k]?.callsign.contains('(You)') ?? false,
      orElse: () => '',
    );
    final self = selfKey.isNotEmpty ? _activePeers[selfKey] : null;

    if (self == null) {
      _telemetryController.add(_activePeers.values.toList());
      return;
    }

    const distCalc = Distance();
    final updatedList = <ConvoyPeer>[];

    for (final entry in _activePeers.entries) {
      final peer = entry.value;
      if (entry.key == selfKey) {
        updatedList.add(peer.copyWith(relativeOffsetMeters: 0));
        continue;
      }

      final distMeters = distCalc.as(
        LengthUnit.Meter,
        LatLng(self.latitude, self.longitude),
        LatLng(peer.latitude, peer.longitude),
      );

      // Determine whether the peer is ahead (+) or behind (-) relative to heading
      double signedOffset = distMeters;
      if (self.speedKmh > 3 || self.headingDeg > 0) {
        final bearing = distCalc.bearing(
          LatLng(self.latitude, self.longitude),
          LatLng(peer.latitude, peer.longitude),
        );
        final diff = (bearing - self.headingDeg + 540) % 360 - 180;
        signedOffset = diff.abs() <= 90 ? distMeters : -distMeters;
      } else {
        if (peer.isLeader) {
          signedOffset = distMeters;
        } else if (self.isLeader) {
          signedOffset = -distMeters;
        }
      }

      updatedList.add(peer.copyWith(relativeOffsetMeters: signedOffset));
    }

    _telemetryController.add(updatedList);
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
