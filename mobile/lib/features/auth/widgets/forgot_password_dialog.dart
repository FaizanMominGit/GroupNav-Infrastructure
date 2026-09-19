import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';

class ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;
  final int resendCountdown;
  final bool isLoading;
  final String? errorMessage;
  final String? destination;
  final Future<bool> Function(String email) onRequestCode;
  final Future<bool> Function({
    required String email,
    required String code,
    required String newPassword,
  }) onConfirmReset;
  final void Function(String email, String newPassword) onSuccess;
  final VoidCallback onCancel;

  const ForgotPasswordDialog({
    super.key,
    required this.initialEmail,
    required this.resendCountdown,
    this.isLoading = false,
    this.errorMessage,
    this.destination,
    required this.onRequestCode,
    required this.onConfirmReset,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  late final TextEditingController _emailController;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  int _currentStep = 0; // 0: Request Code, 1: Verify & Set Password, 2: Success
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    if (widget.destination != null && widget.destination!.isNotEmpty) {
      _currentStep = 1;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _localError = 'Please enter a valid pilot email address.';
      });
      return;
    }

    setState(() {
      _localError = null;
    });

    final success = await widget.onRequestCode(email);
    if (success && mounted) {
      setState(() {
        _currentStep = 1;
      });
    }
  }

  Future<void> _handleConfirmReset() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (code.length != 6) {
      setState(() {
        _localError = 'Please enter the 6-digit confirmation code.';
      });
      return;
    }

    if (newPassword.length < 8) {
      setState(() {
        _localError = 'Password must be at least 8 characters long.';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _localError = 'Passwords do not match. Please verify.';
      });
      return;
    }

    setState(() {
      _localError = null;
    });

    final success = await widget.onConfirmReset(
      email: email,
      code: code,
      newPassword: newPassword,
    );

    if (success && mounted) {
      setState(() {
        _currentStep = 2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorToShow = _localError ?? widget.errorMessage;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: AppTheme.radiusXl,
          boxShadow: AppTheme.elevationLevel3,
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: Icon & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _currentStep == 2
                          ? AppColors.telemetryEmerald.withValues(alpha: 0.12)
                          : AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _currentStep == 2
                          ? Icons.check_circle_outline
                          : (_currentStep == 1 ? Icons.mark_email_read_outlined : Icons.lock_reset),
                      color: _currentStep == 2 ? AppColors.telemetryEmerald : AppColors.primary,
                      size: 22,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                    onPressed: widget.onCancel,
                    splashRadius: 18,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Step Content
              if (_currentStep == 0) _buildStep0RequestCode(errorToShow),
              if (_currentStep == 1) _buildStep1VerifyAndReset(errorToShow),
              if (_currentStep == 2) _buildStep2Success(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep0RequestCode(String? error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reset Account Password', style: AppTypography.headlineMd),
        const SizedBox(height: 6),
        Text(
          'Enter your registered pilot email. AWS Cognito will dispatch an encrypted 6-digit confirmation code.',
          style: AppTypography.bodySm.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),

        Text('Pilot Email Address', style: AppTypography.labelMd),
        const SizedBox(height: 6),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: AppTypography.bodyMd,
          decoration: InputDecoration(
            hintText: 'pilot@groupnav.io',
            prefixIcon: const Icon(Icons.email_outlined, size: 20, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surfaceContainerLowest,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: AppTheme.radiusMd,
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppTheme.radiusMd,
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 14),

        if (error != null) _buildErrorBanner(error),

        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.isLoading ? null : widget.onCancel,
              child: Text(
                'CANCEL',
                style: AppTypography.labelMd.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: widget.isLoading ? null : _handleSendCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('SEND CODE'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep1VerifyAndReset(String? error) {
    final destination = widget.destination ?? _emailController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Set New Password', style: AppTypography.headlineMd),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.mark_email_read, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Code sent to: $destination',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 6-digit confirmation code
        Text('6-Digit Verification Code', style: AppTypography.labelMd),
        const SizedBox(height: 6),
        TextFormField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: AppTypography.headlineMd.copyWith(letterSpacing: 4),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.4), letterSpacing: 4),
            prefixIcon: const Icon(Icons.pin, size: 20, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surfaceContainerLowest,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: AppTheme.radiusMd,
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppTheme.radiusMd,
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // New Password
        Text('New Account Password', style: AppTypography.labelMd),
        const SizedBox(height: 6),
        TextFormField(
          controller: _newPasswordController,
          obscureText: _obscureNewPassword,
          style: AppTypography.bodyMd,
          decoration: InputDecoration(
            hintText: 'Min 8 chars, uppercase & numbers',
            prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppColors.textSecondary),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                size: 20,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
            ),
            filled: true,
            fillColor: AppColors.surfaceContainerLowest,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: AppTheme.radiusMd,
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppTheme.radiusMd,
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Confirm New Password
        Text('Confirm New Password', style: AppTypography.labelMd),
        const SizedBox(height: 6),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          style: AppTypography.bodyMd,
          decoration: InputDecoration(
            hintText: 'Re-enter new password',
            prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppColors.textSecondary),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                size: 20,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            filled: true,
            fillColor: AppColors.surfaceContainerLowest,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: AppTheme.radiusMd,
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppTheme.radiusMd,
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Resend Code Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: widget.resendCountdown > 0
                  ? null
                  : () => widget.onRequestCode(_emailController.text.trim()),
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(
                widget.resendCountdown > 0
                    ? 'Resend in ${widget.resendCountdown}s'
                    : 'Resend Code',
                style: AppTypography.labelSm,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _currentStep = 0),
              child: Text(
                'Change Email',
                style: AppTypography.labelSm.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),

        if (error != null) _buildErrorBanner(error),

        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : _handleConfirmReset,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('RESET PASSWORD & SIGN IN'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Success() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.telemetryEmerald.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            color: AppColors.telemetryEmerald,
            size: 48,
          ),
        ),
        const SizedBox(height: 16),
        Text('Password Reset Complete', style: AppTypography.headlineMd),
        const SizedBox(height: 8),
        Text(
          'Your pilot account password has been updated in AWS Cognito User Pool. You can now access your convoy radar session.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySm.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: () {
              widget.onSuccess(
                _emailController.text.trim(),
                _newPasswordController.text,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
            ),
            child: const Text('PROCEED TO SIGN IN'),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.alertCritical.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.alertCritical.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.alertCritical, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.alertCritical,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
