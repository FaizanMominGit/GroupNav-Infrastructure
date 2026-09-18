import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/trip_history_provider.dart';
import '../widgets/elevation_pace_chart_card.dart';
import '../widgets/recorded_convoys_card.dart';
import '../widgets/replay_control_bar.dart';
import '../widgets/trip_replay_map.dart';

class TripHistoryScreen extends ConsumerWidget {
  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(tripHistoryNotifierProvider);
    final historyNotifier = ref.read(tripHistoryNotifierProvider.notifier);

    final currentTrip = playbackState.selectedTrip;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // Screen Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trip History & Replay',
                        style: AppTypography.headlineLg.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Aurora PostGIS spatial ledger & LiDAR profiles',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_graph, color: AppColors.primary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'POSTGIS',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Live Ride Recording Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: playbackState.isRecording
                    ? AppColors.alertCritical.withOpacity(0.08)
                    : AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: playbackState.isRecording
                      ? AppColors.alertCritical.withOpacity(0.5)
                      : AppColors.borderSubtle,
                  width: playbackState.isRecording ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: playbackState.isRecording
                          ? AppColors.alertCritical
                          : AppColors.primaryFixed.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      playbackState.isRecording ? Icons.fiber_manual_record : Icons.play_circle_outline,
                      color: playbackState.isRecording ? Colors.white : AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playbackState.isRecording
                              ? 'LIVE TRIP RECORDING'
                              : 'Live GPS Track Recorder',
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.w800,
                            color: playbackState.isRecording
                                ? AppColors.alertCritical
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          playbackState.isRecording
                              ? '${playbackState.recordedCoordinates.length} GPS fixes • ${playbackState.recordedElevations.isNotEmpty ? playbackState.recordedElevations.last.distanceKm : 0.0} km'
                              : 'Capture real telemetry coordinates for PostGIS & GPX',
                          style: AppTypography.bodySm.copyWith(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (playbackState.isRecording) {
                        final saved = historyNotifier.stopRecording();
                        if (saved != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Saved "${saved.title}" (${saved.distanceKm} km)! Ready for GPX export.'),
                              backgroundColor: AppColors.primary,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      } else {
                        historyNotifier.startRecording(title: 'Convoy Ride Session');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Live ride recording started! Tracking GPS breadcrumbs...'),
                            backgroundColor: AppColors.primary,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: playbackState.isRecording
                          ? AppColors.alertCritical
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text(
                      playbackState.isRecording ? 'Save Ride' : 'Record',
                      style: AppTypography.labelSm.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (currentTrip == null) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.route, size: 28, color: AppColors.primary),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No Recorded Trips Yet',
                      style: AppTypography.headlineMd.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap "Record" above to capture live GPS telemetry, speeds, and elevation profile. Saved rides will appear here for animated playback and GPX/GeoJSON export.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySm.copyWith(color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // 1. Interactive Replay Map
              TripReplayMap(
                trip: currentTrip,
                activePosition: playbackState.activePosition,
                progress: playbackState.progress,
              ),
              const SizedBox(height: 12),

              // 2. Tactile Replay Control Bar (Scrubber + Play/Pause + Speed)
              ReplayControlBar(
                trip: currentTrip,
                playbackState: playbackState,
                onTogglePlayPause: historyNotifier.togglePlayPause,
                onSeek: historyNotifier.seekProgress,
                onCycleSpeed: historyNotifier.cyclePlaybackSpeed,
              ),
              const SizedBox(height: 16),

              // 3. Spatial Elevation & Pace Chart (LiDAR mesh + Triad)
              ElevationPaceChartCard(
                trip: currentTrip,
                currentPoint: playbackState.currentElevationPoint,
                progress: playbackState.progress,
                onScrub: historyNotifier.seekProgress,
              ),
              const SizedBox(height: 16),

              // 4. Recorded Convoys List & Spatial Export
              RecordedConvoysCard(
                trips: playbackState.availableTrips,
                selectedTrip: currentTrip,
                onSelectTrip: historyNotifier.selectTrip,
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
