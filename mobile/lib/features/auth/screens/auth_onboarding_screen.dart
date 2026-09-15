import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/top_app_bar_pill.dart';
import '../providers/auth_provider.dart';
import '../widgets/beacon_color_picker.dart';
import '../widgets/otp_verification_dialog.dart';
import '../widgets/vehicle_class_selector.dart';

class AuthOnboardingScreen extends ConsumerStatefulWidget {
  const AuthOnboardingScreen({super.key});

  @override
  ConsumerState<AuthOnboardingScreen> createState() => _AuthOnboardingScreenState();
}

class _AuthOnboardingScreenState extends ConsumerState<AuthOnboardingScreen> {
  late final TextEditingController _contactController;
  late final TextEditingController _callsignController;

  @override
  void initState() {
    super.initState();
    final authNotifier = ref.read(authNotifierProvider.notifier);
    _contactController = TextEditingController(text: authNotifier.phoneOrEmail);
    _callsignController = TextEditingController(text: authNotifier.callsign);
  }

  @override
  void dispose() {
    _contactController.dispose();
    _callsignController.dispose();
    super.dispose();
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
                  subtitle: 'DePIN',
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
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 6,
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
                                          const Icon(Icons.lock, size: 13, color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            'SECURE ACCESS',
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
                                          'AWS Cognito Connected',
                                          style: AppTypography.labelSm.copyWith(color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Text('Pilot Authentication', style: AppTypography.headlineLg),
                                const SizedBox(height: 2),
                                Text(
                                  'Link vehicle communications to initiate real-time telemetry consensus.',
                                  style: AppTypography.bodySm,
                                ),
                                const SizedBox(height: 18),

                                // Phone / Email Input Field
                                Text('Mobile Number / Pilot Email', style: AppTypography.labelMd),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _contactController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: AppTypography.bodyMd,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.phone_iphone, size: 20, color: AppColors.textSecondary),
                                    suffixIcon: const Icon(Icons.check_circle, size: 20, color: AppColors.telemetryEmerald),
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
                                  onChanged: authNotifier.setPhoneOrEmail,
                                ),
                                const SizedBox(height: 14),

                                // Tactical Callsign Field
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Tactical Callsign',
                                        style: AppTypography.labelMd,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Pre-assigned mesh tag',
                                        style: AppTypography.labelSm.copyWith(color: AppColors.primary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _callsignController,
                                  style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700),
                                  decoration: InputDecoration(
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
                                const SizedBox(height: 18),

                                // Continue with OTP Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: authState.isLoading
                                        ? null
                                        : () => authNotifier.requestOtp(),
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
                                              Text('Continue with OTP', style: AppTypography.labelLg.copyWith(color: Colors.white)),
                                              const SizedBox(width: 8),
                                              const Icon(Icons.arrow_forward, size: 18),
                                            ],
                                          ),
                                  ),
                                ),

                                if (authState.errorMessage != null) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    authState.errorMessage!,
                                    style: AppTypography.bodySm.copyWith(color: AppColors.alertCritical),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Identity Setup Staging Card
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
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.tune, size: 15, color: AppColors.primary),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Identity Setup Flow',
                                              style: AppTypography.labelLg,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainerLow,
                                        borderRadius: AppTheme.radiusFull,
                                      ),
                                      child: Text(
                                        'Telemetry Staging',
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
                          const SizedBox(height: 16),

                          // DePIN Telemetry Reward Pool Banner
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg.withValues(alpha: 0.9),
                              borderRadius: AppTheme.radiusFull,
                              boxShadow: AppTheme.elevationLevel1,
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.toll, size: 20, color: AppColors.secondary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Convoy Reward Pool',
                                          style: AppTypography.labelSm,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryContainer.withValues(alpha: 0.3),
                                    borderRadius: AppTheme.radiusFull,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppColors.secondary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '+4.2 NAV/hr',
                                        style: AppTypography.labelSm.copyWith(
                                          color: AppColors.secondary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
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
                    phoneOrEmail: authNotifier.phoneOrEmail,
                    session: authState.session ?? '0x82A1B9E3C1',
                    resendCountdown: authState.resendCountdown,
                    isLoading: authState.isLoading,
                    errorMessage: authState.errorMessage,
                    onVerify: (code) async {
                      await authNotifier.verifyOtp(code);
                    },
                    onResend: () async {
                      await authNotifier.requestOtp();
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
