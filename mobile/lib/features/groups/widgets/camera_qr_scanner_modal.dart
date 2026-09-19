import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../services/qr_scanner_service.dart';

class CameraQrScannerModal extends StatefulWidget {
  final ValueChanged<String> onCodeScanned;
  final IQrScannerService? qrScannerService;

  const CameraQrScannerModal({
    super.key,
    required this.onCodeScanned,
    this.qrScannerService,
  });

  static Future<String?> show(BuildContext context, {IQrScannerService? service}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CameraQrScannerModal(
        qrScannerService: service,
        onCodeScanned: (code) {
          Navigator.of(ctx).pop(code);
        },
      ),
    );
  }

  @override
  State<CameraQrScannerModal> createState() => _CameraQrScannerModalState();
}

class _CameraQrScannerModalState extends State<CameraQrScannerModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanAnimCtrl;
  final TextEditingController _manualInputCtrl = TextEditingController(text: 'GN-');
  bool _isFlashOn = false;
  late final IQrScannerService _qrService;

  @override
  void initState() {
    super.initState();
    _qrService = widget.qrScannerService ?? ProductionQrScannerService();
    _scanAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanAnimCtrl.dispose();
    _manualInputCtrl.dispose();
    super.dispose();
  }

  void _handleCode(String raw) {
    final parsed = _qrService.parseQrPayload(raw);
    if (parsed != null && parsed.isNotEmpty) {
      widget.onCodeScanned(parsed);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unrecognized QR payload format. Please enter a valid code.'),
          backgroundColor: AppColors.alertCritical,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Container(
      height: media.size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF0F1218),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          // 1. Simulated Camera Grid Background
          Positioned.fill(
            child: CustomPaint(
              painter: _ScannerBackdropPainter(),
            ),
          ),

          // 2. Main Viewport & Overlay Content
          SafeArea(
            child: Column(
              children: [
                // Top Action Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Flashlight Toggle Button
                      IconButton(
                        icon: Icon(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: _isFlashOn ? AppColors.routeCyan : Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            _isFlashOn = !_isFlashOn;
                          });
                        },
                      ),

                      // Title Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: AppTheme.radiusFull,
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.routeCyan,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'OPTICAL QR SCANNER',
                              style: AppTypography.labelSm.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Close Button
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Center Viewfinder with Animated Laser Reticle
                Center(
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      children: [
                        // Viewfinder Corner Brackets
                        CustomPaint(
                          size: const Size(260, 260),
                          painter: _ReticleCornerPainter(),
                        ),

                        // Animated Laser Scan Line
                        AnimatedBuilder(
                          animation: _scanAnimCtrl,
                          builder: (context, _) {
                            return Positioned(
                              top: _scanAnimCtrl.value * 240 + 10,
                              left: 12,
                              right: 12,
                              child: Container(
                                height: 2.5,
                                decoration: BoxDecoration(
                                  color: AppColors.routeCyan,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.routeCyan.withValues(alpha: 0.8),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Instruction Chip
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Align Road Captain\'s QR Code or bike sticker within the frame',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm.copyWith(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ),

                const Spacer(),

                // Bottom Manual Entry / Quick Simulation Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: AppTheme.radiusLg,
                    boxShadow: AppTheme.elevationLevel3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.keyboard, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'MANUAL CODE OR CLIPBOARD PASTE',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _manualInputCtrl,
                              textCapitalization: TextCapitalization.characters,
                              style: AppTypography.telemetryNum.copyWith(
                                color: AppColors.primary,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                hintText: 'GN-XXXX or JSON',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                filled: true,
                                fillColor: AppColors.surfaceContainerLow,
                                border: OutlineInputBorder(
                                  borderRadius: AppTheme.radiusMd,
                                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Paste Action
                          IconButton(
                            icon: const Icon(Icons.paste, color: AppColors.primary),
                            tooltip: 'Paste from clipboard',
                            onPressed: () async {
                              final data = await Clipboard.getData(Clipboard.kTextPlain);
                              if (data?.text != null && data!.text!.isNotEmpty) {
                                _manualInputCtrl.text = data.text!.trim();
                              }
                            },
                          ),

                          // Join Button
                          ElevatedButton(
                            onPressed: () {
                              _handleCode(_manualInputCtrl.text);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            child: const Text('Join'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Viewfinder corner brackets painter in Route Cyan
class _ReticleCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.routeCyan
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 28.0;

    // Top Left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Top Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom Left
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Bottom Right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Background vector grid pattern for simulated optical feed
class _ScannerBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1B2230)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
