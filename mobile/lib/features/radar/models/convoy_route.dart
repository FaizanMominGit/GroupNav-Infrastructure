import 'package:latlong2/latlong.dart';

enum RouteStopType {
  origin,
  waypoint,
  destination,
}

class RouteStop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final RouteStopType type;

  const RouteStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.type = RouteStopType.waypoint,
  });

  LatLng get toLatLng => LatLng(latitude, longitude);

  String get typeLabel {
    switch (type) {
      case RouteStopType.origin:
        return 'START';
      case RouteStopType.destination:
        return 'FINISH';
      case RouteStopType.waypoint:
        return 'STOP';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': latitude,
        'lng': longitude,
        'type': type.name,
      };

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'waypoint';
    RouteStopType parsedType = RouteStopType.waypoint;
    if (typeStr == 'origin') {
      parsedType = RouteStopType.origin;
    } else if (typeStr == 'destination') {
      parsedType = RouteStopType.destination;
    }

    return RouteStop(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Stop',
      latitude: (json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0.0,
      type: parsedType,
    );
  }
}

class ConvoyRoute {
  final String id;
  final String title;
  final String subtitle;
  final double distanceKm;
  final int elevationGainMeters;
  final String recommendedFormation;
  final String difficultyLevel;
  final List<LatLng> waypoints;
  final List<RouteStop> stops;
  final bool isCustom;

  const ConvoyRoute({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.distanceKm,
    required this.elevationGainMeters,
    required this.recommendedFormation,
    this.difficultyLevel = 'MODERATE',
    required this.waypoints,
    this.stops = const [],
    this.isCustom = false,
  });

  LatLng get startPoint {
    if (stops.isNotEmpty) {
      final origin = stops.firstWhere(
        (s) => s.type == RouteStopType.origin,
        orElse: () => stops.first,
      );
      return origin.toLatLng;
    }
    return waypoints.isNotEmpty ? waypoints.first : const LatLng(19.0760, 72.8777);
  }

  LatLng get endPoint {
    if (stops.isNotEmpty) {
      final dest = stops.lastWhere(
        (s) => s.type == RouteStopType.destination,
        orElse: () => stops.last,
      );
      return dest.toLatLng;
    }
    return waypoints.isNotEmpty ? waypoints.last : const LatLng(19.0760, 72.8777);
  }

  String get description => subtitle;
  int get estimatedMinutes => (distanceKm / 55.0 * 60.0).clamp(5, 300).round();
  int get intermediateStopsCount => stops.where((s) => s.type == RouteStopType.waypoint).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'distanceKm': distanceKm,
        'elevationGainMeters': elevationGainMeters,
        'recommendedFormation': recommendedFormation,
        'difficultyLevel': difficultyLevel,
        'waypoints': waypoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
        'stops': stops.map((s) => s.toJson()).toList(),
        'isCustom': isCustom,
      };

  factory ConvoyRoute.fromJson(Map<String, dynamic> json) {
    final rawPts = json['waypoints'] as List<dynamic>? ?? [];
    final pts = rawPts.map((p) {
      final lat = (p['lat'] as num?)?.toDouble() ?? 0.0;
      final lng = (p['lng'] as num?)?.toDouble() ?? 0.0;
      return LatLng(lat, lng);
    }).toList();

    final rawStops = json['stops'] as List<dynamic>? ?? [];
    final stopsList = rawStops.map((s) => RouteStop.fromJson(s as Map<String, dynamic>)).toList();

    return ConvoyRoute(
      id: json['id'] as String? ?? 'route_default',
      title: json['title'] as String? ?? 'Custom Course',
      subtitle: json['subtitle'] as String? ?? 'Convoy Navigation Course',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 10.0,
      elevationGainMeters: (json['elevationGainMeters'] as num?)?.toInt() ?? 100,
      recommendedFormation: json['recommendedFormation'] as String? ?? 'STAGGERED',
      difficultyLevel: json['difficultyLevel'] as String? ?? 'MODERATE',
      waypoints: pts,
      stops: stopsList,
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }


  /// Curated tactical route catalog for motorcycle convoys
  static const List<ConvoyRoute> defaultRoutes = [
    ConvoyRoute(
      id: 'route_skyline',
      title: 'Skyline Summit Run',
      subtitle: 'Technical mountain sweepers with high elevation changes',
      distanceKm: 24.5,
      elevationGainMeters: 420,
      recommendedFormation: 'STAGGERED',
      difficultyLevel: 'MODERATE',
      waypoints: [
        LatLng(19.0760, 72.8777),
        LatLng(19.0795, 72.8820),
        LatLng(19.0835, 72.8870),
        LatLng(19.0880, 72.8930),
        LatLng(19.0940, 72.9000),
        LatLng(19.1010, 72.9080),
        LatLng(19.1090, 72.9150),
      ],
    ),
    ConvoyRoute(
      id: 'route_coastal',
      title: 'Coastal Marine Highway',
      subtitle: 'Scenic seaside cruise with sweeping open curves',
      distanceKm: 32.0,
      elevationGainMeters: 110,
      recommendedFormation: 'STAGGERED',
      difficultyLevel: 'EASY',
      waypoints: [
        LatLng(18.9220, 72.8347),
        LatLng(18.9350, 72.8280),
        LatLng(18.9550, 72.8180),
        LatLng(18.9750, 72.8120),
        LatLng(19.0000, 72.8150),
        LatLng(19.0300, 72.8250),
      ],
    ),
    ConvoyRoute(
      id: 'route_ghat_twisties',
      title: 'Khandala Ghat Pass',
      subtitle: 'Sharp hairpin turns and steep alpine switchbacks',
      distanceKm: 41.2,
      elevationGainMeters: 890,
      recommendedFormation: 'SINGLE_FILE',
      difficultyLevel: 'TECHNICAL',
      waypoints: [
        LatLng(18.7500, 73.3700),
        LatLng(18.7580, 73.3820),
        LatLng(18.7690, 73.3950),
        LatLng(18.7750, 73.4080),
        LatLng(18.7880, 73.4200),
        LatLng(18.7990, 73.4350),
      ],
    ),
    ConvoyRoute(
      id: 'route_express_corridor',
      title: 'Western Express Corridor',
      subtitle: 'High-speed transit highway with wide lanes and exits',
      distanceKm: 18.5,
      elevationGainMeters: 65,
      recommendedFormation: 'STAGGERED',
      difficultyLevel: 'EASY',
      waypoints: [
        LatLng(19.0600, 72.8500),
        LatLng(19.0800, 72.8550),
        LatLng(19.1100, 72.8600),
        LatLng(19.1400, 72.8650),
        LatLng(19.1700, 72.8700),
      ],
    ),
  ];
}
