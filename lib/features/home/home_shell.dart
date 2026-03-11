import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:endura/core/storage/hive_boxes.dart';
import 'package:endura/core/theme/app_theme.dart';
import 'package:endura/features/profile/user_repository.dart';
import 'package:endura/features/home/feed_screen.dart';
import 'package:endura/features/tracking/tracking_screen.dart';
import 'package:endura/features/explore/explore_screen.dart';
import 'package:endura/features/challenges/challenge_list_screen.dart';
import 'package:endura/features/profile/profile_screen.dart';

/// Main bottom tab navigation shell — 5 tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  String? _avatarLocalPath;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    // Listen for any changes to the user box so the avatar updates live.
    Hive.box<Map>(HiveBoxes.user).listenable().addListener(_onUserBoxChanged);
  }

  @override
  void dispose() {
    Hive.box<Map>(HiveBoxes.user).listenable().removeListener(_onUserBoxChanged);
    super.dispose();
  }

  void _onUserBoxChanged() => _loadAvatar();

  void _loadAvatar() {
    final profile = UserRepository.getProfile();
    final path = profile?.avatarLocalPath;
    if (mounted) {
      setState(() => _avatarLocalPath = (path != null && path.isNotEmpty) ? path : null);
    }
  }

  /// Builds the profile tab icon — circular avatar when a local image exists,
  /// or falls back to the standard person icon.
  Widget _buildProfileIcon({required bool active}) {
    final color = active ? AppTheme.primary : CupertinoColors.inactiveGray;

    if (_avatarLocalPath != null) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: active
                ? AppTheme.primary
                : CupertinoColors.inactiveGray,
            width: active ? 2.0 : 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.file(
          File(_avatarLocalPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            CupertinoIcons.person_crop_circle_fill,
            size: 26,
            color: color,
          ),
        ),
      );
    }

    return Icon(
      CupertinoIcons.person_crop_circle_fill,
      size: 26,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        activeColor: AppTheme.primary,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house_fill),
            label: 'Activities',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.location_fill),
            label: 'Track',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.map_fill),
            label: 'Explore',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.flag_fill),
            label: 'Challenges',
          ),
          BottomNavigationBarItem(
            icon: _buildProfileIcon(active: false),
            activeIcon: _buildProfileIcon(active: true),
            label: 'Profile',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) {
            switch (index) {
              case 0:
                return const FeedScreen();
              case 1:
                return const TrackingScreen();
              case 2:
                return const ExploreScreen();
              case 3:
                return const ChallengeListScreen();
              case 4:
                return const ProfileScreen();
              default:
                return const FeedScreen();
            }
          },
        );
      },
    );
  }
}
