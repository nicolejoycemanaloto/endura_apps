import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Centralized media picker service using image_picker.
class MediaPickerService {
  MediaPickerService._();

  static final _picker = ImagePicker();
  static const _uuid = Uuid();

  /// Pick image from camera. Returns saved file path or null.
  static Future<String?> pickFromCamera({int imageQuality = 85}) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: imageQuality,
    );
    if (image == null) return null;
    return _saveToAppDir(image);
  }

  /// Pick image from gallery. Returns saved file path or null.
  static Future<String?> pickFromGallery({int imageQuality = 85}) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: imageQuality,
    );
    if (image == null) return null;
    return _saveToAppDir(image);
  }

  /// Pick a short video from camera (max 10 seconds).
  static Future<String?> pickVideoFromCamera({
    Duration maxDuration = const Duration(seconds: 10),
  }) async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: maxDuration,
    );
    if (video == null) return null;
    return _saveToAppDir(video);
  }

  /// Pick a video from gallery (max 10 seconds).
  static Future<String?> pickVideoFromGallery({
    Duration maxDuration = const Duration(seconds: 10),
  }) async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: maxDuration,
    );
    if (video == null) return null;
    return _saveToAppDir(video);
  }

  /// Pick multiple images from gallery.
  static Future<List<String>> pickMultipleFromGallery({
    int imageQuality = 85,
  }) async {
    final List<XFile> images = await _picker.pickMultiImage(
      imageQuality: imageQuality,
    );
    final paths = <String>[];
    for (final img in images) {
      final saved = await _saveToAppDir(img);
      if (saved != null) paths.add(saved);
    }
    return paths;
  }

  /// Check if a file path is a video.
  static bool isVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.3gp') ||
        lower.endsWith('.webm');
  }

  /// Save picked file to app documents with UUID filename.
  static Future<String?> _saveToAppDir(XFile file) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = file.path.split('.').last;
      final fileName = '${_uuid.v4()}.$ext';
      final savedPath = '${dir.path}/endura_media/$fileName';

      final mediaDir = Directory('${dir.path}/endura_media');
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      await File(file.path).copy(savedPath);
      return savedPath;
    } catch (e) {
      debugPrint('❌ Error saving media file: $e');
      return null;
    }
  }

  /// Delete a media file by path.
  static Future<void> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('❌ Error deleting media file: $e');
    }
  }
}


