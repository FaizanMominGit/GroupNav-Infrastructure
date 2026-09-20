import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/client_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/screens/auth_onboarding_screen.dart';
import '../groups/screens/pack_management_screen.dart';
import '../radar/models/convoy_alert.dart';
import '../radar/providers/radar_provider.dart';
import '../radar/screens/live_radar_screen.dart';
import '../settings/screens/rider_settings_screen.dart';
import '../trips/screens/trip_history_screen.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  final ClientConfig config;

  const MainShellScreen({super.key, required this.config});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _currentTabIndex = 1; // Default to Radar (Index 1) as mandated by plan
  StreamSubscription? _globalAlertSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final telemetry = ref.read(iotTelemetryServiceProvider);
      _globalAlertSub = telemetry.alertStream.listen((alertJson) {
        if (!mounted) return;
        final alert = ConvoyAlert.fromJson(alertJson);

        if (alert.isSos) {
          HapticFeedback.heavyImpact();
          _showGlobalSosDialog(alert);
        } else {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.campaign, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Convoy Alert: [${alert.callsign}] - ${alert.alertType}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    });
  }

  void _showGlobalSosDialog(ConvoyAlert alert) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.alertCritical, width: 2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.alertCritical,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emergency, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'EMERGENCY SOS',
                style: TextStyle(
                  color: AppColors.alertCritical,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rider "${alert.callsign}" has activated an emergency SOS broadcast!',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              alert.message.isNotEmpty ? alert.message : 'Immediate response requested.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.radar, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Telemetry: High-Priority AWS IoT Core Alert', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _currentTabIndex = 1; // Switch directly to Live Radar
              });
            },
            icon: const Icon(Icons.map, size: 16),
            label: const Text('View on Live Radar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertCritical,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _globalAlertSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // Auth gate: if not authenticated, display Pilot Authentication & Onboarding
    if (!authState.isAuthenticated) {
      return const AuthOnboardingScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
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
          const TripHistoryScreen(),
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
}

