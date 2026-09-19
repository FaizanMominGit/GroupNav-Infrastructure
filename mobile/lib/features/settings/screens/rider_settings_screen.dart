import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/client_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/providers/auth_provider.dart';
import '../../groups/providers/pack_provider.dart';
import '../../radar/providers/radar_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/convoy_alerts_card.dart';
import '../widgets/location_privacy_card.dart';
import '../widgets/navigation_display_card.dart';
import '../widgets/profile_identity_card.dart';
import '../widgets/sign_out_dialog.dart';

class RiderSettingsScreen extends ConsumerWidget {
  final ClientConfig config;

  const RiderSettingsScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final authNotifier = ref.read(authNotifierProvider.notifier);
    final settings = ref.watch(settingsNotifierProvider);
    final settingsNotifier = ref.read(settingsNotifierProvider.notifier);
    final packFormation = ref.watch(packNotifierProvider);
    final packNotifier = ref.read(packNotifierProvider.notifier);


    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Floating Sticky Top App Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.settings,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Rider Settings',
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.headlineMd.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Active Pilot Thumbnail & Status Pill
                  Container(
                    padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'CALLSIGN',
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 9,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              settings.callsign,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelMd.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.telemetryEmerald, width: 2),
                            color: AppColors.primaryFixed,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            (authState.pilot?.callsign ?? settings.callsign).length >= 2
                                ? (authState.pilot?.callsign ?? settings.callsign).substring(0, 2).toUpperCase()
                                : 'ME',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Settings Scrollable List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // Section 1: Profile & Identity
                  ProfileIdentityCard(
                    settings: settings.copyWith(
                      callsign: authState.pilot?.callsign ?? settings.callsign,
                      vehicle: authState.pilot?.vehicleClass ?? settings.vehicle,
                    ),
                    onUpdateCallsign: (newCallsign) async {
                      settingsNotifier.setCallsign(newCallsign);
                      await authNotifier.updateCallsign(newCallsign);
                      ref.read(packNotifierProvider.notifier).updateRiderCallsign(newCallsign);
                      ref.read(iotTelemetryServiceProvider).updateRiderIdentity(
                        riderId: authState.pilot?.cognitoIdentityId ?? authState.pilot?.phoneOrEmail ?? 'pilot',
                        callsign: newCallsign,
                      );
                    },
                    onUpdateVehicle: settingsNotifier.setVehicle,
                    onUpdateEmergencyContact: settingsNotifier.setEmergencyContact,
                  ),
                  const SizedBox(height: 16),

                  // Active Convoy Room Card (Decoupled from Auth)
                  if (packFormation.isInPack) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ACTIVE CONVOY ROOM',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  packFormation.packCode,
                                  style: AppTypography.headlineMd.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${packFormation.connectedCount} active riders in room',
                                  style: AppTypography.bodySm.copyWith(color: AppColors.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              packNotifier.leavePack();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Exited convoy room. Switched to Solo Ride Mode.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.exit_to_app, size: 14, color: AppColors.alertWarning),
                            label: Text(
                              'Leave Pack',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.alertWarning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.alertWarning.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Section 2: Ride & Convoy Alerts
                  ConvoyAlertsCard(
                    settings: settings,
                    onToggleGeofenceWarning: settingsNotifier.toggleGeofenceDepartureWarning,
                    onToggleSpeedAlert: settingsNotifier.toggleSpeedAlert,
                  ),
                  const SizedBox(height: 16),

                  // Section 3: Navigation & Display
                  NavigationDisplayCard(
                    settings: settings,
                    onUnitSystemChanged: settingsNotifier.setUnitSystem,
                    onMapThemeChanged: settingsNotifier.setMapTheme,
                    onToggleKeepScreenAwake: settingsNotifier.toggleKeepScreenAwake,
                  ),
                  const SizedBox(height: 16),

                  // Section 4: Location & Privacy
                  LocationPrivacyCard(
                    settings: settings,
                    onToggleShareLocation: settingsNotifier.toggleShareRealTimeLocation,
                    onGpsRateChanged: settingsNotifier.setGpsRate,
                  ),
                  const SizedBox(height: 20),

                  // Section 5: Account Level Action - Sign Out of Profile
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.alertCritical.withValues(alpha: 0.35),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          SignOutDialog.show(
                            context,
                            onConfirm: () => authNotifier.signOut(),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.logout,
                                color: AppColors.alertCritical,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Log Out of Account',
                                style: AppTypography.labelLg.copyWith(
                                  color: AppColors.alertCritical,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Signing out removes your credentials and pilot profile from this device.',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
