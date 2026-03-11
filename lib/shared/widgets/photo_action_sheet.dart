import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:endura/core/media/media_picker_service.dart';
import 'package:endura/shared/widgets/camera_screen.dart';

/// Result from the media action sheet.
class MediaPickResult {
  final String path;
  final bool isVideo;
  const MediaPickResult({required this.path, this.isVideo = false});
}

/// Shows a CupertinoActionSheet for photo selection (image only).
/// Returns [MediaPickResult] with path, or null.
Future<MediaPickResult?> showMediaActionSheet(
  BuildContext context, {
  bool showRemove = false,
  VoidCallback? onRemove,
}) async {
  final choice = await showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: const Text('Add Photo'),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop('camera'),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.camera_fill, size: 20),
              SizedBox(width: 8),
              Text('Take Photo'),
            ],
          ),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop('gallery'),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.photo_fill, size: 20),
              SizedBox(width: 8),
              Text('Choose from Gallery'),
            ],
          ),
        ),
        if (showRemove)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop('remove'),
            child: const Text('Remove'),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(ctx).pop(),
        child: const Text('Cancel'),
      ),
    ),
  );

  if (choice == null) return null;

  if (choice == 'remove') {
    onRemove?.call();
    return null;
  }

  String? path;
  if (choice == 'camera') {
    // Use the in-app camera (camera plugin) on mobile; fallback on desktop
    if (!context.mounted) return null;
    if (Platform.isAndroid || Platform.isIOS) {
      path = await Navigator.of(context, rootNavigator: true).push<String>(
        CupertinoPageRoute(
          fullscreenDialog: true,
          builder: (_) => const CameraScreen(),
        ),
      );
    } else {
      // Desktop fallback — use image_picker camera
      path = await MediaPickerService.pickFromCamera();
    }
  } else if (choice == 'gallery') {
    path = await MediaPickerService.pickFromGallery();
  }

  if (path == null) return null;
  return MediaPickResult(path: path);
}

/// Legacy wrapper — returns just a path (photo only, for profile etc.).
Future<String?> showPhotoActionSheet(
  BuildContext context, {
  bool showRemove = false,
  VoidCallback? onRemove,
}) async {
  final choice = await showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: const Text('Choose Photo'),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop('camera'),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.camera_fill, size: 20),
              SizedBox(width: 8),
              Text('Take Photo'),
            ],
          ),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop('gallery'),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.photo_fill, size: 20),
              SizedBox(width: 8),
              Text('Choose from Gallery'),
            ],
          ),
        ),
        if (showRemove)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop('remove'),
            child: const Text('Remove Photo'),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(ctx).pop(),
        child: const Text('Cancel'),
      ),
    ),
  );

  if (choice == null) return null;
  if (choice == 'remove') {
    onRemove?.call();
    return null;
  }
  if (choice == 'camera') {
    if (!context.mounted) return null;
    if (Platform.isAndroid || Platform.isIOS) {
      return await Navigator.of(context, rootNavigator: true).push<String>(
        CupertinoPageRoute(
          fullscreenDialog: true,
          builder: (_) => const CameraScreen(),
        ),
      );
    } else {
      return await MediaPickerService.pickFromCamera();
    }
  }
  if (choice == 'gallery') return await MediaPickerService.pickFromGallery();
  return null;
}
