import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/client_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/top_app_bar_pill.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/auth_onboarding_screen.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  final ClientConfig config;

  const MainShellScreen({super.key, required this.config});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _currentTabIndex = 1; // Default to Radar (Index 1) as mandated by plan

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // Auth gate: if not authenticated, display Pilot Authentication & Onboarding
    if (!authState.isAuthenticated) {
      return const AuthOnboardingScreen();
    }

    final pilot = authState.pilot!;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: TopAppBarPill(
        title: 'GroupNav',
        subtitle: pilot.callsign,
        rewardRate: 4.2,
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildPlaceholderScreen('Pack Management', 'Active formation #804 & geofence setup', Icons.navigation),
          _buildRadarScreen(pilot.callsign, pilot.vehicleClass),
          _buildPlaceholderScreen('Trip History', 'Aurora PostgreSQL PostGIS replay ledger', Icons.history),
          _buildSettingsScreen(pilot.callsign, pilot.vehicleClass, pilot.cognitoIdentityId),
        ],
      ),
      bottomNavigationBar: ConvoyBottomNavBar(
        currentIndex: _currentTabIndex,
        onTabSelected: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildRadarScreen(String callsign, String vehicleClass) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryFixed.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.radar, size: 54, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('Leader: $callsign', style: AppTypography.headlineLg),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Class: ${vehicleClass.toUpperCase()}',
                style: AppTypography.labelSm.copyWith(color: AppColors.primaryDark),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Connected to AWS Region: ${widget.config.region}\n'
              'Map Resource: ${widget.config.location.mapName}\n'
              'IoT Endpoint: ${widget.config.iot.endpoint}',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsScreen(String callsign, String vehicleClass, String? identityId) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Text('Rider & Infrastructure Settings', style: AppTypography.headlineMd),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pilot Profile', style: AppTypography.labelLg),
                  const Divider(height: 20),
                  _buildConfigRow('Callsign', callsign),
                  _buildConfigRow('Vehicle Class', vehicleClass),
                  _buildConfigRow('Identity ID', identityId ?? 'ap-south-1:...'),
                  const SizedBox(height: 12),
                  Text('AWS Backend Link', style: AppTypography.labelLg),
                  const Divider(height: 20),
                  _buildConfigRow('Cognito User Pool', widget.config.cognito.userPoolId),
                  _buildConfigRow('Identity Pool', widget.config.cognito.identityPoolId),
                  _buildConfigRow('IoT Topic Pattern', widget.config.compute.telemetryTopicPattern),
                  _buildConfigRow('Redis Endpoint', widget.config.data.redisEndpoint),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Sign Out of Cognito Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertCritical,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySm.copyWith(
                fontFamily: 'monospace',
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderScreen(String title, String desc, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(title, style: AppTypography.headlineMd),
          const SizedBox(height: 8),
          Text(desc, style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
