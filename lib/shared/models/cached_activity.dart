import 'package:endura/shared/models/sync_status.dart';

/// Activity type enum.
enum ActivityType { running, cycling, walking, hiking }

extension ActivityTypeX on ActivityType {
  String get label {
    switch (this) {
      case ActivityType.running:
        return 'Running';
      case ActivityType.cycling:
        return 'Cycling';
      case ActivityType.walking:
        return 'Walking';
      case ActivityType.hiking:
        return 'Hiking';
    }
  }

  String get icon {
    switch (this) {
      case ActivityType.running:
        return '🏃';
      case ActivityType.cycling:
        return '🚴';
      case ActivityType.walking:
        return '🚶';
      case ActivityType.hiking:
        return '🥾';
    }
  }

  static ActivityType fromString(String? s) {
    switch (s) {
      case 'cycling':
        return ActivityType.cycling;
      case 'walking':
        return ActivityType.walking;
      case 'hiking':
        return ActivityType.hiking;
      default:
        return ActivityType.running;
    }
  }
}

/// Photo/video item for activity attachments.
class PhotoItem {
  final String localPath;
  final String? remoteUrl;
  final bool isVideo;
  final DateTime createdAt;
  final SyncStatus syncStatus;

  PhotoItem({
    required this.localPath,
    this.remoteUrl,
    this.isVideo = false,
    DateTime? createdAt,
    this.syncStatus = SyncStatus.pending,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'localPath': localPath,
        'remoteUrl': remoteUrl,
        'isVideo': isVideo,
        'createdAt': createdAt.toIso8601String(),
        'syncStatus': syncStatus.value,
      };

  factory PhotoItem.fromMap(Map<String, dynamic> map) => PhotoItem(
        localPath: map['localPath'] ?? '',
        remoteUrl: map['remoteUrl'],
        isVideo: map['isVideo'] ?? false,
        createdAt: DateTime.tryParse(map['createdAt'] ?? ''),
        syncStatus: SyncStatusX.fromString(map['syncStatus']),
      );
}

/// Cached activity model stored in Hive.
class CachedActivity {
  final String localId;
  final String? remoteId;
  final String userId;
  final ActivityType type;
  final double distance; // meters
  final int duration; // seconds
  final String avgPace;
  final double avgSpeed; // km/h
  final double calories;
  final double elevationGain;
  final List<List<double>> routePoints; // [[lat, lng], ...]
  final DateTime startTime;
  final DateTime endTime;
  final String caption;
  final String title;
  final List<PhotoItem> photos;
  final String visibility;
  final DateTime createdAt;
  final DateTime lastModified;
  final SyncStatus syncStatus;
  final int retryCount;

  CachedActivity({
    required this.localId,
    this.remoteId,
    required this.userId,
    required this.type,
    required this.distance,
    required this.duration,
    required this.avgPace,
    this.avgSpeed = 0,
    this.calories = 0,
    this.elevationGain = 0,
    this.routePoints = const [],
    required this.startTime,
    required this.endTime,
    this.caption = '',
    this.title = '',
    this.photos = const [],
    this.visibility = 'public',
    DateTime? createdAt,
    DateTime? lastModified,
    this.syncStatus = SyncStatus.pending,
    this.retryCount = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastModified = lastModified ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'localId': localId,
        'remoteId': remoteId,
        'userId': userId,
        'type': type.name,
        'distance': distance,
        'duration': duration,
        'avgPace': avgPace,
        'avgSpeed': avgSpeed,
        'calories': calories,
        'elevationGain': elevationGain,
        'routePoints': routePoints,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'caption': caption,
        'title': title,
        'photos': photos.map((p) => p.toMap()).toList(),
        'visibility': visibility,
        'createdAt': createdAt.toIso8601String(),
        'lastModified': lastModified.toIso8601String(),
        'syncStatus': syncStatus.value,
        'retryCount': retryCount,
      };

  factory CachedActivity.fromMap(Map<String, dynamic> map) {
    return CachedActivity(
      localId: map['localId'] ?? '',
      remoteId: map['remoteId'],
      userId: map['userId'] ?? '',
      type: ActivityTypeX.fromString(map['type']),
      distance: (map['distance'] ?? 0).toDouble(),
      duration: map['duration'] ?? 0,
      avgPace: map['avgPace'] ?? '',
      avgSpeed: (map['avgSpeed'] ?? 0).toDouble(),
      calories: (map['calories'] ?? 0).toDouble(),
      elevationGain: (map['elevationGain'] ?? 0).toDouble(),
      routePoints: (map['routePoints'] as List?)
              ?.map((p) => (p as List).map((v) => (v as num).toDouble()).toList())
              .toList() ??
          [],
      startTime: DateTime.tryParse(map['startTime'] ?? '') ?? DateTime.now(),
      endTime: DateTime.tryParse(map['endTime'] ?? '') ?? DateTime.now(),
      caption: map['caption'] ?? '',
      title: map['title'] ?? '',
      photos: (map['photos'] as List?)
              ?.map((p) => PhotoItem.fromMap(Map<String, dynamic>.from(p)))
              .toList() ??
          [],
      visibility: map['visibility'] ?? 'public',
      createdAt: DateTime.tryParse(map['createdAt'] ?? ''),
      lastModified: DateTime.tryParse(map['lastModified'] ?? ''),
      syncStatus: SyncStatusX.fromString(map['syncStatus']),
      retryCount: map['retryCount'] ?? 0,
    );
  }

  CachedActivity copyWith({
    String? caption,
    String? title,
    List<PhotoItem>? photos,
    SyncStatus? syncStatus,
    DateTime? lastModified,
  }) {
    return CachedActivity(
      localId: localId,
      remoteId: remoteId,
      userId: userId,
      type: type,
      distance: distance,
      duration: duration,
      avgPace: avgPace,
      avgSpeed: avgSpeed,
      calories: calories,
      elevationGain: elevationGain,
      routePoints: routePoints,
      startTime: startTime,
      endTime: endTime,
      caption: caption ?? this.caption,
      title: title ?? this.title,
      photos: photos ?? this.photos,
      visibility: visibility,
      createdAt: createdAt,
      lastModified: lastModified ?? DateTime.now(),
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount,
    );
  }
}



