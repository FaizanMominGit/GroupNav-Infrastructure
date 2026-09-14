import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';

class BeaconColorPicker extends StatelessWidget {
  final String selectedColorHex;
  final ValueChanged<String> onSelected;

  const BeaconColorPicker({
    super.key,
    required this.selectedColorHex,
    required this.onSelected,
  });

  static const List<Map<String, dynamic>> _swatches = [
    {'hex': '#00D4FF', 'name': 'Cyan', 'color': AppColors.routeCyan},
    {'hex': '#0066FF', 'name': 'Electric Blue', 'color': AppColors.primary},
    {'hex': '#FF9500', 'name': 'Amber', 'color': AppColors.alertWarning},
    {'hex': '#00C48C', 'name': 'Emerald', 'color': AppColors.telemetryEmerald},
  ];

  @override
  Widget build(BuildContext context) {
    final activeSwatch = _swatches.firstWhere(
      (s) => s['hex'] == selectedColorHex,
      orElse: () => _swatches[1],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CONVOY HUD BEACON COLOR',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              activeSwatch['name'] as String,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: AppTheme.radiusMd,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _swatches.map((swatch) {
              final hex = swatch['hex'] as String;
              final color = swatch['color'] as Color;
              final isSelected = selectedColorHex == hex;

              return InkWell(
                onTap: () => onSelected(hex),
                customBorder: const CircleBorder(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2.5,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
