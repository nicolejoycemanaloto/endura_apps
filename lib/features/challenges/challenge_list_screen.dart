import 'package:flutter/cupertino.dart';
import 'package:endura/core/theme/app_theme.dart';
import 'package:endura/shared/models/cached_challenge.dart';
import 'package:endura/features/challenges/challenge_repository.dart';
import 'package:endura/features/challenges/challenge_detail_screen.dart';

/// Challenges tab — list of all challenges with join/progress.
class ChallengeListScreen extends StatefulWidget {
  const ChallengeListScreen({super.key});

  @override
  State<ChallengeListScreen> createState() => _ChallengeListScreenState();
}

class _ChallengeListScreenState extends State<ChallengeListScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await ChallengeRepository.seedDefaults();
    // Recalculate streaks on screen open
    await ChallengeRepository.recalculateStreaks();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator(radius: 16)),
      );
    }

    return CupertinoPageScaffold(
      child: ValueListenableBuilder(
        valueListenable: ChallengeRepository.listenable,
        builder: (context, box, _) {
          final active = ChallengeRepository.getActive();
          final completed = ChallengeRepository.getCompleted();
          final available = ChallengeRepository.getAvailable();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const CupertinoSliverNavigationBar(
                largeTitle: Text('Challenges'),
                border: null,
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingMd, 0,
                  AppTheme.spacingMd, 100,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Active challenges ──────────────────────────
                    if (active.isNotEmpty) ...[
                      Text(
                        'Active Challenges',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...active.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ChallengeCard(
                              challenge: c,
                              onTap: () => _openDetail(c),
                            ),
                          )),
                      const SizedBox(height: 16),
                    ],
                    // ── Completed challenges ───────────────────────
                    if (completed.isNotEmpty) ...[
                      Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...completed.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ChallengeCard(
                              challenge: c,
                              onTap: () => _openDetail(c),
                            ),
                          )),
                      const SizedBox(height: 16),
                    ],
                    // ── Available challenges ───────────────────────
                    if (available.isEmpty && active.isEmpty && completed.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  CupertinoIcons.rosette,
                                  size: 40,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text('All challenges joined!',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary)),
                              const SizedBox(height: 4),
                              const Text('Great work! Keep tracking activities.',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      )
                    else if (available.isEmpty && (active.isNotEmpty || completed.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                CupertinoIcons.checkmark_circle_fill,
                                size: 32,
                                color: AppTheme.success.withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 8),
                              const Text('All challenges joined!',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      )
                    else
                      ...available.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ChallengeCard(
                              challenge: c,
                              onTap: () => _openDetail(c),
                            ),
                          )),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openDetail(CachedChallenge c) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChallengeDetailScreen(challengeId: c.id),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Challenge Card
// ─────────────────────────────────────────────────────────────────────────────

class _ChallengeCard extends StatefulWidget {
  final CachedChallenge challenge;
  final VoidCallback onTap;

  const _ChallengeCard({required this.challenge, required this.onTap});

  @override
  State<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<_ChallengeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _animCtrl.forward();
  void _onTapUp(TapUpDetails _) {
    _animCtrl.reverse();
    widget.onTap();
  }
  void _onTapCancel() => _animCtrl.reverse();

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final isJoined = c.joined && !c.completed;
    final percent = (c.progressPercent * 100).toInt();

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, _) => Transform.scale(
        scale: _scaleAnim.value,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Subtle background tint for joined/completed
                  if (isJoined || c.completed)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              (c.completed ? AppTheme.success : AppTheme.primary)
                                  .withValues(alpha: 0.04),
                              CupertinoColors.transparent,
                            ],
                            stops: const [0.0, 0.7],
                          ),
                        ),
                      ),
                    ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top accent bar
                      Container(
                        height: 5,
                        decoration: BoxDecoration(
                          gradient: c.completed
                              ? const LinearGradient(
                                  colors: [Color(0xFF34C759), Color(0xFF30D158)])
                              : isJoined
                                  ? const LinearGradient(
                                      colors: [AppTheme.primary, Color(0xFF5AC8FA)])
                                  : LinearGradient(colors: [
                                      CupertinoColors.systemGrey4
                                          .withValues(alpha: 0.5),
                                      CupertinoColors.systemGrey3
                                          .withValues(alpha: 0.3),
                                    ]),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Header row ──────────────────────────────
                            Row(
                              children: [
                                // Badge icon
                                if (c.badge != null) ...[
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primarySurface,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primary
                                              .withValues(alpha: 0.15),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(c.badge!,
                                          style:
                                              const TextStyle(fontSize: 26)),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                ],

                                // Title + type pill
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.title,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textColor(context),
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          c.type.label,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.primary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Status chip
                                if (c.completed)
                                  _StatusChip(
                                    icon: CupertinoIcons.checkmark_circle_fill,
                                    label: 'Done',
                                    color: AppTheme.success,
                                  )
                                else if (isJoined)
                                  _StatusChip(
                                    label: '$percent%',
                                    color: AppTheme.primary,
                                    showDot: true,
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemGrey5
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                        CupertinoIcons.chevron_right,
                                        size: 16,
                                        color:
                                            CupertinoColors.systemGrey2),
                                  ),
                              ],
                            ),

                            // ── Progress bar (joined only) ───────────────
                            if (isJoined) ...[
                              const SizedBox(height: 18),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Progress',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textColor(context))),
                                  Text('$percent%',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textColor(context))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  height: 8,
                                  child: LayoutBuilder(
                                    builder: (ctx, constraints) => Stack(
                                      children: [
                                        Container(
                                          width: constraints.maxWidth,
                                          color: CupertinoColors.systemGrey5,
                                        ),
                                        AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 600),
                                          curve: Curves.easeOutCubic,
                                          width: constraints.maxWidth *
                                              c.progressPercent,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                AppTheme.primary,
                                                Color(0xFF5AC8FA)
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${c.progress.toStringAsFixed(c.type == ChallengeType.activityCount || c.type == ChallengeType.streak ? 0 : 1)} / ${c.target.toStringAsFixed(0)} ${_unitForType(c.type)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small status chip widget
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  final bool showDot;

  const _StatusChip({
    this.icon,
    required this.label,
    required this.color,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ] else if (showDot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

String _unitForType(ChallengeType type) {
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

