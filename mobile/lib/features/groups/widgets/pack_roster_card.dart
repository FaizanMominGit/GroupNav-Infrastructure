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
      decoration: BoxDecoration(
        color: isWarning
            ? const Color(0xFFFFFBEB) // subtle amber-50
            : AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
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
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Left lead highlight bar
            if (isLead)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: Container(color: AppColors.primary),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Avatar with status ping dot
                  Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
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
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: member.dotColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Rider Moniker and Status Metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              member.callsign,
                              style: AppTypography.headlineMd.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isOffline ? AppColors.textSecondary : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: member.statusBadgeColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                member.statusBadgeLabel,
                                style: AppTypography.labelSm.copyWith(
                                  fontSize: 10,
                                  color: member.statusBadgeTextColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (isLead) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(You)',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Subtitle information
                        Row(
                          children: [
                            if (isLead) ...[
                              const Icon(Icons.wifi, size: 13, color: AppColors.telemetryEmerald),
                              const SizedBox(width: 3),
                              Text(
                                'Connected',
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('•', style: AppTypography.bodySm),
                              const SizedBox(width: 6),
                              Text(
                                member.offsetDescription,
                                style: AppTypography.bodySm.copyWith(
                                  fontFamily: 'monospace',
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ] else if (member.status == PackMemberStatus.inBounds) ...[
                              Text(
                                member.offsetDescription,
                                style: AppTypography.bodySm.copyWith(
                                  fontFamily: 'monospace',
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (member.latencyMs != null) ...[
                                const SizedBox(width: 6),
                                Text('•', style: AppTypography.bodySm),
                                const SizedBox(width: 6),
                                Text(
                                  'Latency: ${member.latencyMs}ms',
                                  style: AppTypography.bodySm.copyWith(fontSize: 11),
                                ),
                              ],
                            ] else if (isWarning) ...[
                              Text(
                                member.offsetDescription,
                                style: AppTypography.bodySm.copyWith(
                                  fontFamily: 'monospace',
                                  color: AppColors.alertWarning,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ] else ...[
                              Text(
                                member.lastSeenDescription ?? 'Offline',
                                style: AppTypography.bodySm.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Speed Readout & Status Tag
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isOffline) ...[
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${member.speedKmh.round()} ',
                                style: AppTypography.telemetryNum.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: 'km/h',
                                style: AppTypography.bodySm.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Text(
                          '-- km/h',
                          style: AppTypography.telemetryNum.copyWith(
                            color: AppColors.outline,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),

                      // Status Badge / Action
                      if (isLead) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified, size: 13, color: AppColors.telemetryEmerald),
                            const SizedBox(width: 3),
                            Text(
                              'Leader',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.telemetryEmerald,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ] else if (member.status == PackMemberStatus.inBounds) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'In Bounds',
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 10,
                              color: AppColors.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ] else if (isWarning) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.alertWarning),
                            const SizedBox(width: 3),
                            Text(
                              member.warningDescription ?? 'Near Limit',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.alertWarning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        GestureDetector(
                          onTap: onPing,
                          child: Text(
                            'Ping Rider',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
