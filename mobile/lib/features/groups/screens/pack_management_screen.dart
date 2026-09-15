import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/pack_provider.dart';
import '../widgets/active_code_card.dart';
import '../widgets/geofence_slider_widget.dart';
import '../widgets/pack_roster_card.dart';

class PackManagementScreen extends ConsumerWidget {
  final VoidCallback onExpandMap;

  const PackManagementScreen({
    super.key,
    required this.onExpandMap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formation = ref.watch(packNotifierProvider);
    final packNotifier = ref.read(packNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg.withValues(alpha: 0.95),
            border: const Border(bottom: BorderSide(color: AppColors.borderSubtle)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.navigation,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            formation.title,
                            style: AppTypography.headlineMd.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.telemetryEmerald,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'ACTIVE TELEMETRY SYNC',
                                style: AppTypography.labelSm.copyWith(
                                  fontSize: 10,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Share Pack Details Action
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Convoy invite code "${formation.packCode}" copied to share!'),
                          backgroundColor: AppColors.primary,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.share, color: AppColors.primary),
                    tooltip: 'Share Pack Details',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // 1. Active Group Code & Collapsed Mini-Map Preview Card
          ActiveCodeCard(
            formation: formation,
            onExpandMap: onExpandMap,
            qrPayload: packNotifier.generateQrPayload(),
          ),
          const SizedBox(height: 16),

          // 2. Dynamic Geofence Radius Slider Widget
          GeofenceSliderWidget(
            formation: formation,
            onRadiusChanged: (val) => packNotifier.updateGeofenceRadius(val),
          ),
          const SizedBox(height: 20),

          // 3. Live Pack Roster Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Live Pack Roster',
                    style: AppTypography.headlineMd.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${formation.connectedCount} Connected',
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 10,
                        color: AppColors.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.telemetryEmerald,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Redis Spatial ms-sync',
                    style: AppTypography.labelSm.copyWith(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4. List of Convoy Participants
          ...formation.members.map((member) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: PackRosterCard(
                member: member,
                onPing: () {
                  packNotifier.pingRider(member.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Spatial ping sent to ${member.callsign}'),
                      backgroundColor: AppColors.primary,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            );
          }),
          const SizedBox(height: 16),

          // 5. High-Emphasis SOS Broadcast Section
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _confirmSosBroadcast(context, packNotifier),
              icon: const Icon(Icons.emergency, size: 22, color: Colors.white),
              label: Text(
                'BROADCAST PACK SOS (EMERGENCY)',
                style: AppTypography.labelLg.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.alertCritical,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Broadcasts instantaneous critical alert and GPS coordinates to all convoy units',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),

          // 6. Disband Convoy Option (Leader action)
          Center(
            child: TextButton.icon(
              onPressed: () => _confirmDisband(context, packNotifier),
              icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
              label: Text(
                'Disband Active Formation',
                style: AppTypography.labelMd.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSosBroadcast(BuildContext context, PackNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.emergency, color: AppColors.alertCritical),
            const SizedBox(width: 8),
            const Text('Confirm Pack SOS'),
          ],
        ),
        content: const Text(
          'This will transmit a high-priority emergency packet to AWS IoT Core topic "groupnav/convoy/804/alerts" and trigger siren haptics on all connected convoy units.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              notifier.broadcastSos();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('EMERGENCY SOS BROADCAST ACTIVE!'),
                  backgroundColor: AppColors.alertCritical,
                  duration: Duration(seconds: 4),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertCritical,
              foregroundColor: Colors.white,
            ),
            child: const Text('Broadcast Now'),
          ),
        ],
      ),
    );
  }

  void _confirmDisband(BuildContext context, PackNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Disband Convoy?'),
        content: const Text(
          'Are you sure you want to disband this active convoy? Connected riders will be disconnected from the spatial sync mesh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              notifier.disbandConvoy();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Convoy formation disbanded.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertWarning,
              foregroundColor: Colors.white,
            ),
            child: const Text('Disband'),
          ),
        ],
      ),
    );
  }
}
