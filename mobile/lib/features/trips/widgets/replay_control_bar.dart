import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/trip_record.dart';
import '../providers/trip_history_provider.dart';

class ReplayControlBar extends StatelessWidget {
  final TripRecord trip;
  final TripPlaybackState playbackState;
  final VoidCallback onTogglePlayPause;
  final ValueChanged<double> onSeek;
  final VoidCallback onCycleSpeed;

  const ReplayControlBar({
    super.key,
    required this.trip,
    required this.playbackState,
    required this.onTogglePlayPause,
    required this.onSeek,
    required this.onCycleSpeed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Playback Control Row
          Row(
            children: [
              // Play/Pause Button
              GestureDetector(
                onTap: onTogglePlayPause,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      playbackState.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Time Progress Readout
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONVOY REPLAY PROGRESS',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          playbackState.formattedCurrentTime,
                          style: AppTypography.telemetryNum.copyWith(
                            fontSize: 14,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          ' / ${trip.formattedTime}',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Speed Multiplier Pill
              InkWell(
                onTap: onCycleSpeed,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.speed, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${playbackState.playbackSpeed}x',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Scrubber Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.surfaceContainerHigh,
              thumbColor: AppColors.primary,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              overlayColor: AppColors.primary.withOpacity(0.12),
            ),
            child: Slider(
              value: playbackState.progress,
              min: 0.0,
              max: 1.0,
              onChanged: onSeek,
            ),
          ),
        ],
      ),
    );
  }
}
