import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/pack_member.dart';

class PackRosterCard extends StatelessWidget {
  final PackMember member;
  final VoidCallback? onPing;
  final ValueChanged<PackRole>? onRoleChanged;
  final VoidCallback? onKick;
  final bool canModerate;

  const PackRosterCard({
    super.key,
    required this.member,
    this.onPing,
    this.onRoleChanged,
    this.onKick,
    this.canModerate = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLead = member.status == PackMemberStatus.lead;
    final isWarning = member.status == PackMemberStatus.warning;
    final isOffline = member.status == PackMemberStatus.offline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isWarning
            ? AppColors.alertWarning.withValues(alpha: 0.08)
            : isOffline
                ? AppColors.cardBg.withValues(alpha: 0.7)
                : AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLead
              ? AppColors.primary.withValues(alpha: 0.35)
              : isWarning
                  ? AppColors.alertWarning.withValues(alpha: 0.40)
                  : AppColors.borderSubtle,
          width: isLead ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: member.avatarBackgroundColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              member.initials,
              style: AppTypography.labelLg.copyWith(
                color: member.avatarTextColor,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name, Role Badge, and Speed (Left)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: Prominent Rider Callsign + Lead Star / You Tag
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        member.cleanCallsign,
                        style: AppTypography.headlineMd.copyWith(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: isOffline ? AppColors.textSecondary : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (member.isRoadCaptain) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.star, size: 14, color: AppColors.primary),
                    ],
                    if (member.isCurrentUser || member.callsign.contains('(You)')) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 0.8),
                        ),
                        child: Text(
                          'You',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 9,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),

                // Row 2: Live Speed + Role Tag
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isOffline
                          ? (member.lastSeenDescription ?? 'Offline · 3m ago')
                          : '${member.speedKmh.round()} km/h',
                      style: AppTypography.bodySm.copyWith(
                        fontSize: 12,
                        color: isWarning ? AppColors.alertWarning : AppColors.textSecondary,
                        fontWeight: isWarning ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '•',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: member.roleBadgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: member.roleBadgeColor.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(member.roleIcon, size: 9.5, color: member.roleBadgeColor),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                member.roleLabel,
                                style: AppTypography.labelSm.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: member.roleBadgeColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right: Status Badge or Ping Button
          if (isOffline)
            InkWell(
              onTap: onPing,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(
                  'Ping',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: isLead
                    ? AppColors.primary
                    : isWarning
                        ? AppColors.alertWarning
                        : AppColors.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isLead
                    ? 'Leader'
                    : isWarning
                        ? (member.offsetDescription.isNotEmpty ? member.offsetDescription : 'Lagging')
                        : (member.offsetDescription.isNotEmpty ? member.offsetDescription : 'With Pack'),
                style: AppTypography.labelSm.copyWith(
                  color: isLead || isWarning
                      ? Colors.white
                      : AppColors.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                ),
              ),
            ),

          // Road Captain Moderation Menu
          if (canModerate) ...[
            const SizedBox(width: 2),
            SizedBox(
              width: 22,
              height: 28,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              onSelected: (action) {
                if (action == 'assign_sweeper') {
                  onRoleChanged?.call(PackRole.tailGunner);
                } else if (action == 'assign_member') {
                  onRoleChanged?.call(PackRole.packMember);
                } else if (action == 'kick') {
                  onKick?.call();
                }
              },
              itemBuilder: (ctx) => [
                if (member.role != PackRole.tailGunner)
                  const PopupMenuItem(
                    value: 'assign_sweeper',
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 16, color: AppColors.telemetryEmerald),
                        SizedBox(width: 8),
                        Text('Assign as Tail Gunner'),
                      ],
                    ),
                  ),
                if (member.role == PackRole.tailGunner)
                  const PopupMenuItem(
                    value: 'assign_member',
                    child: Row(
                      children: [
                        Icon(Icons.two_wheeler, size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Set Regular Member'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'kick',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove, size: 16, color: AppColors.alertCritical),
                      SizedBox(width: 8),
                      Text('Kick from Convoy', style: TextStyle(color: AppColors.alertCritical)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
  }
}
