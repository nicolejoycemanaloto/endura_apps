import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:endura/core/theme/app_theme.dart';
import 'package:endura/core/utils/formatters.dart';
import 'package:endura/shared/models/cached_user.dart';
import 'package:endura/shared/widgets/endura_avatar.dart';
import 'package:endura/features/activity/activity_repository.dart';
import 'package:endura/features/profile/user_repository.dart';
import 'package:endura/features/profile/edit_profile_screen.dart';
import 'package:endura/core/storage/hive_boxes.dart';
import 'package:endura/core/utils/biometric_service.dart';
import 'package:endura/signin.dart';
import 'package:endura/main.dart' show themeNotifier;

/// Profile tab — user info, stats, activity history, and inline settings.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  CachedUser? _user;

  // Settings state (inline)
  bool _biometricsEnabled = false;
  bool _biometricsAvailable = false;
  bool _isFaceId = false;

  // Theme mode: now only 'light' or 'dark' (system removed)
  String _themeMode = 'light';

  bool _loadingSettings = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadSettings();
  }

  void _loadUser() {
    setState(() {
      _user = UserRepository.getProfile();
    });
  }

  Future<void> _loadSettings() async {
    final available = await BiometricService.canAuthenticate();
    final enabled = BiometricService.isEnabled();
    final faceId = await BiometricService.isFaceId();
    final theme = themeNotifier.mode;

    // if old value is 'system', default to 'light'
    final normalizedTheme = (theme == 'dark') ? 'dark' : 'light';

    if (!mounted) return;
    setState(() {
      _biometricsAvailable = available;
      _biometricsEnabled = enabled;
      _isFaceId = faceId;
      _themeMode = normalizedTheme;
      _loadingSettings = false;
    });
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      final authenticated = await BiometricService.authenticate(
        reason: 'Authenticate to enable biometric login',
      );
      if (!authenticated) return;
    }

    await BiometricService.setEnabled(value);
    if (mounted) {
      setState(() => _biometricsEnabled = value);
    }
  }

  void _handleLogout() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Log Out?'),
        content: const Text(
          'You will need to sign in again. Your data will be kept.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Log Out'),
            onPressed: () async {
              Navigator.of(ctx).pop();

              final box = Hive.box(HiveBoxes.database);
              await box.put('loggedIn', false);

              if (!mounted) return;

              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                CupertinoPageRoute(builder: (_) => const SigninPage()),
                    (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {

    return CupertinoPageScaffold(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Profile'),
            border: null,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                await Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => const EditProfileScreen(),
                  ),
                );
                _loadUser();
              },
              child: const Icon(CupertinoIcons.pencil, size: 22),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Avatar + bio ────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      EnduraAvatar(
                        imagePath: _user?.avatarLocalPath,
                        name: _user?.displayName,
                        radius: 44,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _user?.displayName ?? 'User',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                      if (_user != null && _user!.bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _user!.bio,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (_user != null && _user!.location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.location_solid,
                                size: 13, color: AppTheme.textSecondary),
                            const SizedBox(width: 3),
                            Text(
                              _user!.location,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Stats — live via Hive listenable ─────────────
                ValueListenableBuilder(
                  valueListenable: ActivityRepository.listenable,
                  builder: (context, _, __) {
                    final totalActivities = ActivityRepository.getCount();
                    final totalDistance = ActivityRepository.getTotalDistance();
                    final totalDuration = ActivityRepository.getTotalDuration();
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor(context),
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ProfileStat(
                              label: 'Activities', value: '$totalActivities'),
                          _ProfileStat(
                            label: 'Distance',
                            value: (totalDistance / 1000).toStringAsFixed(2),
                            unit: 'km',
                          ),
                          _ProfileStat(
                            label: 'Time',
                            value: Formatters.durationTrack(totalDuration),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // ── Settings label ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'SETTINGS',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                if (_loadingSettings)
                  const Center(child: CupertinoActivityIndicator(radius: 14))
                else ...[
                  // Theme
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor(context),
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _themeMode == 'dark'
                                  ? CupertinoIcons.moon_fill
                                  : CupertinoIcons.sun_max_fill,
                              size: 20,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Theme',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColor(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoSlidingSegmentedControl<String>(
                            groupValue: _themeMode,
                            children: const {
                              'light': Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                child: Text('Light',
                                    style: TextStyle(fontSize: 13)),
                              ),
                              'dark': Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                child: Text('Dark',
                                    style: TextStyle(fontSize: 13)),
                              ),
                            },
                            onValueChanged: (value) async {
                              if (value == null) return;
                              setState(() => _themeMode = value);
                              await themeNotifier.setMode(value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Biometrics
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor(context),
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            _isFaceId
                                ? CupertinoIcons.viewfinder
                                : CupertinoIcons.lock_shield_fill,
                            size: 20,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isFaceId ? 'Face ID Login' : 'Biometric Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textColor(context),
                                  ),
                                ),
                                Text(
                                  _biometricsAvailable
                                      ? _isFaceId
                                          ? 'Use Face ID to sign in'
                                          : 'Use fingerprint or Face ID to sign in'
                                      : 'Not available on this device',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          CupertinoSwitch(
                            value: _biometricsEnabled,
                            activeTrackColor: AppTheme.primary,
                            onChanged: _biometricsAvailable
                                ? _toggleBiometrics
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Log out
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor(context),
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    child: _SettingsAction(
                      icon: CupertinoIcons.square_arrow_right,
                      iconColor: AppTheme.primary,
                      label: 'Log Out',
                      onTap: _handleLogout,
                    ),
                  ),
                  const SizedBox(height: 18),

                  Center(
                    child: Column(
                      children: [
                        Text('Endura v1.0.0',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          'Local-first fitness tracking',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;

  const _ProfileStat({required this.label, required this.value, this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textColor(context),
                height: 1.0,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  unit!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}


class _SettingsAction extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _SettingsAction({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor(context),
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: CupertinoColors.systemGrey3,
            ),
          ],
        ),
      ),
    );
  }
}

