import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/pack_formation.dart';
import 'collapsed_mini_map.dart';

class ActiveCodeCard extends StatelessWidget {
  final PackFormation formation;
  final VoidCallback onExpandMap;
  final String qrPayload;
  final bool isCaptain;
  final ValueChanged<bool>? onToggleLock;
  final VoidCallback? onDisband;

  const ActiveCodeCard({
    super.key,
    required this.formation,
    required this.onExpandMap,
    this.qrPayload = '',
    this.isCaptain = false,
    this.onToggleLock,
    this.onDisband,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Code display and copy/share action
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'PACK JOIN CODE',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (formation.isLocked) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.alertWarning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.alertWarning.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock, size: 10, color: AppColors.alertWarning),
                                const SizedBox(width: 3),
                                Text(
                                  'LOCKED',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.alertWarning,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Monospace Code Container
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryFixed.withValues(alpha: 0.40),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
                            ),
                            child: Text(
                              formation.packCode,
                              style: AppTypography.headlineLg.copyWith(
                                fontFamily: 'monospace',
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Copy Code Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: formation.packCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Pack code "${formation.packCode}" copied!'),
                                    backgroundColor: AppColors.primary,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.content_copy, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Copy',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Universal Share Link Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: formation.shareLink));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Convoy invite link copied:\n${formation.shareLink}'),
                                    backgroundColor: AppColors.primary,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.share, size: 14, color: AppColors.secondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Share',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Road Captain Moderation Control Pill
          if (isCaptain) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: formation.isLocked
                    ? AppColors.alertWarning.withValues(alpha: 0.08)
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: formation.isLocked
                      ? AppColors.alertWarning.withValues(alpha: 0.3)
                      : AppColors.borderSubtle,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        formation.isLocked ? Icons.lock : Icons.lock_open,
                        size: 16,
                        color: formation.isLocked ? AppColors.alertWarning : AppColors.telemetryEmerald,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formation.isLocked ? 'Room Locked (Entrants Blocked)' : 'Room Open (Riders Can Join)',
                            style: AppTypography.labelSm.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: formation.isLocked ? AppColors.alertWarning : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            formation.isLocked ? 'Switch to unlock' : 'Switch to prevent new riders',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: formation.isLocked,
                    onChanged: onToggleLock,
                    activeColor: AppColors.alertWarning,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Formation Discipline Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.alt_route, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Formation: ${formation.formationLabel}',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: Text(
                    formation.formationDescription,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Collapsed Static Mini-Map Preview
          CollapsedMiniMap(
            formation: formation,
            onExpandMap: onExpandMap,
          ),
        ],
      ),
    );
  }
}
