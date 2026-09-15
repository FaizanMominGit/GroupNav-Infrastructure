import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/trip_record.dart';

class TripPlaybackState {
  final List<TripRecord> availableTrips;
  final TripRecord selectedTrip;
  final bool isPlaying;
  final double progress; // 0.0 to 1.0
  final double playbackSpeed; // 1.0, 1.5, 2.0
  final LatLng activePosition;
  final ElevationPoint currentElevationPoint;

  const TripPlaybackState({
    required this.availableTrips,
    required this.selectedTrip,
    this.isPlaying = false,
    this.progress = 0.0,
    this.playbackSpeed = 1.0,
    required this.activePosition,
    required this.currentElevationPoint,
  });

  Duration get currentDuration {
    final totalMs = selectedTrip.duration.inMilliseconds;
    return Duration(milliseconds: (totalMs * progress).round());
  }

  String get formattedCurrentTime {
    final dur = currentDuration;
    final hours = dur.inHours.toString().padLeft(2, '0');
    final minutes = dur.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = dur.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  TripPlaybackState copyWith({
    List<TripRecord>? availableTrips,
    TripRecord? selectedTrip,
    bool? isPlaying,
    double? progress,
    double? playbackSpeed,
    LatLng? activePosition,
    ElevationPoint? currentElevationPoint,
  }) {
    return TripPlaybackState(
      availableTrips: availableTrips ?? this.availableTrips,
      selectedTrip: selectedTrip ?? this.selectedTrip,
      isPlaying: isPlaying ?? this.isPlaying,
      progress: progress ?? this.progress,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      activePosition: activePosition ?? this.activePosition,
      currentElevationPoint: currentElevationPoint ?? this.currentElevationPoint,
    );
  }
}

class TripHistoryNotifier extends StateNotifier<TripPlaybackState> {
  Timer? _playbackTimer;

  TripHistoryNotifier() : super(_initialState()) {
    // Initial sync
    _updateInterpolatedState(0.0);
  }

  static TripPlaybackState _initialState() {
    final trips = _getMockTrips();
    final initialTrip = trips.first;
    return TripPlaybackState(
      availableTrips: trips,
      selectedTrip: initialTrip,
      isPlaying: false,
      progress: 0.0,
      playbackSpeed: 1.0,
      activePosition: initialTrip.routeCoordinates.first,
      currentElevationPoint: initialTrip.elevationProfile.first,
    );
  }

  void selectTrip(TripRecord trip) {
    pause();
    state = state.copyWith(
      selectedTrip: trip,
      progress: 0.0,
      activePosition: trip.routeCoordinates.first,
      currentElevationPoint: trip.elevationProfile.first,
    );
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void play() {
    if (state.progress >= 1.0) {
      // Loop from start if finished
      seekProgress(0.0);
    }
    state = state.copyWith(isPlaying: true);
    _startTimer();
  }

  void pause() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    state = state.copyWith(isPlaying: false);
  }

  void seekProgress(double newProgress) {
    final clamped = newProgress.clamp(0.0, 1.0);
    _updateInterpolatedState(clamped);
  }

  void cyclePlaybackSpeed() {
    double nextSpeed;
    if (state.playbackSpeed == 1.0) {
      nextSpeed = 1.5;
    } else if (state.playbackSpeed == 1.5) {
      nextSpeed = 2.0;
    } else {
      nextSpeed = 1.0;
    }
    state = state.copyWith(playbackSpeed: nextSpeed);
  }

  void _startTimer() {
    _playbackTimer?.cancel();
    const interval = Duration(milliseconds: 100);
    _playbackTimer = Timer.periodic(interval, (timer) {
      if (!state.isPlaying) {
        timer.cancel();
        return;
      }

      // Step duration: 100ms * speedMultiplier over a standard 60-second replay demo
      const simulatedReplayDurationSeconds = 60.0;
      final progressStep = (0.1 * state.playbackSpeed) / simulatedReplayDurationSeconds;
      final newProgress = state.progress + progressStep;

      if (newProgress >= 1.0) {
        seekProgress(1.0);
        pause();
      } else {
        _updateInterpolatedState(newProgress);
      }
    });
  }

  void _updateInterpolatedState(double progress) {
    final trip = state.selectedTrip;
    final pos = trip.interpolatePosition(progress);
    final elev = trip.interpolateElevationPoint(progress);

    state = state.copyWith(
      progress: progress,
      activePosition: pos,
      currentElevationPoint: elev,
    );
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  static List<TripRecord> _getMockTrips() {
    // 1. Pacific Coast Highway Run
    final pchCoordinates = [
      const LatLng(37.7749, -122.4194),
      const LatLng(37.7500, -122.4400),
      const LatLng(37.7100, -122.4700),
      const LatLng(37.6600, -122.4900),
      const LatLng(37.6000, -122.5000),
      const LatLng(37.5400, -122.5150),
      const LatLng(37.4800, -122.4800),
      const LatLng(37.4200, -122.4400),
      const LatLng(37.3800, -122.4000),
      const LatLng(37.3200, -122.3800),
    ];

    final pchElevation = [
      const ElevationPoint(distanceKm: 0.0, elevationMeters: 45.0, speedKmh: 42.0),
      const ElevationPoint(distanceKm: 8.5, elevationMeters: 120.0, speedKmh: 68.0),
      const ElevationPoint(distanceKm: 18.0, elevationMeters: 280.0, speedKmh: 82.0),
      const ElevationPoint(distanceKm: 28.5, elevationMeters: 410.0, speedKmh: 95.0),
      const ElevationPoint(distanceKm: 39.0, elevationMeters: 620.0, speedKmh: 88.0),
      const ElevationPoint(distanceKm: 48.2, elevationMeters: 740.0, speedKmh: 112.0),
      const ElevationPoint(distanceKm: 58.0, elevationMeters: 850.0, speedKmh: 76.0),
      const ElevationPoint(distanceKm: 68.0, elevationMeters: 510.0, speedKmh: 84.0),
      const ElevationPoint(distanceKm: 78.4, elevationMeters: 110.0, speedKmh: 64.0),
    ];

    final pchWaypoints = [
      TripWaypoint(position: pchCoordinates.first, title: 'Presidio Gate (Start)', type: WaypointType.start),
      TripWaypoint(position: pchCoordinates[4], title: 'Devil\'s Slide Checkpoint', type: WaypointType.checkpoint),
      TripWaypoint(position: pchCoordinates.last, title: 'Half Moon Bay Marina (Finish)', type: WaypointType.finish),
    ];

    // 2. Monterey to Big Sur Sprint
    final bigSurCoordinates = [
      const LatLng(36.6002, -121.8947),
      const LatLng(36.5500, -121.9200),
      const LatLng(36.4800, -121.9100),
      const LatLng(36.4200, -121.8900),
      const LatLng(36.3600, -121.8700),
      const LatLng(36.2704, -121.8081),
    ];

    final bigSurElevation = [
      const ElevationPoint(distanceKm: 0.0, elevationMeters: 15.0, speedKmh: 50.0),
      const ElevationPoint(distanceKm: 10.5, elevationMeters: 180.0, speedKmh: 78.0),
      const ElevationPoint(distanceKm: 22.0, elevationMeters: 390.0, speedKmh: 88.0),
      const ElevationPoint(distanceKm: 34.0, elevationMeters: 680.0, speedKmh: 98.0),
      const ElevationPoint(distanceKm: 46.2, elevationMeters: 220.0, speedKmh: 65.0),
    ];

    final bigSurWaypoints = [
      TripWaypoint(position: bigSurCoordinates.first, title: 'Fisherman\'s Wharf (Start)', type: WaypointType.start),
      TripWaypoint(position: bigSurCoordinates[2], title: 'Bixby Creek Bridge (CP-2)', type: WaypointType.checkpoint),
      TripWaypoint(position: bigSurCoordinates.last, title: 'Nepenthe Vista (Finish)', type: WaypointType.finish),
    ];

    // 3. Skyline Ridge Formation
    final skylineCoordinates = [
      const LatLng(37.4500, -122.2500),
      const LatLng(37.4000, -122.2400),
      const LatLng(37.3500, -122.2100),
      const LatLng(37.3000, -122.1800),
      const LatLng(37.2500, -122.1500),
    ];

    final skylineElevation = [
      const ElevationPoint(distanceKm: 0.0, elevationMeters: 320.0, speedKmh: 62.0),
      const ElevationPoint(distanceKm: 8.0, elevationMeters: 550.0, speedKmh: 82.0),
      const ElevationPoint(distanceKm: 16.0, elevationMeters: 780.0, speedKmh: 105.0),
      const ElevationPoint(distanceKm: 24.0, elevationMeters: 640.0, speedKmh: 78.0),
      const ElevationPoint(distanceKm: 32.8, elevationMeters: 410.0, speedKmh: 70.0),
    ];

    final skylineWaypoints = [
      TripWaypoint(position: skylineCoordinates.first, title: 'Highway 9 Summit (Start)', type: WaypointType.start),
      TripWaypoint(position: skylineCoordinates[2], title: 'Russian Ridge Checkpoint', type: WaypointType.checkpoint),
      TripWaypoint(position: skylineCoordinates.last, title: 'Alice\'s Restaurant (Finish)', type: WaypointType.finish),
    ];

    return [
      TripRecord(
        id: 'trip-pch-804',
        title: 'Pacific Coast Highway Run',
        date: DateTime(2024, 10, 14, 9, 30),
        distanceKm: 78.4,
        duration: const Duration(hours: 1, minutes: 42),
        maxSpeedKmh: 112.0,
        avgSpeedKmh: 64.0,
        totalClimbMeters: 1240,
        packRidersCount: 4,
        routeCoordinates: pchCoordinates,
        waypoints: pchWaypoints,
        elevationProfile: pchElevation,
      ),
      TripRecord(
        id: 'trip-bigsur-912',
        title: 'Monterey to Big Sur Sprint',
        date: DateTime(2024, 10, 11, 14, 15),
        distanceKm: 46.2,
        duration: const Duration(minutes: 54),
        maxSpeedKmh: 98.0,
        avgSpeedKmh: 58.0,
        totalClimbMeters: 890,
        packRidersCount: 3,
        routeCoordinates: bigSurCoordinates,
        waypoints: bigSurWaypoints,
        elevationProfile: bigSurElevation,
      ),
      TripRecord(
        id: 'trip-skyline-501',
        title: 'Skyline Ridge Formation',
        date: DateTime(2024, 10, 8, 11, 0),
        distanceKm: 32.8,
        duration: const Duration(minutes: 38),
        maxSpeedKmh: 105.0,
        avgSpeedKmh: 72.0,
        totalClimbMeters: 640,
        packRidersCount: 5,
        routeCoordinates: skylineCoordinates,
        waypoints: skylineWaypoints,
        elevationProfile: skylineElevation,
      ),
    ];
  }
}

final tripHistoryNotifierProvider =
    StateNotifierProvider<TripHistoryNotifier, TripPlaybackState>((ref) {
  return TripHistoryNotifier();
});
