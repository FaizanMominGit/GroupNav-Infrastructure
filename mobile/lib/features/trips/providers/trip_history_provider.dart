import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/location_service.dart';
import '../../radar/providers/radar_provider.dart';
import '../models/trip_record.dart';

class TripPlaybackState {
  final List<TripRecord> availableTrips;
  final TripRecord? selectedTrip;
  final bool isPlaying;
  final double progress; // 0.0 to 1.0
  final double playbackSpeed; // 1.0, 1.5, 2.0
  final LatLng activePosition;
  final ElevationPoint currentElevationPoint;
  final bool isRecording;
  final String? activeRecordingTitle;
  final DateTime? recordingStartTime;
  final List<LatLng> recordedCoordinates;
  final List<ElevationPoint> recordedElevations;

  const TripPlaybackState({
    this.availableTrips = const [],
    this.selectedTrip,
    this.isPlaying = false,
    this.progress = 0.0,
    this.playbackSpeed = 1.0,
    this.activePosition = const LatLng(19.0760, 72.8777),
    this.currentElevationPoint = const ElevationPoint(
      distanceKm: 0.0,
      elevationMeters: 0.0,
      speedKmh: 0.0,
    ),
    this.isRecording = false,
    this.activeRecordingTitle,
    this.recordingStartTime,
    this.recordedCoordinates = const [],
    this.recordedElevations = const [],
  });

  Duration get currentDuration {
    if (selectedTrip == null) return Duration.zero;
    final totalMs = selectedTrip!.duration.inMilliseconds;
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
    bool? isRecording,
    String? activeRecordingTitle,
    DateTime? recordingStartTime,
    List<LatLng>? recordedCoordinates,
    List<ElevationPoint>? recordedElevations,
  }) {
    return TripPlaybackState(
      availableTrips: availableTrips ?? this.availableTrips,
      selectedTrip: selectedTrip ?? this.selectedTrip,
      isPlaying: isPlaying ?? this.isPlaying,
      progress: progress ?? this.progress,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      activePosition: activePosition ?? this.activePosition,
      currentElevationPoint: currentElevationPoint ?? this.currentElevationPoint,
      isRecording: isRecording ?? this.isRecording,
      activeRecordingTitle: activeRecordingTitle ?? this.activeRecordingTitle,
      recordingStartTime: recordingStartTime ?? this.recordingStartTime,
      recordedCoordinates: recordedCoordinates ?? this.recordedCoordinates,
      recordedElevations: recordedElevations ?? this.recordedElevations,
    );
  }
}

class TripHistoryNotifier extends StateNotifier<TripPlaybackState> {
  final LocationService? locationService;
  Timer? _playbackTimer;
  StreamSubscription<PositionData>? _locationSub;

  TripHistoryNotifier({this.locationService}) : super(const TripPlaybackState()) {
    _listenToLocation();
  }

  void _listenToLocation() {
    _locationSub = locationService?.positionStream.listen((pos) {
      if (state.isRecording) {
        addBreadcrumb(
          LatLng(pos.latitude, pos.longitude),
          pos.speedKmh,
          pos.altitude,
        );
      }
    });
  }

  void startRecording({String? title}) {
    state = state.copyWith(
      isRecording: true,
      activeRecordingTitle: title ?? 'Live Ride Session',
      recordingStartTime: DateTime.now(),
      recordedCoordinates: [],
      recordedElevations: [],
    );
  }

  void addBreadcrumb(LatLng pos, double speedKmh, double altitudeMeters) {
    if (!state.isRecording) return;
    final updatedCoords = List<LatLng>.from(state.recordedCoordinates)..add(pos);

    // Calculate total distance so far
    double totalDistKm = 0.0;
    const distance = Distance();
    for (int i = 0; i < updatedCoords.length - 1; i++) {
      totalDistKm += distance.as(LengthUnit.Kilometer, updatedCoords[i], updatedCoords[i + 1]);
    }

    final newPoint = ElevationPoint(
      distanceKm: double.parse(totalDistKm.toStringAsFixed(2)),
      elevationMeters: altitudeMeters,
      speedKmh: speedKmh,
    );
    final updatedElevations = List<ElevationPoint>.from(state.recordedElevations)..add(newPoint);

    state = state.copyWith(
      recordedCoordinates: updatedCoords,
      recordedElevations: updatedElevations,
    );
  }

  TripRecord? stopRecording() {
    if (!state.isRecording || state.recordedCoordinates.isEmpty) {
      state = state.copyWith(isRecording: false);
      return null;
    }

    final now = DateTime.now();
    final start = state.recordingStartTime ?? now.subtract(const Duration(minutes: 1));
    final duration = now.difference(start);

    // Compute total distance
    double totalDistKm = 0.0;
    const distance = Distance();
    for (int i = 0; i < state.recordedCoordinates.length - 1; i++) {
      totalDistKm += distance.as(
        LengthUnit.Kilometer,
        state.recordedCoordinates[i],
        state.recordedCoordinates[i + 1],
      );
    }
    if (totalDistKm == 0.0 && state.recordedCoordinates.length > 1) {
      totalDistKm = 0.1;
    }

    // Compute speeds
    double maxSpeed = 0.0;
    double speedSum = 0.0;
    for (final pt in state.recordedElevations) {
      if (pt.speedKmh > maxSpeed) maxSpeed = pt.speedKmh;
      speedSum += pt.speedKmh;
    }
    final avgSpeed = state.recordedElevations.isNotEmpty
        ? speedSum / state.recordedElevations.length
        : 0.0;

    final waypoints = [
      TripWaypoint(
        position: state.recordedCoordinates.first,
        title: 'Start Waypoint',
        type: WaypointType.start,
      ),
      if (state.recordedCoordinates.length > 2)
        TripWaypoint(
          position: state.recordedCoordinates[state.recordedCoordinates.length ~/ 2],
          title: 'Convoy Checkpoint',
          type: WaypointType.checkpoint,
        ),
      TripWaypoint(
        position: state.recordedCoordinates.last,
        title: 'Finish Waypoint',
        type: WaypointType.finish,
      ),
    ];

    final newTrip = TripRecord(
      id: 'trip-${now.millisecondsSinceEpoch}',
      title: state.activeRecordingTitle ?? 'Recorded Convoy Run',
      date: start,
      distanceKm: double.parse(totalDistKm.toStringAsFixed(2)),
      duration: duration,
      maxSpeedKmh: double.parse(maxSpeed.toStringAsFixed(1)),
      avgSpeedKmh: double.parse(avgSpeed.toStringAsFixed(1)),
      totalClimbMeters: 0,
      packRidersCount: 1,
      routeCoordinates: state.recordedCoordinates,
      waypoints: waypoints,
      elevationProfile: state.recordedElevations,
    );

    final updatedList = [newTrip, ...state.availableTrips];

    state = state.copyWith(
      isRecording: false,
      availableTrips: updatedList,
      selectedTrip: newTrip,
      progress: 0.0,
      activePosition: newTrip.routeCoordinates.first,
      currentElevationPoint: newTrip.elevationProfile.isNotEmpty
          ? newTrip.elevationProfile.first
          : const ElevationPoint(distanceKm: 0, elevationMeters: 0, speedKmh: 0),
    );

    return newTrip;
  }

  void selectTrip(TripRecord trip) {
    pause();
    state = state.copyWith(
      selectedTrip: trip,
      progress: 0.0,
      activePosition: trip.routeCoordinates.first,
      currentElevationPoint: trip.elevationProfile.isNotEmpty
          ? trip.elevationProfile.first
          : const ElevationPoint(distanceKm: 0, elevationMeters: 0, speedKmh: 0),
    );
  }

  void togglePlayPause() {
    if (state.selectedTrip == null) return;
    if (state.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void play() {
    if (state.selectedTrip == null) return;
    if (state.progress >= 1.0) {
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
    if (state.selectedTrip == null) return;
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
      if (!state.isPlaying || state.selectedTrip == null) {
        timer.cancel();
        return;
      }

      const simulatedReplayDurationSeconds = 60.0;
      final progressStep = (0.1 * state.playbackSpeed) / simulatedReplayDurationSeconds;
      final newProgress = state.progress + progressStep;

      if (newProgress >= 1.0) {
        seekProgress(1.0);
        pause();
      } else {
        seekProgress(newProgress);
      }
    });
  }

  void _updateInterpolatedState(double progress) {
    final trip = state.selectedTrip;
    if (trip == null || trip.routeCoordinates.isEmpty) return;

    final coords = trip.routeCoordinates;
    final totalSegments = coords.length - 1;
    LatLng newPos;

    if (totalSegments <= 0) {
      newPos = coords.first;
    } else {
      final scaledProgress = progress * totalSegments;
      final index = scaledProgress.floor().clamp(0, totalSegments - 1);
      final fraction = scaledProgress - index;

      final p1 = coords[index];
      final p2 = coords[index + 1];

      final lat = p1.latitude + (p2.latitude - p1.latitude) * fraction;
      final lng = p1.longitude + (p2.longitude - p1.longitude) * fraction;
      newPos = LatLng(lat, lng);
    }

    ElevationPoint newElev = const ElevationPoint(distanceKm: 0, elevationMeters: 0, speedKmh: 0);
    if (trip.elevationProfile.isNotEmpty) {
      final elevProfile = trip.elevationProfile;
      final elevIndex = (progress * (elevProfile.length - 1)).round().clamp(0, elevProfile.length - 1);
      newElev = elevProfile[elevIndex];
    }

    state = state.copyWith(
      progress: progress,
      activePosition: newPos,
      currentElevationPoint: newElev,
    );
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }
}

final tripHistoryNotifierProvider =
    StateNotifierProvider<TripHistoryNotifier, TripPlaybackState>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return TripHistoryNotifier(locationService: locationService);
});
