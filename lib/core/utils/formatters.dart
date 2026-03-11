import 'package:intl/intl.dart';

/// Reusable formatting helpers across the app.
class Formatters {
  Formatters._();

  /// e.g. "5.23 km" or "0.85 km"
  static String distanceKm(double meters) {
    final km = meters / 1000;
    return '${km.toStringAsFixed(2)} km';
  }

  /// e.g. "5.2 mi"
  static String distanceMi(double meters) {
    final mi = meters / 1609.344;
    return '${mi.toStringAsFixed(2)} mi';
  }

  /// e.g. "32:05" or "1:02:05"
  static String duration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  /// Strava-style short duration: "32:05" under 1h, "1h 0m" over 1h.
  static String durationTrack(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes.toString().padLeft(2, '0')}:$seconds';
  }

  /// e.g. "5:42 /km"
  static String pace(Duration d, double meters) {
    if (meters <= 0) return '--:--';
    final totalSeconds = d.inSeconds;
    final paceSecondsPerKm = (totalSeconds / (meters / 1000)).round();
    final m = (paceSecondsPerKm ~/ 60).toString();
    final s = (paceSecondsPerKm % 60).toString().padLeft(2, '0');
    return '$m:$s /km';
  }

  /// Returns just the numeric part of pace e.g. "5:42"
  static String paceValue(Duration d, double meters) {
    if (meters <= 0) return '--:--';
    final totalSeconds = d.inSeconds;
    final paceSecondsPerKm = (totalSeconds / (meters / 1000)).round();
    final m = (paceSecondsPerKm ~/ 60).toString();
    final s = (paceSecondsPerKm % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// e.g. "12.4 km/h"
  static String speedKmh(double metersPerSecond) {
    final kmh = metersPerSecond * 3.6;
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  /// e.g. "12.4 km/h"
  static String speed(double meters, Duration d) {
    if (d.inSeconds <= 0) return '0.0 km/h';
    final kmh = (meters / 1000) / (d.inSeconds / 3600);
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  /// e.g. "142 cal"
  static String calories(double cal) => '${cal.round()} cal';

  /// e.g. "Mar 7, 2026"
  static String date(DateTime dt) => DateFormat.yMMMd().format(dt);

  /// e.g. "Mar 7, 2026 at 3:42 PM"
  static String dateTime(DateTime dt) =>
      '${DateFormat.yMMMd().format(dt)} at ${DateFormat.jm().format(dt)}';

  /// e.g. "3:42 PM"
  static String time(DateTime dt) => DateFormat.jm().format(dt);

  /// e.g. "+124 m"
  static String elevation(double meters) => '+${meters.round()} m';

  /// Relative time e.g. "2h ago", "just now"
  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.yMMMd().format(dt);
  }
}

