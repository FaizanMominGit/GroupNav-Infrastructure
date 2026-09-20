import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/radar_provider.dart';

class RadarHudSheet extends StatelessWidget {
  final RadarState state;
  final VoidCallback onToggleBroadcast;
  final ValueChanged<String>? onSendQuickAlert;

  const RadarHudSheet({
    super.key,
    required this.state,
    required this.onToggleBroadcast,
    this.onSendQuickAlert,
  });

  void _triggerAlert(BuildContext context, String alertType) {
    if (alertType == 'Custom Message') {
      _showCustomMessageDialog(context);
      return;
    }
    if (onSendQuickAlert != null) {
      onSendQuickAlert!(alertType);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Convoy Alert Broadcast: "$alertType" sent to pack!'),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCustomMessageDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text('Custom Convoy Alert', style: AppTypography.headlineMd.copyWith(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Broadcast an immediate tactical status message to all convoy members via AWS IoT Core MQTT.',
              style: AppTypography.labelSm.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: AppTypography.bodyMd,
              decoration: InputDecoration(
                hintText: 'e.g. Road debris ahead, take left lane',
                hintStyle: AppTypography.bodySm.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.6)),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty && onSendQuickAlert != null) {
                onSendQuickAlert!(text);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.notifications_active, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Convoy Alert Broadcast: "$text"')),
                      ],
                    ),
                    backgroundColor: AppColors.primary,
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('BROADCAST'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: AppTheme.elevationLevel3,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle.withValues(alpha: 0.5)),
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
          const SizedBox(height: 8),

          // Live Broadcast & AWS IoT Beacon Bar
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: onToggleBroadcast,
                  borderRadius: AppTheme.radiusFull,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: state.isBroadcasting
                          ? AppColors.telemetryEmerald.withValues(alpha: 0.12)
                          : AppColors.alertWarning.withValues(alpha: 0.12),
                      borderRadius: AppTheme.radiusFull,
                      border: Border.all(
                        color: state.isBroadcasting
                            ? AppColors.telemetryEmerald.withValues(alpha: 0.3)
                            : AppColors.alertWarning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: state.isBroadcasting
                                ? AppColors.telemetryEmerald
                                : AppColors.alertWarning,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          state.isBroadcasting ? 'BROADCASTING LIVE' : 'BROADCAST PAUSED',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: state.isBroadcasting
                                ? AppColors.telemetryEmerald
                                : AppColors.alertWarning,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.isAwsConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppTheme.radiusFull,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_done,
                          size: 11,
                          color: AppColors.telemetryEmerald,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'IoT MQTT • ${state.broadcastCount} pkts',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 3-Card Bento Metric Grid
          Row(
            children: [
              // 1. Speed
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'SPEED',
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            state.currentSpeed.round().toString(),
                            style: AppTypography.telemetryNum.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'km/h',
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Heading
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'HEADING',
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            state.headingDisplay.split(' ').first,
                            style: AppTypography.telemetryNum.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            state.headingDisplay.split(' ').last,
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 3. Pack Status
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'PACK STATUS',
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                            state.cohesionStatus,
                            style: AppTypography.telemetryNum.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      Builder(
                        builder: (context) {
                          final riderCount = state.peers.isEmpty ? 1 : state.peers.length;
                          return Text(
                            '$riderCount ${riderCount == 1 ? 'Rider' : 'Riders'}',
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 9,
                              color: AppColors.textSecondary,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quick Convoy Status Alert Card
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'QUICK CONVOY STATUS',
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Tap to Alert Group',
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 10,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (state.activeAlert != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: state.activeAlert!.isSos
                          ? AppColors.alertCritical.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: state.activeAlert!.isSos
                            ? AppColors.alertCritical
                            : AppColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          state.activeAlert!.isSos ? Icons.emergency : Icons.campaign,
                          size: 16,
                          color: state.activeAlert!.isSos ? AppColors.alertCritical : AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.activeAlert!.isSos
                                ? 'EMERGENCY SOS: ${state.activeAlert!.callsign} requested response!'
                                : 'Active Alert: "${state.activeAlert!.alertType}" from ${state.activeAlert!.callsign}',
                            style: AppTypography.labelSm.copyWith(
                              fontWeight: FontWeight.w700,
                              color: state.activeAlert!.isSos ? AppColors.alertCritical : AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 4 Status Buttons in Responsive Row
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionButton(
                        context: context,
                        icon: Icons.pause_circle_outline,
                        label: 'Regroup',
                        iconColor: AppColors.primary,
                        onTap: () => _triggerAlert(context, 'Regroup'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildQuickActionButton(
                        context: context,
                        icon: Icons.local_gas_station_outlined,
                        label: 'Refuel',
                        iconColor: AppColors.alertWarning,
                        onTap: () => _triggerAlert(context, 'Refuel'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildQuickActionButton(
                        context: context,
                        icon: Icons.build_outlined,
                        label: 'Issue',
                        iconColor: AppColors.secondary,
                        onTap: () => _triggerAlert(context, 'Issue'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildQuickActionButton(
                        context: context,
                        icon: Icons.chat_bubble_outline,
                        label: 'Custom',
                        iconColor: AppColors.textSecondary,
                        onTap: () => _triggerAlert(context, 'Custom Message'),
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

  Widget _buildQuickActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
