import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:endura/core/theme/app_theme.dart';
import 'package:endura/core/utils/formatters.dart';
import 'package:endura/shared/models/cached_activity.dart';
import 'package:endura/shared/widgets/polyline_preview.dart';
import 'package:endura/features/activity/activity_repository.dart';
import 'package:endura/features/feed/feed_repository.dart';

/// Full activity detail screen — Strava-inspired share card with route + stats.
class ActivityDetailScreen extends StatefulWidget {
  final CachedActivity activity;

  const ActivityDetailScreen({super.key, required this.activity});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  CachedActivity get activity => widget.activity;

  List<LatLng> get _routePoints =>
      activity.routePoints.map((p) => LatLng(p[0], p[1])).toList();

  @override
  Widget build(BuildContext context) {
    final points = _routePoints;
    final hasRoute = points.length >= 2;
    final hasMedia = activity.photos.isNotEmpty;
    final firstMedia = hasMedia ? activity.photos.first : null;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          activity.title.isNotEmpty ? activity.title : activity.type.label,
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _confirmDelete(context),
          child: const Icon(CupertinoIcons.trash,
              color: AppTheme.danger, size: 22),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Strava-style Share Card ──────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background
                      if (hasMedia &&
                          File(firstMedia!.localPath).existsSync())
                        Image.file(File(firstMedia.localPath),
                            fit: BoxFit.cover)
                      else
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF1A1A2E),
                                Color(0xFF16213E),
                                Color(0xFF0F3460),
                              ],
                            ),
                          ),
                        ),

                      // Dark overlay for readability
                      if (hasMedia &&
                          firstMedia != null)
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0x00000000),
                                const Color(0x40000000),
                                const Color(0xCC000000),
                              ],
                              stops: const [0.0, 0.4, 1.0],
                            ),
                          ),
                        ),

                      // Content overlay
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Spacer(flex: 3),

                            // Stats
                            _OverlayStat(
                              label: 'Distance',
                              value: (activity.distance / 1000).toStringAsFixed(2),
                              unit: 'km',
                              fontSize: 42,
                            ),
                            const SizedBox(height: 16),
                            _OverlayStat(
                              label: (activity.type == ActivityType.cycling || activity.type == ActivityType.riding) ? 'Speed' : 'Pace',
                              value: (activity.type == ActivityType.cycling || activity.type == ActivityType.riding)
                                  ? activity.avgSpeed.toStringAsFixed(1)
                                  : Formatters.paceValue(
                                      Duration(seconds: activity.duration),
                                      activity.distance),
                              unit: (activity.type == ActivityType.cycling || activity.type == ActivityType.riding) ? 'km/h' : '/km',
                              fontSize: 36,
                            ),
                            const SizedBox(height: 16),
                            _OverlayStat(
                              label: 'Time',
                              value: Formatters.durationTrack(
                                  Duration(seconds: activity.duration)),
                              fontSize: 36,
                            ),

                            const Spacer(flex: 2),

                            // Route polyline-only (no map tiles)
                            if (hasRoute)
                              Container(
                                height: 140,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: CupertinoColors.white
                                          .withValues(alpha: 0.15),
                                      width: 1),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: PolylineOnlyPreview(
                                      routePoints: points),
                                ),
                              ),

                            const SizedBox(height: 16),

                            // Branding
                            Text(
                              'ENDURA',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: CupertinoColors.white
                                    .withValues(alpha: 0.6),
                                letterSpacing: 3,
                              ),
                            ),

                            const Spacer(flex: 1),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Activity Info ────────────────────────────────────
              Text(
                activity.title.isNotEmpty
                    ? activity.title
                    : '${activity.type.icon} ${activity.type.label}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textColor(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${activity.type.icon} ${activity.type.label} · ${Formatters.dateTime(activity.startTime)}',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),

              if (activity.caption.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  activity.caption,
                  style: TextStyle(
                      fontSize: 15, color: AppTheme.textColor(context)),
                ),
              ],
              const SizedBox(height: 20),

              // ── Stats Grid ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(context),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _DetailStat(
                            label: 'Distance',
                            value: (activity.distance / 1000).toStringAsFixed(2),
                            unit: 'km')),
                        Expanded(child: _DetailStat(
                            label: 'Time',
                            value: Formatters.durationTrack(Duration(seconds: activity.duration)))),
                        Expanded(child: (activity.type == ActivityType.cycling || activity.type == ActivityType.riding)
                            ? _DetailStat(
                                label: 'Avg Speed',
                                value: activity.avgSpeed.toStringAsFixed(1),
                                unit: 'km/h')
                            : _DetailStat(
                                label: 'Avg Pace',
                                value: Formatters.paceValue(
                                    Duration(seconds: activity.duration),
                                    activity.distance),
                                unit: '/km')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: (activity.type == ActivityType.cycling || activity.type == ActivityType.riding)
                            ? _DetailStat(
                                label: 'Avg Pace',
                                value: Formatters.paceValue(
                                    Duration(seconds: activity.duration),
                                    activity.distance),
                                unit: '/km')
                            : _DetailStat(
                                label: 'Avg Speed',
                                value: activity.avgSpeed.toStringAsFixed(1),
                                unit: 'km/h')),
                        Expanded(child: _DetailStat(
                            label: 'Calories',
                            value: activity.calories.round().toString(),
                            unit: 'cal')),
                        if (activity.elevationGain > 0)
                          Expanded(child: _DetailStat(
                              label: 'Elevation',
                              value: '+${activity.elevationGain.round()}',
                              unit: 'm')),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Additional Photos ───────────────────────────────
              if (activity.photos.length > 1) ...[
                const SizedBox(height: 20),
                Text('Photos',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor(context))),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: activity.photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final photo = activity.photos[index];
                      return ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: Image.file(
                            File(photo.localPath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: CupertinoColors.systemGrey5,
                              child: const Icon(CupertinoIcons.photo,
                                  color: CupertinoColors.systemGrey3),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Activity?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              // Delete from activities AND feed
              await ActivityRepository.delete(activity.localId);
              await FeedRepository.delete(activity.localId);
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

// ── Overlay stat widget ───────────────────────────────────────────

class _OverlayStat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final double fontSize;

  const _OverlayStat({
    required this.label,
    required this.value,
    this.unit,
    this.fontSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: CupertinoColors.white.withValues(alpha: 0.7),
            letterSpacing: 0.5,
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
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  color: CupertinoColors.white,
                  height: 1.0,
                  letterSpacing: -1,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: EdgeInsets.only(bottom: fontSize * 0.08),
                  child: Text(
                    unit!,
                    style: TextStyle(
                      fontSize: fontSize * 0.38,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white.withValues(alpha: 0.75),
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

// ── Detail stat widget ────────────────────────────────────────────

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  const _DetailStat({required this.label, required this.value, this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textColor(context),
                    height: 1.0)),
            if (unit != null) ...[
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(unit!,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
