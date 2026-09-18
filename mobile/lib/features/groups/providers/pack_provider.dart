import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../radar/providers/radar_provider.dart';
import '../models/pack_formation.dart';
import '../models/pack_member.dart';
import '../services/dynamodb_pack_service.dart';

final dynamoDbPackServiceProvider = Provider<DynamoDbPackService>((ref) {
  final config = ref.watch(clientConfigProvider);
  return DynamoDbPackService(config: config);
});

final packNotifierProvider = StateNotifierProvider<PackNotifier, PackFormation>((ref) {
  final radarNotifier = ref.watch(radarNotifierProvider.notifier);
  final packService = ref.watch(dynamoDbPackServiceProvider);
  return PackNotifier(radarNotifier, packService, ref);
});

class PackNotifier extends StateNotifier<PackFormation> {
  final RadarNotifier _radarNotifier;
  final DynamoDbPackService? _packService;
  final Ref? _ref;
  Timer? _rosterSyncTimer;

  PackNotifier(
    this._radarNotifier, [
    this._packService,
    this._ref,
  ]) : super(_soloFormation()) {
    _initRiderIdentity();
  }

  static PackFormation _soloFormation([String callsign = 'Apex']) {
    return PackFormation(
      packId: '',
      packCode: '',
      title: 'Solo Ride Mode',
      geofenceRadiusMeters: 800.0,
      isTelemetrySyncActive: false,
      isInPack: false,
      members: [
        PackMember(
          id: 'solo-rider',
          callsign: '$callsign (You)',
          initials: callsign.length >= 2 ? callsign.substring(0, 2).toUpperCase() : 'ME',
          status: PackMemberStatus.lead,
          speedKmh: 0.0,
          offsetMeters: 0.0,
          offsetDescription: 'Solo Rider',
          latencyMs: 0,
          isLeader: true,
        ),
      ],
    );
  }

  void _initRiderIdentity() {
    _ref?.listen(authNotifierProvider, (previous, next) {
      if (!state.isInPack && next.pilot != null) {
        state = _soloFormation(next.pilot!.callsign);
      }
    });
  }

  void updateGeofenceRadius(double radius) {
    final clamped = radius.clamp(200.0, 5000.0);
    state = state.copyWith(geofenceRadiusMeters: clamped);
    _radarNotifier.updateGeofenceRadius(clamped);

    // Sync to AWS DynamoDB if in an active pack
    if (state.isInPack && state.packCode.isNotEmpty && _ref != null && _packService != null) {
      final auth = _ref.read(authNotifierProvider);
      final creds = auth.awsCredentials;
      if (creds != null) {
        _packService.updateGeofenceRadius(
          packCode: state.packCode,
          radiusMeters: clamped,
          awsCredentials: creds,
        ).catchError((e) {
          debugPrint('[PackNotifier] Geofence AWS sync error: $e');
        });
      }
    }
  }

  void pingRider(String memberId) {
    // In production, publish MQTT chime packet
  }

  void broadcastSos() {
    final callsign = _ref?.read(authNotifierProvider).pilot?.callsign ?? 'Pilot';
    _radarNotifier.publishAlert(
      packId: state.packId.isNotEmpty ? state.packId : 'convoy',
      alertType: 'Emergency SOS',
      callsign: callsign,
      message: 'CRITICAL: Rider requested immediate emergency response.',
    );
  }

  String generateQrPayload() {
    return jsonEncode({
      'action': 'join_pack',
      'code': state.packCode,
      'packId': state.packId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Leave the active convoy pack and revert to Solo Ride Mode
  Future<void> leavePack() async {
    _rosterSyncTimer?.cancel();
    final auth = _ref?.read(authNotifierProvider);
    final creds = auth?.awsCredentials;
    final riderId = auth?.pilot?.cognitoIdentityId ?? 'solo-rider';

    if (state.isInPack && state.packCode.isNotEmpty && creds != null && _packService != null) {
      try {
        await _packService.leavePack(
          packCode: state.packCode,
          riderId: riderId,
          awsCredentials: creds,
        );
      } catch (e) {
        debugPrint('[PackNotifier] Leave pack AWS error: $e');
      }
    }

    final callsign = auth?.pilot?.callsign ?? 'Apex';
    state = _soloFormation(callsign);
  }

  /// Disband active convoy (alias to leavePack)
  Future<void> disbandConvoy() => leavePack();

  /// Create a real convoy room on AWS DynamoDB
  Future<void> createPack() async {
    if (_ref == null || _packService == null) {
      state = state.copyWith(
        isInPack: true,
        packCode: 'GN-1000',
        packId: '1000',
        title: 'Pack Formation #GN-1000',
        isTelemetrySyncActive: true,
        members: [
          const PackMember(
            id: 'solo-rider',
            callsign: 'Apex (You)',
            initials: 'AP',
            status: PackMemberStatus.lead,
            speedKmh: 0.0,
            offsetMeters: 0.0,
            offsetDescription: 'Convoy Lead',
            latencyMs: 0,
            isLeader: true,
          ),
        ],
      );
      return;
    }

    final auth = _ref.read(authNotifierProvider);
    final creds = auth.awsCredentials;
    if (creds == null) {
      throw Exception('Not authenticated with AWS. Please sign in first.');
    }

    final randomNum = 1000 + (DateTime.now().millisecondsSinceEpoch % 9000);
    final code = 'GN-$randomNum';
    final pilot = auth.pilot;
    final riderId = pilot?.cognitoIdentityId ?? 'rider-$randomNum';
    final callsign = pilot?.callsign ?? 'Captain';
    final vehicleClass = pilot?.vehicleClass ?? 'SPORT';

    final formation = await _packService.createPack(
      packCode: code,
      title: 'Pack Formation #$code',
      hostRiderId: riderId,
      hostCallsign: callsign,
      bikeModel: vehicleClass,
      geofenceRadiusMeters: state.geofenceRadiusMeters,
      awsCredentials: creds,
    );

    state = formation;
    _startRosterPolling(code);
  }

  /// Join a real convoy room on AWS DynamoDB
  Future<void> joinPack(String rawInput) async {
    String cleanCode = rawInput.trim();
    if (cleanCode.startsWith('{') && cleanCode.endsWith('}')) {
      try {
        final decoded = jsonDecode(cleanCode) as Map<String, dynamic>;
        cleanCode = decoded['code']?.toString() ?? cleanCode;
      } catch (_) {}
    }

    cleanCode = cleanCode.toUpperCase();
    if (!cleanCode.startsWith('GN-') && !cleanCode.startsWith('PACK-')) {
      cleanCode = 'GN-$cleanCode';
    }

    if (_ref == null || _packService == null) {
      final packId = cleanCode.replaceFirst(RegExp(r'^(GN-|PACK-)'), '');
      state = state.copyWith(
        isInPack: true,
        packCode: cleanCode,
        packId: packId,
        title: 'Pack Formation #$cleanCode',
        isTelemetrySyncActive: true,
      );
      return;
    }

    final auth = _ref.read(authNotifierProvider);
    final creds = auth.awsCredentials;
    if (creds == null) {
      throw Exception('Not authenticated with AWS. Please sign in first.');
    }

    cleanCode = cleanCode.toUpperCase();
    if (!cleanCode.startsWith('GN-') && !cleanCode.startsWith('PACK-')) {
      cleanCode = 'GN-$cleanCode';
    }

    final pilot = auth.pilot;
    final riderId = pilot?.cognitoIdentityId ?? 'rider-${DateTime.now().millisecondsSinceEpoch}';
    final callsign = pilot?.callsign ?? 'Pilot';
    final vehicleClass = pilot?.vehicleClass ?? 'SPORT';

    final formation = await _packService.joinPack(
      packCode: cleanCode,
      riderId: riderId,
      callsign: callsign,
      bikeModel: vehicleClass,
      awsCredentials: creds,
    );

    state = formation;
    _startRosterPolling(cleanCode);
  }

  void _startRosterPolling(String packCode) {
    _rosterSyncTimer?.cancel();
    _rosterSyncTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!state.isInPack || state.packCode != packCode || _ref == null || _packService == null) return;
      final auth = _ref.read(authNotifierProvider);
      final creds = auth.awsCredentials;
      if (creds == null) return;

      try {
        final latest = await _packService.getPack(
          packCode: packCode,
          awsCredentials: creds,
          currentRiderId: auth.pilot?.cognitoIdentityId,
        );
        if (latest != null && mounted) {
          state = latest;
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _rosterSyncTimer?.cancel();
    super.dispose();
  }
}
