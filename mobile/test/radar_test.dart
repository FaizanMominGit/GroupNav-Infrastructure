import 'package:flutter_test/flutter_test.dart';
import 'package:groupnav_mobile/core/config/client_config.dart';
import 'package:groupnav_mobile/features/radar/models/convoy_peer.dart';
import 'package:groupnav_mobile/features/radar/models/telemetry_packet.dart';
import 'package:groupnav_mobile/features/radar/providers/radar_provider.dart';
import 'package:groupnav_mobile/features/radar/services/iot_telemetry_service.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const dummyConfig = ClientConfig(
    region: 'ap-south-1',
    cognito: CognitoConfig(userPoolId: 'u', userPoolClientId: 'c', identityPoolId: 'i'),
    location: LocationConfig(mapName: 'GroupNavMap', mapArn: 'a', geofenceCollectionName: 'g', geofenceCollectionArn: 'ga'),
    iot: IotConfig(endpoint: 'a362o0ub4ypzaj-ats.iot.ap-south-1.amazonaws.com'),
    network: NetworkConfig(vpcId: 'v', computeSecurityGroupId: 'csg', dataSecurityGroupId: 'dsg'),
    data: DataConfig(redisEndpoint: 'r', auroraClusterEndpoint: 'a'),
    compute: ComputeConfig(lambdaArn: 'l', dlqUrl: 'd', telemetryTopicPattern: 'groupnav/{riderId}/telemetry'),
    cicd: CicdConfig(pipelineName: 'p', pipelineArn: 'pa', gitHubConnectionArn: 'ga', artifactBucketName: 'b'),
  );

  group('TelemetryPacket Unit Tests', () {
    test('Serializes to and from JSON accurately', () {
      final packet = TelemetryPacket(
        riderId: 'rider-123',
        callsign: '0xApex',
        packId: '804',
        latitude: 37.7749,
        longitude: -122.4194,
        altitude: 312.4,
        speedKmh: 78.2,
        headingDeg: 42.0,
        accuracy: 4.5,
        timestamp: 1729012391000,
      );

      final jsonMap = packet.toJson();
      expect(jsonMap['riderId'], equals('rider-123'));
      expect(jsonMap['callsign'], equals('0xApex'));
      expect(jsonMap['speedKmh'], equals(78.2));
      expect(jsonMap['headingDeg'], equals(42.0));

      final restored = TelemetryPacket.fromJson(jsonMap);
      expect(restored.riderId, equals(packet.riderId));
      expect(restored.latitude, equals(packet.latitude));
      expect(restored.longitude, equals(packet.longitude));
      expect(restored.speedKmh, equals(packet.speedKmh));
    });
  });

  group('ConvoyPeer Offset & Moniker Tests', () {
    test('Leader returns moniker tag or HQ', () {
      const leader = ConvoyPeer(
        callsign: 'Leader: Apex',
        latitude: 37.7749,
        longitude: -122.4194,
        speedKmh: 78.0,
        headingDeg: 42.0,
        relativeOffsetMeters: 0,
        isLeader: true,
        monikerTag: 'HQ',
      );

      expect(leader.offsetFormatted, equals('HQ'));
    });

    test('Peer formats positive and negative offsets', () {
      const viperAhead = ConvoyPeer(
        callsign: 'Viper',
        latitude: 37.7760,
        longitude: -122.4180,
        speedKmh: 72.0,
        headingDeg: 38.0,
        relativeOffsetMeters: 120.4,
      );
      expect(viperAhead.offsetFormatted, equals('+120m'));

      const ghostBehind = ConvoyPeer(
        callsign: 'Ghost',
        latitude: 37.7735,
        longitude: -122.4210,
        speedKmh: 68.0,
        headingDeg: 45.0,
        relativeOffsetMeters: -85.2,
      );
      expect(ghostBehind.offsetFormatted, equals('-85m'));
    });
  });

  group('RadarState Heading Cardinal Display Tests', () {
    test('Calculates cardinal direction and padded degrees', () {
      const stateNE = RadarState(currentHeading: 42.0);
      expect(stateNE.headingDisplay, equals('NE 042°'));

      const stateS = RadarState(currentHeading: 180.0);
      expect(stateS.headingDisplay, equals('S 180°'));

      const stateW = RadarState(currentHeading: 270.0);
      expect(stateW.headingDisplay, equals('W 270°'));
    });
  });

  group('IotTelemetryService Packet Generation', () {
    test('createPacket returns valid schema', () {
      final service = IotTelemetryService(config: dummyConfig);
      final soloPacket = service.createPacket(
        riderId: 'test-sub',
        callsign: 'Apex',
        position: const LatLng(37.7749, -122.4194),
        speedKmh: 78.0,
        headingDeg: 42.0,
      );

      expect(soloPacket.riderId, equals('test-sub'));
      expect(soloPacket.packId, equals('solo'));
      expect(soloPacket.latitude, equals(37.7749));
      expect(soloPacket.longitude, equals(-122.4194));
      expect(soloPacket.speedKmh, equals(78.0));
      expect(soloPacket.headingDeg, equals(42.0));

      service.updateActivePack('GN-9482');
      final packPacket = service.createPacket(
        riderId: 'test-sub',
        callsign: 'Apex',
        position: const LatLng(37.7749, -122.4194),
        speedKmh: 80.0,
        headingDeg: 45.0,
      );
      expect(packPacket.packId, equals('GN-9482'));

      service.dispose();
    });
  });
}
