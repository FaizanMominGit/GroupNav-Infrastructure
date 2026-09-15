import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Floating Spatial Top App Bar Pill (Layer Z-20)
class TopAppBarPill extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onMenuPressed;
  final double rewardRate;
  final String nodeStatus;
  final String signalPercent;

  const TopAppBarPill({
    super.key,
    this.title = 'GroupNav',
    this.subtitle = 'DePIN',
    this.onMenuPressed,
    this.rewardRate = 4.2,
    this.nodeStatus = 'NODE 01',
    this.signalPercent = '99.8%',
  });

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: AppTheme.radiusFull,
            boxShadow: AppTheme.elevationLevel2,
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Brand Moniker & Menu
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, size: 20, color: AppColors.onSurfaceVariant),
                      splashRadius: 18,
                      onPressed: onMenuPressed,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineMd.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed.withValues(alpha: 0.5),
                          borderRadius: AppTheme.radiusSm,
                        ),
                        child: Text(
                          subtitle!,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Right: Live Telemetry Node Ping & Reward Ticker
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppTheme.radiusFull,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.telemetryEmerald,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '+$rewardRate NAV/hr',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
