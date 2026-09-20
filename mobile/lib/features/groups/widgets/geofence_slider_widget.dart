import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/pack_formation.dart';

class GeofenceSliderWidget extends StatelessWidget {
  final PackFormation formation;
  final ValueChanged<double> onRadiusChanged;

  const GeofenceSliderWidget({
    super.key,
    required this.formation,
    required this.onRadiusChanged,
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
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fence, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Pack Geofence Radius',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineMd.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Formatted live radius readout
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed.withValues(alpha: 0.40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formation.formattedRadius,
                  style: AppTypography.telemetryNum.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            'Dynamically scale formation bounds. Outer telemetry triggers automated ping.',
            style: AppTypography.bodySm.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),

          // Slider Track
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.surfaceContainerHigh,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.15),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: formation.geofenceRadiusMeters,
              min: 200,
              max: 5000,
              divisions: 96, // 50m intervals between 200m and 5000m
              onChanged: onRadiusChanged,
            ),
          ),

          // Bound markers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('200m', style: AppTypography.labelSm.copyWith(color: AppColors.textSecondary)),
                Text('1.0km', style: AppTypography.labelSm.copyWith(color: AppColors.textSecondary)),
                Text('2.5km', style: AppTypography.labelSm.copyWith(color: AppColors.textSecondary)),
                Text('5.0km', style: AppTypography.labelSm.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Warning Alert Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.alertWarning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.alertWarning.withValues(alpha: 0.30)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active,
                  size: 20,
                  color: AppColors.alertWarning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Riders alerted if radius breached',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
