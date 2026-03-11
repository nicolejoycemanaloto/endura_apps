import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:endura/core/storage/hive_service.dart';
import 'package:endura/shared/models/cached_feed_item.dart';
import 'package:endura/shared/models/cached_activity.dart';
import 'package:endura/shared/models/cached_user.dart';
import 'package:endura/core/utils/formatters.dart';

/// Repository for feed operations on Hive.
class FeedRepository {
  static Box<Map> get _box => HiveService.feedBox;

  /// Listenable that fires when the feed box changes.
  static ValueListenable<Box<Map>> get listenable => _box.listenable();

  /// Get all feed items, newest first.
  static List<CachedFeedItem> getAll() {
    final items = <CachedFeedItem>[];
    for (final key in _box.keys) {
      final data = _box.get(key);
      if (data != null) {
        items.add(CachedFeedItem.fromMap(Map<String, dynamic>.from(data)));
      }
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  /// Create a feed item from a saved activity + user (local social sim).
  static Future<void> createFromActivity(
    CachedActivity activity,
    CachedUser user,
  ) async {
    final item = CachedFeedItem(
      activityId: activity.localId,
      userId: user.id,
      userName: user.displayName,
      userAvatar: user.avatarLocalPath,
      activityType: activity.type.name,
      title: activity.title,
      distance: activity.distance,
      duration: activity.duration,
      pace: Formatters.pace(
        Duration(seconds: activity.duration),
        activity.distance,
      ),
      createdAt: activity.startTime,
      mapPreviewData: activity.routePoints,
      thumbnailPhoto:
          activity.photos.isNotEmpty ? activity.photos.first.localPath : null,
    );
    await _box.put(activity.localId, item.toMap());
  }

  /// Delete a feed item.
  static Future<void> delete(String activityId) async {
    await _box.delete(activityId);
  }

  /// Clear all feed data.
  static Future<void> clearAll() async {
    await _box.clear();
  }
}




