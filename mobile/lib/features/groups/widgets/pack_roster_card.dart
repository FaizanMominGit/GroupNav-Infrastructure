import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/pack_member.dart';

class PackRosterCard extends StatelessWidget {
  final PackMember member;
  final VoidCallback? onPing;

  const PackRosterCard({
    super.key,
    required this.member,
    this.onPing,
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
            width: 40,
            height: 40,
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
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name and Speed (Left)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        member.callsign,
                        style: AppTypography.headlineMd.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isOffline ? AppColors.textSecondary : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isLead) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(You)',
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isOffline
                      ? (member.lastSeenDescription ?? 'Offline · 3m ago')
                      : '${member.speedKmh.round()} km/h',
                  style: AppTypography.bodySm.copyWith(
                    fontSize: 12,
                    color: isWarning
                        ? AppColors.alertWarning
                        : AppColors.textSecondary,
                    fontWeight: isWarning ? FontWeight.w600 : FontWeight.w400,
                  ),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                        ? 'Lagging +790m'
                        : 'With Pack',
                style: AppTypography.labelSm.copyWith(
                  color: isLead || isWarning
                      ? Colors.white
                      : AppColors.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
