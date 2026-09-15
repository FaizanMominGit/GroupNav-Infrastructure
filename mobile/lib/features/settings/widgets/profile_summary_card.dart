import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/models/pilot_profile.dart';

class ProfileSummaryCard extends StatelessWidget {
  final PilotProfile pilot;

  const ProfileSummaryCard({super.key, required this.pilot});

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
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
              border: Border.all(
                color: Color(pilot.beaconColorValue),
                width: 2.5,
              ),
            ),
            child: Center(
              child: Icon(
                _getVehicleIcon(pilot.vehicleClass),
                color: AppColors.primary,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      pilot.callsign,
                      style: AppTypography.headlineMd.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.telemetryEmerald.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.telemetryEmerald.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.telemetryEmerald,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'NODE ACTIVE',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.telemetryEmerald,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      pilot.vehicleClass,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: AppTypography.bodySm.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        pilot.phoneOrEmail,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getVehicleIcon(String vehicleClass) {
    switch (vehicleClass.toLowerCase()) {
      case 'sportbike':
        return Icons.two_wheeler;
      case 'adventure':
        return Icons.terrain;
      case 'touring':
        return Icons.navigation_outlined;
      case 'cruiser':
        return Icons.motorcycle;
      default:
        return Icons.two_wheeler;
    }
  }
}
