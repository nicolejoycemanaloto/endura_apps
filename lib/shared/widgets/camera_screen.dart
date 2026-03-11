import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:endura/core/theme/app_theme.dart';

/// Full-screen in-app camera using the `camera` plugin.
/// Returns the saved file path on capture, or null on cancel.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isTakingPicture = false;
  bool _isInitialized = false;
  String? _error;
  FlashMode _flashMode = FlashMode.auto;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !(_controller!.value.isInitialized)) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'No cameras found on this device.');
        return;
      }
      await _setupController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      setState(() => _error = 'Camera error: $e');
    }
  }

  Future<void> _setupController(CameraDescription camera) async {
    final prev = _controller;
    final newController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    // Dispose previous before initializing new
    await prev?.dispose();

    try {
      await newController.initialize();
      await newController.setFlashMode(_flashMode);
      if (mounted) {
        setState(() {
          _controller = newController;
          _isInitialized = true;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to initialize camera: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupController(_cameras[_selectedCameraIndex]);
  }

  void _cycleFlash() {
    setState(() {
      switch (_flashMode) {
        case FlashMode.auto:
          _flashMode = FlashMode.always;
          break;
        case FlashMode.always:
          _flashMode = FlashMode.off;
          break;
        default:
          _flashMode = FlashMode.auto;
      }
    });
    _controller?.setFlashMode(_flashMode);
  }

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.auto:
        return CupertinoIcons.bolt_badge_a_fill;
      case FlashMode.always:
        return CupertinoIcons.bolt_fill;
      case FlashMode.off:
        return CupertinoIcons.bolt_slash_fill;
      default:
        return CupertinoIcons.bolt_badge_a_fill;
    }
  }

  String get _flashLabel {
    switch (_flashMode) {
      case FlashMode.auto:
        return 'Auto';
      case FlashMode.always:
        return 'On';
      case FlashMode.off:
        return 'Off';
      default:
        return 'Auto';
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isTakingPicture) {
      return;
    }

    setState(() => _isTakingPicture = true);

    try {
      final XFile photo = await _controller!.takePicture();

      // Save to app directory
      final dir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory('${dir.path}/endura_media');
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }
      final fileName = '${const Uuid().v4()}.jpg';
      final savedPath = '${mediaDir.path}/$fileName';
      await File(photo.path).copy(savedPath);

      if (mounted) {
        // Show preview and confirm
        final confirmed = await Navigator.of(context).push<bool>(
          CupertinoPageRoute(
            builder: (_) => _PhotoPreviewScreen(photoPath: savedPath),
          ),
        );

        if (confirmed == true && mounted) {
          Navigator.of(context).pop(savedPath);
        } else {
          // Delete if not confirmed
          try {
            await File(savedPath).delete();
          } catch (_) {}
          setState(() => _isTakingPicture = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTakingPicture = false);
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Capture Failed'),
            content: Text('$e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_isInitialized && _controller != null)
            Center(
              child: CameraPreview(controller: _controller!),
            )
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: CupertinoColors.white, fontSize: 16),
                ),
              ),
            )
          else
            const Center(
              child: CupertinoActivityIndicator(
                  radius: 16, color: CupertinoColors.white),
            ),

          // Top controls: close, flash
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Close
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: CupertinoColors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.xmark,
                        color: CupertinoColors.white, size: 18),
                  ),
                ),
                const Spacer(),
                // Flash
                GestureDetector(
                  onTap: _cycleFlash,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_flashIcon,
                            color: CupertinoColors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _flashLabel,
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom controls: switch camera, capture, placeholder
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Switch camera
                GestureDetector(
                  onTap: _cameras.length > 1 ? _switchCamera : null,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: CupertinoColors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.switch_camera,
                      color: _cameras.length > 1
                          ? CupertinoColors.white
                          : CupertinoColors.systemGrey,
                      size: 24,
                    ),
                  ),
                ),

                // Capture button
                GestureDetector(
                  onTap: _isTakingPicture ? null : _takePicture,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: CupertinoColors.white,
                        width: 4,
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _isTakingPicture
                            ? CupertinoColors.systemGrey
                            : CupertinoColors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),

                // Spacer for symmetry
                const SizedBox(width: 50, height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays the camera preview, respecting the aspect ratio.
class CameraPreview extends StatelessWidget {
  final CameraController controller;
  const CameraPreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = controller.value.previewSize!;
        // previewSize is in landscape orientation, swap for portrait
        final aspectRatio = previewSize.height / previewSize.width;

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxWidth / aspectRatio,
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxWidth / aspectRatio,
                child: controller.buildPreview(),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Preview screen after taking a photo — use or retake.
class _PhotoPreviewScreen extends StatelessWidget {
  final String photoPath;
  const _PhotoPreviewScreen({required this.photoPath});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo
          Center(
            child: Image.file(
              File(photoPath),
              fit: BoxFit.contain,
            ),
          ),

          // Bottom buttons
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 30,
            left: 24,
            right: 24,
            child: Row(
              children: [
                // Retake
                Expanded(
                  child: CupertinoButton(
                    color: CupertinoColors.systemGrey.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Retake',
                        style: TextStyle(
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                // Use Photo
                Expanded(
                  child: CupertinoButton(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(14),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Use Photo',
                        style: TextStyle(
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


