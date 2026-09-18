import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../models/convoy_route.dart';

class RouteSelectionSheet extends StatelessWidget {
  final ConvoyRoute? currentRoute;
  final ValueChanged<ConvoyRoute> onSelectRoute;

  const RouteSelectionSheet({
    super.key,
    required this.currentRoute,
    required this.onSelectRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle.withValues(alpha: 0.8)),
        ),
        boxShadow: AppTheme.elevationLevel3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: AppTheme.radiusFull,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.route_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONVOY NAVIGATION COURSES',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Designate Pack Route',
                      style: AppTypography.headlineMd.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Road Captain Authority Notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Road Captain Authority: Selecting a course will immediately broadcast waypoints to all convoy riders via AWS IoT Core.',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Route Cards List
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: ConvoyRoute.defaultRoutes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final route = ConvoyRoute.defaultRoutes[index];
                final isSelected = currentRoute?.id == route.id;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    onSelectRoute(route);
                    Navigator.of(context).pop();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.borderSubtle,
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                route.title,
                                style: AppTypography.labelLg.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: AppTheme.radiusFull,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check, color: Colors.white, size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      'ACTIVE',
                                      style: AppTypography.labelSm.copyWith(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          route.description,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Badges Row
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildBadge(
                              icon: Icons.straighten,
                              label: '${route.distanceKm.toStringAsFixed(1)} km',
                              color: AppColors.textPrimary,
                            ),
                            _buildBadge(
                              icon: Icons.timer_outlined,
                              label: '${route.estimatedMinutes} min',
                              color: AppColors.textPrimary,
                            ),
                            _buildBadge(
                              icon: Icons.terrain_outlined,
                              label: '+${route.elevationGainMeters.round()}m',
                              color: AppColors.secondary,
                            ),
                            _buildBadge(
                              icon: Icons.group_work_outlined,
                              label: route.recommendedFormation,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
