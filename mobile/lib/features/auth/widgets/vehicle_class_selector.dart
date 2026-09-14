import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';

class VehicleClassSelector extends StatelessWidget {
  final String selectedClass;
  final ValueChanged<String> onSelected;

  const VehicleClassSelector({
    super.key,
    required this.selectedClass,
    required this.onSelected,
  });

  static const List<Map<String, dynamic>> _classes = [
    {
      'id': 'sportbike',
      'label': 'Sportbike',
      'icon': Icons.two_wheeler,
    },
    {
      'id': 'adventure',
      'label': 'Adventure',
      'icon': Icons.terrain,
    },
    {
      'id': 'touring',
      'label': 'Touring',
      'icon': Icons.commute,
    },
    {
      'id': 'cruiser',
      'label': 'Cruiser',
      'icon': Icons.sports_motorsports,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VEHICLE CLASS CONFIGURATION',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 44,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _classes.length,
          itemBuilder: (context, index) {
            final item = _classes[index];
            final isSelected = selectedClass == item['id'];

            return InkWell(
              onTap: () => onSelected(item['id'] as String),
              borderRadius: AppTheme.radiusMd,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
                  borderRadius: AppTheme.radiusMd,
                  border: Border.all(
                    color: isSelected ? AppColors.primaryDark : AppColors.borderSubtle,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      size: 18,
                      color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item['label'] as String,
                      style: AppTypography.labelSm.copyWith(
                        color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (isSelected)
                      const Icon(Icons.check, size: 16, color: Colors.white),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
