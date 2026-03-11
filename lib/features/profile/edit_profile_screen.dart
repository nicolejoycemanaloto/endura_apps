import 'package:flutter/cupertino.dart';
import 'package:endura/core/theme/app_theme.dart';
import 'package:endura/shared/models/cached_user.dart';
import 'package:endura/shared/widgets/endura_avatar.dart';
import 'package:endura/shared/widgets/photo_action_sheet.dart';
import 'package:endura/features/profile/user_repository.dart';

/// Edit profile screen with photo, name, bio, and preferences.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _goalsCtrl;
  String? _avatarPath;
  bool _avatarRemoved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = UserRepository.getProfile();
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
    _bioCtrl = TextEditingController(text: user?.bio ?? '');
    _locationCtrl = TextEditingController(text: user?.location ?? '');
    _goalsCtrl = TextEditingController(text: user?.goals ?? '');
    _avatarPath = user?.avatarLocalPath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    _goalsCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final hasPhoto = _avatarPath != null && _avatarPath!.isNotEmpty;
    final path = await showPhotoActionSheet(
      context,
      showRemove: hasPhoto,
      onRemove: () => setState(() {
        _avatarPath = null;
        _avatarRemoved = true;
      }),
    );
    if (path != null && mounted) {
      setState(() {
        _avatarPath = path;
        _avatarRemoved = false;
      });
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final existing = UserRepository.getProfile();
    final user = (existing ?? CachedUser(id: 'local', displayName: ''))
        .copyWith(
      displayName: _nameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      goals: _goalsCtrl.text.trim(),
      avatarLocalPath: _avatarRemoved
          ? const OptionalValue(null)
          : (_avatarPath != null ? OptionalValue(_avatarPath) : null),
    );

    await UserRepository.saveProfile(user);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Edit Profile'),
        previousPageTitle: 'Profile',
        trailing: _saving
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _save,
                child: const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Avatar
              GestureDetector(
                onTap: _changePhoto,
                child: Stack(
                  children: [
                    EnduraAvatar(
                      imagePath: _avatarPath,
                      name: _nameCtrl.text,
                      radius: 48,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: CupertinoColors.white, width: 2),
                        ),
                        child: const Icon(CupertinoIcons.camera_fill,
                            size: 14, color: CupertinoColors.white),
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.only(top: 6),
                onPressed: _changePhoto,
                child: const Text('Change Photo',
                    style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 16),

              // Fields
              _FormField(
                controller: _nameCtrl,
                label: 'Display Name',
                placeholder: 'Enter your name',
              ),
              const SizedBox(height: 12),
              _FormField(
                controller: _bioCtrl,
                label: 'Bio',
                placeholder: 'Tell us a little about yourself…',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _FormField(
                controller: _locationCtrl,
                label: 'Location',
                placeholder: 'City, Country',
              ),
              const SizedBox(height: 12),
              _FormField(
                controller: _goalsCtrl,
                label: 'Goals',
                placeholder: 'e.g. Run a 5K, cycle 100 km a week…',
                maxLines: 2,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? placeholder;
  final int maxLines;

  const _FormField({
    required this.controller,
    required this.label,
    this.placeholder,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary)),
        ),
        CupertinoTextField(
          controller: controller,
          maxLines: maxLines,
          placeholder: placeholder,
          placeholderStyle: const TextStyle(
            fontSize: 15,
            color: CupertinoColors.placeholderText,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
        ),
      ],
    );
  }
}




