import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:endura/core/theme/app_theme.dart';
import 'package:endura/core/utils/formatters.dart';
import 'package:endura/shared/models/cached_activity.dart';
import 'package:endura/shared/widgets/camera_screen.dart';
import 'package:endura/shared/widgets/photo_action_sheet.dart';
import 'package:endura/shared/widgets/polyline_preview.dart';
import 'package:endura/features/profile/user_repository.dart';
import 'package:endura/features/feed/feed_repository.dart';
import 'package:endura/features/challenges/challenge_repository.dart';
import 'package:endura/features/activity/activity_repository.dart';

/// Strava-inspired post-workout summary screen.
class SummaryScreen extends StatefulWidget {
  final CachedActivity activity;
  const SummaryScreen({super.key, required this.activity});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  final List<PhotoItem> _photos = [];
  final PageController _pageController = PageController();
  bool _saving = false;
  int _currentPreviewIndex = 0;

  List<LatLng> get _routePoints => widget.activity.routePoints
      .map((p) => LatLng(p[0], p[1]))
      .toList();

  CachedActivity get _act => widget.activity;

  @override
  void initState() {
    super.initState();
    _titleController.text = _defaultTitle();
  }

  String _defaultTitle() {
    final hour = _act.startTime.hour;
    final period = hour < 12
        ? 'Morning'
        : hour < 17
            ? 'Afternoon'
            : 'Evening';
    return '$period ${_act.type.label}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────

  Future<void> _addPhoto() async {
    final result = await showMediaActionSheet(context);
    if (result != null && mounted) {
      setState(() => _photos.add(PhotoItem(localPath: result.path)));
    }
  }

  /// Launch the in-app camera directly (uses camera plugin).
  Future<void> _openCamera() async {
    String? path;
    if (Platform.isAndroid || Platform.isIOS) {
      path = await Navigator.of(context, rootNavigator: true).push<String>(
        CupertinoPageRoute(
          fullscreenDialog: true,
          builder: (_) => const CameraScreen(),
        ),
      );
    } else {
      // Desktop fallback
      final result = await showMediaActionSheet(context);
      if (result != null) path = result.path;
    }
    if (path != null && mounted) {
      setState(() => _photos.add(PhotoItem(localPath: path!)));
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
      // If we were viewing this photo or a later one, go back to transparent
      if (_currentPreviewIndex > 0 && _currentPreviewIndex >= index + 1) {
        _currentPreviewIndex = 0;
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = UserRepository.getProfile();
      final userId = user?.id ?? '';

      final toSave = CachedActivity(
        localId: _act.localId,
        userId: userId,
        type: _act.type,
        distance: _act.distance,
        duration: _act.duration,
        avgPace: _act.avgPace,
        avgSpeed: _act.avgSpeed,
        calories: _act.calories,
        elevationGain: _act.elevationGain,
        routePoints: _act.routePoints,
        startTime: _act.startTime,
        endTime: _act.endTime,
        caption: _captionController.text.trim(),
        title: _titleController.text.trim(),
        photos: _photos,
      );

      await ActivityRepository.save(toSave);
      if (user != null) {
        await FeedRepository.createFromActivity(toSave, user);
      }
      await ChallengeRepository.updateProgressFromActivity(toSave);

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showError('Could not save activity: $e');
      }
    }
  }

  void _discard() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Discard Workout?'),
        content: const Text('This workout will not be saved.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Discard'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }

  void _openShareScreen() {
    // Get the current photo based on preview index
    PhotoItem? currentPhoto;
    if (_currentPreviewIndex > 0 && _currentPreviewIndex - 1 < _photos.length) {
      currentPhoto = _photos[_currentPreviewIndex - 1];
    }

    Navigator.of(context).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ShareActivityScreen(
          activity: _act,
          routePoints: _routePoints,
          coverPhoto: currentPhoto,
        ),
      ),
    );
  }

  void _showError(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dur = Duration(seconds: _act.duration);
    final isCycling = _act.type == ActivityType.cycling || _act.type == ActivityType.riding;

    // Pace / speed split into value + unit
    final String paceVal;
    final String paceUnit;
    if (isCycling) {
      paceVal = _act.avgSpeed.toStringAsFixed(1);
      paceUnit = 'km/h';
    } else {
      final raw = _act.avgPace.isNotEmpty
          ? _act.avgPace
          : Formatters.pace(dur, _act.distance);
      // raw is "6:37 /km" — split at space
      final parts = raw.split(' ');
      paceVal = parts.first;
      paceUnit = parts.length > 1 ? parts.last : '';
    }
    final paceLabel = isCycling ? 'Avg Speed' : 'Avg Pace';

    // Distance split
    final distKm = (_act.distance / 1000).toStringAsFixed(2);

    // Time — Strava style
    final timeStr = Formatters.durationTrack(dur);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Save Activity'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _discard,
          child: const Text('Discard',
              style: TextStyle(color: AppTheme.danger, fontSize: 15)),
        ),
        trailing: _saving
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _save,
                child: const Text('Save',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Title field (editable, Strava-style) ────────
              CupertinoTextField(
                controller: _titleController,
                placeholder: 'Name your activity',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textColor(context),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(),
              ),

              // Activity type + date subtitle
              Row(
                children: [
                  Text(
                    '${_act.type.icon} ${_act.type.label}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '· ${Formatters.dateTime(_act.startTime)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── 2. Swipeable share card preview ───────────────
              // Shows transparent view first, then uploaded images with stats
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1C1C1E),
                  ),
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() => _currentPreviewIndex = index);
                      },
                      itemCount: 1 + _photos.length, // transparent + photos
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // First page: Transparent view
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              // Checkerboard background to show transparency
                              CustomPaint(
                                painter: _CheckerboardPainter(),
                              ),
                              // The transparent overlay content
                              _TransparentOverlay(
                                activity: _act,
                                routePoints: _routePoints,
                              ),
                            ],
                          );
                        } else {
                          // Photo pages: Image background with stats overlay
                          final photoIndex = index - 1;
                          if (photoIndex < _photos.length) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                // Photo background
                                Image.file(
                                  File(_photos[photoIndex].localPath),
                                  fit: BoxFit.cover,
                                ),
                                // Stats overlay
                                _TransparentOverlay(
                                  activity: _act,
                                  routePoints: _routePoints,
                                ),
                              ],
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Label and page indicators
              Column(
                children: [
                  // Current view label
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: CupertinoColors.systemGrey3,
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _currentPreviewIndex == 0
                          ? 'TRANSPARENT'
                          : 'PHOTO ${_currentPreviewIndex}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.systemGrey,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  // Page indicators if there are multiple views
                  if (_photos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        1 + _photos.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == _currentPreviewIndex
                                ? AppTheme.primary
                                : CupertinoColors.systemGrey3,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Swipe hint if there are photos
                  if (_photos.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Swipe to view with photos',
                      style: TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.systemGrey.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // ── 3. Stats grid ──────────────────────────────────
              _StatsGrid(
                children: [
                  _StatCell(
                      label: 'Distance',
                      value: distKm,
                      unit: 'km',
                      large: true),
                  _StatCell(
                      label: 'Time',
                      value: timeStr,
                      large: true),
                  _StatCell(
                      label: paceLabel,
                      value: paceVal,
                      unit: paceUnit),
                  _StatCell(
                      label: 'Calories',
                      value: _act.calories.round().toString(),
                      unit: 'cal'),
                  if (_act.elevationGain > 0)
                    _StatCell(
                        label: 'Elevation',
                        value: '+${_act.elevationGain.round()}',
                        unit: 'm'),
                  _StatCell(
                    label: isCycling ? 'Avg Pace' : 'Avg Speed',
                    value: isCycling
                        ? (() {
                            final raw = _act.avgPace.isNotEmpty
                                ? _act.avgPace
                                : Formatters.pace(dur, _act.distance);
                            return raw.split(' ').first;
                          })()
                        : _act.avgSpeed.toStringAsFixed(1),
                    unit: isCycling ? '/km' : 'km/h',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── 4. Caption ─────────────────────────────────────
              Text(
                'How was your activity?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor(context),
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _captionController,
                placeholder: 'Share how it went…',
                maxLines: 3,
                minLines: 2,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CupertinoDynamicColor.resolve(
                      CupertinoColors.systemGrey6, context),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 20),

              // ── 5. Photos ──────────────────────────────────────
              Row(
                children: [
                  Text(
                    'Photos',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _openCamera,
                    child: const Row(
                      children: [
                        Icon(CupertinoIcons.camera_fill,
                            size: 16, color: AppTheme.primary),
                        SizedBox(width: 4),
                        Text('Camera',
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: _addPhoto,
                    child: const Row(
                      children: [
                        Icon(CupertinoIcons.photo_fill,
                            size: 16, color: AppTheme.primary),
                        SizedBox(width: 4),
                        Text('Gallery',
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_photos.isEmpty)
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _openCamera,
                        child: Container(
                          height: 90,
                          decoration: BoxDecoration(
                            color: CupertinoDynamicColor.resolve(
                                CupertinoColors.systemGrey6, context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.primary
                                    .withValues(alpha: 0.2)),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.camera_fill,
                                  size: 26, color: AppTheme.primary),
                              SizedBox(height: 6),
                              Text('Take Photo',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _addPhoto,
                        child: Container(
                          height: 90,
                          decoration: BoxDecoration(
                            color: CupertinoDynamicColor.resolve(
                                CupertinoColors.systemGrey6, context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: CupertinoColors.systemGrey4
                                    .withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.photo_fill,
                                  size: 26,
                                  color: AppTheme.textSecondary),
                              const SizedBox(height: 6),
                              Text('Gallery',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length + 1,
                    separatorBuilder: (_, i) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      if (i == _photos.length) {
                        return GestureDetector(
                          onTap: _addPhoto,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: CupertinoDynamicColor.resolve(
                                  CupertinoColors.systemGrey6, context),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(CupertinoIcons.plus,
                                color: AppTheme.primary, size: 28),
                          ),
                        );
                      }
                      return _PhotoTile(
                        path: _photos[i].localPath,
                        onRemove: () => _removePhoto(i),
                        onTap: () {
                          final targetPage = i + 1; // +1 because transparent is page 0
                          _pageController.animateToPage(
                            targetPage,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),

              // ── 6. Share button → opens share screen ───────────
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: _openShareScreen,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.share,
                          size: 18, color: CupertinoColors.white),
                      SizedBox(width: 8),
                      Text('Share with Friends',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: CupertinoColors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TRANSPARENT OVERLAY — the actual sticker content (no background)
// Stats + route polyline + branding, all in white
// ═══════════════════════════════════════════════════════════════════

class _TransparentOverlay extends StatelessWidget {
  final CachedActivity activity;
  final List<LatLng> routePoints;

  const _TransparentOverlay({
    required this.activity,
    required this.routePoints,
  });

  @override
  Widget build(BuildContext context) {
    final hasRoute = routePoints.length >= 2;
    final dur = Duration(seconds: activity.duration);
    final isCycling = activity.type == ActivityType.cycling || activity.type == ActivityType.riding;

    final String paceVal;
    final String paceUnit;
    if (isCycling) {
      paceVal = activity.avgSpeed.toStringAsFixed(1);
      paceUnit = 'km/h';
    } else {
      paceVal = Formatters.paceValue(dur, activity.distance);
      paceUnit = '/km';
    }
    final paceLabel = isCycling ? 'Speed' : 'Pace';

    final distKm = (activity.distance / 1000).toStringAsFixed(2);
    final timeStr = Formatters.durationTrack(dur);

    // Route line color — matches app's grape purple theme
    const routeColor = Color(0xFF6F2DA8); // AppTheme.primary

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),

          // Distance
          _OverlayStat(label: 'Distance',
              value: distKm, unit: 'km', fontSize: 40),
          const SizedBox(height: 20),

          // Pace / Speed
          _OverlayStat(label: paceLabel, value: paceVal, unit: paceUnit, fontSize: 32),
          const SizedBox(height: 20),

          // Time
          _OverlayStat(
              label: 'Time',
              value: timeStr,
              fontSize: 32),

          if (activity.elevationGain > 0) ...[
            const SizedBox(height: 20),
            _OverlayStat(
                label: 'Elev Gain',
                value: '+${activity.elevationGain.round()}',
                unit: 'm',
                fontSize: 32),
          ],

          const Spacer(flex: 1),

          // Route polyline
          if (hasRoute)
            SizedBox(
              height: 120,
              width: double.infinity,
              child: PolylineOnlyPreview(
                routePoints: routePoints,
                backgroundColor: CupertinoColors.transparent,
                lineColor: routeColor,
                lineWidth: 5,
                showEndpoints: true,
                showGlow: false,
              ),
            )
          else
            SizedBox(
              height: 60,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.location_slash,
                        size: 18,
                        color: CupertinoColors.white.withValues(alpha: 0.3)),
                    const SizedBox(width: 8),
                    Text(
                      'No route recorded',
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (hasRoute) const SizedBox(height: 20),

          // Branding
          Text(
            'ENDURA',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: CupertinoColors.white.withValues(alpha: 0.85),
              letterSpacing: 6,
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

class _OverlayStat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final double fontSize;

  const _OverlayStat({
    required this.label,
    required this.value,
    this.unit,
    this.fontSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: CupertinoColors.white.withValues(alpha: 0.7),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  color: CupertinoColors.white,
                  height: 1.0,
                  letterSpacing: -1,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: EdgeInsets.only(bottom: fontSize * 0.08),
                  child: Text(
                    unit!,
                    style: TextStyle(
                      fontSize: fontSize * 0.4,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CHECKERBOARD PAINTER — shows transparency like Photoshop/Strava
// ═══════════════════════════════════════════════════════════════════

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 16.0;
    final darkPaint = Paint()..color = const Color(0xFF3A3A3C);
    final lightPaint = Paint()..color = const Color(0xFF2C2C2E);

    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        final isEven =
            ((x / cellSize).floor() + (y / cellSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          isEven ? darkPaint : lightPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════
// SHARE ACTIVITY SCREEN — Strava-style full-screen share modal
// ═══════════════════════════════════════════════════════════════════

class _ShareActivityScreen extends StatefulWidget {
  final CachedActivity activity;
  final List<LatLng> routePoints;
  final PhotoItem? coverPhoto;

  const _ShareActivityScreen({
    required this.activity,
    required this.routePoints,
    this.coverPhoto,
  });

  @override
  State<_ShareActivityScreen> createState() => _ShareActivityScreenState();
}

class _ShareActivityScreenState extends State<_ShareActivityScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _showWithPhoto = false;

  bool get _hasCover =>
      widget.coverPhoto != null &&
      File(widget.coverPhoto!.localPath).existsSync();

  Future<void> _shareImage() async {
    try {
      // Capture the full preview (background + overlay composite)
      final Uint8List? imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 80),
        pixelRatio: 3.0,
      );

      if (imageBytes == null) {
        _shareText();
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/endura_share.png');
      await file.writeAsBytes(imageBytes);

      await SharePlus.instance.share(
        ShareParams(
          text: _shareString(),
          files: [XFile(file.path)],
        ),
      );
    } catch (e) {
      _shareText();
    }
  }

  void _shareText() {
    SharePlus.instance.share(ShareParams(text: _shareString()));
  }

  String _shareString() {
    final a = widget.activity;
    final pace = (a.type == ActivityType.cycling || a.type == ActivityType.riding)
        ? '🚴 ${a.avgSpeed.toStringAsFixed(1)} km/h'
        : '🏃 ${a.avgPace.isNotEmpty ? a.avgPace : Formatters.pace(Duration(seconds: a.duration), a.distance)}';
    return '${a.type.icon} ${a.type.label}\n'
        '📏 ${Formatters.distanceKm(a.distance)}\n'
        '⏱ ${Formatters.duration(Duration(seconds: a.duration))}\n'
        '$pace\n'
        '\nTracked with Endura 🏔️';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFF000000),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close',
              style: TextStyle(color: CupertinoColors.white, fontSize: 16)),
        ),
        middle: const Text('Share Activity',
            style: TextStyle(color: CupertinoColors.white)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Preview card (Screenshot wraps everything) ────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    // Screenshot wraps the FULL stack so "with photo" mode
                    // captures the composite (photo + stats overlay)
                    child: Screenshot(
                      controller: _screenshotController,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background: checkerboard or photo
                          if (_showWithPhoto && _hasCover)
                            Image.file(
                              File(widget.coverPhoto!.localPath),
                              fit: BoxFit.cover,
                            )
                          else
                            CustomPaint(painter: _CheckerboardPainter()),

                          // Stats + polyline overlay
                          _TransparentOverlay(
                            activity: widget.activity,
                            routePoints: widget.routePoints,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Toggle: Transparent / With Photo ─────────────────
            if (_hasCover)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showWithPhoto = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_showWithPhoto
                                ? CupertinoColors.white.withValues(alpha: 0.15)
                                : CupertinoColors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: !_showWithPhoto
                                ? Border.all(
                                    color: CupertinoColors.white
                                        .withValues(alpha: 0.3))
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Transparent',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: !_showWithPhoto
                                    ? CupertinoColors.white
                                    : CupertinoColors.white
                                        .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showWithPhoto = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _showWithPhoto
                                ? CupertinoColors.white.withValues(alpha: 0.15)
                                : CupertinoColors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: _showWithPhoto
                                ? Border.all(
                                    color: CupertinoColors.white
                                        .withValues(alpha: 0.3))
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'With Photo',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _showWithPhoto
                                    ? CupertinoColors.white
                                    : CupertinoColors.white
                                        .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // ── Share button ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: _shareImage,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.share,
                          size: 18, color: CupertinoColors.white),
                      SizedBox(width: 8),
                      Text('Share',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: CupertinoColors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// STATS GRID
// ═══════════════════════════════════════════════════════════════════

class _StatsGrid extends StatelessWidget {
  final List<_StatCell> children;
  const _StatsGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? CupertinoColors.systemGrey.withValues(alpha: 0.15)
              : CupertinoColors.systemGrey4.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i += 2) ...[
            if (i > 0)
              Container(
                height: 0.5,
                color: isDark
                    ? CupertinoColors.systemGrey.withValues(alpha: 0.2)
                    : CupertinoColors.systemGrey4.withValues(alpha: 0.4),
              ),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(child: children[i]),
                  Container(
                    width: 0.5,
                    color: isDark
                        ? CupertinoColors.systemGrey.withValues(alpha: 0.2)
                        : CupertinoColors.systemGrey4
                            .withValues(alpha: 0.4),
                  ),
                  Expanded(
                    child: i + 1 < children.length
                        ? children[i + 1]
                        : const SizedBox(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final bool large;
  const _StatCell({
    required this.label,
    required this.value,
    this.unit,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: large ? 26 : 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textColor(context),
                    letterSpacing: -0.3,
                    height: 1.0,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 3),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      unit!,
                      style: TextStyle(
                        fontSize: large ? 13 : 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PHOTO TILE
// ═══════════════════════════════════════════════════════════════════

class _PhotoTile extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;
  final VoidCallback? onTap;
  const _PhotoTile({required this.path, required this.onRemove, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 100,
              height: 100,
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, e, s) => Container(
                  color: CupertinoColors.systemGrey5,
                  child: const Icon(CupertinoIcons.photo,
                      color: CupertinoColors.systemGrey3),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xCC000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.xmark,
                    size: 11, color: CupertinoColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

