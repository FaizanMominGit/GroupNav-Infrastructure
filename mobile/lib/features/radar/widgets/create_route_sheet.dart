import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/convoy_route.dart';
import '../providers/radar_provider.dart';
import '../services/aws_location_route_service.dart';

class CreateRouteSheet extends ConsumerStatefulWidget {
  const CreateRouteSheet({super.key});

  @override
  ConsumerState<CreateRouteSheet> createState() => _CreateRouteSheetState();
}

class _CreateRouteSheetState extends ConsumerState<CreateRouteSheet> {
  final _titleController = TextEditingController(text: 'Ghats Tactical Course');
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();

  final List<TextEditingController> _intermediateControllers = [];
  final List<RouteStop> _intermediateStops = [];

  RouteStop? _originStop;
  RouteStop? _destinationStop;

  String _selectedFormation = 'STAGGERED';
  bool _isCalculating = false;
  ConvoyRoute? _previewRoute;
  String? _errorMessage;

  // Search Autocomplete state
  int? _activeSearchIndex; // -1 for origin, -2 for destination, >= 0 for intermediate
  List<PlaceSearchResult> _autocompleteResults = [];
  bool _isSearchingPlaces = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCurrentLocationAsOrigin();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    for (final c in _intermediateControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _initializeCurrentLocationAsOrigin() {
    final radarState = ref.read(radarNotifierProvider);
    final pos = radarState.centerPosition;
    setState(() {
      _originStop = RouteStop(
        id: 'stop_origin',
        name: 'Current Location',
        latitude: pos.latitude,
        longitude: pos.longitude,
        type: RouteStopType.origin,
      );
      _originController.text = '📍 Current Location (${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)})';
    });
  }

  void _addIntermediateStop() {
    if (_intermediateStops.length >= 8) return;
    setState(() {
      final idx = _intermediateStops.length + 1;
      _intermediateControllers.add(TextEditingController());
      _intermediateStops.add(
        RouteStop(
          id: 'stop_wp_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Waypoint $idx',
          latitude: 0.0,
          longitude: 0.0,
          type: RouteStopType.waypoint,
        ),
      );
    });
  }

  void _removeIntermediateStop(int index) {
    setState(() {
      _intermediateControllers[index].dispose();
      _intermediateControllers.removeAt(index);
      _intermediateStops.removeAt(index);
      _previewRoute = null;
    });
  }

  Future<void> _searchPlacesFor(int targetIndex, String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _activeSearchIndex = null;
        _autocompleteResults = [];
      });
      return;
    }

    setState(() {
      _activeSearchIndex = targetIndex;
      _isSearchingPlaces = true;
    });

    final routeService = ref.read(awsLocationRouteServiceProvider);
    final auth = ref.read(authNotifierProvider);
    final radar = ref.read(radarNotifierProvider);

    try {
      final results = await routeService.searchPlaces(
        query: query,
        biasPosition: radar.centerPosition,
        awsCredentials: auth.awsCredentials,
      );

      if (mounted && _activeSearchIndex == targetIndex) {
        setState(() {
          _autocompleteResults = results;
          _isSearchingPlaces = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearchingPlaces = false);
      }
    }
  }

  void _selectPlace(int targetIndex, PlaceSearchResult place) {
    setState(() {
      if (targetIndex == -1) {
        _originStop = RouteStop(
          id: 'stop_origin',
          name: place.label,
          latitude: place.latitude,
          longitude: place.longitude,
          type: RouteStopType.origin,
        );
        _originController.text = place.label;
      } else if (targetIndex == -2) {
        _destinationStop = RouteStop(
          id: 'stop_dest',
          name: place.label,
          latitude: place.latitude,
          longitude: place.longitude,
          type: RouteStopType.destination,
        );
        _destinationController.text = place.label;
      } else if (targetIndex >= 0 && targetIndex < _intermediateStops.length) {
        _intermediateStops[targetIndex] = RouteStop(
          id: _intermediateStops[targetIndex].id,
          name: place.label,
          latitude: place.latitude,
          longitude: place.longitude,
          type: _intermediateStops[targetIndex].type,
        );
        _intermediateControllers[targetIndex].text = place.label;
      }
      _activeSearchIndex = null;
      _autocompleteResults = [];
      _previewRoute = null;
    });
  }

  Future<void> _calculateRoute() async {
    if (_originStop == null || _originStop!.latitude == 0.0) {
      setState(() => _errorMessage = 'Please specify a valid start/origin stop.');
      return;
    }
    if (_destinationStop == null || _destinationStop!.latitude == 0.0) {
      setState(() => _errorMessage = 'Please specify a destination stop.');
      return;
    }

    final validIntermediates = _intermediateStops
        .where((s) => s.latitude != 0.0 && s.longitude != 0.0)
        .toList();

    final allStops = [
      _originStop!,
      ...validIntermediates,
      _destinationStop!,
    ];

    setState(() {
      _isCalculating = true;
      _errorMessage = null;
    });

    final routeService = ref.read(awsLocationRouteServiceProvider);
    final auth = ref.read(authNotifierProvider);

    try {
      final route = await routeService.calculateRoute(
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : 'Custom Convoy Route',
        subtitle: '${allStops.length} Stops • $_selectedFormation',
        recommendedFormation: _selectedFormation,
        stops: allStops,
        awsCredentials: auth.awsCredentials,
      );

      if (mounted) {
        setState(() {
          _previewRoute = route;
          _isCalculating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCalculating = false;
          _errorMessage = 'Route calculation failed: $e';
        });
      }
    }
  }

  void _dispatchRouteToConvoy() {
    if (_previewRoute == null) return;

    ref.read(radarNotifierProvider.notifier).addCustomRoute(
          _previewRoute!,
          activate: true,
          broadcast: true,
        );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Custom Route "${_previewRoute!.title}" activated & dispatched to convoy!',
                style: AppTypography.labelMd.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
        ),
        boxShadow: AppTheme.elevationLevel3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: AppTheme.radiusFull,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_road, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AMAZON LOCATION SERVICE',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                    Text(
                      'Build Custom Multi-Stop Route',
                      style: AppTypography.headlineMd.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scrollable Form Body
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Course Title Input
                  Text(
                    'ROUTE TITLE',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleController,
                    style: AppTypography.bodyMd.copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. Western Ghats Express Run',
                      hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Formation Presets
                  Text(
                    'CONVOY FORMATION',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildFormationChip('STAGGERED', 'Staggered'),
                      const SizedBox(width: 8),
                      _buildFormationChip('SINGLE_FILE', 'Single File'),
                      const SizedBox(width: 8),
                      _buildFormationChip('FREE_CRUISE', 'Free Cruise'),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Origin Stop
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'START POINT (ORIGIN)',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _initializeCurrentLocationAsOrigin,
                        child: Text(
                          '📍 Use Current Location',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildStopTextField(
                    controller: _originController,
                    hint: 'Search origin landmark or city...',
                    targetIndex: -1,
                    icon: Icons.trip_origin,
                    iconColor: AppColors.primary,
                  ),
                  if (_activeSearchIndex == -1) _buildAutocompleteDropdown(-1),

                  const SizedBox(height: 14),

                  // Intermediate Stops (Dynamic Waypoints)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'INTERMEDIATE STOPS (${_intermediateStops.length})',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _addIntermediateStop,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add, color: AppColors.secondary, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'ADD STOP',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (_intermediateStops.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderSubtle.withValues(alpha: 0.5), style: BorderStyle.solid),
                      ),
                      child: Text(
                        'No intermediate stops. Tap "+ ADD STOP" for toll plazas, fuel stations, or scenic regroup points.',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    )
                  else
                    ..._intermediateStops.asMap().entries.map((entry) {
                      final i = entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStopTextField(
                                    controller: _intermediateControllers[i],
                                    hint: 'Stop ${i + 1} (e.g. Lonavala Toll / Food Mall)',
                                    targetIndex: i,
                                    icon: Icons.location_on_outlined,
                                    iconColor: AppColors.secondary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                  onPressed: () => _removeIntermediateStop(i),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            if (_activeSearchIndex == i) _buildAutocompleteDropdown(i),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 14),

                  // Destination Stop
                  Text(
                    'DESTINATION (FINISH)',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildStopTextField(
                    controller: _destinationController,
                    hint: 'Search destination landmark (e.g. Tiger Point)...',
                    targetIndex: -2,
                    icon: Icons.flag,
                    iconColor: AppColors.error,
                  ),
                  if (_activeSearchIndex == -2) _buildAutocompleteDropdown(-2),

                  const SizedBox(height: 16),

                  // Error Message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.labelSm.copyWith(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Route Calculation Preview Box
                  if (_previewRoute != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.verified, color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'AWS ESRI ROAD CALCULATION READY',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetricItem(
                                '${_previewRoute!.distanceKm.toStringAsFixed(1)} KM',
                                'ROAD DISTANCE',
                                Icons.straighten,
                              ),
                              _buildMetricItem(
                                '${_previewRoute!.estimatedMinutes} MIN',
                                'ESTIMATED TIME',
                                Icons.timer,
                              ),
                              _buildMetricItem(
                                '${_previewRoute!.waypoints.length}',
                                'GPS WAYPOINTS',
                                Icons.polyline,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Actions
                  Row(
                    children: [
                      // Calculate Button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isCalculating ? null : _calculateRoute,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isCalculating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.alt_route, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      _previewRoute == null ? 'CALCULATE VIA AWS' : 'RECALCULATE',
                                      style: AppTypography.labelMd.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      if (_previewRoute != null) ...[
                        const SizedBox(width: 10),
                        // Dispatch Button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _dispatchRouteToConvoy,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.send_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'DISPATCH COURSE',
                                  style: AppTypography.labelMd.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormationChip(String formationKey, String label) {
    final isSelected = _selectedFormation == formationKey;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedFormation = formationKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStopTextField({
    required TextEditingController controller,
    required String hint,
    required int targetIndex,
    required IconData icon,
    required Color iconColor,
  }) {
    return TextField(
      controller: controller,
      onChanged: (val) => _searchPlacesFor(targetIndex, val),
      style: AppTypography.bodyMd.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: iconColor, size: 18),
        hintText: hint,
        hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.outline, fontSize: 13),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: iconColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildAutocompleteDropdown(int targetIndex) {
    if (_isSearchingPlaces) {
      return Container(
        padding: const EdgeInsets.all(8),
        alignment: Alignment.centerLeft,
        child: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            SizedBox(width: 8),
            Text('Searching Amazon Location Places...', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      );
    }

    if (_autocompleteResults.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: AppTheme.elevationLevel2,
      ),
      constraints: const BoxConstraints(maxHeight: 180),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _autocompleteResults.length,
        separatorBuilder: (_, __) => const Divider(color: AppColors.borderSubtle, height: 1),
        itemBuilder: (context, idx) {
          final place = _autocompleteResults[idx];
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.place, color: AppColors.primary, size: 16),
            title: Text(
              place.label,
              style: AppTypography.bodySm.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}',
              style: AppTypography.labelSm.copyWith(color: AppColors.textSecondary, fontSize: 10),
            ),
            onTap: () => _selectPlace(targetIndex, place),
          );
        },
      ),
    );
  }

  Widget _buildMetricItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.labelLg.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.textSecondary,
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
