import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/rider_settings.dart';

class ProfileIdentityCard extends StatelessWidget {
  final RiderSettings settings;
  final ValueChanged<String> onUpdateCallsign;
  final ValueChanged<String> onUpdateVehicle;
  final ValueChanged<String> onUpdateEmergencyContact;
  final String? walletAddress;
  final double navBalance;
  final VoidCallback? onConnectWallet;
  final VoidCallback? onDisconnectWallet;

  const ProfileIdentityCard({
    super.key,
    required this.settings,
    required this.onUpdateCallsign,
    required this.onUpdateVehicle,
    required this.onUpdateEmergencyContact,
    this.walletAddress,
    this.navBalance = 0.0,
    this.onConnectWallet,
    this.onDisconnectWallet,
  });

  void _showEditDialog({
    required BuildContext context,
    required String title,
    required String initialValue,
    required ValueChanged<String> onSave,
  }) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: AppTypography.headlineMd),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTypography.labelMd.copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onSave(controller.text.trim());
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWalletLinked = walletAddress != null && walletAddress!.isNotEmpty;
    final truncatedWallet = isWalletLinked
        ? (walletAddress!.length > 10
            ? '${walletAddress!.substring(0, 6)}...${walletAddress!.substring(walletAddress!.length - 4)}'
            : walletAddress!)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Active Rider status pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile & Identity',
                      style: AppTypography.headlineMd.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your rider handle, ride setup, and emergency info',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.telemetryEmerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Active Rider',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 14),

          // Item 1: Callsign
          _buildInfoRow(
            context: context,
            label: 'CALLSIGN',
            value: settings.callsign,
            actionText: 'Edit',
            onTapAction: () => _showEditDialog(
              context: context,
              title: 'Edit Callsign',
              initialValue: settings.callsign,
              onSave: onUpdateCallsign,
            ),
          ),
          const SizedBox(height: 10),

          // Item 2: Vehicle
          _buildInfoRow(
            context: context,
            label: 'VEHICLE',
            value: settings.vehicle,
            actionText: 'Change',
            onTapAction: () => _showEditDialog(
              context: context,
              title: 'Change Vehicle',
              initialValue: settings.vehicle,
              onSave: onUpdateVehicle,
            ),
          ),
          const SizedBox(height: 10),

          // Item 3: Emergency Contact
          _buildInfoRow(
            context: context,
            label: 'EMERGENCY CONTACT',
            value: settings.emergencyContact,
            actionText: 'Update',
            onTapAction: () => _showEditDialog(
              context: context,
              title: 'Update Emergency Contact',
              initialValue: settings.emergencyContact,
              onSave: onUpdateEmergencyContact,
            ),
          ),
          const SizedBox(height: 10),

          // Item 4: Web3 DePIN Telemetry Wallet
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isWalletLinked
                  ? AppColors.telemetryEmerald.withValues(alpha: 0.05)
                  : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isWalletLinked
                    ? AppColors.telemetryEmerald.withValues(alpha: 0.3)
                    : AppColors.borderSubtle,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'DEPIN TELEMETRY WALLET',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (isWalletLinked) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.telemetryEmerald.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${navBalance.toStringAsFixed(1)} NAV',
                                style: AppTypography.labelSm.copyWith(
                                  fontSize: 9,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isWalletLinked ? truncatedWallet! : 'Not linked (+4.2 NAV/hr available)',
                        style: AppTypography.labelLg.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isWalletLinked ? AppColors.secondary : AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: isWalletLinked ? onDisconnectWallet : onConnectWallet,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      isWalletLinked ? 'Disconnect' : 'Connect',
                      style: AppTypography.labelSm.copyWith(
                        color: isWalletLinked ? AppColors.alertCritical : AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required String label,
    required String value,
    required String actionText,
    required VoidCallback onTapAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.labelLg.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onTapAction,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                actionText,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
