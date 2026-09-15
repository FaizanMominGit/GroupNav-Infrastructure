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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
