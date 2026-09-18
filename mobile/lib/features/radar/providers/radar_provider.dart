import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/location_service.dart';
import '../../auth/models/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/models/rider_settings.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/convoy_peer.dart';
import '../models/convoy_route.dart';
import '../services/iot_telemetry_service.dart';

class RadarState {
  final List<ConvoyPeer> peers;
  final LatLng centerPosition;
  final double currentSpeed;
  final double currentHeading;
  final double currentElevation;
  final int packCohesion;
  final String cohesionStatus;
  final bool isBroadcasting;
  final double geofenceRadiusMeters;
  final List<LatLng> routeWaypoints;
  final bool isAwsConnected;
  final ConvoyRoute? activeRoute;
  final int broadcastCount;
  final DateTime? lastBroadcastTime;
  final bool isLeader;

  const RadarState({
    this.peers = const [],
    this.centerPosition = const LatLng(19.0760, 72.8777), // Default geographic reference (Mumbai / ap-south-1)
    this.currentSpeed = 0.0,
    this.currentHeading = 0.0,
    this.currentElevation = 0.0,
    this.packCohesion = 100,
    this.cohesionStatus = 'SOLO',
    this.isBroadcasting = true,
    this.geofenceRadiusMeters = 800.0,
    this.routeWaypoints = const [],
    this.isAwsConnected = false,
    this.activeRoute,
    this.broadcastCount = 0,
    this.lastBroadcastTime,
    this.isLeader = true,
  });

  String get headingDisplay {
    final deg = currentHeading.round();
    String cardinal = 'N';
    if (deg >= 22.5 && deg < 67.5) {
      cardinal = 'NE';
    } else if (deg >= 67.5 && deg < 112.5) {
      cardinal = 'E';
    } else if (deg >= 112.5 && deg < 157.5) {
      cardinal = 'SE';
    } else if (deg >= 157.5 && deg < 202.5) {
      cardinal = 'S';
    } else if (deg >= 202.5 && deg < 247.5) {
      cardinal = 'SW';
    } else if (deg >= 247.5 && deg < 292.5) {
      cardinal = 'W';
    } else if (deg >= 292.5 && deg < 337.5) {
      cardinal = 'NW';
    }

    return '$cardinal ${deg.toString().padLeft(3, '0')}°';
  }

  RadarState copyWith({
    List<ConvoyPeer>? peers,
    LatLng? centerPosition,
    double? currentSpeed,
    double? currentHeading,
    double? currentElevation,
    int? packCohesion,
    String? cohesionStatus,
    bool? isBroadcasting,
    double? geofenceRadiusMeters,
    List<LatLng>? routeWaypoints,
    bool? isAwsConnected,
    ConvoyRoute? activeRoute,
    int? broadcastCount,
    DateTime? lastBroadcastTime,
    bool? isLeader,
  }) {
    return RadarState(
      peers: peers ?? this.peers,
      centerPosition: centerPosition ?? this.centerPosition,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      currentHeading: currentHeading ?? this.currentHeading,
      currentElevation: currentElevation ?? this.currentElevation,
      packCohesion: packCohesion ?? this.packCohesion,
      cohesionStatus: cohesionStatus ?? this.cohesionStatus,
      isBroadcasting: isBroadcasting ?? this.isBroadcasting,
      geofenceRadiusMeters: geofenceRadiusMeters ?? this.geofenceRadiusMeters,
      routeWaypoints: routeWaypoints ?? this.routeWaypoints,
      isAwsConnected: isAwsConnected ?? this.isAwsConnected,
      activeRoute: activeRoute ?? this.activeRoute,
      broadcastCount: broadcastCount ?? this.broadcastCount,
      lastBroadcastTime: lastBroadcastTime ?? this.lastBroadcastTime,
      isLeader: isLeader ?? this.isLeader,
    );
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  final initialMode = settings.isDemoSimulation ? LocationMode.simulation : LocationMode.hardware;
  final service = LocationService(initialMode: initialMode);

  ref.listen<RiderSettings>(settingsNotifierProvider, (previous, next) {
    if (previous?.isDemoSimulation != next.isDemoSimulation) {
      service.setMode(next.isDemoSimulation ? LocationMode.simulation : LocationMode.hardware);
    }
  });

  ref.onDispose(() => service.dispose());
  return service;
});

final iotTelemetryServiceProvider = Provider<IotTelemetryService>((ref) {
  final config = ref.watch(clientConfigProvider);
  final locationService = ref.watch(locationServiceProvider);
  final service = IotTelemetryService(config: config, locationService: locationService);

  // When auth credentials change, connect MQTT with authentic SigV4 credentials
  ref.listen<AuthState>(authNotifierProvider, (previous, next) {
    final creds = next.awsCredentials;
    if (next.pilot != null) {
      service.updateRiderIdentity(
        riderId: next.pilot!.cognitoIdentityId ?? 'pilot',
        callsign: next.pilot!.callsign,
      );
    }

    if (creds != null &&
        creds['AccessKeyId'] != null &&
        creds['SecretKey'] != null &&
        !service.isMqttConnected) {
      service.connectMqtt(
        accessKeyId: creds['AccessKeyId']!,
        secretKey: creds['SecretKey']!,
        sessionToken: creds['SessionToken'],
      );
    }
  });

  ref.onDispose(() => service.dispose());
  return service;
});

final radarNotifierProvider = StateNotifierProvider<RadarNotifier, RadarState>((ref) {
  final telemetryService = ref.watch(iotTelemetryServiceProvider);
  return RadarNotifier(telemetryService);
});

class RadarNotifier extends StateNotifier<RadarState> {
  final IotTelemetryService _telemetryService;

  RadarNotifier(this._telemetryService)
      : super(RadarState(
          activeRoute: ConvoyRoute.defaultRoutes.first,
          routeWaypoints: ConvoyRoute.defaultRoutes.first.waypoints,
        )) {
    _listenToTelemetry();
    _listenToConnection();
    _listenToRouteUpdates();
  }

  void _listenToConnection() {
    _telemetryService.connectionStatusStream.listen((connected) {
      if (!mounted) return;
      state = state.copyWith(isAwsConnected: connected);
    });
  }

  void _listenToRouteUpdates() {
    _telemetryService.routeUpdateStream.listen((route) {
      if (!mounted) return;
      state = state.copyWith(
        activeRoute: route,
        routeWaypoints: route.waypoints,
      );
    });
  }

  void _listenToTelemetry() {
    _telemetryService.convoyStream.listen((peers) {
      if (!mounted) return;
      if (peers.isEmpty) return;

      final leader = peers.firstWhere((p) => p.isLeader, orElse: () => peers.first);

      // Compute dynamic cohesion score based on real peer distance
      int cohesion = 100;
      String status = peers.length > 1 ? 'TIGHT' : 'SOLO';

      if (peers.length > 1) {
        for (final p in peers) {
          if (p.relativeOffsetMeters.abs() > 300) {
            cohesion = 74;
            status = 'SPREAD';
            break;
          } else if (p.relativeOffsetMeters.abs() > 150) {
            cohesion = 88;
            status = 'EXTENDED';
          }
        }
      }

      state = state.copyWith(
        peers: peers,
        centerPosition: LatLng(leader.latitude, leader.longitude),
        currentSpeed: leader.speedKmh,
        currentHeading: leader.headingDeg,
        currentElevation: leader.altitude,
        packCohesion: cohesion,
        cohesionStatus: status,
        isAwsConnected: _telemetryService.isMqttConnected,
        broadcastCount: _telemetryService.broadcastCount,
        lastBroadcastTime: _telemetryService.lastBroadcastTime,
      );
    });
  }

  /// Change active navigation course and broadcast to convoy members
  void setRoute(ConvoyRoute route, {bool broadcast = true}) {
    state = state.copyWith(
      activeRoute: route,
      routeWaypoints: route.waypoints,
    );
    if (broadcast) {
      _telemetryService.broadcastRoute(route);
    }
  }

  /// Update leader status
  void updateLeaderStatus(bool isLeader) {
    _telemetryService.updateLeaderStatus(isLeader);
    state = state.copyWith(isLeader: isLeader);
  }

  void publishAlert({
    required String packId,
    required String alertType,
    String? callsign,
    String? message,
  }) {
    _telemetryService.publishAlert(
      packId: packId,
      alertType: alertType,
      callsign: callsign,
      message: message,
    );
  }

  void toggleBroadcasting() {
    final next = !state.isBroadcasting;
    _telemetryService.setBroadcasting(next);
    state = state.copyWith(isBroadcasting: next);
  }

  void updateGeofenceRadius(double radius) {
    state = state.copyWith(geofenceRadiusMeters: radius);
  }
}
