import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/rider_settings.dart';

class ConvoyAlertsCard extends StatelessWidget {
  final RiderSettings settings;
  final ValueChanged<bool> onToggleGeofenceWarning;
  final ValueChanged<bool> onToggleSpeedAlert;

  const ConvoyAlertsCard({
    super.key,
    required this.settings,
    required this.onToggleGeofenceWarning,
    required this.onToggleSpeedAlert,
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
            'Ride & Convoy Alerts',
            style: AppTypography.headlineMd.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Visual HUD notifications during group rides',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 10),

          // Switch 1: Geofence Departure Warning
          _buildToggleRow(
            title: 'Geofence Departure Warning',
            subtitle: 'Notify when a rider leaves convoy radius',
            value: settings.geofenceDepartureWarning,
            onChanged: onToggleGeofenceWarning,
          ),
          const Divider(height: 16, color: AppColors.borderSubtle),

          // Switch 2: Speed Alert
          _buildToggleRow(
            title: 'Speed Alert',
            subtitle: 'Alert if leader accelerates over limit',
            value: settings.speedAlert,
            onChanged: onToggleSpeedAlert,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.labelLg.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
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
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ],
    );
  }
}
