import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../radar/models/convoy_route.dart';
import '../../radar/providers/radar_provider.dart';
import '../../radar/services/iot_telemetry_service.dart';
import '../models/pack_formation.dart';
import '../models/pack_member.dart';
import '../services/dynamodb_pack_service.dart';
import '../services/qr_scanner_service.dart';

final dynamoDbPackServiceProvider = Provider<DynamoDbPackService>((ref) {
  final config = ref.watch(clientConfigProvider);
  return DynamoDbPackService(config: config);
});

final qrScannerServiceProvider = Provider<IQrScannerService>((ref) {
  return ProductionQrScannerService();
});

final packNotifierProvider = StateNotifierProvider<PackNotifier, PackFormation>((ref) {
  final radarNotifier = ref.watch(radarNotifierProvider.notifier);
  final packService = ref.watch(dynamoDbPackServiceProvider);
  final telemetryService = ref.watch(iotTelemetryServiceProvider);
  final qrService = ref.watch(qrScannerServiceProvider);
  return PackNotifier(radarNotifier, packService, ref, telemetryService, qrService);
});

class PackNotifier extends StateNotifier<PackFormation> {
  final RadarNotifier? _radarNotifier;
  final DynamoDbPackService? _packService;
  final Ref? _ref;
  final IotTelemetryService? _telemetryService;
  final IQrScannerService? _qrScannerService;
  Timer? _rosterSyncTimer;
  StreamSubscription? _telemetrySub;
  static const _storage = FlutterSecureStorage();
  static const _activePackKey = 'groupnav_active_pack_code';

  PackNotifier([
    this._radarNotifier,
    this._packService,
    this._ref,
    this._telemetryService,
    this._qrScannerService,
  ]) : super(_soloFormation()) {
    _initRiderIdentity();
    _listenToTelemetryForRoster();
    _radarNotifier?.onRouteBroadcast = (route) {
      syncRouteToDynamoDb(route);
    };
  }

  static PackFormation _soloFormation([String callsign = 'Pilot']) {
    final effectiveCallsign = callsign.isNotEmpty ? callsign : 'Pilot';
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
          callsign: effectiveCallsign,
          initials: effectiveCallsign.length >= 2 ? effectiveCallsign.substring(0, 2).toUpperCase() : 'ME',
          status: PackMemberStatus.lead,
          speedKmh: 0.0,
          offsetMeters: 0.0,
          offsetDescription: 'Solo Rider',
          latencyMs: 0,
          isLeader: true,
          role: PackRole.roadCaptain,
          isCurrentUser: true,
        ),
      ],
    );
  }

  void _initRiderIdentity() {
    _restoreSavedPack();
    
    if (_ref != null) {
      final currentAuth = _ref.read(authNotifierProvider);
      if (!state.isInPack && currentAuth.pilot != null) {
        state = _soloFormation(currentAuth.pilot!.callsign);
      }
    }
    _ref?.listen(authNotifierProvider, (previous, next) {
      if (!state.isInPack && next.pilot != null) {
        state = _soloFormation(next.pilot!.callsign);
      }
    });
  }

  Future<void> _safeStorageWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('[PackNotifier] Secure storage write error: $e');
    }
  }

  Future<void> _safeStorageDelete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('[PackNotifier] Secure storage delete error: $e');
    }
  }

  Future<void> _restoreSavedPack() async {
    try {
      final savedCode = await _storage.read(key: _activePackKey);
      if (savedCode != null && savedCode.isNotEmpty && _ref != null && _packService != null) {
        final auth = _ref.read(authNotifierProvider);
        final creds = auth.awsCredentials;
        if (creds != null) {
          try {
            final restored = await _packService.getPack(
              packCode: savedCode,
              awsCredentials: creds,
              currentRiderId: auth.pilot?.cognitoIdentityId ?? auth.pilot?.phoneOrEmail,
            );
            if (restored != null && mounted) {
              state = restored.copyWith(isInPack: true);
              _radarNotifier?.updateGeofenceRadius(restored.geofenceRadiusMeters);
              if (restored.activeRoute != null) {
                _radarNotifier?.setRoute(restored.activeRoute!, broadcast: false);
              }
              _telemetryService?.updateActivePack(restored.packCode);
              _startRosterPolling(restored.packCode);
              debugPrint('[PackNotifier] Restored active pack room: $savedCode from DynamoDB');
              return;
            }
          } catch (e) {
            debugPrint('[PackNotifier] Failed to restore saved pack $savedCode: $e');
          }
        }
        // If we reach here, we failed to restore or it's not active anymore.
        await _safeStorageDelete(_activePackKey);
      }
    } catch (e) {
      debugPrint('[PackNotifier] Secure storage read error: $e');
    }
  }

  void updateRiderCallsign(String newCallsign) {
    if (newCallsign.trim().isEmpty) return;
    final updatedMembers = state.members.map((m) {
      if (m.isCurrentUser) {
        return m.copyWith(
          callsign: newCallsign,
          initials: newCallsign.length >= 2 ? newCallsign.substring(0, 2).toUpperCase() : 'ME',
        );
      }
      return m;
    }).toList();
    
    // Update local state (solo or pack)
    state = state.copyWith(
      members: updatedMembers,
      // If Solo, update title or leave it. We just update members.
    );
  }

  void updateGeofenceRadius(double radius) {
    final clamped = radius.clamp(200.0, 5000.0);
    state = state.copyWith(geofenceRadiusMeters: clamped);
    _radarNotifier?.updateGeofenceRadius(clamped);

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
    final packId = state.packId.isNotEmpty ? state.packId : 'convoy';
    const message = 'CRITICAL: Rider requested immediate emergency response.';
    if (_telemetryService != null) {
      _telemetryService.publishAlert(
        packId: packId,
        alertType: 'Emergency SOS',
        callsign: callsign,
        message: message,
      );
    } else {
      _radarNotifier?.publishAlert(
        packId: packId,
        alertType: 'Emergency SOS',
        callsign: callsign,
        message: message,
      );
    }
  }

  String generateQrPayload() {
    return jsonEncode({
      'action': 'join_pack',
      'code': state.packCode,
      'packId': state.packId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Promote or demote a member's role (Road Captain only)
  Future<void> assignMemberRole(String memberId, PackRole newRole) async {
    final updatedMembers = state.members.map((m) {
      if (m.id == memberId) {
        final newDesc = newRole == PackRole.tailGunner
            ? 'Tail Gunner (Sweeper)'
            : (newRole == PackRole.roadCaptain ? 'Road Captain' : 'Pack Rider');
        return m.copyWith(
          role: newRole,
          offsetDescription: newDesc,
          isLeader: newRole == PackRole.roadCaptain,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(members: updatedMembers);

    if (state.isInPack && state.packCode.isNotEmpty && _ref != null && _packService != null) {
      final auth = _ref.read(authNotifierProvider);
      final creds = auth.awsCredentials;
      if (creds != null) {
        _packService.updateMemberRole(
          packCode: state.packCode,
          memberId: memberId,
          newRole: newRole,
          awsCredentials: creds,
        ).catchError((e) {
          debugPrint('[PackNotifier] Role update AWS error: $e');
        });
      }
    }
  }

  /// Kick a disruptive member from the convoy (Road Captain only)
  Future<void> kickMember(String memberId) async {
    final updatedMembers = state.members.where((m) => m.id != memberId).toList();
    state = state.copyWith(members: updatedMembers);

    if (state.isInPack && state.packCode.isNotEmpty && _ref != null && _packService != null) {
      final auth = _ref.read(authNotifierProvider);
      final creds = auth.awsCredentials;
      if (creds != null) {
        _packService.kickMember(
          packCode: state.packCode,
          memberId: memberId,
          awsCredentials: creds,
        ).catchError((e) {
          debugPrint('[PackNotifier] Kick member AWS error: $e');
        });
      }
    }
  }

  /// Toggle room lock against new entrants (Road Captain only)
  Future<void> toggleRoomLock(bool isLocked) async {
    state = state.copyWith(isLocked: isLocked);

    if (state.isInPack && state.packCode.isNotEmpty && _ref != null && _packService != null) {
      final auth = _ref.read(authNotifierProvider);
      final creds = auth.awsCredentials;
      if (creds != null) {
        _packService.setPackLocked(
          packCode: state.packCode,
          isLocked: isLocked,
          awsCredentials: creds,
        ).catchError((e) {
          debugPrint('[PackNotifier] Set lock AWS error: $e');
        });
      }
    }
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

    final callsign = auth?.pilot?.callsign ?? 'Pilot';
    state = _soloFormation(callsign);
    _telemetryService?.updateActivePack('');
    await _safeStorageDelete(_activePackKey);
  }

  /// Disband active convoy for everyone (Road Captain only)
  Future<void> disbandConvoy() async {
    if (state.isInPack && state.packCode.isNotEmpty && _ref != null && _packService != null) {
      final auth = _ref.read(authNotifierProvider);
      final creds = auth.awsCredentials;
      if (creds != null) {
        try {
          await _packService.disbandPack(
            packCode: state.packCode,
            awsCredentials: creds,
          );
        } catch (e) {
          debugPrint('[PackNotifier] Disband pack AWS error: $e');
        }
      }
    }
    await leavePack();
    await _safeStorageDelete(_activePackKey);
  }

  /// Scan QR payload and join the pack automatically
  Future<void> scanAndJoinQr(String qrData) async {
    final qrService = _qrScannerService ?? ProductionQrScannerService();
    final parsedCode = qrService.parseQrPayload(qrData);
    if (parsedCode == null || parsedCode.isEmpty) {
      throw Exception('Invalid GroupNav QR code or link format.');
    }
    await joinPack(parsedCode);
  }

  /// Create a real convoy room on AWS DynamoDB
  Future<void> createPack({
    String? customTitle,
    String? customCode,
    double? geofenceRadius,
    String formationType = 'STAGGERED',
  }) async {
    final effectiveRadius = geofenceRadius ?? state.geofenceRadiusMeters;

    if (_ref == null || _packService == null) {
      final code = (customCode != null && customCode.trim().isNotEmpty)
          ? (customCode.trim().toUpperCase().startsWith('GN-')
              ? customCode.trim().toUpperCase()
              : 'GN-${customCode.trim().toUpperCase()}')
          : 'GN-1000';
      final title = (customTitle != null && customTitle.trim().isNotEmpty)
          ? customTitle.trim()
          : 'Pack Formation #$code';

      const hostCallsign = 'Pilot';
      state = state.copyWith(
        isInPack: true,
        packCode: code,
        packId: code.replaceAll(RegExp(r'[^0-9]'), ''),
        title: title,
        geofenceRadiusMeters: effectiveRadius,
        formationType: formationType,
        isTelemetrySyncActive: true,
        isLocked: false,
        hostRiderId: 'solo-rider',
        members: [
          PackMember(
            id: 'solo-rider',
            callsign: hostCallsign,
            initials: hostCallsign.length >= 2 ? hostCallsign.substring(0, 2).toUpperCase() : 'ME',
            status: PackMemberStatus.lead,
            speedKmh: 0.0,
            offsetMeters: 0.0,
            offsetDescription: 'Road Captain (Host)',
            latencyMs: 0,
            isLeader: true,
            role: PackRole.roadCaptain,
            isCurrentUser: true,
          ),
        ],
      );
      _radarNotifier?.updateGeofenceRadius(effectiveRadius);
      _telemetryService?.updateActivePack(code);
      return;
    }

    final auth = _ref.read(authNotifierProvider);
    final creds = auth.awsCredentials;
    if (creds == null) {
      final randomNum = 1000 + (DateTime.now().millisecondsSinceEpoch % 9000);
      final code = (customCode != null && customCode.trim().isNotEmpty)
          ? (customCode.trim().toUpperCase().startsWith('GN-')
              ? customCode.trim().toUpperCase()
              : 'GN-${customCode.trim().toUpperCase()}')
          : 'GN-$randomNum';
      final title = (customTitle != null && customTitle.trim().isNotEmpty)
          ? customTitle.trim()
          : 'Pack Formation #$code';

      final hostCallsign = auth.pilot?.callsign ?? 'Pilot';
      state = state.copyWith(
        isInPack: true,
        packCode: code,
        packId: code.replaceAll(RegExp(r'[^0-9]'), ''),
        title: title,
        geofenceRadiusMeters: effectiveRadius,
        formationType: formationType,
        isTelemetrySyncActive: true,
        isLocked: false,
        hostRiderId: 'solo-rider',
        members: [
          PackMember(
            id: 'solo-rider',
            callsign: hostCallsign,
            initials: hostCallsign.length >= 2 ? hostCallsign.substring(0, 2).toUpperCase() : 'ME',
            status: PackMemberStatus.lead,
            speedKmh: 0.0,
            offsetMeters: 0.0,
            offsetDescription: 'Road Captain (Host)',
            latencyMs: 0,
            isLeader: true,
            role: PackRole.roadCaptain,
            isCurrentUser: true,
          ),
        ],
      );
      _radarNotifier?.updateGeofenceRadius(effectiveRadius);
      _telemetryService?.updateActivePack(code);
      return;
    }

    final randomNum = 1000 + (DateTime.now().millisecondsSinceEpoch % 9000);
    final code = (customCode != null && customCode.trim().isNotEmpty)
        ? (customCode.trim().toUpperCase().startsWith('GN-')
            ? customCode.trim().toUpperCase()
            : 'GN-${customCode.trim().toUpperCase()}')
        : 'GN-$randomNum';

    final title = (customTitle != null && customTitle.trim().isNotEmpty)
        ? customTitle.trim()
        : 'Pack Formation #$code';

    final pilot = auth.pilot;
    final riderId = pilot?.cognitoIdentityId ?? 'rider-$randomNum';
    final callsign = pilot?.callsign ?? 'Captain';
    final vehicleClass = pilot?.vehicleClass ?? 'SPORT';
    final initialRoute = _radarNotifier?.state.activeRoute;

    final formation = await _packService.createPack(
      packCode: code,
      title: title,
      hostRiderId: riderId,
      hostCallsign: callsign,
      bikeModel: vehicleClass,
      geofenceRadiusMeters: effectiveRadius,
      formationType: formationType,
      activeRoute: initialRoute,
      awsCredentials: creds,
    );

    state = formation.copyWith(
      isInPack: true,
      hostRiderId: riderId,
    );
    _radarNotifier?.updateGeofenceRadius(effectiveRadius);
    _telemetryService?.updateActivePack(formation.packCode);
    await _safeStorageWrite(_activePackKey, formation.packCode);
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

    final qrService = _qrScannerService ?? ProductionQrScannerService();
    cleanCode = qrService.parseQrPayload(cleanCode) ?? cleanCode;

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
      _telemetryService?.updateActivePack(cleanCode);
      return;
    }

    final auth = _ref.read(authNotifierProvider);
    final creds = auth.awsCredentials;
    if (creds == null) {
      throw Exception('Not authenticated with AWS. Please sign in first.');
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

    state = formation.copyWith(isInPack: true);
    if (formation.activeRoute != null) {
      _radarNotifier?.setRoute(formation.activeRoute!, broadcast: false);
      debugPrint('[PackNotifier] Applied active pack route ${formation.activeRoute?.title} from DynamoDB upon join');
    }
    _telemetryService?.updateActivePack(formation.packCode);
    await _safeStorageWrite(_activePackKey, formation.packCode);
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
          currentRiderId: auth.pilot?.cognitoIdentityId ?? auth.pilot?.phoneOrEmail,
        );
        if (latest != null && mounted) {
          state = latest.copyWith(isInPack: true);
          if (latest.activeRoute != null &&
              latest.activeRoute?.id != _radarNotifier?.state.activeRoute?.id) {
            _radarNotifier?.setRoute(latest.activeRoute!, broadcast: false);
            debugPrint('[PackNotifier] Received new route update ${latest.activeRoute?.title} via DynamoDB roster poll');
          }
        }
      } catch (_) {}
    });
  }

  /// Persist active navigation route to AWS DynamoDB
  Future<void> syncRouteToDynamoDb(ConvoyRoute? route) async {
    state = state.copyWith(activeRoute: route, clearRoute: route == null);
    if (!state.isInPack || state.packCode.isEmpty || _ref == null || _packService == null) return;
    final auth = _ref.read(authNotifierProvider);
    final creds = auth.awsCredentials;
    if (creds == null) return;

    try {
      await _packService.updatePackRoute(
        packCode: state.packCode,
        route: route,
        awsCredentials: creds,
      );
      debugPrint('[PackNotifier] Successfully synced active route ${route?.title} to DynamoDB pack ${state.packCode}');
    } catch (e) {
      debugPrint('[PackNotifier] Error persisting active route to DynamoDB: $e');
    }
  }

  void _listenToTelemetryForRoster() {
    _telemetrySub?.cancel();
    _telemetrySub = _telemetryService?.convoyStream.listen((peers) {
      if (!mounted || !state.isInPack || state.members.isEmpty) return;

      bool hasChanges = false;
      final updatedMembers = state.members.map((member) {
        final cleanMemberCallsign = member.callsign.replaceAll(' (You)', '').trim().toLowerCase();
        final match = peers.where((p) {
          final cleanPeerCallsign = p.callsign.replaceAll(' (You)', '').trim().toLowerCase();
          return cleanPeerCallsign == cleanMemberCallsign;
        }).firstOrNull;

        if (match != null) {
          final newSpeed = match.speedKmh;
          final newOffset = match.relativeOffsetMeters;
          final absOffset = newOffset.abs();

          String newDesc;
          if (member.isLeader) {
            newDesc = newSpeed > 5 ? '${newSpeed.round()} km/h · Leading' : 'Road Captain';
          } else if (absOffset < 20) {
            newDesc = 'With Pack';
          } else {
            final formattedDist = absOffset >= 1000
                ? '${(absOffset / 1000).toStringAsFixed(1)}km'
                : '${absOffset.round()}m';
            newDesc = newOffset >= 0 ? '+$formattedDist ahead' : '$formattedDist behind';
          }

          if (member.speedKmh != newSpeed ||
              (member.offsetMeters - newOffset).abs() > 2 ||
              member.offsetDescription != newDesc) {
            hasChanges = true;
            return member.copyWith(
              speedKmh: newSpeed,
              offsetMeters: newOffset,
              offsetDescription: newDesc,
            );
          }
        }
        return member;
      }).toList();

      if (hasChanges) {
        state = state.copyWith(members: updatedMembers);
      }
    });
  }

  @override
  void dispose() {
    _rosterSyncTimer?.cancel();
    _telemetrySub?.cancel();
    super.dispose();
  }
}
