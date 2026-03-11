import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:endura/core/theme/app_theme.dart';
import 'package:endura/core/maps/endura_map.dart';
import 'package:endura/core/maps/marker_helper.dart';
import 'package:endura/core/utils/formatters.dart';
import 'package:endura/core/utils/location_service.dart';
import 'package:endura/shared/models/cached_activity.dart';
import 'package:endura/features/activity/activity_repository.dart';
import 'package:endura/features/activity/activity_detail_screen.dart';

/// Explore tab — all saved activity routes overlaid on the map.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final MapController _mapController = MapController();
  CachedActivity? _selected;
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    try {
      final granted = await LocationService.ensurePermission();
      if (!granted || !mounted) return;
      final pos = await LocationService.getCurrentPosition();
      if (mounted) setState(() => _currentLocation = LatLng(pos.latitude, pos.longitude));
    } catch (_) {}
  }

  void _recenter() {
    if (_currentLocation == null) return;
    try {
      _mapController.move(_currentLocation!, 15);
    } catch (_) {}
  }

  List<CachedActivity> get _activities =>
      ActivityRepository.getAll().where((a) => a.routePoints.length >= 2).toList();

  void _onRouteTap(CachedActivity activity) {
    setState(() => _selected = activity);

    // Fit map to selected route
    final points = activity.routePoints
        .map((p) => LatLng(p[0], p[1]))
        .toList();
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(48),
        ),
      );
    } catch (_) {}
  }

  void _openDetail(CachedActivity activity) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ActivityDetailScreen(activity: activity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Explore'),
        border: null,
      ),
      child: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: ActivityRepository.listenable,
          builder: (context, _, __) {
            final acts = _activities;

            if (acts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.map,
                        size: 56, color: CupertinoColors.systemGrey3),
                    const SizedBox(height: 16),
                    Text(
                      'No routes yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Complete a workout to see your routes here.',
                      style: TextStyle(
                          fontSize: 14, color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            // Build polylines for all activities
            final polylines = <Polyline>[];
            final markers = <Marker>[];

            for (final a in acts) {
              final pts = a.routePoints
                  .map((p) => LatLng(p[0], p[1]))
                  .toList();
              final isSelected = _selected?.localId == a.localId;

              polylines.add(Polyline(
                points: pts,
                color: isSelected
                    ? AppTheme.primary
                    : AppTheme.primary.withValues(alpha: 0.35),
                strokeWidth: isSelected ? 5 : 3,
                borderColor: isSelected
                    ? const Color(0x40000000)
                    : const Color(0x00000000),
                borderStrokeWidth: isSelected ? 1 : 0,
              ));

              if (isSelected) {
                markers.add(MarkerHelper.start(pts.first));
                markers.add(MarkerHelper.end(pts.last));
              }
            }

            // Initial camera fit — all routes
            final allPoints = acts
                .expand((a) => a.routePoints.map((p) => LatLng(p[0], p[1])))
                .toList();
            final initialFit = CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(allPoints),
              padding: const EdgeInsets.all(32),
            );

            return Column(
              children: [
                // ── Map ──────────────────────────────────────────
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      EnduraMap(
                        mapController: _mapController,
                        interactive: true,
                        polylines: polylines,
                        markers: [
                          ...markers,
                          if (_currentLocation != null)
                            MarkerHelper.currentLocation(_currentLocation!),
                        ],
                        initialCameraFit: initialFit,
                      ),

                      // Recenter button — bottom right of map
                      Positioned(
                        right: 14,
                        bottom: 14,
                        child: GestureDetector(
                          onTap: _recenter,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor(context),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0x28000000),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: const Icon(
                              CupertinoIcons.location_fill,
                              size: 20,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ),

                      // Deselect / Clear button
                      if (_selected != null)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: GestureDetector(
                            onTap: () => setState(() => _selected = null),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor(context)
                                    .withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0x1A000000),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(CupertinoIcons.xmark,
                                      size: 13,
                                      color: AppTheme.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Clear',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Route list ───────────────────────────────────
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Text(
                          '${acts.length} Route${acts.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textColor(context),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: acts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final a = acts[i];
                            final isSelected =
                                _selected?.localId == a.localId;
                            return GestureDetector(
                              onTap: () => _onRouteTap(a),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primary
                                          .withValues(alpha: 0.10)
                                      : AppTheme.cardColor(context),
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radius),
                                  border: isSelected
                                      ? Border.all(
                                          color: AppTheme.primary
                                              .withValues(alpha: 0.4),
                                        )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    // Icon
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primarySurface,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(a.type.icon,
                                            style: const TextStyle(
                                                fontSize: 18)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            a.title.isNotEmpty
                                                ? a.title
                                                : a.type.label,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  AppTheme.textColor(context),
                                            ),
                                          ),
                                          Text(
                                            Formatters.date(a.startTime),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppTheme.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Stats
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          Formatters.distanceKm(a.distance),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                AppTheme.textColor(context),
                                          ),
                                        ),
                                        Text(
                                          Formatters.duration(Duration(
                                              seconds: a.duration)),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 6),
                                    // Open detail
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      onPressed: () => _openDetail(a),
                                      child: const Icon(
                                        CupertinoIcons.chevron_right,
                                        size: 16,
                                        color: CupertinoColors.systemGrey3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


