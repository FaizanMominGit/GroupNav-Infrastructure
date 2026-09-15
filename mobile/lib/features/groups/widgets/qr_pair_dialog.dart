import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class QrPairDialog extends StatelessWidget {
  final String packCode;
  final String packId;
  final String qrPayload;

  const QrPairDialog({
    super.key,
    required this.packCode,
    required this.packId,
    required this.qrPayload,
  });

  static Future<void> show(BuildContext context, {
    required String packCode,
    required String packId,
    required String qrPayload,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.inverseSurface.withValues(alpha: 0.60),
      builder: (context) => QrPairDialog(
        packCode: packCode,
        packId: packId,
        qrPayload: qrPayload,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_2, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('In-Person Pair', style: AppTypography.headlineMd.copyWith(fontSize: 17)),
                        Text('Pack #$packId Rendezvous', style: AppTypography.bodySm),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tactical QR Matrix Simulation Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // QR Matrix Visual
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(180, 180),
                          painter: _TacticalQrPainter(),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.navigation,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pack Code Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      packCode,
                      style: AppTypography.headlineLg.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 4,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Have nearby convoy members scan this code with their GroupNav app to sync automatically.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            // Copy Payload / Share Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: qrPayload));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pairing payload copied to clipboard!'),
                      backgroundColor: AppColors.primary,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy Pairing Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter rendering a stylized high-contrast QR Matrix pattern
class _TacticalQrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.fill;

    const double cellSize = 10.0;
    final int cols = (size.width / cellSize).floor();
    final int rows = (size.height / cellSize).floor();

    // Position detection corner squares (Top-Left, Top-Right, Bottom-Left)
    _drawCornerMarker(canvas, 0, 0, cellSize, paint);
    _drawCornerMarker(canvas, (cols - 7) * cellSize, 0, cellSize, paint);
    _drawCornerMarker(canvas, 0, (rows - 7) * cellSize, cellSize, paint);

    // Decorative procedural tactical data pattern
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        // Skip corner detection zones and center badge
        if ((r < 8 && c < 8) ||
            (r < 8 && c >= cols - 8) ||
            (r >= rows - 8 && c < 8) ||
            (r >= rows / 2 - 2 && r <= rows / 2 + 2 && c >= cols / 2 - 2 && c <= cols / 2 + 2)) {
          continue;
        }

        // Pseudo-random bit deterministic grid
        final hash = (r * 17 + c * 31 + (r ^ c)) % 3;
        if (hash == 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(c * cellSize + 1, r * cellSize + 1, cellSize - 2, cellSize - 2),
              const Radius.circular(2),
            ),
            paint,
          );
        }
      }
    }
  }

  void _drawCornerMarker(Canvas canvas, double x, double y, double cellSize, Paint paint) {
    // Outer 7x7
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, 7 * cellSize, 7 * cellSize),
        const Radius.circular(6),
      ),
      paint,
    );
    // Inner white 5x5
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + cellSize, y + cellSize, 5 * cellSize, 5 * cellSize),
        const Radius.circular(4),
      ),
      whitePaint,
    );
    // Center solid 3x3
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 2 * cellSize, y + 2 * cellSize, 3 * cellSize, 3 * cellSize),
        const Radius.circular(3),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
