import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/pipeline_metrics.dart';

class MetricsGrid2x2 extends StatelessWidget {
  final PipelineHealthState health;

  const MetricsGrid2x2({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.bolt,
                iconColor: AppColors.primary,
                title: 'LAMBDA INGEST',
                value: '${health.lambdaInvocationsPerMin}',
                unit: '/min',
                subtitle: '+4.2% normal load',
                accentColor: AppColors.telemetryEmerald,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRedisCard(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.mark_email_read_outlined,
                iconColor: AppColors.telemetryEmerald,
                title: 'DLQ BUFFER',
                value: '${health.dlqMessageDepth}',
                unit: 'msgs',
                subtitle: 'Zero drop failures',
                accentColor: AppColors.telemetryEmerald,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.cloud_sync,
                iconColor: AppColors.routeCyan,
                title: 'MQTT INGEST',
                value: '${health.mqttIngestRatePktsPerSec}',
                unit: 'pkts/s',
                subtitle: 'QoS 1 Guaranteed',
                accentColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                  fontSize: 9,
                ),
              ),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTypography.telemetryNum.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTypography.bodySm.copyWith(
              color: accentColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedisCard() {
    final pct = health.redisLoadPercentage;
    final pctInt = (pct * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REDIS MEMORY',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                  fontSize: 9,
                ),
              ),
              const Icon(Icons.memory, size: 16, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${health.redisUsedMemoryMb}',
                style: AppTypography.telemetryNum.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ ${health.redisTotalMemoryMb} MB',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Linear Progress Load Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.telemetryEmerald),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$pctInt% cache capacity',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
