import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:groupnav_mobile/features/trips/models/trip_record.dart';
import 'package:groupnav_mobile/features/trips/providers/trip_history_provider.dart';

void main() {
  final sampleCoordinates = [
    const LatLng(37.7749, -122.4194),
    const LatLng(37.6600, -122.4900),
    const LatLng(37.5400, -122.5150),
  ];

  final sampleElevation = [
    const ElevationPoint(distanceKm: 0.0, elevationMeters: 50.0, speedKmh: 40.0),
    const ElevationPoint(distanceKm: 20.0, elevationMeters: 250.0, speedKmh: 80.0),
    const ElevationPoint(distanceKm: 40.0, elevationMeters: 500.0, speedKmh: 100.0),
  ];

  final sampleTrip = TripRecord(
    id: 'test-trip-01',
    title: 'Coastal Test Run',
    date: DateTime(2024, 10, 15, 10, 0),
    distanceKm: 40.0,
    duration: const Duration(hours: 1, minutes: 15),
    maxSpeedKmh: 100.0,
    avgSpeedKmh: 65.0,
    totalClimbMeters: 750,
    packRidersCount: 4,
    routeCoordinates: sampleCoordinates,
    waypoints: [
      TripWaypoint(position: sampleCoordinates.first, title: 'Start', type: WaypointType.start),
      TripWaypoint(position: sampleCoordinates.last, title: 'Finish', type: WaypointType.finish),
    ],
    elevationProfile: sampleElevation,
  );

  group('TripRecord Model Tests', () {
    test('Formats duration and elapsed time strings accurately', () {
      expect(sampleTrip.formattedDuration, '1h 15m');
      expect(sampleTrip.formattedTime, '01:15:00');

      final shortTrip = TripRecord(
        id: 'short-trip',
        title: 'Sprint',
        date: DateTime(2024, 10, 16),
        distanceKm: 10.0,
        duration: const Duration(minutes: 45),
        maxSpeedKmh: 80,
        avgSpeedKmh: 50,
        totalClimbMeters: 200,
        packRidersCount: 2,
        routeCoordinates: const [],
        waypoints: const [],
        elevationProfile: const [],
      );
      expect(shortTrip.formattedDuration, '45m');
    });

    test('interpolatePosition computes exact linear segment positions', () {
      final start = sampleTrip.interpolatePosition(0.0);
      expect(start.latitude, closeTo(37.7749, 0.0001));
      expect(start.longitude, closeTo(-122.4194, 0.0001));

      final end = sampleTrip.interpolatePosition(1.0);
      expect(end.latitude, closeTo(37.5400, 0.0001));
      expect(end.longitude, closeTo(-122.5150, 0.0001));

      final midpoint = sampleTrip.interpolatePosition(0.5);
      expect(midpoint.latitude, closeTo(37.6600, 0.0001));
      expect(midpoint.longitude, closeTo(-122.4900, 0.0001));
    });

    test('interpolateElevationPoint computes linear elevation and speed', () {
      final start = sampleTrip.interpolateElevationPoint(0.0);
      expect(start.distanceKm, 0.0);
      expect(start.elevationMeters, 50.0);
      expect(start.speedKmh, 40.0);

      final end = sampleTrip.interpolateElevationPoint(1.0);
      expect(end.distanceKm, 40.0);
      expect(end.elevationMeters, 500.0);
      expect(end.speedKmh, 100.0);

      final mid = sampleTrip.interpolateElevationPoint(0.5);
      expect(mid.distanceKm, closeTo(20.0, 0.1));
      expect(mid.elevationMeters, closeTo(250.0, 0.1));
      expect(mid.speedKmh, closeTo(80.0, 0.1));
    });

    test('toGeoJson serializes to valid GeoJSON FeatureCollection', () {
      final geoJsonStr = sampleTrip.toGeoJson();
      final map = jsonDecode(geoJsonStr) as Map<String, dynamic>;

      expect(map['type'], 'FeatureCollection');
      final features = map['features'] as List;
      expect(features.length, 1);

      final feature = features.first as Map<String, dynamic>;
      expect(feature['type'], 'Feature');
      expect(feature['properties']['tripId'], 'test-trip-01');
      expect(feature['properties']['distanceKm'], 40.0);

      final geometry = feature['geometry'] as Map<String, dynamic>;
      expect(geometry['type'], 'LineString');
      final coordinates = geometry['coordinates'] as List;
      expect(coordinates.length, 3);
    });

    test('toGpx serializes to standard XML GPX 1.1 format', () {
      final gpxStr = sampleTrip.toGpx();

      expect(gpxStr.contains('<?xml version="1.0" encoding="UTF-8"?>'), true);
      expect(gpxStr.contains('<gpx version="1.1"'), true);
      expect(gpxStr.contains('<name>Coastal Test Run</name>'), true);
      expect(gpxStr.contains('<trk>'), true);
      expect(gpxStr.contains('<trkseg>'), true);
      expect(gpxStr.contains('lat="37.774900" lon="-122.419400"'), true);
      expect(gpxStr.contains('</gpx>'), true);
    });
  });

  group('TripHistoryNotifier Playback Tests', () {
    test('Initializes with default trips and zero playback progress', () {
      final notifier = TripHistoryNotifier();
      final state = notifier.state;

      expect(state.availableTrips.isEmpty, true);
      expect(state.isPlaying, false);
      expect(state.progress, 0.0);
      expect(state.playbackSpeed, 1.0);
      expect(state.formattedCurrentTime, '00:00:00');
    });

    test('selectTrip switches active session and resets scrubber', () {
      final notifier = TripHistoryNotifier();
      final sampleTrip = TripRecord(
        id: 'sample-1',
        title: 'Sample Ride',
        date: DateTime.now(),
        distanceKm: 12.0,
        duration: const Duration(minutes: 20),
        maxSpeedKmh: 80,
        avgSpeedKmh: 60,
        totalClimbMeters: 50,
        packRidersCount: 1,
        routeCoordinates: const [LatLng(19.0760, 72.8777), LatLng(19.0800, 72.8800)],
        waypoints: const [],
        elevationProfile: const [],
      );

      notifier.selectTrip(sampleTrip);
      notifier.seekProgress(0.75);
      expect(notifier.state.progress, 0.75);

      notifier.selectTrip(sampleTrip);

      expect(notifier.state.selectedTrip?.id, sampleTrip.id);
      expect(notifier.state.progress, 0.0);
      expect(notifier.state.isPlaying, false);
    });

    test('togglePlayPause transitions playback play and pause states', () {
      final notifier = TripHistoryNotifier();
      expect(notifier.state.isPlaying, false);

      final sampleTrip = TripRecord(
        id: 'sample-1',
        title: 'Sample Ride',
        date: DateTime.now(),
        distanceKm: 12.0,
        duration: const Duration(minutes: 20),
        maxSpeedKmh: 80,
        avgSpeedKmh: 60,
        totalClimbMeters: 50,
        packRidersCount: 1,
        routeCoordinates: const [LatLng(19.0760, 72.8777), LatLng(19.0800, 72.8800)],
        waypoints: const [],
        elevationProfile: const [],
      );
      notifier.selectTrip(sampleTrip);

      notifier.togglePlayPause();
      expect(notifier.state.isPlaying, true);

      notifier.togglePlayPause();
      expect(notifier.state.isPlaying, false);
    });

    test('seekProgress clamps progress and updates interpolated coordinates', () {
      final notifier = TripHistoryNotifier();
      final sampleTrip = TripRecord(
        id: 'sample-1',
        title: 'Sample Ride',
        date: DateTime.now(),
        distanceKm: 12.0,
        duration: const Duration(minutes: 20),
        maxSpeedKmh: 80,
        avgSpeedKmh: 60,
        totalClimbMeters: 50,
        packRidersCount: 1,
        routeCoordinates: const [LatLng(19.0760, 72.8777), LatLng(19.0800, 72.8800)],
        waypoints: const [],
        elevationProfile: const [
          ElevationPoint(distanceKm: 0.0, elevationMeters: 10, speedKmh: 40),
          ElevationPoint(distanceKm: 12.0, elevationMeters: 50, speedKmh: 80),
        ],
      );
      notifier.selectTrip(sampleTrip);

      notifier.seekProgress(0.5);

      expect(notifier.state.progress, 0.5);
      expect(notifier.state.activePosition, isNotNull);
      expect(notifier.state.currentElevationPoint, isNotNull);

      // Clamp checks
      notifier.seekProgress(1.5);
      expect(notifier.state.progress, 1.0);

      notifier.seekProgress(-0.5);
      expect(notifier.state.progress, 0.0);
    });

    test('cyclePlaybackSpeed cycles through 1.0x, 1.5x, 2.0x', () {
      final notifier = TripHistoryNotifier();
      expect(notifier.state.playbackSpeed, 1.0);

      notifier.cyclePlaybackSpeed();
      expect(notifier.state.playbackSpeed, 1.5);

      notifier.cyclePlaybackSpeed();
      expect(notifier.state.playbackSpeed, 2.0);

      notifier.cyclePlaybackSpeed();
      expect(notifier.state.playbackSpeed, 1.0);
    });

    test('Live recording accumulates breadcrumbs and finalizes into selectable TripRecord', () {
      final notifier = TripHistoryNotifier();
      final initialCount = notifier.state.availableTrips.length;
      expect(initialCount, equals(0)); // No fake mock trips!

      notifier.startRecording(title: 'Apex Skyline Test');
      expect(notifier.state.isRecording, isTrue);
      expect(notifier.state.activeRecordingTitle, equals('Apex Skyline Test'));

      // Accumulate 3 breadcrumbs
      notifier.addBreadcrumb(const LatLng(37.7749, -122.4194), 55.0, 310.0);
      notifier.addBreadcrumb(const LatLng(37.7800, -122.4150), 65.0, 325.0);
      notifier.addBreadcrumb(const LatLng(37.7850, -122.4110), 85.0, 340.0);

      expect(notifier.state.recordedCoordinates.length, equals(3));
      expect(notifier.state.recordedElevations.length, equals(3));
      expect(notifier.state.recordedElevations.last.distanceKm, greaterThan(0.5));

      // Finalize and save
      final savedTrip = notifier.stopRecording();
      expect(savedTrip, isNotNull);
      expect(savedTrip!.title, equals('Apex Skyline Test'));
      expect(savedTrip.routeCoordinates.length, equals(3));
      expect(savedTrip.maxSpeedKmh, equals(85.0));
      expect(savedTrip.avgSpeedKmh, closeTo(68.3, 0.5));
      expect(notifier.state.isRecording, isFalse);

      // Verify prepended into availableTrips and active
      expect(notifier.state.availableTrips.length, equals(initialCount + 1));
      expect(notifier.state.selectedTrip?.id, equals(savedTrip.id));
      expect(notifier.state.selectedTrip?.title, equals('Apex Skyline Test'));

      // Verify exportability
      final gpx = savedTrip.toGpx();
      expect(gpx.contains('lat="37.774900"'), isTrue);
      expect(gpx.contains('lat="37.785000"'), isTrue);

      final geoJson = jsonDecode(savedTrip.toGeoJson()) as Map<String, dynamic>;
      expect(geoJson['type'], equals('FeatureCollection'));
      final feature = (geoJson['features'] as List).first as Map<String, dynamic>;
      expect(feature['properties']['title'], equals('Apex Skyline Test'));
    });
  });
}
