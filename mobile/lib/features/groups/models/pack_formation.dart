import 'pack_member.dart';

class PackFormation {
  final String packId;
  final String packCode;
  final String title;
  final double geofenceRadiusMeters;
  final bool isTelemetrySyncActive;
  final bool isInPack;
  final List<PackMember> members;

  const PackFormation({
    this.packId = '804',
    this.packCode = 'GN-9482',
    this.title = 'Pack Formation #804',
    this.geofenceRadiusMeters = 850.0,
    this.isTelemetrySyncActive = true,
    this.isInPack = true,
    this.members = const [],
  });

  String get formattedRadius {
    if (geofenceRadiusMeters >= 1000) {
      final km = geofenceRadiusMeters / 1000;
      return '${km.toStringAsFixed(1)}km';
    }
    return '${geofenceRadiusMeters.round()}m';
  }

  int get connectedCount => members.where((m) => m.status != PackMemberStatus.offline).length;

  PackFormation copyWith({
    String? packId,
    String? packCode,
    String? title,
    double? geofenceRadiusMeters,
    bool? isTelemetrySyncActive,
    bool? isInPack,
    List<PackMember>? members,
  }) {
    return PackFormation(
      packId: packId ?? this.packId,
      packCode: packCode ?? this.packCode,
      title: title ?? this.title,
      geofenceRadiusMeters: geofenceRadiusMeters ?? this.geofenceRadiusMeters,
      isTelemetrySyncActive: isTelemetrySyncActive ?? this.isTelemetrySyncActive,
      isInPack: isInPack ?? this.isInPack,
      members: members ?? this.members,
    );
  }
}
