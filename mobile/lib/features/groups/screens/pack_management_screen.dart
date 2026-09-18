import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: formation.isInPack
                                ? AppColors.surfaceContainerLow
                                : AppColors.primaryFixed.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            formation.isInPack ? Icons.navigation : Icons.person_pin_circle,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                formation.isInPack ? formation.title : 'Solo Ride Mode',
                                style: AppTypography.headlineMd.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: formation.isInPack
                                          ? AppColors.telemetryEmerald
                                          : AppColors.textSecondary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      formation.isInPack
                                          ? '${formation.connectedCount} Riders Connected'
                                          : 'Independent Pilot (No Active Pack)',
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.labelSm.copyWith(
                                        fontSize: 11,
                                        color: formation.isInPack
                                            ? AppColors.secondary
                                            : AppColors.textSecondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  if (formation.isInPack) ...[
                    // Leave Pack Action Pill in AppBar
                    OutlinedButton.icon(
                      onPressed: () => _confirmLeavePack(context, packNotifier, formation.packCode),
                      icon: const Icon(Icons.exit_to_app, size: 14, color: AppColors.alertCritical),
                      label: Text(
                        'Leave',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.alertCritical,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.alertCritical.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ] else ...[
                    // Join Pack Action Pill
                    ElevatedButton.icon(
                      onPressed: () => _showJoinPackDialog(context, packNotifier),
                      icon: const Icon(Icons.group_add, size: 14, color: Colors.white),
                      label: Text(
                        'Join Pack',
                        style: AppTypography.labelSm.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      body: formation.isInPack
          ? _buildInPackView(context, formation, packNotifier)
          : _buildSoloView(context, formation, packNotifier),
    );
  }

  // ---------------------------------------------------------------------------
  // Active Pack Mode View
  // ---------------------------------------------------------------------------
  Widget _buildInPackView(BuildContext context, dynamic formation, PackNotifier packNotifier) {
    return ListView(
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
            Text(
              'Riders in Pack',
              style: AppTypography.headlineMd.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${formation.members.length} members',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
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

        // 6. Leave Convoy Room Action
        Center(
          child: TextButton.icon(
            onPressed: () => _confirmLeavePack(context, packNotifier, formation.packCode),
            icon: const Icon(Icons.exit_to_app, size: 16, color: AppColors.alertCritical),
            label: Text(
              'Leave Convoy Room (Return to Solo Mode)',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.alertCritical,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Solo Mode View (Not in any pack room)
  // ---------------------------------------------------------------------------
  Widget _buildSoloView(BuildContext context, dynamic formation, PackNotifier packNotifier) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Solo Status Hero Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.navigation, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'SOLO RIDER MODE',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'GPS ACTIVE',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.telemetryEmerald,
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Ride Independently or Join a Convoy',
                style: AppTypography.headlineLg.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You are currently in solo mode. Your GPS breadcrumbs and trip metrics are tracked locally. Join or create a convoy room to share real-time spatial telemetry and geofence alerts with other riders.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons: Create Pack & Join Pack
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await packNotifier.createPack();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Created new Convoy Room on AWS! You are Convoy Lead.'),
                                backgroundColor: AppColors.primary,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to create convoy on AWS: ${e.toString().replaceAll("Exception: ", "")}'),
                                backgroundColor: AppColors.alertCritical,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.white),
                      label: const Text('Create Convoy'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showJoinPackDialog(context, packNotifier),
                      icon: const Icon(Icons.meeting_room, size: 18, color: AppColors.primary),
                      label: const Text('Join Room'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Solo Roster (Just User)
        Text(
          'Active Pilot Status',
          style: AppTypography.headlineMd.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),

        if (formation.members.isNotEmpty)
          PackRosterCard(
            member: formation.members.first,
            onPing: null,
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------
  void _confirmLeavePack(BuildContext context, PackNotifier notifier, String packCode) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.exit_to_app, color: AppColors.alertCritical),
            const SizedBox(width: 8),
            const Text('Leave Convoy Room?'),
          ],
        ),
        content: Text(
          'You will exit room "$packCode" and switch to Solo Ride Mode. Your pilot account, profile, and settings will remain fully active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTypography.labelMd.copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await notifier.leavePack();
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Exited convoy room. Now in Solo Ride Mode.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertCritical,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave Room'),
          ),
        ],
      ),
    );
  }

  void _showJoinPackDialog(BuildContext context, PackNotifier notifier) {
    final controller = TextEditingController(text: 'GN-');
    String? localError;
    bool isJoining = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.group_add, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Join Convoy Room'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter the 6-character convoy code or paste pairing payload shared by the lead:',
                  style: AppTypography.bodySm.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  enabled: !isJoining,
                  style: AppTypography.telemetryNum.copyWith(
                    fontSize: 16,
                    letterSpacing: 1.2,
                    color: AppColors.primary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'GN-9482 or QR JSON',
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                if (localError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    localError!,
                    style: AppTypography.bodySm.copyWith(color: AppColors.alertCritical),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: isJoining
                        ? null
                        : () async {
                            final data = await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null && data!.text!.trim().isNotEmpty) {
                              setState(() {
                                controller.text = data.text!.trim();
                                localError = null;
                              });
                            }
                          },
                    icon: const Icon(Icons.paste, size: 14, color: AppColors.secondary),
                    label: Text(
                      'Paste Clipboard Data',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isJoining ? null : () => Navigator.of(ctx).pop(),
                child: Text('Cancel', style: AppTypography.labelMd.copyWith(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isJoining
                    ? null
                    : () async {
                        final code = controller.text.trim();
                        if (code.isEmpty || code == 'GN-') {
                          setState(() {
                            localError = 'Please enter a valid room code.';
                          });
                          return;
                        }

                        setState(() {
                          isJoining = true;
                          localError = null;
                        });

                        try {
                          await notifier.joinPack(code);
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Successfully joined Convoy Room "$code" on AWS!'),
                                backgroundColor: AppColors.primary,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() {
                            isJoining = false;
                            localError = e.toString().replaceAll('Exception: ', '');
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: isJoining
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Join Room'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmSosBroadcast(BuildContext context, PackNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.emergency, color: AppColors.alertCritical),
            const SizedBox(width: 8),
            const Text('Confirm Pack SOS'),
          ],
        ),
        content: const Text(
          'This will transmit a high-priority emergency packet to AWS IoT Core topic "groupnav/convoy/alerts" and trigger siren haptics on all connected convoy units.',
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
}
