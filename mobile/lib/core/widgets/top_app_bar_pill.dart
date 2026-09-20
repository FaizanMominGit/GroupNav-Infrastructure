import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Floating Spatial Top App Bar Pill (Layer Z-20)
class TopAppBarPill extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final String cloudStatus;

  const TopAppBarPill({
    super.key,
    this.title = 'GroupNav',
    this.subtitle = 'AWS Live',
    this.cloudStatus = 'AWS Cloud',
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: AppTheme.radiusFull,
            boxShadow: AppTheme.elevationLevel2,
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Brand Moniker
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.navigation, color: AppColors.primary, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineMd.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          fontSize: 16,
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
                            fontSize: 9.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Right: AWS Cloud Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppTheme.radiusFull,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.telemetryEmerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cloudStatus,
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
