import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/top_app_bar_pill.dart';
import '../providers/auth_provider.dart';
import '../widgets/beacon_color_picker.dart';
import '../widgets/forgot_password_dialog.dart';
import '../widgets/otp_verification_dialog.dart';
import '../widgets/vehicle_class_selector.dart';

class AuthOnboardingScreen extends ConsumerStatefulWidget {
  const AuthOnboardingScreen({super.key});

  @override
  ConsumerState<AuthOnboardingScreen> createState() => _AuthOnboardingScreenState();
}

class _AuthOnboardingScreenState extends ConsumerState<AuthOnboardingScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _callsignController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final authNotifier = ref.read(authNotifierProvider.notifier);
    _emailController = TextEditingController(text: authNotifier.email);
    _passwordController = TextEditingController(text: authNotifier.password);
    _callsignController = TextEditingController(text: authNotifier.callsign);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _callsignController.dispose();
    super.dispose();
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final authNotifier = ref.read(authNotifierProvider.notifier);
    authNotifier.clearPasswordResetState();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(authNotifierProvider);
          return ForgotPasswordDialog(
            initialEmail: _emailController.text.trim(),
            resendCountdown: state.resendCountdown,
            isLoading: state.isPasswordResetLoading,
            errorMessage: state.passwordResetError,
            destination: state.passwordResetDestination,
            onRequestCode: (email) async {
              final result = await authNotifier.sendPasswordResetCode(email);
              return result != null;
            },
            onConfirmReset: ({
              required String email,
              required String code,
              required String newPassword,
            }) async {
              return await authNotifier.confirmPasswordReset(
                email: email,
                code: code,
                newPassword: newPassword,
              );
            },
            onSuccess: (email, newPassword) {
              Navigator.of(ctx).pop();
              _emailController.text = email;
              _passwordController.text = newPassword;
              authNotifier.setEmail(email);
              authNotifier.setPassword(newPassword);
              authNotifier.clearPasswordResetState();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Password updated successfully! You can now sign in.',
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.telemetryEmerald,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 4),
                ),
              );
            },
            onCancel: () {
              Navigator.of(ctx).pop();
              authNotifier.clearPasswordResetState();
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final authNotifier = ref.read(authNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.darkMapCanvas,
      body: Stack(
        children: [
          // 1. Simulated Vector Map Backdrop (Layer Z-0)
          Positioned.fill(
            child: CustomPaint(
              painter: _VectorGridPainter(),
            ),
          ),

          // 2. Main Content Canvas
          SafeArea(
            child: Column(
              children: [
                // Top Header Pill (Layer Z-20)
                TopAppBarPill(
                  title: 'GroupNav',
                  subtitle: 'AWS Live',
                  rewardRate: 4.2,
                  onMenuPressed: () {},
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Primary Pilot Authentication Card (Layer Z-30)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: AppTheme.radiusXl,
                              boxShadow: AppTheme.elevationLevel3,
                              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Status Badges
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainer,
                                        borderRadius: AppTheme.radiusFull,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.cloud_done, size: 13, color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            'AWS COGNITO',
                                            style: AppTypography.labelSm.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: AppColors.telemetryEmerald,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Real-Time Auth',
                                          style: AppTypography.labelSm.copyWith(color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Text(
                                  authNotifier.isSignUpMode ? 'Create Pilot Account' : 'Pilot Sign In',
                                  style: AppTypography.headlineLg,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  authNotifier.isSignUpMode
                                      ? 'Register with AWS Cognito User Pool to obtain authenticated telemetry credentials.'
                                      : 'Sign in to access your convoy telemetry, rooms, and live radar tracking.',
                                  style: AppTypography.bodySm,
                                ),
                                const SizedBox(height: 16),

                                // Mode Switcher: Sign In vs Sign Up
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            if (authNotifier.isSignUpMode) {
                                              setState(() {
                                                authNotifier.toggleSignUpMode();
                                              });
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            decoration: BoxDecoration(
                                              color: !authNotifier.isSignUpMode
                                                  ? AppColors.cardBg
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                              boxShadow: !authNotifier.isSignUpMode
                                                  ? [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.05),
                                                        blurRadius: 4,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Sign In',
                                                style: AppTypography.labelMd.copyWith(
                                                  fontWeight: !authNotifier.isSignUpMode
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color: !authNotifier.isSignUpMode
                                                      ? AppColors.primary
                                                      : AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            if (!authNotifier.isSignUpMode) {
                                              setState(() {
                                                authNotifier.toggleSignUpMode();
                                              });
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            decoration: BoxDecoration(
                                              color: authNotifier.isSignUpMode
                                                  ? AppColors.cardBg
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                              boxShadow: authNotifier.isSignUpMode
                                                  ? [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.05),
                                                        blurRadius: 4,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Create Account',
                                                style: AppTypography.labelMd.copyWith(
                                                  fontWeight: authNotifier.isSignUpMode
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color: authNotifier.isSignUpMode
                                                      ? AppColors.primary
                                                      : AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Email Input Field
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
                                  onChanged: authNotifier.setEmail,
                                ),
                                const SizedBox(height: 14),

                                // Password Input Field
                                Text('Account Password', style: AppTypography.labelMd),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: AppTypography.bodyMd,
                                  decoration: InputDecoration(
                                    hintText: 'Min 8 chars, uppercase & digits',
                                    prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppColors.textSecondary),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                        size: 20,
                                        color: AppColors.textSecondary,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
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
                                  onChanged: authNotifier.setPassword,
                                ),
                                const SizedBox(height: 8),

                                // Forgot Password Link in Sign In Mode
                                if (!authNotifier.isSignUpMode) ...[
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => _showForgotPasswordDialog(context),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Forgot Password?',
                                        style: AppTypography.labelSm.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ] else ...[
                                  const SizedBox(height: 6),
                                ],

                                // Callsign Field (Visible in Sign Up mode)
                                if (authNotifier.isSignUpMode) ...[
                                  Text('Tactical Callsign', style: AppTypography.labelMd),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _callsignController,
                                    style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. Apex, Maverick, Ghost',
                                      prefixIcon: const Icon(Icons.tag, size: 20, color: AppColors.textSecondary),
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
                                    onChanged: authNotifier.setCallsign,
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                // Error Banner if any
                                if (authState.errorMessage != null) ...[
                                  Container(
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
                                            authState.errorMessage!,
                                            style: AppTypography.bodySm.copyWith(
                                              color: AppColors.alertCritical,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                // Submit Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: authState.isLoading
                                        ? null
                                        : () {
                                            if (authNotifier.isSignUpMode) {
                                              authNotifier.signUp(
                                                email: _emailController.text,
                                                password: _passwordController.text,
                                                callsign: _callsignController.text,
                                              );
                                            } else {
                                              authNotifier.signIn(
                                                email: _emailController.text,
                                                password: _passwordController.text,
                                              );
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.onPrimary,
                                      shape: const RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
                                      elevation: 2,
                                    ),
                                    child: authState.isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                authNotifier.isSignUpMode ? 'Register Pilot with AWS' : 'Sign In to AWS',
                                                style: AppTypography.labelLg.copyWith(color: Colors.white),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(Icons.arrow_forward, size: 18),
                                            ],
                                          ),
                                  ),
                                ),

                                // Quick Biometric Unlock (Face ID / Fingerprint)
                                if (!authNotifier.isSignUpMode && authState.canUseBiometrics) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Expanded(child: Divider(color: AppColors.borderSubtle)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Text(
                                          'OR BIOMETRIC UNLOCK',
                                          style: AppTypography.labelSm.copyWith(
                                            fontSize: 9,
                                            color: AppColors.textSecondary,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ),
                                      const Expanded(child: Divider(color: AppColors.borderSubtle)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: authState.isBiometricLoading
                                          ? null
                                          : () => authNotifier.unlockWithBiometrics(),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                                        shape: const RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.05),
                                      ),
                                      child: authState.isBiometricLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  authState.biometricTypeLabel.contains('Face')
                                                      ? Icons.face
                                                      : Icons.fingerprint,
                                                  color: AppColors.primary,
                                                  size: 22,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Unlock with ${authState.biometricTypeLabel}',
                                                  style: AppTypography.labelLg.copyWith(
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],

                                // Biometric Login Preference Switch
                                if (!authNotifier.isSignUpMode) ...[
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () {
                                      authNotifier.toggleBiometricLogin(!authState.isBiometricEnabled);
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.fingerprint,
                                                size: 16,
                                                color: authState.isBiometricEnabled
                                                    ? AppColors.primary
                                                    : AppColors.textSecondary,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'One-Touch Biometric Login',
                                                style: AppTypography.labelSm.copyWith(
                                                  color: AppColors.textSecondary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Switch(
                                            value: authState.isBiometricEnabled,
                                            activeColor: AppColors.primary,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            onChanged: (val) {
                                              authNotifier.toggleBiometricLogin(val);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Vehicle and Telemetry Staging Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg.withValues(alpha: 0.95),
                              borderRadius: AppTheme.radiusXl,
                              boxShadow: AppTheme.elevationLevel2,
                              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.motorcycle, size: 15, color: AppColors.primary),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('Convoy Profile', style: AppTypography.labelLg),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainerLow,
                                        borderRadius: AppTheme.radiusFull,
                                      ),
                                      child: Text(
                                        'Rider Metadata',
                                        style: AppTypography.labelSm.copyWith(color: AppColors.onPrimaryFixedVariant),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),

                                // Vehicle Class Selector
                                VehicleClassSelector(
                                  selectedClass: authNotifier.selectedVehicleClass,
                                  onSelected: (val) {
                                    setState(() {
                                      authNotifier.setVehicleClass(val);
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),

                                // HUD Beacon Color Swatch
                                BeaconColorPicker(
                                  selectedColorHex: authNotifier.selectedBeaconColor,
                                  onSelected: (val) {
                                    setState(() {
                                      authNotifier.setBeaconColor(val);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. OTP Verification Modal Overlay
          if (authState.isOtpPending)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: Center(
                  child: OtpVerificationDialog(
                    phoneOrEmail: authNotifier.email,
                    session: 'aws-verification',
                    resendCountdown: authState.resendCountdown,
                    isLoading: authState.isLoading,
                    errorMessage: authState.errorMessage,
                    onVerify: (code) async {
                      await authNotifier.confirmSignUp(code);
                    },
                    onResend: () async {
                      await authNotifier.resendConfirmationCode();
                    },
                    onCancel: authNotifier.cancelOtp,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Simulated vector map street grids & glowing neon routes
class _VectorGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF252B3B).withValues(alpha: 0.45)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double step = 60.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Arterial Route Lines
    final routePaint = Paint()
      ..color = const Color(0xFF1F2638)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path1 = Path()
      ..moveTo(0, size.height * 0.3)
      ..cubicTo(size.width * 0.3, size.height * 0.35, size.width * 0.6, size.height * 0.15, size.width, size.height * 0.4);
    canvas.drawPath(path1, routePaint);

    // Glowing Neon Convoy Polyline
    final glowPaint = Paint()
      ..color = AppColors.routeCyan.withValues(alpha: 0.7)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final neonPath = Path()
      ..moveTo(size.width * 0.1, size.height * 0.25)
      ..cubicTo(size.width * 0.4, size.height * 0.28, size.width * 0.7, size.height * 0.5, size.width * 0.9, size.height * 0.75);
    canvas.drawPath(neonPath, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
