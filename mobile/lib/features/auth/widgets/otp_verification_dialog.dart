import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';

class OtpVerificationDialog extends StatefulWidget {
  final String phoneOrEmail;
  final String session;
  final int resendCountdown;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<String> onVerify;
  final VoidCallback onResend;
  final VoidCallback onCancel;

  const OtpVerificationDialog({
    super.key,
    required this.phoneOrEmail,
    required this.session,
    required this.resendCountdown,
    this.isLoading = false,
    this.errorMessage,
    required this.onVerify,
    required this.onResend,
    required this.onCancel,
  });

  @override
  State<OtpVerificationDialog> createState() => _OtpVerificationDialogState();
}

class _OtpVerificationDialogState extends State<OtpVerificationDialog> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _submitOtp();
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  void _submitOtp() {
    final code = _controllers.map((c) => c.text).join();
    if (code.length == 6) {
      widget.onVerify(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maskedContact = widget.phoneOrEmail.length > 6
        ? '${widget.phoneOrEmail.substring(0, 3)} ••• ${widget.phoneOrEmail.substring(widget.phoneOrEmail.length - 4)}'
        : widget.phoneOrEmail;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: AppTheme.radiusXl,
          boxShadow: AppTheme.elevationLevel3,
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Action Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryFixed,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pin, color: AppColors.primary, size: 20),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                  onPressed: widget.onCancel,
                  splashRadius: 18,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title & Masked Phone
            Text('Enter Verification Code', style: AppTypography.headlineMd),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                text: 'Sent via encrypted SMS to ',
                style: AppTypography.bodySm,
                children: [
                  TextSpan(
                    text: maskedContact,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 6-Digit Split Input Grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 44,
                  height: 52,
                  child: TextFormField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: AppTypography.telemetryNum.copyWith(
                      color: AppColors.primary,
                      fontSize: 20,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: _controllers[index].text.isNotEmpty
                          ? AppColors.primaryFixed.withValues(alpha: 0.25)
                          : AppColors.surfaceContainerLow,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: AppTheme.radiusMd,
                        borderSide: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppTheme.radiusMd,
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                    onChanged: (val) => _onDigitChanged(index, val),
                  ),
                );
              }),
            ),

            if (widget.errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                widget.errorMessage!,
                style: AppTypography.labelSm.copyWith(color: AppColors.alertCritical),
              ),
            ],

            const SizedBox(height: 16),

            // Resend Timer & Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      widget.resendCountdown > 0
                          ? 'Resend in 0:${widget.resendCountdown.toString().padLeft(2, '0')}'
                          : 'Code expired',
                      style: AppTypography.bodySm,
                    ),
                  ],
                ),
                TextButton(
                  onPressed: widget.resendCountdown == 0 ? widget.onResend : null,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Resend Code',
                    style: AppTypography.labelSm.copyWith(
                      color: widget.resendCountdown == 0 ? AppColors.primary : AppColors.outline,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: widget.isLoading ? null : _submitOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: const RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
                  elevation: 2,
                ),
                child: widget.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_user, size: 18),
                          const SizedBox(width: 8),
                          Text('Verify & Connect Fleet', style: AppTypography.labelLg.copyWith(color: Colors.white)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),

            // Secondary Action: Cancel / Change Phone
            Center(
              child: TextButton(
                onPressed: widget.onCancel,
                child: Text(
                  'Change Mobile Number',
                  style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
            ),

            const Divider(height: 24),

            // DePIN / Cognito Anchor
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield, size: 14, color: AppColors.telemetryEmerald),
                  const SizedBox(width: 6),
                  Text(
                    'Cognito Session: ${widget.session.substring(0, widget.session.length > 10 ? 10 : widget.session.length)}...',
                    style: AppTypography.bodySm.copyWith(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
