import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:groupnav_mobile/core/config/client_config.dart';
import 'package:groupnav_mobile/features/groups/models/pack_formation.dart';
import 'package:groupnav_mobile/features/groups/models/pack_member.dart';
import 'package:groupnav_mobile/features/groups/providers/pack_provider.dart';
import 'package:groupnav_mobile/features/groups/services/qr_scanner_service.dart';
import 'package:groupnav_mobile/features/groups/widgets/active_code_card.dart';
import 'package:groupnav_mobile/features/groups/widgets/camera_qr_scanner_modal.dart';
import 'package:groupnav_mobile/features/groups/widgets/pack_roster_card.dart';
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
      FlutterSecureStorage.setMockInitialValues({});
      telemetryService = IotTelemetryService(config: dummyConfig);
      radarNotifier = RadarNotifier(telemetryService);
      packNotifier = PackNotifier(radarNotifier);
    });

    tearDown(() {
      telemetryService.dispose();
    });

    test('Initializes cleanly in Solo Ride Mode with 0 fake peers', () {
      expect(packNotifier.state.packId, equals(''));
      expect(packNotifier.state.packCode, equals(''));
      expect(packNotifier.state.isTelemetrySyncActive, isFalse);
      expect(packNotifier.state.isInPack, isFalse);
      expect(packNotifier.state.members.length, equals(1));
      expect(packNotifier.state.members.first.isLeader, isTrue);
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

    test('generateQrPayload produces valid JSON with correct pack rendezvous data', () async {
      await packNotifier.joinPack('GN-9482');
      final payload = packNotifier.generateQrPayload();
      final map = jsonDecode(payload) as Map<String, dynamic>;
      expect(map['action'], equals('join_pack'));
      expect(map['code'], equals('GN-9482'));
      expect(map.containsKey('timestamp'), isTrue);
    });

    test('disbandConvoy deactivates sync and retains only leader', () {
      packNotifier.disbandConvoy();
      expect(packNotifier.state.isTelemetrySyncActive, isFalse);
      expect(packNotifier.state.isInPack, isFalse);
      expect(packNotifier.state.members.length, equals(1));
      expect(packNotifier.state.members.first.isLeader, isTrue);
    });

    test('leavePack sets isInPack to false and clears packCode', () async {
      await packNotifier.joinPack('GN-7721');
      expect(packNotifier.state.isInPack, isTrue);

      await packNotifier.leavePack();
      expect(packNotifier.state.isInPack, isFalse);
      expect(packNotifier.state.packCode, isEmpty);
      expect(packNotifier.state.title, equals('Solo Ride Mode'));
      expect(packNotifier.state.isTelemetrySyncActive, isFalse);
      expect(packNotifier.state.members.length, equals(1));
      expect(packNotifier.state.members.first.callsign, equals('Pilot'));
    });

    test('joinPack sets isInPack to true and updates packCode', () async {
      await packNotifier.leavePack();
      expect(packNotifier.state.isInPack, isFalse);

      await packNotifier.joinPack('GN-7721');
      expect(packNotifier.state.isInPack, isTrue);
      expect(packNotifier.state.packCode, equals('GN-7721'));
      expect(packNotifier.state.title, equals('Pack Formation #GN-7721'));
      expect(packNotifier.state.isTelemetrySyncActive, isTrue);
    });

    test('joinPack parses full QR JSON pairing payload accurately', () {
      packNotifier.leavePack();
      expect(packNotifier.state.isInPack, isFalse);

      const qrPayload = '{"action":"join_pack","code":"GN-3391","packId":"3391","timestamp":1729012391000}';
      packNotifier.joinPack(qrPayload);

      expect(packNotifier.state.isInPack, isTrue);
      expect(packNotifier.state.packCode, equals('GN-3391'));
      expect(packNotifier.state.packId, equals('3391'));
      expect(packNotifier.state.title, equals('Pack Formation #GN-3391'));
      expect(packNotifier.state.isTelemetrySyncActive, isTrue);
    });

    test('joinPack normalizes bare numeric code with GN- prefix', () {
      packNotifier.leavePack();
      expect(packNotifier.state.isInPack, isFalse);

      packNotifier.joinPack('8842');

      expect(packNotifier.state.isInPack, isTrue);
      expect(packNotifier.state.packCode, equals('GN-8842'));
      expect(packNotifier.state.packId, equals('8842'));
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
      expect(packNotifier.state.members.first.isRoadCaptain, isTrue);
      expect(packNotifier.state.members.first.offsetDescription, contains('Road Captain'));
    });

    test('createPack supports custom title, code, geofence, and formation discipline', () {
      packNotifier.leavePack();
      expect(packNotifier.state.isInPack, isFalse);

      packNotifier.createPack(
        customTitle: 'Skyline Sunset Cruise',
        customCode: 'GN-4422',
        geofenceRadius: 1500.0,
        formationType: 'SINGLE_FILE',
      );

      expect(packNotifier.state.isInPack, isTrue);
      expect(packNotifier.state.packCode, equals('GN-4422'));
      expect(packNotifier.state.title, equals('Skyline Sunset Cruise'));
      expect(packNotifier.state.geofenceRadiusMeters, equals(1500.0));
      expect(packNotifier.state.formationType, equals('SINGLE_FILE'));
      expect(packNotifier.state.formationLabel, equals('Single File'));
      expect(packNotifier.state.formationDescription, contains('Mountain'));
      expect(radarNotifier.state.geofenceRadiusMeters, equals(1500.0));
    });

    test('PackFormation returns correct formation descriptions for all presets', () {
      const staggered = PackFormation(formationType: 'STAGGERED');
      expect(staggered.formationLabel, equals('Staggered (2s)'));

      const singleFile = PackFormation(formationType: 'SINGLE_FILE');
      expect(singleFile.formationLabel, equals('Single File'));

      const freeFlight = PackFormation(formationType: 'FREE_FLIGHT');
      expect(freeFlight.formationLabel, equals('Free Cruise'));
    });

    test('assignMemberRole promotes and updates member role properly', () async {
      await packNotifier.joinPack('GN-1234');
      packNotifier.state = packNotifier.state.copyWith(
        members: [
          const PackMember(
            id: 'rider-1',
            callsign: 'Captain',
            initials: 'CP',
            status: PackMemberStatus.lead,
            speedKmh: 80,
            offsetMeters: 0,
            offsetDescription: 'Lead',
            role: PackRole.roadCaptain,
          ),
          const PackMember(
            id: 'rider-2',
            callsign: 'Sweeper',
            initials: 'SW',
            status: PackMemberStatus.inBounds,
            speedKmh: 75,
            offsetMeters: 200,
            offsetDescription: 'Pack Rider',
            role: PackRole.packMember,
          ),
        ],
      );

      await packNotifier.assignMemberRole('rider-2', PackRole.tailGunner);
      final member = packNotifier.state.members.firstWhere((m) => m.id == 'rider-2');
      expect(member.role, equals(PackRole.tailGunner));
      expect(member.isTailGunner, isTrue);
      expect(member.offsetDescription, contains('Tail Gunner'));
    });

    test('kickMember removes member from pack roster', () async {
      await packNotifier.joinPack('GN-1234');
      packNotifier.state = packNotifier.state.copyWith(
        members: [
          const PackMember(
            id: 'rider-1',
            callsign: 'Captain',
            initials: 'CP',
            status: PackMemberStatus.lead,
            speedKmh: 80,
            offsetMeters: 0,
            offsetDescription: 'Lead',
            role: PackRole.roadCaptain,
          ),
          const PackMember(
            id: 'rider-2',
            callsign: 'BadRider',
            initials: 'BR',
            status: PackMemberStatus.warning,
            speedKmh: 120,
            offsetMeters: 900,
            offsetDescription: 'Disruptive',
            role: PackRole.packMember,
          ),
        ],
      );

      await packNotifier.kickMember('rider-2');
      expect(packNotifier.state.members.length, equals(1));
      expect(packNotifier.state.members.any((m) => m.id == 'rider-2'), isFalse);
    });

    test('toggleRoomLock sets isLocked on formation', () async {
      await packNotifier.joinPack('GN-1234');
      expect(packNotifier.state.isLocked, isFalse);

      await packNotifier.toggleRoomLock(true);
      expect(packNotifier.state.isLocked, isTrue);

      await packNotifier.toggleRoomLock(false);
      expect(packNotifier.state.isLocked, isFalse);
    });

    test('scanAndJoinQr parses QR payload and joins pack', () async {
      await packNotifier.scanAndJoinQr('https://groupnav.app/join/GN-8811');
      expect(packNotifier.state.isInPack, isTrue);
      expect(packNotifier.state.packCode, equals('GN-8811'));
    });
  });

  group('Step 14: Convoy Hierarchy, Roles & Universal Share Tests', () {
    test('PackMember role badges, icons, and colors derive accurately', () {
      const captain = PackMember(
        id: 'c1',
        callsign: 'LeadRider',
        initials: 'LR',
        status: PackMemberStatus.lead,
        speedKmh: 90,
        offsetMeters: 0,
        offsetDescription: 'Lead',
        role: PackRole.roadCaptain,
      );
      expect(captain.isRoadCaptain, isTrue);
      expect(captain.isTailGunner, isFalse);
      expect(captain.roleLabel, equals('Road Captain'));

      const sweeper = PackMember(
        id: 's1',
        callsign: 'SweeperRider',
        initials: 'SR',
        status: PackMemberStatus.inBounds,
        speedKmh: 85,
        offsetMeters: 400,
        offsetDescription: 'Tail',
        role: PackRole.tailGunner,
      );
      expect(sweeper.isTailGunner, isTrue);
      expect(sweeper.isRoadCaptain, isFalse);
      expect(sweeper.roleLabel, equals('Tail Gunner'));

      const member = PackMember(
        id: 'm1',
        callsign: 'PackRider',
        initials: 'PR',
        status: PackMemberStatus.inBounds,
        speedKmh: 88,
        offsetMeters: 150,
        offsetDescription: 'Pack',
        role: PackRole.packMember,
      );
      expect(member.isRoadCaptain, isFalse);
      expect(member.isTailGunner, isFalse);
      expect(member.roleLabel, equals('Pack Member'));
    });

    test('PackFormation generates correct universal shareLink and evaluates captain hierarchy', () {
      const formation = PackFormation(
        packCode: 'GN-4921',
        hostRiderId: 'pilot-100',
        members: [
          PackMember(
            id: 'pilot-100',
            callsign: 'Captain',
            initials: 'CP',
            status: PackMemberStatus.lead,
            speedKmh: 80,
            offsetMeters: 0,
            offsetDescription: '',
            role: PackRole.roadCaptain,
          ),
          PackMember(
            id: 'pilot-200',
            callsign: 'Member',
            initials: 'MB',
            status: PackMemberStatus.inBounds,
            speedKmh: 80,
            offsetMeters: 100,
            offsetDescription: '',
            role: PackRole.packMember,
          ),
        ],
      );

      expect(formation.shareLink, equals('https://groupnav.app/join/GN-4921'));
      expect(formation.isCaptain('pilot-100'), isTrue);
      expect(formation.isCaptain('pilot-200'), isFalse);
      expect(formation.isCaptain('unknown'), isFalse);
    });

    test('ProductionQrScannerService parses various QR payload formats correctly', () {
      final qrService = ProductionQrScannerService();

      // Deep link URL
      expect(qrService.parseQrPayload('https://groupnav.app/join/GN-7721'), equals('GN-7721'));
      expect(qrService.parseQrPayload('https://groupnav.app/join/4422'), equals('GN-4422'));

      // JSON payload
      const jsonStr = '{"action":"join_pack","code":"GN-9900","packId":"9900"}';
      expect(qrService.parseQrPayload(jsonStr), equals('GN-9900'));

      // Direct codes
      expect(qrService.parseQrPayload('GN-1234'), equals('GN-1234'));
      expect(qrService.parseQrPayload('pack-5678'), equals('GN-5678'));
      expect(qrService.parseQrPayload('9482'), equals('GN-9482'));

      // Invalid
      expect(qrService.parseQrPayload(''), isNull);
    });

    testWidgets('PackRosterCard displays tactical role badges and captain moderation menu', (tester) async {
      PackRole? assignedRole;
      bool kicked = false;

      const member = PackMember(
        id: 'r-2',
        callsign: 'Phantom',
        initials: 'PH',
        status: PackMemberStatus.inBounds,
        speedKmh: 85,
        offsetMeters: 200,
        offsetDescription: '+200m',
        role: PackRole.packMember,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PackRosterCard(
              member: member,
              canModerate: true,
              onRoleChanged: (r) => assignedRole = r,
              onKick: () => kicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Phantom'), findsOneWidget);
      expect(find.text('Pack Member'), findsOneWidget);

      // Tap moderation more_vert icon
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Assign as Tail Gunner'), findsOneWidget);
      expect(find.text('Kick from Convoy'), findsOneWidget);

      // Select Assign Tail Gunner
      await tester.tap(find.text('Assign as Tail Gunner'));
      await tester.pumpAndSettle();

      expect(assignedRole, equals(PackRole.tailGunner));

      // Reopen menu and test Kick action
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kick from Convoy'));
      await tester.pumpAndSettle();

      expect(kicked, isTrue);
    });

    testWidgets('ActiveCodeCard shows universal share button and locked badge', (tester) async {
      bool? lockToggled;

      const formation = PackFormation(
        packCode: 'GN-8844',
        isLocked: true,
        hostRiderId: 'pilot-1',
        members: [
          PackMember(
            id: 'pilot-1',
            callsign: 'Captain',
            initials: 'CP',
            status: PackMemberStatus.lead,
            speedKmh: 0,
            offsetMeters: 0,
            offsetDescription: '',
            role: PackRole.roadCaptain,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveCodeCard(
              formation: formation,
              onExpandMap: () {},
              qrPayload: '{"code":"GN-8844"}',
              isCaptain: true,
              onToggleLock: (val) => lockToggled = val,
            ),
          ),
        ),
      );

      expect(find.text('GN-8844'), findsOneWidget);
      expect(find.text('LOCKED'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Room Locked (Entrants Blocked)'), findsOneWidget);

      // Toggle switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(lockToggled, isFalse);
    });

    testWidgets('CameraQrScannerModal renders tactical targeting reticle and controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraQrScannerModal(
              onCodeScanned: (code) {},
            ),
          ),
        ),
      );

      expect(find.text('OPTICAL QR SCANNER'), findsOneWidget);
      expect(find.text("Align Road Captain's QR Code or bike sticker within the frame"), findsOneWidget);
      expect(find.byIcon(Icons.flash_off), findsOneWidget);
      expect(find.byIcon(Icons.keyboard), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Test flashlight toggle
      await tester.tap(find.byIcon(Icons.flash_off));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.flash_on), findsOneWidget);
    });
  });
}
