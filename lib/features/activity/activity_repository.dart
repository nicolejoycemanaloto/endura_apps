import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:endura/core/storage/hive_service.dart';
import 'package:endura/shared/models/cached_activity.dart';

/// Repository for activity operations on Hive.
class ActivityRepository {
  static Box<Map> get _box => HiveService.activitiesBox;

  /// Listenable that fires when the activities box changes.
  static ValueListenable<Box<Map>> get listenable => _box.listenable();

  /// Get all saved activities, newest first.
  static List<CachedActivity> getAll() {
    final activities = <CachedActivity>[];
    for (final key in _box.keys) {
      final data = _box.get(key);
      if (data != null) {
        activities.add(
          CachedActivity.fromMap(Map<String, dynamic>.from(data)),
        );
      }
    }
    activities.sort((a, b) => b.startTime.compareTo(a.startTime));
    return activities;
  }

  /// Get activities filtered by type.
  static List<CachedActivity> getByType(ActivityType type) {
    return getAll().where((a) => a.type == type).toList();
  }

  /// Get a single activity by localId.
  static CachedActivity? getById(String localId) {
    final data = _box.get(localId);
    if (data == null) return null;
    return CachedActivity.fromMap(Map<String, dynamic>.from(data));
  }

  /// Save an activity.
  static Future<void> save(CachedActivity activity) async {
    await _box.put(activity.localId, activity.toMap());
  }

  /// Delete an activity.
  static Future<void> delete(String localId) async {
    await _box.delete(localId);
  }

  /// Get total distance for all activities.
  static double getTotalDistance() {
    return getAll().fold(0.0, (sum, a) => sum + a.distance);
  }

  /// Get total duration for all activities.
  static Duration getTotalDuration() {
    final totalSeconds = getAll().fold(0, (sum, a) => sum + a.duration);
    return Duration(seconds: totalSeconds);
  }

  /// Get total activity count.
  static int getCount() => getAll().length;
}
