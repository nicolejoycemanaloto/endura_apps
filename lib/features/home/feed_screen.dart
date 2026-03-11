import 'package:flutter/cupertino.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:endura/core/theme/app_theme.dart';
import 'package:endura/core/utils/formatters.dart';
import 'package:endura/shared/models/cached_feed_item.dart';
import 'package:endura/shared/models/cached_activity.dart';
import 'package:endura/shared/widgets/endura_avatar.dart';
import 'package:endura/shared/widgets/polyline_preview.dart';
import 'package:endura/features/feed/feed_repository.dart';
import 'package:endura/features/activity/activity_detail_screen.dart';
import 'package:endura/features/activity/activity_repository.dart';

/// Home tab — your activity feed.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: ValueListenableBuilder(
        valueListenable: FeedRepository.listenable,
        builder: (context, box, _) {
          final items = FeedRepository.getAll();

          if (items.isEmpty) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                const CupertinoSliverNavigationBar(
                  largeTitle: Text('Activities'),
                  border: null,
                ),
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.sportscourt,
                            size: 56, color: CupertinoColors.systemGrey3),
                        const SizedBox(height: AppTheme.spacingMd),
                        Text(
                          'No activities yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textColor(context),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingSm),
                        const Text(
                          'Start a workout to see it here!',
                          style: TextStyle(
                              fontSize: 14, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              const CupertinoSliverNavigationBar(
                largeTitle: Text('Activities'),
                border: null,
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingMd,
                  AppTheme.spacingMd,
                  AppTheme.spacingMd,
                  100,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppTheme.spacingMd),
                      child: _FeedCard(
                        item: items[index],
                        onTap: () => _openDetail(context, items[index]),
                      ),
                    ),
                    childCount: items.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openDetail(BuildContext context, CachedFeedItem item) {
    final activity = ActivityRepository.getById(item.activityId);
    if (activity == null) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ActivityDetailScreen(activity: activity),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final CachedFeedItem item;
  final VoidCallback onTap;

  const _FeedCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final routePoints = item.mapPreviewData
        .map((p) => LatLng(p[0], p[1]))
        .toList();
    final typeEnum = ActivityTypeX.fromString(item.activityType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          boxShadow: [
            BoxShadow(
              color: const Color(0x0A000000),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  EnduraAvatar(
                    imagePath: item.userAvatar,
                    name: item.userName,
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title.isNotEmpty
                              ? item.title
                              : '${typeEnum.icon} ${typeEnum.label}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textColor(context),
                          ),
                        ),
                        Text(
                          '${typeEnum.icon} ${typeEnum.label} · ${Formatters.timeAgo(item.createdAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Mini route preview (polyline only, no map tiles)
            if (routePoints.length >= 2)
              ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: SizedBox(
                  height: 160,
                  child: PolylineOnlyPreview(routePoints: routePoints),
                ),
              ),
            // Stats
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MiniStat(
                    label: 'Distance',
                    value: (item.distance / 1000).toStringAsFixed(2),
                    unit: 'km',
                  ),
                  _MiniStat(
                    label: 'Time',
                    value: Formatters.durationTrack(Duration(seconds: item.duration)),
                  ),
                  _MiniStat(
                    label: 'Pace',
                    value: item.pace.split(' ').first,
                    unit: item.pace.contains(' ') ? item.pace.split(' ').last : '',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;

  const _MiniStat({required this.label, required this.value, this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textColor(context),
                height: 1.0,
              ),
            ),
            if (unit != null && unit!.isNotEmpty) ...[
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  unit!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}








