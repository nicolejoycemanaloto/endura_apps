import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'package:endura/core/theme/app_theme.dart';
import 'package:endura/core/maps/endura_map.dart';
import 'package:endura/core/maps/polyline_helper.dart';
import 'package:endura/core/maps/marker_helper.dart';
import 'package:endura/core/utils/location_service.dart';
import 'package:endura/core/utils/formatters.dart';
import 'package:endura/shared/models/cached_activity.dart';
import 'package:endura/features/activity/summary_screen.dart';
import 'package:endura/features/profile/user_repository.dart';

/// Track tab — live workout recording with map.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

enum _WorkoutState { idle, tracking, paused }

class _TrackingScreenState extends State<TrackingScreen> {
  _WorkoutState _state = _WorkoutState.idle;
  ActivityType _selectedType = ActivityType.walking;
  bool _permissionGranted = false;
  bool _checkingPermission = true;
  bool _isFollowing = true; // auto-follow user location

  // Workout data
  final List<LatLng> _routePoints = [];
  LatLng? _currentLocation;
  double _distance = 0; // meters
  int _elapsedSeconds = 0;
  double _calories = 0;
  double _elevationGain = 0;
  DateTime? _startTime;
  double? _lastAltitude;
  DateTime? _lastPositionTime; // used for speed-outlier rejection

  StreamSubscription<Position>? _positionSub;
  Timer? _timer;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await LocationService.ensurePermission();
    if (mounted) {
      setState(() {
        _permissionGranted = granted;
        _checkingPermission = false;
      });
      if (granted) _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      if (mounted) {
        final loc = LatLng(pos.latitude, pos.longitude);
        setState(() => _currentLocation = loc);
        // Center the map on the user's position immediately
        try {
          _mapController.move(loc, 16);
        } catch (_) {}
      }
    } catch (_) {}
  }

  void _recenter() {
    if (_currentLocation == null) return;
    try {
      _mapController.move(_currentLocation!, 16);
    } catch (_) {}
    setState(() => _isFollowing = true);
  }

  void _startWorkout() {
    _routePoints.clear();
    _distance = 0;
    _elapsedSeconds = 0;
    _calories = 0;
    _elevationGain = 0;
    _lastAltitude = null;
    _lastPositionTime = null;
    _startTime = DateTime.now();
    _isFollowing = true;

    _positionSub = LocationService.getPositionStream(distanceFilter: 3)
        .listen(_onPosition);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == _WorkoutState.tracking && mounted) {
        setState(() => _elapsedSeconds++);
      }
    });

    setState(() => _state = _WorkoutState.tracking);
  }

  void _onPosition(Position pos) {
    if (_state != _WorkoutState.tracking) return;

    // ── Layer 1: Accuracy gate ─────────────────────────────────────────────
    // Reject fixes with horizontal accuracy worse than 20 m.
    // (was 50 m — far too loose; a 49 m accuracy fix is nearly useless)
    if (pos.accuracy > 20) return;

    final newPoint = LatLng(pos.latitude, pos.longitude);
    final now = DateTime.now();

    if (_routePoints.isNotEmpty) {
      final distFromLast = LocationService.distanceBetween(
        _routePoints.last.latitude, _routePoints.last.longitude,
        newPoint.latitude, newPoint.longitude,
      );

      // ── Layer 2: Min-distance guard ───────────────────────────────────────
      // Ignore points closer than 5 m — eliminates stationary GPS drift.
      if (distFromLast < 5) {
        setState(() => _currentLocation = newPoint);
        if (_isFollowing) {
          try { _mapController.move(newPoint, _mapController.camera.zoom); } catch (_) {}
        }
        return;
      }

      // ── Layer 3: Speed-outlier rejection ──────────────────────────────────
      // If the implied speed between the last accepted point and this one
      // exceeds the physical maximum for the selected activity, it's a GPS
      // spike — update the map dot but don't add the distance.
      if (_lastPositionTime != null) {
        final elapsedSec =
            now.difference(_lastPositionTime!).inMilliseconds / 1000.0;
        if (elapsedSec > 0) {
          final impliedSpeedMs = distFromLast / elapsedSec;
          if (impliedSpeedMs > _maxSpeedForActivity) {
            setState(() => _currentLocation = newPoint);
            if (_isFollowing) {
              try { _mapController.move(newPoint, _mapController.camera.zoom); } catch (_) {}
            }
            return; // spike — skip this point
          }
        }
      }
    }

    // ── Accepted point — update all workout metrics ────────────────────────
    _lastPositionTime = now;

    setState(() {
      if (_routePoints.isNotEmpty) {
        final last = _routePoints.last;
        _distance += LocationService.distanceBetween(
          last.latitude, last.longitude,
          newPoint.latitude, newPoint.longitude,
        );
      }

      // Elevation — only count uphill gain
      if (_lastAltitude != null && pos.altitude > _lastAltitude!) {
        _elevationGain += pos.altitude - _lastAltitude!;
      }
      _lastAltitude = pos.altitude;

      _calories = (_distance / 1000) * _caloriesPerKm;

      _routePoints.add(newPoint);
      _currentLocation = newPoint;
    });

    if (_isFollowing) {
      try { _mapController.move(newPoint, _mapController.camera.zoom); } catch (_) {}
    }
  }

  /// Max credible speed (m/s) for the currently selected activity type.
  double get _maxSpeedForActivity {
    switch (_selectedType) {
      case ActivityType.running: return LocationService.maxSpeedRunning;
      case ActivityType.cycling: return LocationService.maxSpeedCycling;
      case ActivityType.walking: return LocationService.maxSpeedWalking;
      case ActivityType.hiking:  return LocationService.maxSpeedHiking;
      case ActivityType.riding:  return LocationService.maxSpeedRiding;
    }
  }

  double get _caloriesPerKm {
    switch (_selectedType) {
      case ActivityType.running:
        return 62;
      case ActivityType.cycling:
        return 30;
      case ActivityType.walking:
        return 45;
      case ActivityType.hiking:
        return 55;
      case ActivityType.riding:
        return 10;
    }
  }

  void _confirmStop() {
    // Pause while user decides
    if (_state == _WorkoutState.tracking) {
      _pauseWorkout();
    }

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
              _resumeWorkout();
            },
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Finish'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _stopWorkout();
            },
          ),
        ],
      ),
    );
  }

  void _pauseWorkout() => setState(() => _state = _WorkoutState.paused);

  void _resumeWorkout() => setState(() => _state = _WorkoutState.tracking);

  void _stopWorkout() {
    // Set idle FIRST so any in-flight _onPosition call returns early
    // via the `if (_state != _WorkoutState.tracking) return;` guard.
    setState(() => _state = _WorkoutState.idle);

    _positionSub?.cancel();
    _timer?.cancel();

    final userId = UserRepository.getProfile()?.id ?? '';

    final activity = CachedActivity(
      localId: const Uuid().v4(),
      userId: userId,
      type: _selectedType,
      distance: _distance,
      duration: _elapsedSeconds,
      avgPace: Formatters.pace(Duration(seconds: _elapsedSeconds), _distance),
      avgSpeed: _elapsedSeconds > 0
          ? (_distance / 1000) / (_elapsedSeconds / 3600)
          : 0,
      calories: _calories,
      elevationGain: _elevationGain,
      routePoints: _routePoints.map((p) => [p.latitude, p.longitude]).toList(),
      startTime: _startTime ?? DateTime.now(),
      endTime: DateTime.now(),
    );


    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => SummaryScreen(activity: activity),
      ),
    );
  }


  @override
  void dispose() {
    _positionSub?.cancel();
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              const Icon(CupertinoIcons.location_slash_fill,
                  size: 48, color: CupertinoColors.systemGrey3),
              const SizedBox(height: 16),
              const Text('Location Permission Required',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Enable location to track workouts.',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
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
          // Map — wrapped in Listener to detect manual pan
          Listener(
            onPointerDown: (_) {
              if (_isFollowing) setState(() => _isFollowing = false);
            },
            child: EnduraMap(
              center: _currentLocation,
              zoom: 16,
              mapController: _mapController,
              interactive: true,
              polylines: _routePoints.length >= 2
                  ? [PolylineHelper.route(_routePoints, color: AppTheme.primary, width: 5)]
                  : [],
              markers: [
                if (_routePoints.isNotEmpty)
                  MarkerHelper.start(_routePoints.first),
                if (_currentLocation != null)
                  MarkerHelper.currentLocation(_currentLocation!),
              ],
            ),
          ),

          // Recenter button — top-right, solid and always visible
          if (_currentLocation != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 14,
              child: GestureDetector(
                onTap: _recenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor(context),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x33000000),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.location_fill,
                          size: 16, color: AppTheme.primary),
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

          // Bottom controls
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
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x1A000000),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: _state == _WorkoutState.idle
                    ? _buildIdleControls()
                    : _buildActiveControls(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Activity type picker with icons
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ActivityType.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final type = ActivityType.values[i];
              final selected = _selectedType == type;
              return GestureDetector(
                onTap: () => setState(() => _selectedType = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary
                        : AppTheme.cardColor(context).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
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
                          color: selected
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
            onPressed: _startWorkout,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _selectedType.icon,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  'Start ${_selectedType.label}',
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

  Widget _buildActiveControls() {
    final dur = Duration(seconds: _elapsedSeconds);

    // Pace / Speed — value and unit split
    final String paceVal;
    final String paceUnit;
    if (_selectedType == ActivityType.cycling || _selectedType == ActivityType.riding) {
      final kmh = _elapsedSeconds > 0
          ? ((_distance / 1000) / (_elapsedSeconds / 3600))
          : 0.0;
      paceVal = kmh.toStringAsFixed(1);
      paceUnit = 'km/h';
    } else {
      paceVal = Formatters.paceValue(dur, _distance);
      paceUnit = '/km';
    }
    final paceLabel = (_selectedType == ActivityType.cycling || _selectedType == ActivityType.riding) ? 'Speed' : 'Pace';

    // Distance — value and unit split
    final distKm = _distance / 1000;
    final distVal = distKm.toStringAsFixed(2);

    // Time — Strava style (1h 0m or mm:ss)
    final timeVal = Formatters.durationTrack(dur);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Big stats row ───────────────────────────────────────
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
        // ── Controls row ────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Stop button
            GestureDetector(
              onTap: _confirmStop,
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
                child: const Icon(CupertinoIcons.stop_fill,
                    color: CupertinoColors.white, size: 26),
              ),
            ),
            // Pause/Resume button
            GestureDetector(
              onTap: _state == _WorkoutState.paused
                  ? _resumeWorkout
                  : _pauseWorkout,
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
                  _state == _WorkoutState.paused
                      ? CupertinoIcons.play_fill
                      : CupertinoIcons.pause_fill,
                  color: CupertinoColors.white,
                  size: 32,
                ),
              ),
            ),
            // Spacer for symmetry
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
  final String? unit; // rendered smaller, inline after value

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


