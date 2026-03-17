import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:endura/core/utils/formatters.dart';
import 'package:endura/shared/models/cached_activity.dart'; // Add this to see ActivityTypeX
import 'package:endura/features/tracking/application/active_workout_provider.dart';

final workoutNotificationServiceProvider =
    Provider<WorkoutNotificationService>((ref) {
  final service = WorkoutNotificationService(ref);
  return service;
});

class WorkoutNotificationService {
  WorkoutNotificationService(this._ref) {
    _ref.listen<ActiveWorkoutState>(
      activeWorkoutProvider,
      (previous, next) => _handleWorkoutChange(previous, next),
    );
  }

  static const _notificationId = 4101;
  static const _androidChannelId = 'active_workout_channel';
  static const _androidChannelName = 'Active workout';
  static const _androidChannelDescription =
      'Shows live workout progress with quick actions.';

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionsRequested = false;
  bool? _lastActiveState;
  WorkoutStatus? _lastWorkoutStatus;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings(
      notificationCategories: [],
      requestSoundPermission: true,
      requestBadgePermission: false,
      requestAlertPermission: true,
      defaultPresentSound: false,
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(settings);

    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: _androidChannelDescription,
      importance: Importance.max,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> _handleWorkoutChange(
    ActiveWorkoutState? previous,
    ActiveWorkoutState next,
  ) async {
    if (!_initialized) return;

    if (!next.isActive) {
      if (previous?.isActive ?? false) {
        await _plugin.cancel(_notificationId);
      }
      _lastActiveState = false;
      _lastWorkoutStatus = null;
      return;
    }

    await _ensurePermissions();

    final shouldAlert = _shouldAlertForUpdate(next);
    await _showOrUpdate(next, shouldAlert: shouldAlert);

    _lastActiveState = true;
    _lastWorkoutStatus = next.status;
  }

  bool _shouldAlertForUpdate(ActiveWorkoutState state) {
    final isFirstActiveNotification = _lastActiveState != true;
    final statusChanged = _lastWorkoutStatus != null && _lastWorkoutStatus != state.status;

    // Alert only when workout starts or status changes (pause/resume).
    return isFirstActiveNotification || statusChanged;
  }

  Future<void> _ensurePermissions() async {
    if (_permissionsRequested) return;
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

    _permissionsRequested = true;
  }

  Future<void> _showOrUpdate(
    ActiveWorkoutState state, {
    required bool shouldAlert,
  }) async {
    final duration =
        Formatters.durationTrack(Duration(seconds: state.elapsedSeconds));
    final distanceKm = state.distance / 1000;
    final distanceLabel = distanceKm >= 100
        ? distanceKm.toStringAsFixed(1)
        : distanceKm.toStringAsFixed(2);

    final titlePrefix =
        state.status == WorkoutStatus.paused ? 'Paused' : 'Tracking';
    final title = '$titlePrefix ${state.selectedType.label}';
    final body = '$duration • $distanceLabel km';

    final androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.status,
      ticker: 'Workout running',
    );

    final darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: null,
      threadIdentifier: 'active_workout',
      interruptionLevel: InterruptionLevel.timeSensitive,
      presentAlert: shouldAlert,
      presentSound: shouldAlert,
      presentBadge: false,
      sound: shouldAlert ? 'default' : null,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    print('🔔 Showing notification: $title - Status: ${state.status}');
    print('   Category: none (actions removed)');

    await _plugin.show(
      _notificationId,
      title,
      body,
      details,
      payload: 'active_workout',
    );
  }
}
