import 'pack_member.dart';

class PackFormation {
  final String packId;
  final String packCode;
  final String title;
  final double geofenceRadiusMeters;
  final bool isTelemetrySyncActive;
  final bool isInPack;
  final String formationType;
  final List<PackMember> members;
  final bool isLocked;
  final String hostRiderId;
  final String status;

  const PackFormation({
    this.packId = '',
    this.packCode = '',
    this.title = 'Solo Ride Mode',
    this.geofenceRadiusMeters = 800.0,
    this.isTelemetrySyncActive = false,
    this.isInPack = false,
    this.formationType = 'STAGGERED',
    this.members = const [],
    this.isLocked = false,
    this.hostRiderId = '',
    this.status = 'active',
  });

  String get shareLink => 'https://groupnav.app/join/$packCode';

  bool isCaptain(String? riderId) {
    if (hostRiderId.isNotEmpty && riderId == hostRiderId) return true;
    final leadMember = members.where((m) => m.isRoadCaptain).firstOrNull;
    return leadMember != null && leadMember.id == riderId;
  }

  String get formattedRadius {
    if (geofenceRadiusMeters >= 1000) {
      final km = geofenceRadiusMeters / 1000;
      return '${km.toStringAsFixed(1)}km';
    }
    return '${geofenceRadiusMeters.round()}m';
  }

  String get formationLabel {
    switch (formationType.toUpperCase()) {
      case 'SINGLE_FILE':
        return 'Single File';
      case 'FREE_FLIGHT':
        return 'Free Cruise';
      case 'STAGGERED':
      default:
        return 'Staggered (2s)';
    }
  }

  String get formationDescription {
    switch (formationType.toUpperCase()) {
      case 'SINGLE_FILE':
        return 'Mountain & Twisties formation';
      case 'FREE_FLIGHT':
        return 'Open highway free spacing';
      case 'STAGGERED':
      default:
        return '2-second lane zigzag spacing';
    }
  }

  int get connectedCount => members.where((m) => m.status != PackMemberStatus.offline).length;

  PackFormation copyWith({
    String? packId,
    String? packCode,
    String? title,
    double? geofenceRadiusMeters,
    bool? isTelemetrySyncActive,
    bool? isInPack,
    String? formationType,
    List<PackMember>? members,
    bool? isLocked,
    String? hostRiderId,
    String? status,
  }) {
    return PackFormation(
      packId: packId ?? this.packId,
      packCode: packCode ?? this.packCode,
      title: title ?? this.title,
      geofenceRadiusMeters: geofenceRadiusMeters ?? this.geofenceRadiusMeters,
      isTelemetrySyncActive: isTelemetrySyncActive ?? this.isTelemetrySyncActive,
      isInPack: isInPack ?? this.isInPack,
      formationType: formationType ?? this.formationType,
      members: members ?? this.members,
      isLocked: isLocked ?? this.isLocked,
      hostRiderId: hostRiderId ?? this.hostRiderId,
      status: status ?? this.status,
    );
  }
}
