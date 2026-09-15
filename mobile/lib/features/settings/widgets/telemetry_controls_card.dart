import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/rider_settings.dart';

class TelemetryControlsCard extends StatelessWidget {
  final RiderSettings settings;
  final ValueChanged<GpsRate> onGpsRateChanged;
  final ValueChanged<bool> onBackgroundBroadcastChanged;
  final ValueChanged<bool> onHighPrecisionAlertChanged;

  const TelemetryControlsCard({
    super.key,
    required this.settings,
    required this.onGpsRateChanged,
    required this.onBackgroundBroadcastChanged,
    required this.onHighPrecisionAlertChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Telemetry & Hardware Controls',
                style: AppTypography.labelLg.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // GPS Rate Title & Subtitle
          Text(
            'GPS SAMPLING FREQUENCY',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          // 3-way Segmented Control
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: GpsRate.values.map((rate) {
                final isSelected = settings.gpsRate == rate;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onGpsRateChanged(rate),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.cardBg : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rate.shortLabel,
                            style: AppTypography.labelMd.copyWith(
                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getSubtitleForRate(rate),
                            style: AppTypography.bodySm.copyWith(
                              fontSize: 9,
                              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Current: ${settings.gpsRate.label} • Filter: ${settings.gpsRate.distanceFilterMeters}m',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),

          const Divider(height: 28, color: AppColors.borderSubtle),

          // Background Broadcast Toggle
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Background Telemetry Broadcast',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Keep publishing MQTT telemetry when app is minimized',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.backgroundBroadcast,
                onChanged: onBackgroundBroadcastChanged,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primaryFixed,
              ),
            ],
          ),

          const Divider(height: 28, color: AppColors.borderSubtle),

          // High-Precision Geofence Alert Toggle
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lane Departure Precision Alert',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Haptic warning when deviating >15m from convoy formation',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.highPrecisionGeofenceAlert,
                onChanged: onHighPrecisionAlertChanged,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primaryFixed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getSubtitleForRate(GpsRate rate) {
    switch (rate) {
      case GpsRate.oneHz:
        return 'Saver';
      case GpsRate.fiveHz:
        return 'Balanced';
      case GpsRate.tenHz:
        return 'Convoy Pro';
    }
  }
}
