import 'package:endura/shared/models/sync_status.dart';

/// Cached feed item model stored in Hive.
class CachedFeedItem {
  final String activityId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String activityType;
  final String title;
  final double distance;
  final int duration;
  final String pace;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final List<List<double>> mapPreviewData; // route points for mini map
  final String? thumbnailPhoto;
  final DateTime cachedAt;
  final SyncStatus syncStatus;

  CachedFeedItem({
    required this.activityId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.activityType,
    this.title = '',
    required this.distance,
    required this.duration,
    this.pace = '',
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.mapPreviewData = const [],
    this.thumbnailPhoto,
    DateTime? cachedAt,
    this.syncStatus = SyncStatus.pending,
  }) : cachedAt = cachedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'activityId': activityId,
        'userId': userId,
        'userName': userName,
        'userAvatar': userAvatar,
        'activityType': activityType,
        'title': title,
        'distance': distance,
        'duration': duration,
        'pace': pace,
        'createdAt': createdAt.toIso8601String(),
        'likesCount': likesCount,
        'commentsCount': commentsCount,
        'mapPreviewData': mapPreviewData,
        'thumbnailPhoto': thumbnailPhoto,
        'cachedAt': cachedAt.toIso8601String(),
        'syncStatus': syncStatus.value,
      };

  factory CachedFeedItem.fromMap(Map<String, dynamic> map) => CachedFeedItem(
        activityId: map['activityId'] ?? '',
        userId: map['userId'] ?? '',
        userName: map['userName'] ?? '',
        userAvatar: map['userAvatar'],
        activityType: map['activityType'] ?? 'running',
        title: map['title'] ?? '',
        distance: (map['distance'] ?? 0).toDouble(),
        duration: map['duration'] ?? 0,
        pace: map['pace'] ?? '',
        createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
        likesCount: map['likesCount'] ?? 0,
        commentsCount: map['commentsCount'] ?? 0,
        mapPreviewData: (map['mapPreviewData'] as List?)
                ?.map((p) =>
                    (p as List).map((v) => (v as num).toDouble()).toList())
                .toList() ??
            [],
        thumbnailPhoto: map['thumbnailPhoto'],
        cachedAt: DateTime.tryParse(map['cachedAt'] ?? ''),
        syncStatus: SyncStatusX.fromString(map['syncStatus']),
      );
}


