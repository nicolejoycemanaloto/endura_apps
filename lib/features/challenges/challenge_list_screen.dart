// endura_app\lib\features\challenges\challenge_list_screen.dart

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
    await ChallengeRepository.recalculateStreaks();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return CupertinoPageScaffold(
        child: Center(
          child: CupertinoActivityIndicator(
            radius: 16,
            color: AppTheme.primary,
          ),
        ),
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
                largeTitle: Text(
                  'Challenges',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                border: null,
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingMd,
                  0,
                  AppTheme.spacingMd,
                  100,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),

                    // ── Active challenges ──────────────────────────
                    if (active.isNotEmpty) ...[
                      _SectionHeader(title: 'Active Challenges'),
                      const SizedBox(height: 8),
                      ...active.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ChallengeCard(
                          challenge: c,
                          onTap: () => _openDetail(c),
                        ),
                      )),
                      const SizedBox(height: 24),
                    ],

                    // ── Completed challenges ───────────────────────
                    if (completed.isNotEmpty) ...[
                      _SectionHeader(title: 'Completed'),
                      const SizedBox(height: 8),
                      ...completed.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ChallengeCard(
                          challenge: c,
                          onTap: () => _openDetail(c),
                        ),
                      )),
                      const SizedBox(height: 24),
                    ],

                    // ── Available challenges ───────────────────────
                    if (available.isEmpty && active.isEmpty && completed.isEmpty)
                      _EmptyStateFull()
                    else if (available.isEmpty && (active.isNotEmpty || completed.isNotEmpty))
                      _AllJoinedNotice()
                    else
                      ...available.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ChallengeCard(
                          challenge: c,
                          onTap: () => _openDetail(c),
                        ),
                      )),

                    const SizedBox(height: 20),
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
// Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textColor(context),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.3),
                    AppTheme.primary.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.8],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty States
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyStateFull extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.2),
                    AppTheme.primary.withValues(alpha: 0.0),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.rosette,
                size: 48,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'All challenges joined!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Great work! Keep tracking activities\nto unlock new challenges soon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllJoinedNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.success.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.checkmark_circle_fill,
            size: 28,
            color: AppTheme.success,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'All challenges joined!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Keep crushing your active challenges.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
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

// ─────────────────────────────────────────────────────────────────────────────
// Challenge Card (Redesigned)
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
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
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
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // Subtle gradient background
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            (c.completed
                                ? AppTheme.success
                                : isJoined
                                ? AppTheme.primary
                                : CupertinoColors.systemGrey)
                                .withValues(alpha: 0.03),
                            CupertinoColors.transparent,
                          ],
                          stops: const [0.0, 0.8],
                        ),
                      ),
                    ),
                  ),

                  // Left accent bar
                  Positioned(
                    left: 0,
                    top: 16,
                    bottom: 16,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: c.completed
                              ? [
                            AppTheme.success,
                            AppTheme.success.withValues(alpha: 0.5)
                          ]
                              : isJoined
                              ? [
                            AppTheme.primary,
                            AppTheme.primary.withValues(alpha: 0.5)
                          ]
                              : [
                            CupertinoColors.systemGrey,
                            CupertinoColors.systemGrey2,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header row ──────────────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Badge / Icon
                            if (c.badge != null) ...[
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppTheme.primary.withValues(alpha: 0.1),
                                      AppTheme.primary.withValues(alpha: 0.2),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Center(
                                  child: Text(
                                    c.badge!,
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],

                            // Title + type
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      c.type.label,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Status indicator
                            if (c.completed)
                              _StatusChip(
                                icon: CupertinoIcons.checkmark_circle_fill,
                                label: 'Done',
                                color: AppTheme.success,
                              )
                            else if (isJoined)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(40),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$percent%',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemGrey5
                                      .withValues(alpha: 0.7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  CupertinoIcons.chevron_right,
                                  size: 16,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                          ],
                        ),

                        // ── Progress section (joined only) ───────────────
                        if (isJoined) ...[
                          const SizedBox(height: 20),

                          // Progress label and percentage
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progress',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                '$percent%',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textColor(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Progress bar
                          Stack(
                            children: [
                              Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemGrey5,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeOutCubic,
                                height: 10,
                                width: (MediaQuery.of(context).size.width -
                                    2 * AppTheme.spacingMd -
                                    40) *
                                    c.progressPercent,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.primary, Color(0xFF5AC8FA)],
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Current / target
                          Row(
                            children: [
                              Icon(
                                _iconForType(c.type),
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${c.progress.toStringAsFixed(c.type == ChallengeType.activityCount || c.type == ChallengeType.streak ? 0 : 1)} / ${c.target.toStringAsFixed(0)} ${_unitForType(c.type)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForType(ChallengeType type) {
    switch (type) {
      case ChallengeType.distance:
        return CupertinoIcons.map;
      case ChallengeType.time:
        return CupertinoIcons.clock;
      case ChallengeType.activityCount:
        return CupertinoIcons.flame;
      case ChallengeType.streak:
        return CupertinoIcons.calendar;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small status chip widget
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;

  const _StatusChip({this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 14, color: color),
          if (icon != null) const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unit helper
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