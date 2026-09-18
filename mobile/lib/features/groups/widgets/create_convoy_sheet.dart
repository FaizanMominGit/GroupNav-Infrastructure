import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/pack_provider.dart';

class CreateConvoySheet extends ConsumerStatefulWidget {
  const CreateConvoySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateConvoySheet(),
    );
  }

  @override
  ConsumerState<CreateConvoySheet> createState() => _CreateConvoySheetState();
}

class _CreateConvoySheetState extends ConsumerState<CreateConvoySheet> {
  late final TextEditingController _titleController;
  late String _generatedCode;
  double _geofenceRadius = 800.0;
  String _selectedFormation = 'STAGGERED';
  bool _isCreating = false;
  String? _errorMessage;

  static const List<Map<String, String>> _titlePresets = [
    {'title': 'Mountain Twisties Run', 'icon': '🏔️'},
    {'title': 'Highway Fast Cruise', 'icon': '⚡'},
    {'title': 'City Sunset Ride', 'icon': '🌆'},
    {'title': 'Weekend Breakfast Meet', 'icon': '☕'},
  ];

  static const List<Map<String, dynamic>> _radiusPresets = [
    {'label': '500m', 'value': 500.0, 'tag': 'Tight'},
    {'label': '800m', 'value': 800.0, 'tag': 'Standard'},
    {'label': '1.5km', 'value': 1500.0, 'tag': 'Highway'},
    {'label': '3.0km', 'value': 3000.0, 'tag': 'Open'},
  ];

  static const List<Map<String, String>> _formationPresets = [
    {
      'id': 'STAGGERED',
      'title': 'Staggered (2s)',
      'subtitle': '2-second lane zigzag formation',
      'icon': 'zigzag',
    },
    {
      'id': 'SINGLE_FILE',
      'title': 'Single File',
      'subtitle': 'Mountain passes & tight twisties',
      'icon': 'line',
    },
    {
      'id': 'FREE_FLIGHT',
      'title': 'Free Cruise',
      'subtitle': 'Open highway dynamic spacing',
      'icon': 'open',
    },
  ];

  @override
  void initState() {
    super.initState();
    _generatedCode = _generateRandomCode();
    _titleController = TextEditingController(text: 'Pack Formation #$_generatedCode');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _generateRandomCode() {
    final rand = 1000 + Random().nextInt(9000);
    return 'GN-$rand';
  }

  void _regenerateCode() {
    setState(() {
      _generatedCode = _generateRandomCode();
      if (_titleController.text.startsWith('Pack Formation #')) {
        _titleController.text = 'Pack Formation #$_generatedCode';
      }
    });
  }

  Future<void> _handleCreate() async {
    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    final packNotifier = ref.read(packNotifierProvider.notifier);

    try {
      await packNotifier.createPack(
        customTitle: _titleController.text.trim(),
        customCode: _generatedCode,
        geofenceRadius: _geofenceRadius,
        formationType: _selectedFormation,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Convoy Room "$_generatedCode" launched! You are Road Captain.'),
                ),
              ],
            ),
            backgroundColor: AppColors.telemetryEmerald,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final pilot = authState.pilot;
    final callsign = pilot?.callsign ?? 'Pilot';
    final vehicleClass = pilot?.vehicleClass ?? 'SPORT';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle pill
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_circle, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Convoy Room',
                              style: AppTypography.headlineMd.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'Launch real-time telemetry rendezvous on AWS',
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Road Captain Identity Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            callsign.isNotEmpty ? callsign[0].toUpperCase() : 'C',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                callsign,
                                style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Road Captain',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$vehicleClass • Lead Unit',
                            style: AppTypography.bodySm.copyWith(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.telemetryEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
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
                        const SizedBox(width: 5),
                        Text(
                          'HOST',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.telemetryEmerald,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Convoy Ride Title Input
            Text('Convoy Ride Title', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'e.g. Skyline Sunset Run',
                prefixIcon: const Icon(Icons.edit_note, size: 20, color: AppColors.textSecondary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: AppColors.textSecondary),
                  onPressed: () => _titleController.clear(),
                ),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),

            // Quick Title Presets
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _titlePresets.map((preset) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: Text('${preset['icon']} ${preset['title']}'),
                      labelStyle: AppTypography.labelSm.copyWith(fontSize: 11),
                      backgroundColor: AppColors.surfaceContainerLowest,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onPressed: () {
                        setState(() {
                          _titleController.text = preset['title']!;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Convoy Room Code Preview & Shuffle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Convoy Pairing Code', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700)),
                TextButton.icon(
                  onPressed: _regenerateCode,
                  icon: const Icon(Icons.refresh, size: 14, color: AppColors.primary),
                  label: Text(
                    'Regenerate',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.vpn_key_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        _generatedCode,
                        style: AppTypography.telemetryNum.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'AUTO-GENERATED',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Geofence Boundary Radius
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Geofence Perimeter', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  _geofenceRadius >= 1000
                      ? '${(_geofenceRadius / 1000).toStringAsFixed(1)}km'
                      : '${_geofenceRadius.round()}m',
                  style: AppTypography.telemetryNum.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Radius preset pills
            Row(
              children: _radiusPresets.map((preset) {
                final isSelected = (_geofenceRadius == preset['value']);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _geofenceRadius = preset['value'] as double;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.borderSubtle,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              preset['label'] as String,
                              style: AppTypography.labelSm.copyWith(
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              preset['tag'] as String,
                              style: AppTypography.labelSm.copyWith(
                                color: isSelected ? Colors.white70 : AppColors.textSecondary,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),

            // Fine Slider
            Slider(
              value: _geofenceRadius,
              min: 200.0,
              max: 5000.0,
              divisions: 48,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.borderSubtle,
              onChanged: (val) {
                setState(() {
                  _geofenceRadius = val;
                });
              },
            ),
            const SizedBox(height: 8),

            // Formation Preset Selector
            Text('Convoy Formation Discipline', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: _formationPresets.map((formation) {
                final isSelected = (_selectedFormation == formation['id']);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedFormation = formation['id']!;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryFixed.withValues(alpha: 0.4) : AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.borderSubtle,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formation['title']!,
                              style: AppTypography.labelSm.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formation['subtitle']!,
                              style: AppTypography.bodySm.copyWith(
                                fontSize: 9,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Error Banner if any
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.alertCritical.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.alertCritical.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.alertCritical, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.alertCritical,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Launch Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _handleCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isCreating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Text('Deploying Convoy to AWS...'),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.rocket_launch, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Launch Convoy Room',
                            style: AppTypography.labelLg.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
