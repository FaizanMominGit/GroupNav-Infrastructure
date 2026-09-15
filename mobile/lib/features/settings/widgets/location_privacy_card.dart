import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/rider_settings.dart';

class LocationPrivacyCard extends StatelessWidget {
  final RiderSettings settings;
  final ValueChanged<bool> onToggleShareLocation;
  final ValueChanged<GpsRate> onGpsRateChanged;

  const LocationPrivacyCard({
    super.key,
    required this.settings,
    required this.onToggleShareLocation,
    required this.onGpsRateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Text(
            'Location & Privacy',
            style: AppTypography.headlineMd.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Manage team visibility and positioning accuracy',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 12),

          // 1. Share Real-Time Location with Group
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share Real-Time Location with Group',
                      style: AppTypography.labelLg.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Broadcast telemetry and waypoint updates to pack',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(
                value: settings.shareRealTimeLocation,
                onChanged: onToggleShareLocation,
                activeColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 12),

          // 2. GPS Refresh Rate
          Text(
            'GPS Refresh Rate',
            style: AppTypography.labelMd.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildGpsSegmentButton(
                    label: 'Battery Saver (1s)',
                    isSelected: settings.gpsRate == GpsRate.oneHz,
                    onTap: () => onGpsRateChanged(GpsRate.oneHz),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildGpsSegmentButton(
                    label: 'Standard (500ms)',
                    isSelected: settings.gpsRate == GpsRate.fiveHz,
                    onTap: () => onGpsRateChanged(GpsRate.fiveHz),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildGpsSegmentButton(
                    label: 'High Precision (100ms)',
                    isSelected: settings.gpsRate == GpsRate.tenHz,
                    onTap: () => onGpsRateChanged(GpsRate.tenHz),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Subtitle disclaimer
          Text(
            'Your location is only shared with accepted pack members during an active ride.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsSegmentButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
