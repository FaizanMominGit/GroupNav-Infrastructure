import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/observability_provider.dart';
import '../widgets/live_terminal_console.dart';
import '../widgets/metrics_grid_2x2.dart';
import '../widgets/operational_status_card.dart';

class PipelineHealthScreen extends ConsumerWidget {
  const PipelineHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthState = ref.watch(observabilityProvider);
    final obsNotifier = ref.read(observabilityProvider.notifier);

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
                      'Pipeline Health & OPS',
                      style: AppTypography.headlineLg.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AWS IoT Core broker & CloudWatch runtime metrics',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monitor_heart, color: AppColors.primary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'OPS LIVE',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. Operational Status Card
            OperationalStatusCard(health: healthState),
            const SizedBox(height: 16),

            // 2. 2x2 CloudWatch Operational Metrics Grid
            MetricsGrid2x2(health: healthState),
            const SizedBox(height: 16),

            // 3. Dark Technical Terminal (MQTT Real-time feed)
            LiveTerminalConsole(
              packets: healthState.logPackets,
              isStreaming: healthState.isStreaming,
              onToggleStreaming: obsNotifier.toggleStreaming,
              onClearLogs: obsNotifier.clearLogs,
            ),
            const SizedBox(height: 16),

            // 4. CloudWatch Launch Card / CTA
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.alertWarning.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.dashboard_outlined, color: AppColors.alertWarning, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CloudWatch Live Dashboard',
                          style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'GroupNav-Observability-Dashboard',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.textSecondary,
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: healthState.dashboardUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Dashboard URL copied! Paste into browser to open.'),
                          backgroundColor: AppColors.primaryDark,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('Open'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
