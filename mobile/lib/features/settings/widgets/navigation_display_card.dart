import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/rider_settings.dart';

class NavigationDisplayCard extends StatelessWidget {
  final RiderSettings settings;
  final ValueChanged<UnitSystem> onUnitSystemChanged;
  final ValueChanged<MapThemeMode> onMapThemeChanged;
  final ValueChanged<bool> onToggleKeepScreenAwake;

  const NavigationDisplayCard({
    super.key,
    required this.settings,
    required this.onUnitSystemChanged,
    required this.onMapThemeChanged,
    required this.onToggleKeepScreenAwake,
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
            'Navigation & Display',
            style: AppTypography.headlineMd.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Screen behavior and dashboard units',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 12),

          // 1. Speed & Distance Units
          Text(
            'Speed & Distance Units',
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
                  child: _buildSegmentButton(
                    label: 'Metric (km/h)',
                    isSelected: settings.unitSystem == UnitSystem.metric,
                    onTap: () => onUnitSystemChanged(UnitSystem.metric),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildSegmentButton(
                    label: 'Imperial (mph)',
                    isSelected: settings.unitSystem == UnitSystem.imperial,
                    onTap: () => onUnitSystemChanged(UnitSystem.imperial),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Map Theme
          Text(
            'Map Theme',
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
                  child: _buildSegmentButton(
                    label: 'Day',
                    isSelected: settings.mapThemeMode == MapThemeMode.day,
                    onTap: () => onMapThemeChanged(MapThemeMode.day),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildSegmentButton(
                    label: 'Night',
                    isSelected: settings.mapThemeMode == MapThemeMode.night,
                    onTap: () => onMapThemeChanged(MapThemeMode.night),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildSegmentButton(
                    label: 'Auto (Sensor)',
                    isSelected: settings.mapThemeMode == MapThemeMode.system,
                    onTap: () => onMapThemeChanged(MapThemeMode.system),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 12),

          // 3. Keep Screen Awake While Riding
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keep Screen Awake While Riding',
                      style: AppTypography.labelLg.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Prevents device sleep during route tracking',
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
                value: settings.keepScreenAwake,
                onChanged: onToggleKeepScreenAwake,
                activeColor: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
