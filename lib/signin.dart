import 'dart:convert';
import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'constants.dart';
import 'core/storage/hive_boxes.dart';
import 'core/storage/hive_service.dart';
import 'core/utils/biometric_service.dart';
import 'features/home/home_shell.dart';
import 'features/profile/user_repository.dart';
import 'signup.dart';

class SigninPage extends StatefulWidget {
  const SigninPage({super.key});

  @override
  State<SigninPage> createState() => _SigninPageState();
}

class _SigninPageState extends State<SigninPage> {
  final box = Hive.box(HiveBoxes.database);
  bool hidePassword = true;
  bool _biometricsAvailable = false;
  bool _isFaceId = false;
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final enabled = BiometricService.isEnabled();
    final canAuth = await BiometricService.canAuthenticate();
    final faceId = await BiometricService.isFaceId();
    if (mounted) {
      setState(() {
        _biometricsAvailable = enabled && canAuth;
        _isFaceId = faceId;
      });
    }
  }

  Future<void> _handleBiometricLogin() async {
    final authenticated = await BiometricService.authenticate(
      reason: 'Sign in to Endura',
    );
    if (!authenticated || !mounted) return;

    // Biometric passed — log in directly
    box.put('loggedIn', true);

    final storedUsername = box.get('username');
    if (UserRepository.getProfile() == null && storedUsername != null) {
      await UserRepository.createFromAuth(storedUsername);
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const HomeShell()),
          (route) => false,
    );
  }

  void _showError(String message) {
    showLightDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Oops'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(ctx).pop(),
          )
        ],
      ),
    );
  }

  Future<void> _handleSignin() async {
    final username = _username.text.trim();
    final password = _password.text.trim();

    // Validation
    if (username.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }
    if (username.length > 50 || password.length > 100) {
      _showError('Invalid input length.');
      return;
    }

    final storedUsername = box.get('username');
    final storedPassword = box.get('password');

    if (storedUsername == null || storedPassword == null) {
      _showError('No account found. Please sign up first.');
      return;
    }

    if (username != storedUsername ||
        sha256.convert(utf8.encode(password)).toString() != storedPassword) {
      _showError('Invalid username or password.');
      return;
    }

    // Set logged in flag
    box.put('loggedIn', true);

    // Ensure profile exists
    if (UserRepository.getProfile() == null) {
      await UserRepository.createFromAuth(storedUsername);
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const HomeShell()),
      (route) => false,
    );
  }

  void _handleResetData() async {
    if (BiometricService.isEnabled()) {
      // ── Biometrics ON → use biometric auth ──────────────────
      final authenticated = await BiometricService.authenticate(
        reason: 'Authenticate to reset all data',
      );
      if (!authenticated) {
        if (mounted) {
          showLightDialog(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: const Text('Authentication Failed'),
              content: const Text(
                'Biometric authentication is required to reset data.',
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          );
        }
        return;
      }
      if (mounted) _confirmReset();
    } else {
      // ── Biometrics OFF → ask for password confirmation ───────
      final TextEditingController passwordCtrl = TextEditingController();
      if (!mounted) return;

      showLightDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Confirm Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Enter your password to reset all data.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: passwordCtrl,
                  placeholder: 'Password',
                  obscureText: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF6F2DA8).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text('Confirm'),
                onPressed: () {
                  final storedPassword = box.get('password');
                  final enteredHash = sha256
                      .convert(utf8.encode(passwordCtrl.text.trim()))
                      .toString();
                  if (enteredHash == storedPassword) {
                    Navigator.of(ctx).pop();
                    if (mounted) _confirmReset();
                  } else {
                    Navigator.of(ctx).pop();
                    if (mounted) {
                      showLightDialog(
                        context: context,
                        builder: (ctx2) => CupertinoAlertDialog(
                          title: const Text('Incorrect Password'),
                          content: const Text('The password you entered is incorrect.'),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text('OK'),
                              onPressed: () => Navigator.of(ctx2).pop(),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
      );
    }
  }

  void _confirmReset() {
    showLightDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Reset All Data?'),
        content: const Text(
          'This will permanently delete your account, all activities, '
          'challenges, feed data, and preferences. This cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Reset Everything'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await HiveService.clearAll();
              await box.clear();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                CupertinoPageRoute(builder: (_) => const SignupPage()),
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
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmall = screenHeight < 700;

    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      children: [
                        SizedBox(
                          height: constraints.maxHeight * 0.42,
                          child: _buildHero(isSmall),
                        ),
                        SizedBox(
                          height: constraints.maxHeight * 0.58,
                          child: _buildCard(isSmall),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D0118), Color(0xFF1E0638), Color(0xFF4A1080)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60, right: -40,
            child: _GlowBlob(color: const Color(0xFF9B4DCA).withValues(alpha: 0.55), size: 260, blur: 50),
          ),
          Positioned(
            top: 120, left: -70,
            child: _GlowBlob(color: const Color(0xFFFF5ACD).withValues(alpha: 0.15), size: 220, blur: 40),
          ),
          Positioned(
            bottom: 80, right: -60,
            child: _GlowBlob(color: const Color(0xFF4D7CFE).withValues(alpha: 0.12), size: 240, blur: 45),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(bool isSmall) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, isSmall ? 4 : 10, 24, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // SVG — large, bare, with glow underneath (no box/border)
          Stack(
            alignment: Alignment.center,
            children: [
              // Glow halo behind icon
              Container(
                width: isSmall ? 160 : 190,
                height: isSmall ? 160 : 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFAB5CF0).withValues(alpha: 0.35),
                      const Color(0xFF6F2DA8).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              SvgPicture.asset(
                'assets/svg/sigin.svg',
                width: isSmall ? 130 : 155,
                height: isSmall ? 130 : 155,
                fit: BoxFit.contain,
              ),
            ],
          ),
          SizedBox(height: isSmall ? 10 : 14),
          // Brand name with letter spacing
          const Text(
            'ENDURA',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 6),
          // Tagline with subtle dividers
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 28, height: 1,
                  color: CupertinoColors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 10),
              Text(
                'Welcome back',
                style: TextStyle(
                  color: CupertinoColors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 10),
              Container(width: 28, height: 1,
                  color: CupertinoColors.white.withValues(alpha: 0.3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(bool isSmall) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFAF5FF).withValues(alpha: 0.97),
                const Color(0xFFEDE0FF).withValues(alpha: 0.94),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            border: Border.all(
              color: CupertinoColors.white.withValues(alpha: 0.7),
              width: 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(26, isSmall ? 14 : 20, 26, isSmall ? 10 : 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top section
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6F2DA8).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: isSmall ? 12 : 18),

                    // Title
                    const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2D0A55),
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enter your credentials to continue',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF4A1A6B).withValues(alpha: 0.55),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: isSmall ? 14 : 20),

                    // Fields
                    _AuthField(
                      controller: _username,
                      placeholder: 'Username',
                      icon: CupertinoIcons.person_fill,
                    ),
                    const SizedBox(height: 10),
                    _AuthField(
                      controller: _password,
                      placeholder: 'Password',
                      icon: CupertinoIcons.lock_fill,
                      obscureText: hidePassword,
                      suffix: GestureDetector(
                        onTap: () => setState(() => hidePassword = !hidePassword),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Icon(
                            hidePassword ? CupertinoIcons.eye_fill : CupertinoIcons.eye_slash_fill,
                            color: const Color(0xFF6F2DA8).withValues(alpha: 0.5),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isSmall ? 14 : 20),

                    // Sign In button
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6F2DA8), Color(0xFFAB5CF0)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6F2DA8).withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: CupertinoButton(
                          color: CupertinoColors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          pressedOpacity: 0.75,
                          onPressed: _handleSignin,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Biometrics
                    if (_biometricsAvailable) ...[
                      SizedBox(height: isSmall ? 10 : 14),
                      Row(
                        children: [
                          Expanded(child: Container(height: 0.8,
                              color: const Color(0xFF6F2DA8).withValues(alpha: 0.12))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or', style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: const Color(0xFF4A1A6B).withValues(alpha: 0.4),
                            )),
                          ),
                          Expanded(child: Container(height: 0.8,
                              color: const Color(0xFF6F2DA8).withValues(alpha: 0.12))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _handleBiometricLogin,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF6F2DA8).withValues(alpha: 0.25),
                              width: 1.2,
                            ),
                            color: const Color(0xFF6F2DA8).withValues(alpha: 0.06),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isFaceId ? CupertinoIcons.viewfinder : CupertinoIcons.lock_shield_fill,
                                color: const Color(0xFF6F2DA8),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Sign in with biometrics',
                                style: TextStyle(
                                  color: const Color(0xFF4A1A6B).withValues(alpha: 0.75),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Bottom: Reset Data
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  pressedOpacity: 0.5,
                  onPressed: _handleResetData,
                  child: Text(
                    'Reset All Data',
                    style: TextStyle(
                      color: const Color(0xFF4A1A6B).withValues(alpha: 0.38),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: const Color(0xFF4A1A6B).withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Glow blob for background ────────────────────────────────────────────────
class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  final double blur;

  const _GlowBlob({
    required this.color,
    required this.size,
    required this.blur,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Modern Auth Field Component (focus glow) ────────────────────────────────
class _AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final bool obscureText;
  final Widget? suffix;

  const _AuthField({
    required this.controller,
    required this.placeholder,
    required this.icon,
    this.obscureText = false,
    this.suffix,
  });

  @override
  State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!mounted) return;
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _focused
        ? const Color(0xFF6F2DA8).withValues(alpha: 0.55)
        : const Color(0xFF6F2DA8).withValues(alpha: 0.12);

    final glowColor = _focused
        ? const Color(0xFFB26CFF).withValues(alpha: 0.28)
        : const Color(0xFF6F2DA8).withValues(alpha: 0.10);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CupertinoColors.white.withValues(alpha: 0.94),
            const Color(0xFFF6EEFF).withValues(alpha: 0.86),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: _focused ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: _focused ? 22 : 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CupertinoTextField(
        focusNode: _focusNode,
        controller: widget.controller,
        placeholder: widget.placeholder,
        placeholderStyle: TextStyle(
          color: const Color(0xFF4A1A6B).withValues(alpha: 0.40),
          fontWeight: FontWeight.w600,
        ),
        style: const TextStyle(
          color: CupertinoColors.black,
          fontWeight: FontWeight.w700,
        ),
        obscureText: widget.obscureText,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(
            widget.icon,
            color: _focused
                ? const Color(0xFF6F2DA8).withValues(alpha: 0.95)
                : const Color(0xFF6F2DA8).withValues(alpha: 0.70),
          ),
        ),
        suffix: widget.suffix,
        decoration: BoxDecoration(
          color: CupertinoColors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
