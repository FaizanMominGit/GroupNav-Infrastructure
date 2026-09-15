import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../radar/providers/radar_provider.dart';
import '../models/pack_formation.dart';
import '../models/pack_member.dart';

final packNotifierProvider = StateNotifierProvider<PackNotifier, PackFormation>((ref) {
  final radarNotifier = ref.watch(radarNotifierProvider.notifier);
  return PackNotifier(radarNotifier);
});

class PackNotifier extends StateNotifier<PackFormation> {
  final RadarNotifier _radarNotifier;

  PackNotifier(this._radarNotifier) : super(_defaultFormation());

  static PackFormation _defaultFormation() {
    return const PackFormation(
      packId: '804',
      packCode: 'GN-9482',
      title: 'Pack Formation #804',
      geofenceRadiusMeters: 850.0,
      isTelemetrySyncActive: true,
      members: [
        PackMember(
          id: 'apex-lead',
          callsign: 'Apex',
          initials: 'AP',
          status: PackMemberStatus.lead,
          speedKmh: 82.0,
          offsetMeters: 0.0,
          offsetDescription: '0m offset',
          latencyMs: 8,
          isLeader: true,
        ),
        PackMember(
          id: 'viper-peer',
          callsign: 'Viper',
          initials: 'VP',
          status: PackMemberStatus.inBounds,
          speedKmh: 80.0,
          offsetMeters: 140.0,
          offsetDescription: '+140m ahead',
          latencyMs: 12,
        ),
        PackMember(
          id: 'ghost-peer',
          callsign: 'Ghost',
          initials: 'GH',
          status: PackMemberStatus.warning,
          speedKmh: 75.0,
          offsetMeters: 790.0,
          offsetDescription: '+790m near edge',
          warningDescription: '60m to limit',
          latencyMs: 15,
        ),
        PackMember(
          id: 'nomad-peer',
          callsign: 'Nomad',
          initials: 'NM',
          status: PackMemberStatus.offline,
          speedKmh: 0.0,
          offsetMeters: 1250.0,
          offsetDescription: 'Offline',
          lastSeenDescription: 'Last seen 3m ago',
        ),
      ],
    );
  }

  void updateGeofenceRadius(double radius) {
    final clamped = radius.clamp(200.0, 5000.0);
    state = state.copyWith(geofenceRadiusMeters: clamped);
    _radarNotifier.updateGeofenceRadius(clamped);
  }

  void pingRider(String memberId) {
    // In production, publish MQTT chime packet to `groupnav/convoy/804/chime`
  }

  void broadcastSos() {
    // In production, publish high-priority emergency packet to `groupnav/convoy/804/alerts`
  }

  String generateQrPayload() {
    return jsonEncode({
      'action': 'join_pack',
      'code': state.packCode,
      'packId': state.packId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void leavePack() {
    state = state.copyWith(
      isInPack: false,
      packCode: '',
      packId: '',
      title: 'Solo Ride Mode',
      isTelemetrySyncActive: false,
      members: const [
        PackMember(
          id: 'apex-lead',
          callsign: 'Apex (You)',
          initials: 'AP',
          status: PackMemberStatus.lead,
          speedKmh: 0.0,
          offsetMeters: 0.0,
          offsetDescription: 'Solo Rider',
          latencyMs: 5,
          isLeader: true,
        ),
      ],
    );
  }

  void joinPack(String code) {
    final cleanCode = code.trim().toUpperCase();
    state = state.copyWith(
      isInPack: true,
      packCode: cleanCode,
      packId: cleanCode.replaceAll('GN-', ''),
      title: 'Pack Formation #$cleanCode',
      isTelemetrySyncActive: true,
      members: _defaultFormation().members,
    );
  }

  void createPack() {
    final randomNum = 1000 + (DateTime.now().millisecondsSinceEpoch % 9000);
    final code = 'GN-$randomNum';
    state = state.copyWith(
      isInPack: true,
      packCode: code,
      packId: randomNum.toString(),
      title: 'Pack Formation #$code',
      isTelemetrySyncActive: true,
      members: [
        const PackMember(
          id: 'apex-lead',
          callsign: 'Apex (Lead)',
          initials: 'AP',
          status: PackMemberStatus.lead,
          speedKmh: 0.0,
          offsetMeters: 0.0,
          offsetDescription: 'Convoy Lead',
          latencyMs: 5,
          isLeader: true,
        ),
      ],
    );
  }

  void disbandConvoy() {
    leavePack();
  }
}
