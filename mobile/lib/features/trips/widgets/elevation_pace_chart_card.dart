import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/trip_record.dart';

class ElevationPaceChartCard extends StatelessWidget {
  final TripRecord trip;
  final ElevationPoint currentPoint;
  final double progress;
  final ValueChanged<double>? onScrub;

  const ElevationPaceChartCard({
    super.key,
    required this.trip,
    required this.currentPoint,
    required this.progress,
    this.onScrub,
  });

  @override
  Widget build(BuildContext context) {
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
          // Header with LiDAR badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.terrain, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Spatial Elevation & Pace',
                    style: AppTypography.labelLg.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.routeCyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.routeCyan.withOpacity(0.3)),
                ),
                child: Text(
                  'LiDAR MESH',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Key Metric Triad Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricItem(
                  'MAX SPEED',
                  '${trip.maxSpeedKmh.round()}',
                  'km/h',
                  AppColors.primary,
                ),
                _buildDivider(),
                _buildMetricItem(
                  'AVG PACE',
                  '${trip.avgSpeedKmh.round()}',
                  'km/h',
                  AppColors.telemetryEmerald,
                ),
                _buildDivider(),
                _buildMetricItem(
                  'TOTAL CLIMB',
                  '+${trip.totalClimbMeters}',
                  'm',
                  AppColors.alertWarning,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Custom Elevation & Pace Chart Canvas
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              if (onScrub != null) {
                final RenderBox box = context.findRenderObject() as RenderBox;
                final localX = details.localPosition.dx.clamp(0.0, box.size.width);
                final newProgress = (localX / box.size.width).clamp(0.0, 1.0);
                onScrub!(newProgress);
              }
            },
            child: SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(
                painter: _ElevationChartPainter(
                  profile: trip.elevationProfile,
                  progress: progress,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Cursor Live Value Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Cursor Position:',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${currentPoint.distanceKm.toStringAsFixed(1)} km  •  ${currentPoint.elevationMeters.round()} m  •  ${currentPoint.speedKmh.round()} km/h',
                  style: AppTypography.bodySm.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, String unit, Color accent) {
    return Column(
      children: [
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.textSecondary,
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AppTypography.telemetryNum.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      color: AppColors.borderSubtle,
    );
  }
}

class _ElevationChartPainter extends CustomPainter {
  final List<ElevationPoint> profile;
  final double progress;

  _ElevationChartPainter({
    required this.profile,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.isEmpty) return;

    const double maxElevation = 900.0;
    const double maxSpeed = 120.0;

    // Draw grid guide lines
    final gridPaint = Paint()
      ..color = AppColors.borderSubtle.withOpacity(0.5)
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Build Area & Line Path for Elevation
    final areaPath = Path();
    final linePath = Path();
    final speedPath = Path();

    for (int i = 0; i < profile.length; i++) {
      final point = profile[i];
      final x = (i / (profile.length - 1)) * size.width;
      final yElev = size.height - (point.elevationMeters / maxElevation * size.height);
      final ySpeed = size.height - (point.speedKmh / maxSpeed * size.height);

      if (i == 0) {
        areaPath.moveTo(x, size.height);
        areaPath.lineTo(x, yElev);
        linePath.moveTo(x, yElev);
        speedPath.moveTo(x, ySpeed);
      } else {
        areaPath.lineTo(x, yElev);
        linePath.lineTo(x, yElev);
        speedPath.lineTo(x, ySpeed);
      }
    }

    areaPath.lineTo(size.width, size.height);
    areaPath.close();

    // Fill Elevation Gradient Area
    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withOpacity(0.28),
          AppColors.primary.withOpacity(0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(areaPath, areaPaint);

    // Draw Elevation Outline
    final linePaint = Paint()
      ..color = AppColors.routeCyan
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(linePath, linePaint);

    // Draw Speed Profile (Dashed / Emerald)
    final speedPaint = Paint()
      ..color = AppColors.telemetryEmerald.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(speedPath, speedPaint);

    // Draw Scrub Cursor Line
    final cursorX = progress * size.width;
    final cursorPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 1.8;

    canvas.drawLine(Offset(cursorX, 0), Offset(cursorX, size.height), cursorPaint);

    // Draw Cursor Indicator Dots
    final dotOuter = Paint()..color = AppColors.primary;
    final dotInner = Paint()..color = Colors.white;

    // Approximate elevation y at progress
    final totalSegments = profile.length - 1;
    final exactIdx = progress * totalSegments;
    final segIdx = exactIdx.floor().clamp(0, totalSegments - 1);
    final segProg = exactIdx - segIdx;
    final pElev = profile[segIdx].elevationMeters +
        (profile[segIdx + 1].elevationMeters - profile[segIdx].elevationMeters) * segProg;
    final cursorY = size.height - (pElev / maxElevation * size.height);

    canvas.drawCircle(Offset(cursorX, cursorY), 5.0, dotOuter);
    canvas.drawCircle(Offset(cursorX, cursorY), 2.5, dotInner);
  }

  @override
  bool shouldRepaint(covariant _ElevationChartPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.profile != profile;
  }
}
