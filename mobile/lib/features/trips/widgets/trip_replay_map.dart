import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/trip_record.dart';

class TripReplayMap extends StatefulWidget {
  final TripRecord trip;
  final LatLng activePosition;
  final double progress;

  const TripReplayMap({
    super.key,
    required this.trip,
    required this.activePosition,
    required this.progress,
  });

  @override
  State<TripReplayMap> createState() => _TripReplayMapState();
}

class _TripReplayMapState extends State<TripReplayMap> {
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(TripReplayMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.id != widget.trip.id) {
      _fitRoute();
    }
  }

  void _fitRoute() {
    if (widget.trip.routeCoordinates.isEmpty) return;
    _mapController.move(widget.trip.routeCoordinates.first, 12.0);
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          color: AppColors.mapSurface,
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: trip.routeCoordinates.isNotEmpty
                    ? trip.routeCoordinates[trip.routeCoordinates.length ~/ 2]
                    : const LatLng(37.7749, -122.4194),
                initialZoom: 11.5,
                minZoom: 9.0,
                maxZoom: 17.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.groupnav.mobile',
                ),

                // Route Polylines: Glowing route cyan underlay + solid primary core
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: trip.routeCoordinates,
                      strokeWidth: 6.0,
                      color: AppColors.routeCyan.withOpacity(0.55),
                    ),
                    Polyline(
                      points: trip.routeCoordinates,
                      strokeWidth: 3.5,
                      color: AppColors.primary,
                    ),
                  ],
                ),

                // Waypoint & Replay Position Markers
                MarkerLayer(
                  markers: [
                    // Start Marker
                    if (trip.waypoints.isNotEmpty)
                      Marker(
                        point: trip.waypoints.first.position,
                        width: 32,
                        height: 32,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.telemetryEmerald,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'A',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Intermediate Checkpoints
                    ...trip.waypoints.where((w) => w.type == WaypointType.checkpoint).map(
                          (wp) => Marker(
                            point: wp.position,
                            width: 68,
                            height: 26,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 4,
                                  ),
                                ],
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
                                  const SizedBox(width: 4),
                                  Text(
                                    'CP-2',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                    // Finish Marker
                    if (trip.waypoints.length > 1)
                      Marker(
                        point: trip.waypoints.last.position,
                        width: 32,
                        height: 32,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.alertCritical,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.flag, color: Colors.white, size: 16),
                          ),
                        ),
                      ),

                    // Active Replay Avatar (interpolated)
                    Marker(
                      point: widget.activePosition,
                      width: 46,
                      height: 46,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withOpacity(0.18),
                        ),
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.navigation,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Top Floating Metadata Tag
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.routeCyan,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Aurora PostGIS Track • ${trip.distanceKm} km',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Recenter Action Button
            Positioned(
              bottom: 12,
              right: 12,
              child: InkWell(
                onTap: _fitRoute,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.my_location, color: AppColors.primary, size: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
