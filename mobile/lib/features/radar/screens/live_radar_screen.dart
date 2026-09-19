import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/providers/auth_provider.dart';
import '../../groups/providers/pack_provider.dart';
import '../models/convoy_route.dart';
import '../providers/radar_provider.dart';
import '../widgets/convoy_marker_widget.dart';
import '../widgets/create_route_sheet.dart';
import '../widgets/radar_hud_sheet.dart';
import '../widgets/route_selection_sheet.dart';

class LiveRadarScreen extends ConsumerStatefulWidget {
  const LiveRadarScreen({super.key});

  @override
  ConsumerState<LiveRadarScreen> createState() => _LiveRadarScreenState();
}

class _LiveRadarScreenState extends ConsumerState<LiveRadarScreen> {
  final MapController _mapController = MapController();
  StreamSubscription? _alertSub;
  bool _hasCenteredOnGps = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final telemetryService = ref.read(iotTelemetryServiceProvider);
      _alertSub = telemetryService.alertStream.listen((alert) {
        if (!mounted) return;
        final callsign = alert['callsign'] ?? 'Convoy';
        final type = alert['alertType'] ?? 'Alert';
        final msg = alert['message'] as String?;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    msg != null && msg.isNotEmpty && !msg.startsWith('Status update:')
                        ? 'Convoy Alert [$callsign]: $msg'
                        : 'Convoy Alert: [$callsign] - $type',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    super.dispose();
  }

  void _recenterOnLeader(LatLng leaderPos) {
    _mapController.move(leaderPos, 15.5);
  }

  void _showCreateRouteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const CreateRouteSheet(),
    );
  }

  void _showRouteSelectionSheet(
    BuildContext context,
    ConvoyRoute? currentRoute,
    RadarNotifier radarNotifier,
    List<ConvoyRoute> customRoutes,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => RouteSelectionSheet(
        currentRoute: currentRoute,
        customRoutes: customRoutes,
        onCreateCustomRoute: () => _showCreateRouteSheet(context),
        onSelectRoute: (selectedRoute) {
          radarNotifier.setRoute(selectedRoute, broadcast: true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Course "${selectedRoute.title}" dispatched to all pack riders via AWS IoT Core!',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _showFollowerLockedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text('Course Locked', style: AppTypography.headlineMd.copyWith(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Only the Road Captain (Convoy Leader) has authority to designate and alter navigation courses.',
              style: AppTypography.bodySm.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              'Your navigation course is synchronized in real-time with the leader via AWS IoT Core MQTT. When the Road Captain selects a course, your map updates automatically.',
              style: AppTypography.bodySm.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('UNDERSTOOD'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radarState = ref.watch(radarNotifierProvider);
    final radarNotifier = ref.read(radarNotifierProvider.notifier);
    final packFormation = ref.watch(packNotifierProvider);
    final authState = ref.watch(authNotifierProvider);

    final currentPilotId = authState.pilot?.cognitoIdentityId ?? '';
    // Leader authority rule:
    // Solo ride (not in pack) -> rider is authority of their own course.
    // In pack -> check if user is designated leader
    final isLeader = !packFormation.isInPack ||
        packFormation.members.isEmpty ||
        packFormation.members.any((m) =>
            (m.id == currentPilotId || m.callsign.contains('(You)')) && m.isLeader);

    // Synchronize leader status with telemetry service
    if (radarState.isLeader != isLeader) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          radarNotifier.updateLeaderStatus(isLeader);
        }
      });
    }

    // Auto-center map on first real GPS lock
    if (!_hasCenteredOnGps &&
        radarState.centerPosition.latitude != 0.0 &&
        radarState.centerPosition.longitude != 0.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_hasCenteredOnGps && mounted) {
          _mapController.move(radarState.centerPosition, 15.5);
          _hasCenteredOnGps = true;
        }
      });
    }

    final activeRoute = radarState.activeRoute;
    final routeTitle = activeRoute?.title ?? 'Skyline Summit Run';
    final routeSubtitle = activeRoute != null
        ? '${activeRoute.distanceKm.toStringAsFixed(1)} km • ${activeRoute.estimatedMinutes} min'
        : 'Tactical Corridor';

    return Scaffold(
      backgroundColor: AppColors.mapSurface,
      body: Stack(
        children: [
          // 1. Full-Bleed Map Canvas (Layer Z-0)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: radarState.centerPosition,
              initialZoom: 15.5,
              minZoom: 12.0,
              maxZoom: 18.0,
            ),
            children: [
              // Tile Layer (Vector/Raster Street Cartography)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.groupnav.mobile',
              ),

              // 800m Geofence Boundary Mesh
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: radarState.centerPosition,
                    radius: packFormation.geofenceRadiusMeters,
                    useRadiusInMeter: true,
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderColor: AppColors.primary,
                    borderStrokeWidth: 2.0,
                  ),
                ],
              ),

              // Active Route Polylines (Glowing Core)
              if (radarState.routeWaypoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // Outer Glow Polyline
                    Polyline(
                      points: radarState.routeWaypoints,
                      color: AppColors.primary.withValues(alpha: 0.5),
                      strokeWidth: 8.0,
                    ),
                    // Inner High-Intensity Core
                    Polyline(
                      points: radarState.routeWaypoints,
                      color: AppColors.routeCyan,
                      strokeWidth: 3.5,
                    ),
                  ],
                ),

              // Convoy Participant & Route Stop Markers Layer
              MarkerLayer(
                markers: [
                  // Route Stop Markers
                  if (radarState.activeRoute != null && radarState.activeRoute!.stops.isNotEmpty)
                    ...radarState.activeRoute!.stops.map((stop) {
                      Color stopColor;
                      switch (stop.type) {
                        case RouteStopType.origin:
                          stopColor = AppColors.primary;
                          break;
                        case RouteStopType.destination:
                          stopColor = AppColors.error;
                          break;
                        case RouteStopType.waypoint:
                          stopColor = AppColors.secondary;
                          break;
                      }

                      return Marker(
                        point: stop.toLatLng,
                        width: 130,
                        height: 48,
                        alignment: Alignment.topCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.cardBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: stopColor, width: 1.5),
                                boxShadow: AppTheme.elevationLevel1,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: stopColor,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      stop.typeLabel,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      stop.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_drop_down, color: stopColor, size: 14),
                          ],
                        ),
                      );
                    }),

                  // Rider Convoy Peer Markers
                  ...radarState.peers.map((peer) {
                    return Marker(
                      point: LatLng(peer.latitude, peer.longitude),
                      width: peer.isLeader ? 150 : 120,
                      height: peer.isLeader ? 84 : 68,
                      child: ConvoyMarkerWidget(peer: peer),
                    );
                  }),
                ],
              ),
            ],
          ),

          // 2. Geofence Boundary Label Indicator Tag
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 70),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg.withValues(alpha: 0.95),
                      borderRadius: AppTheme.radiusFull,
                      border: Border.all(color: AppColors.borderSubtle),
                      boxShadow: AppTheme.elevationLevel1,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${packFormation.geofenceRadiusMeters.round()}M CONVOY GEOFENCE',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Floating Top Route Authority Pill (Layer Z-20)
          Positioned(
            top: 0,
            left: 14,
            right: 14,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (isLeader) {
                        _showRouteSelectionSheet(context, activeRoute, radarNotifier, radarState.customRoutes);
                      } else {
                        _showFollowerLockedDialog(context);
                      }
                    },
                    borderRadius: AppTheme.radiusFull,
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: AppTheme.radiusFull,
                  boxShadow: AppTheme.elevationLevel2,
                  border: Border.all(
                    color: isLeader
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.borderSubtle.withValues(alpha: 0.8),
                    width: isLeader ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isLeader
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isLeader ? Icons.route_outlined : Icons.lock_outline,
                        color: isLeader ? AppColors.primary : AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Text(
                                isLeader ? 'ACTIVE ROUTE • ROAD CAPTAIN' : 'ACTIVE ROUTE • LOCKED',
                                style: AppTypography.labelSm.copyWith(
                                  fontSize: 8.5,
                                  color: isLeader ? AppColors.primary : AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (isLeader) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.touch_app, size: 10, color: AppColors.primary),
                              ],
                            ],
                          ),
                          Text(
                            '$routeTitle • $routeSubtitle',
                            style: AppTypography.labelLg.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Active Live Convoy Pill / Route Modifier Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: AppTheme.radiusFull,
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
                          const SizedBox(width: 4),
                          Text(
                            isLeader ? 'CHANGE' : '${radarState.peers.length + 1} Live',
                            style: AppTypography.labelSm.copyWith(
                              color: isLeader ? AppColors.primary : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),

          // 4. Right Floating Action Buttons (Layer Z-20)
          Positioned(
            right: 14,
            bottom: 220,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'fab_layers',
                  backgroundColor: AppColors.cardBg,
                  foregroundColor: AppColors.onSurfaceVariant,
                  elevation: 3,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Standard OpenStreetMap Cartography Active'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Icon(Icons.layers, size: 20),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'fab_recenter',
                  backgroundColor: AppColors.cardBg,
                  foregroundColor: AppColors.primary,
                  elevation: 4,
                  onPressed: () => _recenterOnLeader(radarState.centerPosition),
                  child: const Icon(Icons.my_location, size: 24),
                ),
              ],
            ),
          ),

          // 5. Docked Telemetry HUD Bottom Sheet (Layer Z-30)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RadarHudSheet(
              state: radarState,
              onToggleBroadcast: radarNotifier.toggleBroadcasting,
              onSendQuickAlert: (alertType) {
                final pack = ref.read(packNotifierProvider);
                final packCode = pack.packCode.isNotEmpty
                    ? pack.packCode
                    : (pack.packId.isNotEmpty ? 'GN-${pack.packId}' : 'solo');
                final pilot = ref.read(authNotifierProvider).pilot;
                final callsign = pilot?.callsign ?? 'Pilot';
                radarNotifier.publishAlert(
                  packId: packCode,
                  alertType: alertType,
                  callsign: '$callsign${isLeader ? ' (Lead)' : ''}',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
