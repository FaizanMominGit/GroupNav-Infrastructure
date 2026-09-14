import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../models/convoy_peer.dart';

class ConvoyMarkerWidget extends StatelessWidget {
  final ConvoyPeer peer;

  const ConvoyMarkerWidget({super.key, required this.peer});

  @override
  Widget build(BuildContext context) {
    if (peer.isLeader) {
      return _buildLeaderMarker();
    } else {
      return _buildPeerMarker();
    }
  }

  Widget _buildLeaderMarker() {
    final rotationRad = peer.headingDeg * (math.pi / 180.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Moniker & Status Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: AppTheme.radiusFull,
            boxShadow: AppTheme.elevationLevel1,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.telemetryEmerald,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(peer.callsign, style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              Text(peer.offsetFormatted, style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Direction Vector Disc with Pulsing Radar Ring
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Transform.rotate(
                  angle: rotationRad,
                  child: const Icon(
                    Icons.navigation,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPeerMarker() {
    final rotationRad = peer.headingDeg * (math.pi / 180.0);
    final isAhead = peer.relativeOffsetMeters >= 0;
    final badgeColor = isAhead ? AppColors.secondary : AppColors.alertWarning;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Moniker & Offset Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: AppTheme.radiusFull,
            boxShadow: AppTheme.elevationLevel1,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${peer.callsign}:', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 3),
              Text(peer.offsetFormatted, style: AppTypography.labelSm.copyWith(color: badgeColor, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 3),

        // Peer Node Disc
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderSubtle, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Transform.rotate(
              angle: rotationRad,
              child: Icon(
                Icons.navigation,
                size: 15,
                color: isAhead ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
