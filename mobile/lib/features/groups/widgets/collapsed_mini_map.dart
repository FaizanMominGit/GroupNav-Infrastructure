import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/pack_formation.dart';

class CollapsedMiniMap extends StatelessWidget {
  final PackFormation formation;
  final VoidCallback onExpandMap;

  const CollapsedMiniMap({
    super.key,
    required this.formation,
    required this.onExpandMap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.mapSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            // 1. Vector Map Grid Simulation Background
            Positioned.fill(
              child: CustomPaint(
                painter: _MiniMapBackgroundPainter(),
              ),
            ),

            // 2. Geofence Boundary Mesh (Dashed Ellipse/Circle)
            Center(
              child: Container(
                width: 120,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(42),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.40),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
              ),
            ),

            // 3. Pack Cluster Vehicle Nodes
            Center(
              child: SizedBox(
                width: 130,
                height: 80,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Primary Rider (Self / Road Captain) - Center
                    Align(
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(alpha: 0.25),
                            ),
                          ),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dynamic Pack Members
                    ...formation.members.where((m) => !m.isCurrentUser && !m.isLeader).toList().asMap().entries.map((entry) {
                      final idx = entry.key;
                      final member = entry.value;
                      final isAhead = member.offsetMeters > 0;
                      final top = (idx % 2 == 0) ? 14.0 : 50.0;
                      final left = (idx % 2 == 0) ? 20.0 : 96.0;
                      final color = isAhead ? AppColors.telemetryEmerald : AppColors.secondary;
                      return Positioned(
                        top: top,
                        left: left,
                        child: Tooltip(
                          message: member.cleanCallsign,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // 4. Cluster Metadata Badge (Bottom-Left)
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cardBg.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.borderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hub, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Cluster Mesh: ${formation.members.length} Vehicles',
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 10,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. Expand Map CTA (Top-Right)
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onExpandMap,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.borderSubtle),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fullscreen, size: 14, color: AppColors.textPrimary),
                        const SizedBox(width: 3),
                        Text(
                          'Expand Map',
                          style: AppTypography.labelMd.copyWith(
                            fontSize: 11,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter rendering subtle cartographic street grid lines
class _MiniMapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final thinRoadPaint = Paint()
      ..color = const Color(0xFFEDF2F7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final cyanRoutePaint = Paint()
      ..color = AppColors.routeCyan.withValues(alpha: 0.75)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Horizontal & vertical arterial lines
    canvas.drawLine(Offset(0, size.height * 0.4), Offset(size.width, size.height * 0.4), roadPaint);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.3, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.7, 0), Offset(size.width * 0.7, size.height), thinRoadPaint);

    // Diagonal route curve
    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.75)
      ..quadraticBezierTo(size.width * 0.45, size.height * 0.2, size.width * 0.95, size.height * 0.6);
    canvas.drawPath(path, cyanRoutePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
