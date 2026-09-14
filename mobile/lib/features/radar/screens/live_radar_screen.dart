import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/radar_provider.dart';
import '../widgets/convoy_marker_widget.dart';
import '../widgets/radar_hud_sheet.dart';

class LiveRadarScreen extends ConsumerStatefulWidget {
  const LiveRadarScreen({super.key});

  @override
  ConsumerState<LiveRadarScreen> createState() => _LiveRadarScreenState();
}

class _LiveRadarScreenState extends ConsumerState<LiveRadarScreen> {
  final MapController _mapController = MapController();

  void _recenterOnLeader(LatLng leaderPos) {
    _mapController.move(leaderPos, 15.5);
  }

  @override
  Widget build(BuildContext context) {
    final radarState = ref.watch(radarNotifierProvider);
    final radarNotifier = ref.read(radarNotifierProvider.notifier);

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
                    radius: radarState.geofenceRadiusMeters,
                    useRadiusInMeter: true,
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderColor: AppColors.primary,
                    borderStrokeWidth: 2.0,
                  ),
                ],
              ),

              // Active Route Polylines (Glowing Core)
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

              // Convoy Participant Markers Layer
              MarkerLayer(
                markers: radarState.peers.map((peer) {
                  return Marker(
                    point: LatLng(peer.latitude, peer.longitude),
                    width: peer.isLeader ? 110 : 90,
                    height: peer.isLeader ? 80 : 64,
                    child: ConvoyMarkerWidget(peer: peer),
                  );
                }).toList(),
              ),
            ],
          ),

          // 2. Geofence Boundary Label Indicator Tag
          Positioned(
            top: 76,
            left: 0,
            right: 0,
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
                      '${radarState.geofenceRadiusMeters.round()}M CONVOY GEOFENCE',
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

          // 3. Floating Top Route Pill (Layer Z-20)
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: AppTheme.radiusFull,
                boxShadow: AppTheme.elevationLevel2,
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.near_me, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('ACTIVE ROUTE', style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.textSecondary)),
                        Text('Skyline Summit', style: AppTypography.labelLg.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  // Live DePIN NAV Token Ticker & Wallet Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppTheme.radiusFull,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
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
                        Text('142.8 \$NAV', style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        Container(width: 1, height: 12, color: AppColors.borderSubtle),
                        const SizedBox(width: 6),
                        Text('0x7F2', style: AppTypography.labelSm.copyWith(fontFamily: 'monospace', color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Right Floating Action Buttons (Layer Z-20)
          Positioned(
            right: 14,
            bottom: 180,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'fab_layers',
                  backgroundColor: AppColors.cardBg,
                  foregroundColor: AppColors.onSurfaceVariant,
                  elevation: 3,
                  onPressed: () {},
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
            ),
          ),
        ],
      ),
    );
  }
}
