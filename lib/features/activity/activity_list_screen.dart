import 'package:flutter/cupertino.dart';
import 'package:endura/core/theme/app_theme.dart';
import 'package:endura/core/utils/formatters.dart';
import 'package:endura/shared/models/cached_activity.dart';
import 'package:endura/features/activity/activity_repository.dart';
import 'package:endura/features/activity/activity_detail_screen.dart';

/// Activity history list — real-time updates via Hive listenable.
class ActivityListScreen extends StatefulWidget {
  const ActivityListScreen({super.key});

  @override
  State<ActivityListScreen> createState() => _ActivityListScreenState();
}

class _ActivityListScreenState extends State<ActivityListScreen> {
  ActivityType? _filterType;

  List<CachedActivity> _getFiltered() {
    final all = ActivityRepository.getAll();
    if (_filterType == null) return all;
    return all.where((a) => a.type == _filterType).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Activity History'),
        previousPageTitle: 'Profile',
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Filter segmented control
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _filterType == null
                    ? 0
                    : ActivityType.values.indexOf(_filterType!) + 1,
                children: {
                  0: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Text('All', style: TextStyle(fontSize: 13)),
                  ),
                  for (int i = 0; i < ActivityType.values.length; i++)
                    i + 1: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Text(ActivityType.values[i].label,
                          style: const TextStyle(fontSize: 13)),
                    ),
                },
                onValueChanged: (v) {
                  setState(() {
                    _filterType =
                        v == null || v == 0 ? null : ActivityType.values[v - 1];
                  });
                },
              ),
            ),
            // Real-time list
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: ActivityRepository.listenable,
                builder: (context, box, _) {
                  final activities = _getFiltered();

                  if (activities.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.sportscourt,
                              size: 48, color: CupertinoColors.systemGrey3),
                          const SizedBox(height: 12),
                          Text('No activities yet',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textColor(context))),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: activities.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final activity = activities[index];
                      return _ActivityCard(
                        activity: activity,
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) =>
                                  ActivityDetailScreen(activity: activity),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final CachedActivity activity;
  final VoidCallback onTap;

  const _ActivityCard({required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          boxShadow: [
            BoxShadow(
              color: const Color(0x0A000000),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  activity.type.icon,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title.isNotEmpty
                        ? activity.title
                        : activity.type.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.dateTime(activity.startTime),
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            // Stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      (activity.distance / 1000).toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor(context),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 1),
                      child: Text(
                        'km',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.durationTrack(Duration(seconds: activity.duration)),
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(CupertinoIcons.chevron_right,
                size: 16, color: CupertinoColors.systemGrey3),
          ],
        ),
      ),
    );
  }
}





