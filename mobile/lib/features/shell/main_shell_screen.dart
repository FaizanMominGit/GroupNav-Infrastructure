import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/client_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/top_app_bar_pill.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/auth_onboarding_screen.dart';
import '../groups/screens/pack_management_screen.dart';
import '../radar/screens/live_radar_screen.dart';
import '../settings/screens/rider_settings_screen.dart';

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
      appBar: (_currentTabIndex == 0 || _currentTabIndex == 1 || _currentTabIndex == 3)
          ? null
          : TopAppBarPill(
              title: 'GroupNav',
              subtitle: pilot.callsign,
              rewardRate: 4.2,
            ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          PackManagementScreen(
            onExpandMap: () {
              setState(() {
                _currentTabIndex = 1;
              });
            },
          ),
          const LiveRadarScreen(),
          _buildPlaceholderScreen('Trip History', 'Aurora PostgreSQL PostGIS replay ledger', Icons.history),
          RiderSettingsScreen(config: widget.config),
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
