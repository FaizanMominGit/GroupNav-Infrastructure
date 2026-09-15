import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/rider_settings.dart';

class DisplayPreferencesCard extends StatelessWidget {
  final RiderSettings settings;
  final ValueChanged<UnitSystem> onUnitSystemChanged;
  final ValueChanged<MapThemeMode> onMapThemeChanged;
  final ValueChanged<bool> onCohesionPingAudioChanged;

  const DisplayPreferencesCard({
    super.key,
    required this.settings,
    required this.onUnitSystemChanged,
    required this.onMapThemeChanged,
    required this.onCohesionPingAudioChanged,
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
              const Icon(Icons.palette_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Map & Display Preferences',
                style: AppTypography.labelLg.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Unit System
          Text(
            'MEASUREMENT SYSTEM',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: UnitSystem.values.map((unit) {
                final isSelected = settings.unitSystem == unit;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onUnitSystemChanged(unit),
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
                      child: Center(
                        child: Text(
                          unit.label,
                          style: AppTypography.labelMd.copyWith(
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 28, color: AppColors.borderSubtle),

          // Map Theme Mode
          Text(
            'MAP THEME',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: MapThemeMode.values.map((theme) {
                final isSelected = settings.mapThemeMode == theme;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onMapThemeChanged(theme),
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getThemeIcon(theme),
                            size: 16,
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            theme.label,
                            style: AppTypography.labelMd.copyWith(
                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

          const Divider(height: 28, color: AppColors.borderSubtle),

          // Cohesion Ping Audio Alert
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cohesion Audio Pulse',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Spatial audio pulse indicating convoy member proximity',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.cohesionPingAudio,
                onChanged: onCohesionPingAudioChanged,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primaryFixed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getThemeIcon(MapThemeMode theme) {
    switch (theme) {
      case MapThemeMode.day:
        return Icons.light_mode_outlined;
      case MapThemeMode.night:
        return Icons.dark_mode_outlined;
      case MapThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }
}
