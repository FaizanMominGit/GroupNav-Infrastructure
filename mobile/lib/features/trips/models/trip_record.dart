import 'dart:convert';
import 'package:latlong2/latlong.dart';

class ElevationPoint {
  final double distanceKm;
  final double elevationMeters;
  final double speedKmh;

  const ElevationPoint({
    required this.distanceKm,
    required this.elevationMeters,
    required this.speedKmh,
  });
}

enum WaypointType {
  start,
  checkpoint,
  finish;

  String get label {
    switch (this) {
      case WaypointType.start:
        return 'Start Waypoint';
      case WaypointType.checkpoint:
        return 'Convoy Checkpoint';
      case WaypointType.finish:
        return 'Finish Line';
    }
  }
}

class TripWaypoint {
  final LatLng position;
  final String title;
  final WaypointType type;

  const TripWaypoint({
    required this.position,
    required this.title,
    required this.type,
  });
}

class TripRecord {
  final String id;
  final String title;
  final DateTime date;
  final double distanceKm;
  final Duration duration;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final int totalClimbMeters;
  final int packRidersCount;
  final List<LatLng> routeCoordinates;
  final List<TripWaypoint> waypoints;
  final List<ElevationPoint> elevationProfile;

  const TripRecord({
    required this.id,
    required this.title,
    required this.date,
    required this.distanceKm,
    required this.duration,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    required this.totalClimbMeters,
    required this.packRidersCount,
    required this.routeCoordinates,
    required this.waypoints,
    required this.elevationProfile,
  });

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedTime {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  LatLng interpolatePosition(double progress) {
    if (routeCoordinates.isEmpty) {
      return const LatLng(37.7749, -122.4194);
    }
    if (routeCoordinates.length == 1 || progress <= 0.0) {
      return routeCoordinates.first;
    }
    if (progress >= 1.0) {
      return routeCoordinates.last;
    }

    final totalSegments = routeCoordinates.length - 1;
    final exactIndex = progress * totalSegments;
    final segmentIndex = exactIndex.floor().clamp(0, totalSegments - 1);
    final segmentProgress = exactIndex - segmentIndex;

    final p1 = routeCoordinates[segmentIndex];
    final p2 = routeCoordinates[segmentIndex + 1];

    final lat = p1.latitude + (p2.latitude - p1.latitude) * segmentProgress;
    final lng = p1.longitude + (p2.longitude - p1.longitude) * segmentProgress;

    return LatLng(lat, lng);
  }

  ElevationPoint interpolateElevationPoint(double progress) {
    if (elevationProfile.isEmpty) {
      return const ElevationPoint(distanceKm: 0, elevationMeters: 0, speedKmh: 0);
    }
    if (elevationProfile.length == 1 || progress <= 0.0) {
      return elevationProfile.first;
    }
    if (progress >= 1.0) {
      return elevationProfile.last;
    }

    final totalSegments = elevationProfile.length - 1;
    final exactIndex = progress * totalSegments;
    final segmentIndex = exactIndex.floor().clamp(0, totalSegments - 1);
    final segmentProgress = exactIndex - segmentIndex;

    final e1 = elevationProfile[segmentIndex];
    final e2 = elevationProfile[segmentIndex + 1];

    return ElevationPoint(
      distanceKm: e1.distanceKm + (e2.distanceKm - e1.distanceKm) * segmentProgress,
      elevationMeters: e1.elevationMeters + (e2.elevationMeters - e1.elevationMeters) * segmentProgress,
      speedKmh: e1.speedKmh + (e2.speedKmh - e1.speedKmh) * segmentProgress,
    );
  }

  String toGeoJson() {
    final coordinates = routeCoordinates
        .map((p) => [double.parse(p.longitude.toStringAsFixed(5)), double.parse(p.latitude.toStringAsFixed(5))])
        .toList();

    final geoJsonMap = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {
            'tripId': id,
            'title': title,
            'date': date.toIso8601String(),
            'distanceKm': distanceKm,
            'durationMinutes': duration.inMinutes,
            'maxSpeedKmh': maxSpeedKmh,
            'avgSpeedKmh': avgSpeedKmh,
            'totalClimbMeters': totalClimbMeters,
            'packRidersCount': packRidersCount,
          },
          'geometry': {
            'type': 'LineString',
            'coordinates': coordinates,
          },
        },
      ],
    };

    return const JsonEncoder.withIndent('  ').convert(geoJsonMap);
  }

  String toGpx() {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="GroupNav DePIN Convoy" xmlns="http://www.topografix.com/GPX/1/1">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>$title</name>');
    buffer.writeln('    <time>${date.toIso8601String()}</time>');
    buffer.writeln('  </metadata>');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>$title</name>');
    buffer.writeln('    <trkseg>');
    for (final point in routeCoordinates) {
      buffer.writeln('      <trkpt lat="${point.latitude.toStringAsFixed(6)}" lon="${point.longitude.toStringAsFixed(6)}" />');
    }
    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');
    return buffer.toString();
  }
}
