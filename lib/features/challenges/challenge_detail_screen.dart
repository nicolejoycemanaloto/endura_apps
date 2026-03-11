import 'package:flutter/cupertino.dart';
import 'package:endura/core/theme/app_theme.dart';
import 'package:endura/shared/models/cached_challenge.dart';
import 'package:endura/core/utils/formatters.dart';
import 'package:endura/features/challenges/challenge_repository.dart';

/// Challenge detail screen with progress, description, and join/leave.
class ChallengeDetailScreen extends StatefulWidget {
  final String challengeId;

  const ChallengeDetailScreen({super.key, required this.challengeId});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  String get challengeId => widget.challengeId;

  Future<void> _toggleJoin(CachedChallenge challenge) async {
    if (challenge.joined) {
      await _confirmLeave(challenge);
    } else {
      await ChallengeRepository.join(challengeId);
    }
  }

  Future<void> _confirmLeave(CachedChallenge challenge) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Leave Challenge?'),
        content: Text(
          'Are you sure you want to leave "${challenge.title}"? Your progress will be reset.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ChallengeRepository.leave(challengeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ChallengeRepository.listenable,
      builder: (context, box, _) {
        final c = ChallengeRepository.getById(challengeId);

        if (c == null) {
          return const CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(middle: Text('Challenge')),
            child: Center(child: Text('Challenge not found')),
          );
        }

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: const Text('Challenge'),
            previousPageTitle: 'Challenges',
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge + title
                  Center(
                    child: Column(
                      children: [
                        if (c.badge != null)
                          Text(c.badge!,
                              style: const TextStyle(fontSize: 56)),
                        const SizedBox(height: 12),
                        Text(
                          c.title,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textColor(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.type.label,
                          style: const TextStyle(
                              fontSize: 14, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Progress ring
                  if (c.joined) ...[
                    Center(
                      child: SizedBox(
                        width: 140,
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 140,
                              height: 140,
                              child: CustomPaint(
                                painter: _RingPainter(
                                  progress: c.progressPercent,
                                  color: c.completed
                                      ? AppTheme.success
                                      : AppTheme.primary,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(c.progressPercent * 100).toInt()}%',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textColor(context),
                                  ),
                                ),
                                if (c.completed)
                                  const Text('Complete!',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.success)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        '${c.progress.toStringAsFixed(1)} / ${c.target.toStringAsFixed(0)} ${_unitLabel(c.type)}',
                        style: const TextStyle(
                            fontSize: 15, color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Description
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor(context),
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('About',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColor(context))),
                        const SizedBox(height: 8),
                        Text(c.description,
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dates
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor(context),
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Start',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            Text(Formatters.date(c.startDate),
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textColor(context))),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('End',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            Text(Formatters.date(c.endDate),
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textColor(context))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Join / Leave button
                  Container(
                    width: double.infinity,
                    height: 56,
                    child: CupertinoButton(
                      color: c.completed
                          ? CupertinoColors.systemGrey4
                          : c.joined
                              ? AppTheme.danger
                              : AppTheme.primary,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: c.completed ? null : () => _toggleJoin(c),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (c.completed)
                            const Icon(CupertinoIcons.checkmark_circle_fill,
                                size: 20, color: CupertinoColors.white)
                          else if (c.joined)
                            const Icon(CupertinoIcons.minus_circle_fill,
                                size: 20, color: CupertinoColors.white)
                          else
                            const Icon(CupertinoIcons.plus_circle_fill,
                                size: 20, color: CupertinoColors.white),
                          const SizedBox(width: 8),
                          Text(
                            c.completed
                                ? 'Challenge Complete!'
                                : c.joined
                                    ? 'Leave Challenge'
                                    : 'Join Challenge',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                color: CupertinoColors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _unitLabel(ChallengeType type) {
    switch (type) {
      case ChallengeType.distance:
        return 'km';
      case ChallengeType.time:
        return 'min';
      case ChallengeType.activityCount:
        return 'activities';
      case ChallengeType.streak:
        return 'days';
    }
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 10.0;

    // Background ring
    final bgPaint = Paint()
      ..color = CupertinoColors.systemGrey5
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -3.14159 / 2; // top
    final sweepAngle = 2 * 3.14159 * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}



