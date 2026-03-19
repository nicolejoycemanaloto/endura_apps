import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:endura/core/theme/app_theme.dart';
import 'package:endura/core/maps/endura_map.dart';
import 'package:endura/core/maps/map_tile_source.dart';
import 'package:endura/core/maps/polyline_helper.dart';
import 'package:endura/core/maps/marker_helper.dart';
import 'package:endura/core/utils/location_service.dart';
import 'package:endura/core/utils/formatters.dart';
import 'package:endura/shared/models/cached_activity.dart';
import 'package:endura/features/activity/summary_screen.dart';
import 'package:endura/features/tracking/application/active_workout_provider.dart';
import 'package:endura/features/tracking/providers/map_source_provider.dart';

/// Track tab — live workout recording with map.
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  bool _permissionGranted = false;
  bool _checkingPermission = true;
  bool _isFollowing = true;
  LatLng? _currentLocation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    // _workoutSub is not needed when using ref.listen inside build or ConsumerStatefulWidget
    _mapController.dispose();
    super.dispose();
  }

  void _showMapOptions(MapTileSource selectedMapSource) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Map style'),
        message: Text('Current: ${selectedMapSource.label}'),
        actions: [
          for (final source in MapTileSources.all)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                ref.read(trackingMapSourceProvider.notifier).setSource(source);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (source.id == selectedMapSource.id) ...[
                    const Icon(
                      CupertinoIcons.check_mark_circled_solid,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(source.label),
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _checkPermission() async {
    try {
      final granted = await LocationService.ensurePermission();
      if (!mounted) return;
      setState(() {
        _permissionGranted = granted;
        _checkingPermission = false;
      });
      if (granted) {
        await _getCurrentLocation();
      } else {
        _showError('Location permission is required to track workouts.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checkingPermission = false);
        debugPrint('❌ Permission check error: $e');
        _showError('Error checking location permission: $e');
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentLocation = loc);
      try {
        _mapController.move(loc, 16);
      } catch (e) {
        debugPrint('❌ Map move error: $e');
      }
    } catch (e) {
      if (mounted) {
        debugPrint('❌ Location error: $e');
        _showError('Could not get location: $e');
      }
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(ctx).pop(),
          )
        ],
      ),
    );
  }

  Future<void> _handleStartWorkout() async {
    setState(() => _isFollowing = true);
    await ref.read(activeWorkoutProvider.notifier).start();
  }

  void _confirmStop(ActiveWorkoutState workout) {
    final controller = ref.read(activeWorkoutProvider.notifier);
    final wasTracking = workout.status == WorkoutStatus.tracking;
    if (wasTracking) controller.pause();

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Finish Workout?'),
        content: const Text('Do you want to stop and save this workout?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Resume'),
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.resume();
            },
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Finish'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _stopWorkout();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _stopWorkout() async {
    final activity = await ref.read(activeWorkoutProvider.notifier).stop();
    if (!mounted || activity == null) return;
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => SummaryScreen(activity: activity),
      ),
    );
  }

  void _recenter(LatLng location) {
    try {
      _mapController.move(location, 16);
    } catch (_) {}
    setState(() {
      _currentLocation = location;
      _isFollowing = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ActiveWorkoutState>(
      activeWorkoutProvider,
      (prev, next) {
        final nextLoc = next.currentLocation;
        final prevLoc = prev?.currentLocation;

        // If newly paused or resuming, ensure UI sync
        if (prev?.status != next.status) {
           setState(() {}); // refresh if needed, though ref.watch triggers build, listen handles side-effects
        }

        if (!_isFollowing || nextLoc == null || nextLoc == prevLoc) return;
        try {
           _mapController.move(nextLoc, _mapController.camera.zoom);
        } catch (_) {}
      },
    );

    final workout = ref.watch(activeWorkoutProvider);
    final selectedMapSource = ref.watch(trackingMapSourceProvider).maybeWhen(
          data: (source) => source,
          orElse: () => MapTileSources.byId(null),
        );
    final mapLocation = workout.currentLocation ?? _currentLocation;
    final routePoints = workout.routePoints;

    if (_checkingPermission) {
      return const CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text('Track')),
        child: Center(child: CupertinoActivityIndicator(radius: 16)),
      );
    }

    if (!_permissionGranted) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('Track')),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.location_slash_fill,
                size: 48,
                color: CupertinoColors.systemGrey3,
              ),
              const SizedBox(height: 16),
              const Text(
                'Location Permission Required',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enable location to track workouts.',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                onPressed: _checkPermission,
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ),
      );
    }

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          Listener(
            onPointerDown: (_) {
              if (_isFollowing) setState(() => _isFollowing = false);
            },
            child: EnduraMap(
              center: mapLocation,
              zoom: 16,
              mapController: _mapController,
              interactive: true,
              tileSource: selectedMapSource,
              polylines: routePoints.length >= 2
                  ? [
                      PolylineHelper.route(
                        routePoints,
                        color: AppTheme.primary,
                        width: 5,
                      ),
                    ]
                  : [],
              markers: [
                if (routePoints.isNotEmpty) MarkerHelper.start(routePoints.first),
                if (mapLocation != null) MarkerHelper.currentLocation(mapLocation),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 14,
            child: GestureDetector(
              onTap: () => _showMapOptions(selectedMapSource),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(context),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.map_pin_ellipse,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      selectedMapSource.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (mapLocation != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 14,
              child: GestureDetector(
                onTap: () => _recenter(mapLocation),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor(context),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.location_fill,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Recenter',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(context).withValues(alpha: 0.97),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 12,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: workout.status == WorkoutStatus.idle
                    ? _buildIdleControls(workout)
                    : _buildActiveControls(workout),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleControls(ActiveWorkoutState workout) {
    final controller = ref.read(activeWorkoutProvider.notifier);
    final selectedType = workout.selectedType;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ActivityType.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final type = ActivityType.values[i];
              final isSelected = selectedType == type;
              return GestureDetector(
                onTap: () => controller.selectType(type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.cardColor(context).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : CupertinoColors.systemGrey4.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(type.icon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? CupertinoColors.white
                              : AppTheme.textColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            onPressed: _handleStartWorkout,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  selectedType.icon,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  'Start ${selectedType.label}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: CupertinoColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveControls(ActiveWorkoutState workout) {
    final controller = ref.read(activeWorkoutProvider.notifier);
    final status = workout.status;
    final selectedType = workout.selectedType;
    final distance = workout.distance;
    final elapsedSeconds = workout.elapsedSeconds;
    final duration = Duration(seconds: elapsedSeconds);

    final bool isSpeedBased =
        selectedType == ActivityType.cycling || selectedType == ActivityType.riding;
    final String paceVal;
    final String paceUnit;
    if (isSpeedBased) {
      final kmh = elapsedSeconds > 0
          ? (distance / 1000) / (elapsedSeconds / 3600)
          : 0.0;
      paceVal = kmh.toStringAsFixed(1);
      paceUnit = 'km/h';
    } else {
      paceVal = Formatters.paceValue(duration, distance);
      paceUnit = '/km';
    }
    final paceLabel = isSpeedBased ? 'Speed' : 'Pace';

    final distVal = (distance / 1000).toStringAsFixed(2);
    final timeVal = Formatters.durationTrack(duration);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _BigStat(
                  label: 'Distance',
                  value: distVal,
                  unit: 'km',
                ),
              ),
            ),
            Container(width: 1, height: 52, color: CupertinoColors.separator),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _BigStat(
                  label: 'Time',
                  value: timeVal,
                ),
              ),
            ),
            Container(width: 1, height: 52, color: CupertinoColors.separator),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _BigStat(
                  label: paceLabel,
                  value: paceVal,
                  unit: paceUnit,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              onTap: () => _confirmStop(workout),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.danger,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.danger.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.stop_fill,
                  color: CupertinoColors.white,
                  size: 26,
                ),
              ),
            ),
            GestureDetector(
              onTap:
                  status == WorkoutStatus.paused ? controller.resume : controller.pause,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  status == WorkoutStatus.paused
                      ? CupertinoIcons.play_fill
                      : CupertinoIcons.pause_fill,
                  color: CupertinoColors.white,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(width: 60, height: 60),
          ],
        ),
      ],
    );
  }
}

class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;

  const _BigStat({required this.label, required this.value, this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textColor(context),
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

