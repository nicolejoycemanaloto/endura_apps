import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';

/// Centralized location permission and streaming service.
class LocationService {
  LocationService._();

  // ── Max credible speeds per activity type (m/s) ────────────────────────────
  // Anything faster than these values between two GPS fixes is a spike — reject.
  static const double maxSpeedRunning = 6.7;   // ≈ 24 km/h  (sub-elite sprint)
  static const double maxSpeedCycling = 22.2;  // ≈ 80 km/h  (fast road bike)
  static const double maxSpeedWalking = 2.8;   // ≈ 10 km/h  (very brisk walk)
  static const double maxSpeedHiking  = 2.5;   // ≈  9 km/h  (steep trail)
  static const double maxSpeedRiding  = 38.9;  // ≈ 140 km/h (motor / car)

  /// Check current permission status.
  static Future<LocationPermission> checkPermission() =>
      Geolocator.checkPermission();

  /// Request permission from user.
  static Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  /// Returns true if location services are enabled and permission granted.
  static Future<bool> ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Get current position once — highest possible accuracy for a good first fix.
  static Future<Position> getCurrentPosition() =>
      Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          // bestForNavigation uses barometric + GPS fusion on iOS
          accuracy: Platform.isIOS
              ? LocationAccuracy.bestForNavigation
              : LocationAccuracy.best,
        ),
      );

  /// Stream continuous position updates for workout tracking.
  ///
  /// [distanceFilter] = 3 m (was 5 m): OS fires more often, giving the
  /// software-level filters in tracking_screen.dart enough resolution to
  /// compute speed and reject outliers accurately.
  static Stream<Position> getPositionStream({int distanceFilter = 3}) {
    if (Platform.isAndroid) {
      return Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilter,
          forceLocationManager: false,         // prefer Fused Location Provider
          intervalDuration: const Duration(seconds: 1),
        ),
      );
    } else if (Platform.isIOS) {
      return Geolocator.getPositionStream(
        locationSettings: AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: distanceFilter,
          activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
        ),
      );
    } else {
      return Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: distanceFilter,
        ),
      );
    }
  }

  /// Calculate distance in metres between two lat/lng coordinates.
  static double distanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) =>
      Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
}
