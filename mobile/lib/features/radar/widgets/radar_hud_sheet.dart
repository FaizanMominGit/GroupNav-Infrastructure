import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/radar_provider.dart';

class RadarHudSheet extends StatelessWidget {
  final RadarState state;
  final VoidCallback onToggleBroadcast;

  const RadarHudSheet({
    super.key,
    required this.state,
    required this.onToggleBroadcast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: AppTheme.elevationLevel3,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle Indicator Pill
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSubtle,
              borderRadius: AppTheme.radiusFull,
            ),
          ),
          const SizedBox(height: 12),

          // 4-Card Bento Metric Strip
          Row(
            children: [
              // 1. Speed
              Expanded(
                child: _buildMetricCard(
                  label: 'SPEED',
                  value: state.currentSpeed.round().toString(),
                  unit: 'km/h',
                  valueColor: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),

              // 2. Heading
              Expanded(
                child: _buildMetricCard(
                  label: 'HEADING',
                  value: state.headingDisplay.split(' ').first,
                  unit: state.headingDisplay.split(' ').last,
                  valueColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),

              // 3. Elevation
              Expanded(
                child: _buildMetricCard(
                  label: 'ELEVATION',
                  value: state.currentElevation.round().toString(),
                  unit: 'meters',
                  valueColor: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),

              // 4. Pack Cohesion
              Expanded(
                child: _buildMetricCard(
                  label: 'COHESION',
                  value: '${state.packCohesion}%',
                  unit: state.cohesionStatus,
                  valueColor: AppColors.secondary,
                  unitColor: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // AWS IoT Core MQTT Live Broadcast Controller Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppTheme.radiusLg,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Pulsing Emerald Indicator
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: state.isBroadcasting
                            ? AppColors.telemetryEmerald
                            : AppColors.outlineVariant,
                        shape: BoxShape.circle,
                        boxShadow: state.isBroadcasting
                            ? [
                                BoxShadow(
                                  color: AppColors.telemetryEmerald.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'AWS IoT Core MQTT',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryFixed,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'QoS 1',
                                style: AppTypography.labelSm.copyWith(
                                  fontSize: 9,
                                  color: AppColors.onSecondaryFixedVariant,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          state.isBroadcasting ? 'Online / Broadcasting' : 'Paused / Offline',
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.w700,
                            color: state.isBroadcasting ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Hardware Style Toggle Switch
                Switch(
                  value: state.isBroadcasting,
                  onChanged: (_) => onToggleBroadcast(),
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primaryFixed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String unit,
    required Color valueColor,
    Color? unitColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              fontSize: 9,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.telemetryNum.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            unit,
            style: AppTypography.labelSm.copyWith(
              fontSize: 10,
              color: unitColor ?? AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
