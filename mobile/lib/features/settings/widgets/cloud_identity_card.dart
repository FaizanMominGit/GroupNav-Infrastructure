import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/config/client_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/rider_settings.dart';

class CloudIdentityCard extends StatelessWidget {
  final RiderSettings settings;
  final ClientConfig config;
  final String? cognitoIdentityId;

  const CloudIdentityCard({
    super.key,
    required this.settings,
    required this.config,
    this.cognitoIdentityId,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIdentityId = cognitoIdentityId ?? 'ap-south-1:325313611329-identity-session';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_done_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'AWS Cloud & DePIN Identity',
                style: AppTypography.labelLg.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Staked Balance & Wallet Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryDark,
                  AppColors.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TELEMETRY STAKED REWARDS',
                      style: AppTypography.labelSm.copyWith(
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.telemetryEmerald.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '+${settings.navRewardRate} NAV/hr',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.secondaryFixed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      settings.stakedBalanceNav.toStringAsFixed(1),
                      style: AppTypography.headlineXl.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '\$NAV',
                      style: AppTypography.headlineMd.copyWith(
                        color: AppColors.routeCyan,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        settings.walletAddress,
                        style: AppTypography.bodySm.copyWith(
                          fontFamily: 'monospace',
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _copyToClipboard(context, settings.walletAddress, 'Wallet Address'),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.copy, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Cognito Identity ID Row with Copy Action
          Text(
            'COGNITO IDENTITY ID (STS SCOPE)',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.fingerprint, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    effectiveIdentityId,
                    style: AppTypography.bodySm.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18, color: AppColors.primary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Copy Cognito Identity ID',
                  onPressed: () => _copyToClipboard(context, effectiveIdentityId, 'Cognito Identity ID'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // IAM Scoped Telemetry Role
          _buildInfoRow(
            icon: Icons.shield_outlined,
            label: 'IAM Telemetry Role',
            value: 'arn:aws:iam::325313611329:role/GroupNavTelemetryClientRole',
            onTapCopy: (val) => _copyToClipboard(context, val, 'IAM Role ARN'),
          ),

          const Divider(height: 24, color: AppColors.borderSubtle),

          // AWS Backend Mappings
          _buildDetailRow('User Pool', config.cognito.userPoolId),
          _buildDetailRow('Identity Pool', config.cognito.identityPoolId),
          _buildDetailRow('IoT Topic Pattern', config.compute.telemetryTopicPattern),
          _buildDetailRow('Redis In-Memory', config.data.redisEndpoint),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required void Function(String) onTapCopy,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelSm.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: AppTypography.bodySm.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => onTapCopy(value),
                child: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.copy, size: 14, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySm.copyWith(
                fontFamily: 'monospace',
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
