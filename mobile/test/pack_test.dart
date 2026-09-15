import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:groupnav_mobile/core/config/client_config.dart';
import 'package:groupnav_mobile/features/groups/models/pack_formation.dart';
import 'package:groupnav_mobile/features/groups/models/pack_member.dart';
import 'package:groupnav_mobile/features/groups/providers/pack_provider.dart';
import 'package:groupnav_mobile/features/radar/providers/radar_provider.dart';
import 'package:groupnav_mobile/features/radar/services/iot_telemetry_service.dart';

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

  group('PackMember Model Tests', () {
    test('Status badge labels and text colors derive correctly', () {
      const lead = PackMember(
        id: '1',
        callsign: 'Apex',
        initials: 'AP',
        status: PackMemberStatus.lead,
        speedKmh: 82.0,
        offsetMeters: 0.0,
        offsetDescription: '0m offset',
        isLeader: true,
      );
      expect(lead.statusBadgeLabel, equals('LEAD'));
      expect(lead.isLeader, isTrue);

      const inBounds = PackMember(
        id: '2',
        callsign: 'Viper',
        initials: 'VP',
        status: PackMemberStatus.inBounds,
        speedKmh: 80.0,
        offsetMeters: 140.0,
        offsetDescription: '+140m ahead',
      );
      expect(inBounds.statusBadgeLabel, equals('In Bounds'));

      const warning = PackMember(
        id: '3',
        callsign: 'Ghost',
        initials: 'GH',
        status: PackMemberStatus.warning,
        speedKmh: 75.0,
        offsetMeters: 790.0,
        offsetDescription: '+790m near edge',
      );
      expect(warning.statusBadgeLabel, equals('Warning'));

      const offline = PackMember(
        id: '4',
        callsign: 'Nomad',
        initials: 'NM',
        status: PackMemberStatus.offline,
        speedKmh: 0.0,
        offsetMeters: 1250.0,
        offsetDescription: 'Offline',
      );
      expect(offline.statusBadgeLabel, equals('Offline'));
    });
  });

  group('PackFormation Model Tests', () {
    test('Formats radius correctly for meters (<1km) and kilometers (>=1km)', () {
      const subKm = PackFormation(geofenceRadiusMeters: 850.0);
      expect(subKm.formattedRadius, equals('850m'));

      const exactKm = PackFormation(geofenceRadiusMeters: 1000.0);
      expect(exactKm.formattedRadius, equals('1.0km'));

      const multiKm = PackFormation(geofenceRadiusMeters: 2500.0);
      expect(multiKm.formattedRadius, equals('2.5km'));
    });

    test('Computes connected count excluding offline members', () {
      const formation = PackFormation(
        members: [
          PackMember(id: '1', callsign: 'A', initials: 'A', status: PackMemberStatus.lead, speedKmh: 80, offsetMeters: 0, offsetDescription: ''),
          PackMember(id: '2', callsign: 'B', initials: 'B', status: PackMemberStatus.inBounds, speedKmh: 80, offsetMeters: 100, offsetDescription: ''),
          PackMember(id: '3', callsign: 'C', initials: 'C', status: PackMemberStatus.warning, speedKmh: 70, offsetMeters: 500, offsetDescription: ''),
          PackMember(id: '4', callsign: 'D', initials: 'D', status: PackMemberStatus.offline, speedKmh: 0, offsetMeters: 1000, offsetDescription: ''),
        ],
      );
      expect(formation.connectedCount, equals(3));
      expect(formation.members.length, equals(4));
    });
  });

  group('PackNotifier State Tests', () {
    late IotTelemetryService telemetryService;
    late RadarNotifier radarNotifier;
    late PackNotifier packNotifier;

    setUp(() {
      telemetryService = IotTelemetryService(config: dummyConfig);
      radarNotifier = RadarNotifier(telemetryService);
      packNotifier = PackNotifier(radarNotifier);
    });

    tearDown(() {
      telemetryService.dispose();
    });

    test('Initializes with standard pack formation #804 and GN-9482 code', () {
      expect(packNotifier.state.packId, equals('804'));
      expect(packNotifier.state.packCode, equals('GN-9482'));
      expect(packNotifier.state.isTelemetrySyncActive, isTrue);
      expect(packNotifier.state.members.length, equals(4));
      expect(packNotifier.state.geofenceRadiusMeters, equals(850.0));
    });

    test('updateGeofenceRadius updates formation and syncs to RadarNotifier', () {
      packNotifier.updateGeofenceRadius(1500.0);
      expect(packNotifier.state.geofenceRadiusMeters, equals(1500.0));
      expect(radarNotifier.state.geofenceRadiusMeters, equals(1500.0));
    });

    test('updateGeofenceRadius clamps within bounds (200m to 5000m)', () {
      packNotifier.updateGeofenceRadius(50.0);
      expect(packNotifier.state.geofenceRadiusMeters, equals(200.0));

      packNotifier.updateGeofenceRadius(10000.0);
      expect(packNotifier.state.geofenceRadiusMeters, equals(5000.0));
    });

    test('generateQrPayload produces valid JSON with correct pack rendezvous data', () {
      final payload = packNotifier.generateQrPayload();
      final map = jsonDecode(payload) as Map<String, dynamic>;
      expect(map['action'], equals('join_pack'));
      expect(map['code'], equals('GN-9482'));
      expect(map['packId'], equals('804'));
      expect(map.containsKey('timestamp'), isTrue);
    });

    test('disbandConvoy deactivates sync and retains only leader', () {
      packNotifier.disbandConvoy();
      expect(packNotifier.state.isTelemetrySyncActive, isFalse);
      expect(packNotifier.state.isInPack, isFalse);
      expect(packNotifier.state.members.length, equals(1));
      expect(packNotifier.state.members.first.isLeader, isTrue);
    });

    test('leavePack sets isInPack to false and clears packCode', () {
      expect(packNotifier.state.isInPack, isTrue);
      packNotifier.leavePack();
      expect(packNotifier.state.isInPack, isFalse);
      expect(packNotifier.state.packCode, isEmpty);
      expect(packNotifier.state.title, equals('Solo Ride Mode'));
      expect(packNotifier.state.isTelemetrySyncActive, isFalse);
      expect(packNotifier.state.members.length, equals(1));
      expect(packNotifier.state.members.first.callsign, equals('Apex (You)'));
    });

    test('joinPack sets isInPack to true and updates packCode', () {
      packNotifier.leavePack();
      expect(packNotifier.state.isInPack, isFalse);

      packNotifier.joinPack('GN-7721');
      expect(packNotifier.state.isInPack, isTrue);
      expect(packNotifier.state.packCode, equals('GN-7721'));
      expect(packNotifier.state.title, equals('Pack Formation #GN-7721'));
      expect(packNotifier.state.isTelemetrySyncActive, isTrue);
      expect(packNotifier.state.members.length, equals(4));
    });

    test('createPack generates a new room and assigns user as Convoy Lead', () {
      packNotifier.leavePack();
      expect(packNotifier.state.isInPack, isFalse);

      packNotifier.createPack();
      expect(packNotifier.state.isInPack, isTrue);
      expect(packNotifier.state.packCode, startsWith('GN-'));
      expect(packNotifier.state.isTelemetrySyncActive, isTrue);
      expect(packNotifier.state.members.length, equals(1));
      expect(packNotifier.state.members.first.isLeader, isTrue);
      expect(packNotifier.state.members.first.offsetDescription, equals('Convoy Lead'));
    });
  });
}
