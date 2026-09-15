import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/client_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/cloud_identity_card.dart';
import '../widgets/display_preferences_card.dart';
import '../widgets/profile_summary_card.dart';
import '../widgets/sign_out_dialog.dart';
import '../widgets/telemetry_controls_card.dart';

class RiderSettingsScreen extends ConsumerWidget {
  final ClientConfig config;

  const RiderSettingsScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final settings = ref.watch(settingsNotifierProvider);
    final settingsNotifier = ref.read(settingsNotifierProvider.notifier);

    final pilot = authState.pilot;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // Screen Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rider & Infrastructure',
                      style: AppTypography.headlineLg.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Telemetry parameters & AWS node identity',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.settings, color: AppColors.primary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Pilot Profile Summary Card
            if (pilot != null) ...[
              ProfileSummaryCard(pilot: pilot),
              const SizedBox(height: 16),
            ],

            // Telemetry & Hardware Controls Card
            TelemetryControlsCard(
              settings: settings,
              onGpsRateChanged: settingsNotifier.setGpsRate,
              onBackgroundBroadcastChanged: settingsNotifier.toggleBackgroundBroadcast,
              onHighPrecisionAlertChanged: settingsNotifier.toggleHighPrecisionAlert,
            ),
            const SizedBox(height: 16),

            // Display & Units Preferences Card
            DisplayPreferencesCard(
              settings: settings,
              onUnitSystemChanged: settingsNotifier.setUnitSystem,
              onMapThemeChanged: settingsNotifier.setMapTheme,
              onCohesionPingAudioChanged: settingsNotifier.toggleCohesionPingAudio,
            ),
            const SizedBox(height: 16),

            // AWS Cloud & DePIN Identity Card
            CloudIdentityCard(
              settings: settings,
              config: config,
              cognitoIdentityId: pilot?.cognitoIdentityId,
            ),
            const SizedBox(height: 24),

            // Destructive Sign Out Action
            ElevatedButton.icon(
              onPressed: () {
                SignOutDialog.show(
                  context,
                  onConfirm: () {
                    ref.read(authNotifierProvider.notifier).signOut();
                  },
                );
              },
              icon: const Icon(Icons.logout, color: Colors.white, size: 20),
              label: Text(
                'Sign Out of Cognito Session',
                style: AppTypography.labelMd.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.alertCritical,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 12),

            Center(
              child: Text(
                'GroupNav DePIN Client v1.0.0 • Build #1',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
