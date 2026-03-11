import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:endura/core/storage/hive_service.dart';
import 'package:endura/shared/models/cached_challenge.dart';
import 'package:endura/shared/models/cached_activity.dart';

/// Repository for challenge operations on Hive.
class ChallengeRepository {
  static Box<Map> get _box => HiveService.challengeBox;

  /// Listenable that fires when the challenge box changes.
  static ValueListenable<Box<Map>> get listenable => _box.listenable();

  static const _versionKey = '__challenge_seed_v';

  /// Get all challenges.
  static List<CachedChallenge> getAll() {
    final items = <CachedChallenge>[];
    for (final key in _box.keys) {
      if (key == _versionKey) continue; // skip internal marker
      final data = _box.get(key);
      if (data != null) {
        try {
          items.add(CachedChallenge.fromMap(Map<String, dynamic>.from(data)));
        } catch (_) {
          // skip corrupt entries
        }
      }
    }
    return items;
  }

  /// Get only joined challenges (includes completed).
  static List<CachedChallenge> getJoined() =>
      getAll().where((c) => c.joined).toList();

  /// Get only active (joined but not completed and not expired) challenges.
  static List<CachedChallenge> getActive() =>
      getAll().where((c) => c.joined && !c.completed && !c.isExpired).toList();

  /// Get only completed challenges.
  static List<CachedChallenge> getCompleted() =>
      getAll().where((c) => c.joined && c.completed).toList();

  /// Get available (not joined, not expired) challenges.
  static List<CachedChallenge> getAvailable() =>
      getAll().where((c) => !c.joined && !c.isExpired).toList();

  /// Get a single challenge.
  static CachedChallenge? getById(String id) {
    final data = _box.get(id);
    if (data == null) return null;
    return CachedChallenge.fromMap(Map<String, dynamic>.from(data));
  }

  /// Save a challenge.
  static Future<void> save(CachedChallenge challenge) async {
    await _box.put(challenge.id, challenge.toMap());
  }

  /// Join a challenge.
  static Future<void> join(String id) async {
    final challenge = getById(id);
    if (challenge == null) return;
    await save(challenge.copyWith(joined: true));
  }

  /// Leave a challenge.
  static Future<void> leave(String id) async {
    final challenge = getById(id);
    if (challenge == null) return;
    await save(challenge.copyWith(joined: false, progress: 0));
  }

  /// Update progress for all joined challenges based on a new activity.
  static Future<void> updateProgressFromActivity(
      CachedActivity activity) async {
    final joined = getJoined();
    for (final challenge in joined) {
      if (challenge.completed || challenge.isExpired) continue;

      double newProgress = challenge.progress;
      switch (challenge.type) {
        case ChallengeType.distance:
          newProgress += activity.distance / 1000; // km
          break;
        case ChallengeType.activityCount:
          newProgress += 1;
          break;
        case ChallengeType.time:
          newProgress += activity.duration / 60; // minutes
          break;
        case ChallengeType.streak:
          // Compute actual streak from all saved activities
          newProgress = _computeCurrentStreak().toDouble();
          break;
      }

      final isCompleted = newProgress >= challenge.target;
      await save(challenge.copyWith(
        progress: newProgress,
        completed: isCompleted,
      ));
    }
  }

  /// Compute current consecutive-day workout streak from activities box.
  static int _computeCurrentStreak() {
    final activitiesBox = HiveService.activitiesBox;
    final dates = <DateTime>{};

    for (final key in activitiesBox.keys) {
      final data = activitiesBox.get(key);
      if (data != null) {
        final map = Map<String, dynamic>.from(data);
        final startStr = map['startTime'] as String?;
        if (startStr != null) {
          final dt = DateTime.tryParse(startStr);
          if (dt != null) {
            // Normalize to date-only
            dates.add(DateTime(dt.year, dt.month, dt.day));
          }
        }
      }
    }

    if (dates.isEmpty) return 0;

    // Sort dates descending
    final sorted = dates.toList()..sort((a, b) => b.compareTo(a));

    // Today or yesterday must be in the list to have an active streak
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final yesterdayNorm = todayNorm.subtract(const Duration(days: 1));

    if (sorted.first != todayNorm && sorted.first != yesterdayNorm) {
      return 0; // streak broken
    }

    int streak = 1;
    for (int i = 0; i < sorted.length - 1; i++) {
      final diff = sorted[i].difference(sorted[i + 1]).inDays;
      if (diff == 1) {
        streak++;
      } else if (diff > 1) {
        break; // gap found
      }
      // diff == 0 means same day, skip
    }

    return streak;
  }

  /// Recalculate all streak challenges from scratch.
  static Future<void> recalculateStreaks() async {
    final joined = getJoined();
    for (final challenge in joined) {
      if (challenge.type != ChallengeType.streak) continue;
      if (challenge.completed) continue;

      final streak = _computeCurrentStreak().toDouble();
      final isCompleted = streak >= challenge.target;
      await save(challenge.copyWith(
        progress: streak,
        completed: isCompleted,
      ));
    }
  }

  /// Seed default challenges. Replaces old set with modern challenges.
  static Future<void> seedDefaults() async {
    const currentVersion = 3; // bump this to force reseed
    final existingVersion = _box.get(_versionKey);
    if (existingVersion != null &&
        existingVersion['v'] == currentVersion) {
      return;
    }

    // Clear old challenges and reseed
    await _box.clear();

    final now = DateTime.now();
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final quarterEnd = DateTime(now.year, now.month + 3, 0);

    final challenges = [
      CachedChallenge(
        id: 'c_50k_month',
        title: '50K Monthly',
        description:
            'Cover 50 kilometers this month. Any activity counts — run, walk, cycle, or hike your way there.',
        type: ChallengeType.distance,
        target: 50,
        startDate: DateTime(now.year, now.month, 1),
        endDate: monthEnd,
        badge: '🏃',
      ),
      CachedChallenge(
        id: 'c_10_activities',
        title: '10 Workouts',
        description:
            'Complete 10 workouts this month. Consistency beats intensity — just show up.',
        type: ChallengeType.activityCount,
        target: 10,
        startDate: DateTime(now.year, now.month, 1),
        endDate: monthEnd,
        badge: '💪',
      ),
      CachedChallenge(
        id: 'c_300min',
        title: '300 Active Minutes',
        description:
            'Accumulate 300 minutes of movement this month. Every minute of effort adds up.',
        type: ChallengeType.time,
        target: 300,
        startDate: DateTime(now.year, now.month, 1),
        endDate: monthEnd,
        badge: '⏱️',
      ),
      CachedChallenge(
        id: 'c_100k_quarter',
        title: '100K Quarterly',
        description:
            'A bigger goal for dedicated athletes — cover 100 km this quarter. Take your time, stay committed.',
        type: ChallengeType.distance,
        target: 100,
        startDate: DateTime(now.year, now.month, 1),
        endDate: quarterEnd,
        badge: '🏆',
      ),
      CachedChallenge(
        id: 'c_20_activities_quarter',
        title: '20 Sessions',
        description:
            'Complete 20 workout sessions this quarter. Build momentum and make fitness a lifestyle.',
        type: ChallengeType.activityCount,
        target: 20,
        startDate: DateTime(now.year, now.month, 1),
        endDate: quarterEnd,
        badge: '🔥',
      ),
      CachedChallenge(
        id: 'c_5k_week',
        title: 'Weekly 5K',
        description:
            'Hit 5 km in a single week. A small weekly goal to keep you moving forward.',
        type: ChallengeType.distance,
        target: 5,
        startDate: now,
        endDate: now.add(const Duration(days: 7)),
        badge: '⚡',
      ),
    ];

    for (final c in challenges) {
      await save(c);
    }

    // Store version marker
    await _box.put(_versionKey, {'v': currentVersion});
  }
}









