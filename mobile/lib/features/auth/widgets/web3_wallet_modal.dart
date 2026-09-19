import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../services/web3_wallet_service.dart';

class Web3WalletModal extends StatefulWidget {
  final Function(Web3WalletType walletType, Web3Chain chain) onConnect;
  final bool isConnecting;
  final String? errorMessage;
  final bool isLinkingMode;

  const Web3WalletModal({
    super.key,
    required this.onConnect,
    this.isConnecting = false,
    this.errorMessage,
    this.isLinkingMode = false,
  });

  @override
  State<Web3WalletModal> createState() => _Web3WalletModalState();
}

class _Web3WalletModalState extends State<Web3WalletModal> {
  Web3WalletType _selectedWallet = Web3WalletType.metamask;
  Web3Chain _selectedChain = Web3Chain.polygon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle pill
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isLinkingMode ? 'Link DePIN Wallet' : 'Connect Web3 Wallet',
                          style: AppTypography.headlineMd.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Self-Custody Pilot Identity & Rewards',
                          style: AppTypography.bodySm.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // DePIN Telemetry Reward Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.telemetryEmerald.withValues(alpha: 0.08),
                borderRadius: AppTheme.radiusMd,
                border: Border.all(color: AppColors.telemetryEmerald.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.telemetryEmerald,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Earn +4.2 NAV/hr verified on-chain during convoy rides',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Chain Selector
            Text('SELECT BLOCKCHAIN NETWORK', style: AppTypography.labelSm.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildChainChip(Web3Chain.polygon, 'Polygon (PoS)'),
                const SizedBox(width: 8),
                _buildChainChip(Web3Chain.ethereum, 'Ethereum'),
                const SizedBox(width: 8),
                _buildChainChip(Web3Chain.solana, 'Solana'),
              ],
            ),
            const SizedBox(height: 16),

            // Wallet Provider Cards
            Text('SELECT WALLET PROVIDER', style: AppTypography.labelSm.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),

            _buildWalletTile(
              walletType: Web3WalletType.metamask,
              title: 'MetaMask',
              subtitle: 'Popular EVM wallet (Mobile & Extension)',
              icon: Icons.shield_outlined,
              iconColor: const Color(0xFFF6851B),
            ),
            const SizedBox(height: 8),

            _buildWalletTile(
              walletType: Web3WalletType.phantom,
              title: 'Phantom',
              subtitle: 'Multi-chain & Solana high-speed wallet',
              icon: Icons.flash_on,
              iconColor: const Color(0xFFAB9FF2),
            ),
            const SizedBox(height: 8),

            _buildWalletTile(
              walletType: Web3WalletType.walletConnect,
              title: 'WalletConnect',
              subtitle: 'Connect with 100+ mobile crypto wallets',
              icon: Icons.qr_code,
              iconColor: const Color(0xFF3B99FC),
            ),
            const SizedBox(height: 16),

            // Error message if any
            if (widget.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.alertCritical.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.alertCritical.withValues(alpha: 0.3)),
                ),
                child: Text(
                  widget.errorMessage!,
                  style: AppTypography.bodySm.copyWith(color: AppColors.alertCritical, fontSize: 12),
                ),
              ),
            ],

            // Connect Action CTA
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: widget.isConnecting
                    ? null
                    : () {
                        widget.onConnect(_selectedWallet, _selectedChain);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
                ),
                child: widget.isConnecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.isLinkingMode
                                ? 'Authorize & Link ${_selectedWallet.displayName}'
                                : 'Sign In with ${_selectedWallet.displayName}',
                            style: AppTypography.labelLg.copyWith(color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChainChip(Web3Chain chain, String label) {
    final isSelected = _selectedChain == chain;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedChain = chain;
            if (chain == Web3Chain.solana) {
              _selectedWallet = Web3WalletType.phantom;
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderSubtle,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletTile({
    required Web3WalletType walletType,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    final isSelected = _selectedWallet == walletType;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedWallet = walletType;
          if (walletType == Web3WalletType.phantom) {
            _selectedChain = Web3Chain.solana;
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodySm.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Radio<Web3WalletType>(
              value: walletType,
              groupValue: _selectedWallet,
              activeColor: AppColors.primary,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedWallet = val;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
