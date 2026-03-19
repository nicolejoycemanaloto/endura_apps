import 'package:endura/shared/models/sync_status.dart';

/// Sentinel wrapper that lets [CachedUser.copyWith] distinguish between
/// "not provided" (omit the parameter) and "explicitly set to null".
///
/// Usage:
///   user.copyWith(avatarLocalPath: const OptionalValue(null))  // clears it
///   user.copyWith()                                            // keeps old value
class OptionalValue<T> {
  final T? value;
  const OptionalValue(this.value);
}

/// Cached user profile model stored in Hive.
class CachedUser {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? avatarLocalPath;
  final String bio;
  final String location;
  final String preferredSport;
  final String goals;
  final String profileVisibility;
  final String measurementUnit; // 'metric' or 'imperial'
  final double weightKg; // User weight in kg for calorie calculations
  final DateTime updatedAt;
  final SyncStatus syncStatus;
  final String? remoteId;

  CachedUser({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.avatarLocalPath,
    this.bio = '',
    this.location = '',
    this.preferredSport = 'running',
    this.goals = '',
    this.profileVisibility = 'public',
    this.measurementUnit = 'metric',
    this.weightKg = 70.0, // Default to 70kg
    DateTime? updatedAt,
    this.syncStatus = SyncStatus.pending,
    this.remoteId,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'avatarLocalPath': avatarLocalPath,
        'bio': bio,
        'location': location,
        'preferredSport': preferredSport,
        'goals': goals,
        'profileVisibility': profileVisibility,
        'measurementUnit': measurementUnit,
        'weightKg': weightKg,
        'updatedAt': updatedAt.toIso8601String(),
        'syncStatus': syncStatus.value,
        'remoteId': remoteId,
      };

  factory CachedUser.fromMap(Map<String, dynamic> map) => CachedUser(
        id: map['id'] ?? '',
        displayName: map['displayName'] ?? '',
        avatarUrl: map['avatarUrl'],
        avatarLocalPath: map['avatarLocalPath'],
        bio: map['bio'] ?? '',
        location: map['location'] ?? '',
        preferredSport: map['preferredSport'] ?? 'running',
        goals: map['goals'] ?? '',
        profileVisibility: map['profileVisibility'] ?? 'public',
        measurementUnit: map['measurementUnit'] ?? 'metric',
        weightKg: (map['weightKg'] ?? 70.0).toDouble(),
        updatedAt: DateTime.tryParse(map['updatedAt'] ?? ''),
        syncStatus: SyncStatusX.fromString(map['syncStatus']),
        remoteId: map['remoteId'],
      );

  CachedUser copyWith({
    String? displayName,
    /// Wrap with [OptionalValue] to explicitly clear: `OptionalValue(null)`
    OptionalValue<String>? avatarUrl,
    /// Wrap with [OptionalValue] to explicitly clear: `OptionalValue(null)`
    OptionalValue<String>? avatarLocalPath,
    String? bio,
    String? location,
    String? preferredSport,
    String? goals,
    String? profileVisibility,
    String? measurementUnit,
    double? weightKg,
    SyncStatus? syncStatus,
  }) {
    return CachedUser(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl != null ? avatarUrl.value : this.avatarUrl,
      avatarLocalPath: avatarLocalPath != null ? avatarLocalPath.value : this.avatarLocalPath,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      preferredSport: preferredSport ?? this.preferredSport,
      goals: goals ?? this.goals,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      measurementUnit: measurementUnit ?? this.measurementUnit,
      weightKg: weightKg ?? this.weightKg,
      updatedAt: DateTime.now(),
      syncStatus: syncStatus ?? SyncStatus.pending,
      remoteId: remoteId,
    );
  }
}


