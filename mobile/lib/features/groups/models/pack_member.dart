import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum PackMemberStatus {
  lead,
  inBounds,
  warning,
  offline,
}

enum PackRole {
  roadCaptain,
  tailGunner,
  packMember,
}

class PackMember {
  final String id;
  final String callsign;
  final String initials;
  final PackMemberStatus status;
  final double speedKmh;
  final double offsetMeters;
  final String offsetDescription;
  final int? latencyMs;
  final String? lastSeenDescription;
  final bool isLeader;
  final String? warningDescription;
  final PackRole role;

  const PackMember({
    required this.id,
    required this.callsign,
    required this.initials,
    required this.status,
    required this.speedKmh,
    required this.offsetMeters,
    required this.offsetDescription,
    this.latencyMs,
    this.lastSeenDescription,
    this.isLeader = false,
    this.warningDescription,
    this.role = PackRole.packMember,
  });

  bool get isRoadCaptain => role == PackRole.roadCaptain || isLeader;
  bool get isTailGunner => role == PackRole.tailGunner;

  String get roleLabel {
    switch (role) {
      case PackRole.roadCaptain:
        return 'Road Captain';
      case PackRole.tailGunner:
        return 'Tail Gunner';
      case PackRole.packMember:
        return 'Pack Member';
    }
  }

  IconData get roleIcon {
    switch (role) {
      case PackRole.roadCaptain:
        return Icons.star;
      case PackRole.tailGunner:
        return Icons.shield_outlined;
      case PackRole.packMember:
        return Icons.two_wheeler;
    }
  }

  Color get roleBadgeColor {
    switch (role) {
      case PackRole.roadCaptain:
        return const Color(0xFFEAB308); // Gold
      case PackRole.tailGunner:
        return AppColors.telemetryEmerald; // Emerald
      case PackRole.packMember:
        return AppColors.primary; // Blue
    }
  }

  String get statusBadgeLabel {
    switch (status) {
      case PackMemberStatus.lead:
        return 'LEAD';
      case PackMemberStatus.inBounds:
        return 'In Bounds';
      case PackMemberStatus.warning:
        return 'Warning';
      case PackMemberStatus.offline:
        return 'Offline';
    }
  }

  Color get statusBadgeColor {
    switch (status) {
      case PackMemberStatus.lead:
        return AppColors.primary;
      case PackMemberStatus.inBounds:
        return AppColors.secondaryContainer;
      case PackMemberStatus.warning:
        return AppColors.alertWarning.withValues(alpha: 0.2);
      case PackMemberStatus.offline:
        return AppColors.surfaceContainerHighest;
    }
  }

  Color get statusBadgeTextColor {
    switch (status) {
      case PackMemberStatus.lead:
        return Colors.white;
      case PackMemberStatus.inBounds:
        return AppColors.onSecondaryContainer;
      case PackMemberStatus.warning:
        return AppColors.alertWarning;
      case PackMemberStatus.offline:
        return AppColors.onSurfaceVariant;
    }
  }

  Color get avatarBackgroundColor {
    switch (status) {
      case PackMemberStatus.lead:
        return AppColors.primaryFixed;
      case PackMemberStatus.inBounds:
        return AppColors.surfaceContainer;
      case PackMemberStatus.warning:
        return const Color(0xFFFEF3C7); // amber-100
      case PackMemberStatus.offline:
        return AppColors.surfaceContainerHighest;
    }
  }

  Color get avatarTextColor {
    switch (status) {
      case PackMemberStatus.lead:
        return AppColors.primary;
      case PackMemberStatus.inBounds:
        return AppColors.textSecondary;
      case PackMemberStatus.warning:
        return AppColors.alertWarning;
      case PackMemberStatus.offline:
        return AppColors.outline;
    }
  }

  Color get dotColor {
    switch (status) {
      case PackMemberStatus.lead:
      case PackMemberStatus.inBounds:
        return AppColors.telemetryEmerald;
      case PackMemberStatus.warning:
        return AppColors.alertWarning;
      case PackMemberStatus.offline:
        return AppColors.outline;
    }
  }

  PackMember copyWith({
    String? id,
    String? callsign,
    String? initials,
    PackMemberStatus? status,
    double? speedKmh,
    double? offsetMeters,
    String? offsetDescription,
    int? latencyMs,
    String? lastSeenDescription,
    bool? isLeader,
    String? warningDescription,
    PackRole? role,
  }) {
    return PackMember(
      id: id ?? this.id,
      callsign: callsign ?? this.callsign,
      initials: initials ?? this.initials,
      status: status ?? this.status,
      speedKmh: speedKmh ?? this.speedKmh,
      offsetMeters: offsetMeters ?? this.offsetMeters,
      offsetDescription: offsetDescription ?? this.offsetDescription,
      latencyMs: latencyMs ?? this.latencyMs,
      lastSeenDescription: lastSeenDescription ?? this.lastSeenDescription,
      isLeader: isLeader ?? this.isLeader,
      warningDescription: warningDescription ?? this.warningDescription,
      role: role ?? this.role,
    );
  }
}
