import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:endura/core/storage/hive_boxes.dart';

/// Centralized biometric authentication service.
/// Uses fingerprint on Android, Face ID / Touch ID on iOS,
/// and Windows Hello (PIN / face / fingerprint) on Windows.
class BiometricService {
  BiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();
  static const String _biometricKey = 'biometrics_enabled';

  /// Check if the device supports biometrics / Windows Hello.
  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('❌ Error checking device support: $e');
      return false;
    }
  }

  /// Check if biometrics are enrolled on the device.
  /// On Windows, getAvailableBiometrics() always returns [] even when
  /// Windows Hello is set up — so we fall back to isDeviceSupported().
  static Future<bool> canAuthenticate() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return false;
      if (Platform.isWindows) return true; // Windows Hello — trust isDeviceSupported
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking biometric availability: $e');
      return false;
    }
  }

  /// Get available biometric types (fingerprint, face, iris).
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('❌ Error getting biometric types: $e');
      return [];
    }
  }

  /// Authenticate using biometrics / Windows Hello.
  /// [reason] is the message shown in the system prompt.
  static Future<bool> authenticate({
    String reason = 'Authenticate to continue',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          // On Windows, biometricOnly:true blocks PIN-based Windows Hello.
          // Allow PIN fallback on Windows so it actually works.
          biometricOnly: !Platform.isWindows,
        ),
      );
    } catch (e) {
      debugPrint('❌ Biometric authentication error: $e');
      return false;
    }
  }

  /// Check if the user has enabled biometric login in settings.
  static bool isEnabled() {
    try {
      final box = Hive.box(HiveBoxes.database);
      return box.get(_biometricKey, defaultValue: false) == true;
    } catch (e) {
      debugPrint('❌ Error reading biometric setting: $e');
      return false;
    }
  }

  /// Enable or disable biometric login.
  static Future<void> setEnabled(bool enabled) async {
    try {
      final box = Hive.box(HiveBoxes.database);
      await box.put(_biometricKey, enabled);
    } catch (e) {
      debugPrint('❌ Error saving biometric setting: $e');
    }
  }

  /// Returns true if the device primarily uses Face ID (not fingerprint).
  /// On Windows always returns false (shows generic Windows Hello icon).
  static Future<bool> isFaceId() async {
    if (Platform.isWindows) return false;
    try {
      final types = await _auth.getAvailableBiometrics();
      return types.contains(BiometricType.face);
    } catch (e) {
      debugPrint('❌ Error checking Face ID: $e');
      return false;
    }
  }
}
