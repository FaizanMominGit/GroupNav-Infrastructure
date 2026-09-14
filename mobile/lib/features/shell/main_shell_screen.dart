import 'package:flutter/material.dart';
import '../../core/config/client_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/top_app_bar_pill.dart';

class MainShellScreen extends StatefulWidget {
  final ClientConfig config;

  const MainShellScreen({super.key, required this.config});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentTabIndex = 1; // Default to Radar (Index 1) as mandated by plan

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const TopAppBarPill(
        title: 'GroupNav',
        subtitle: 'DePIN',
        rewardRate: 4.2,
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildPlaceholderScreen('Pack Management', 'Active formation #804 & geofence setup', Icons.navigation),
          _buildRadarScreen(),
          _buildPlaceholderScreen('Trip History', 'Aurora PostgreSQL PostGIS replay ledger', Icons.history),
          _buildSettingsScreen(),
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

  Widget _buildRadarScreen() {
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
            Text('Live Convoy Radar', style: AppTypography.headlineLg),
            const SizedBox(height: 8),
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

  Widget _buildSettingsScreen() {
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
