import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'constants.dart';
import 'core/storage/hive_boxes.dart';
import 'signin.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final box = Hive.box(HiveBoxes.database);
  bool hidePassword = true;
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

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

  void _handleSignup() {
    if (_username.text.trim().isEmpty || _password.text.trim().isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }

    box.put('username', _username.text.trim());
    box.put('password', _password.text.trim());
    box.put('biometrics', false);

    showLightDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: const Text(
          'Account created successfully!\nPlease sign in to continue.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Sign In'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushReplacement(
                context,
                CupertinoPageRoute(builder: (_) => const SigninPage()),
              );
            },
          )
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
            child: Column(
              children: [
                Expanded(flex: 40, child: _buildHero(isSmall)),
                Expanded(flex: 60, child: _buildCard(isSmall)),
              ],
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
      padding: EdgeInsets.fromLTRB(24, isSmall ? 8 : 16, 24, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: isSmall ? 100 : 120,
                height: isSmall ? 100 : 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CupertinoColors.white.withValues(alpha: 0.18),
                      CupertinoColors.white.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: CupertinoColors.white.withValues(alpha: 0.22),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6F2DA8).withValues(alpha: 0.5),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(isSmall ? 18 : 22),
                child: SvgPicture.asset('assets/svg/signup.svg', fit: BoxFit.contain),
              ),
            ),
          ),
          SizedBox(height: isSmall ? 12 : 16),
          const Text(
            'ENDURA',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 28, height: 1,
                  color: CupertinoColors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 10),
              Text(
                'Build endurance, achieve greatness ⚡',
                style: TextStyle(
                  color: CupertinoColors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
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
            padding: EdgeInsets.fromLTRB(26, isSmall ? 14 : 20, 26, isSmall ? 14 : 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6F2DA8).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(height: isSmall ? 12 : 18),

                    // Title
                    const Center(
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2D0A55),
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'Start your fitness journey today',
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF4A1A6B).withValues(alpha: 0.55),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: isSmall ? 14 : 20),

                    // Fields
                    _AuthField(
                      controller: _username,
                      placeholder: 'Choose a username',
                      icon: CupertinoIcons.person_fill,
                    ),
                    const SizedBox(height: 10),
                    _AuthField(
                      controller: _password,
                      placeholder: 'Create a password',
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
                    const SizedBox(height: 8),

                    // Password tip
                    Row(
                      children: [
                        Icon(CupertinoIcons.shield_lefthalf_fill,
                            size: 12, color: const Color(0xFF6F2DA8).withValues(alpha: 0.45)),
                        const SizedBox(width: 5),
                        Text(
                          'Use a strong password for better security',
                          style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF4A1A6B).withValues(alpha: 0.45),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmall ? 14 : 20),

                    // Get Started button
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
                              color: const Color(0xFF6F2DA8).withValues(alpha: 0.45),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: CupertinoButton(
                          color: CupertinoColors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          pressedOpacity: 0.75,
                          onPressed: _handleSignup,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: const Text(
                            'Get Started',
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
                  ],
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

// ── ModernBackground (kept for backward compat) ────────────────────────────────
class ModernBackground extends StatelessWidget {
  final Widget child;
  const ModernBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8D5F2), Color(0xFFD4BBE8)],
        ),
      ),
      child: child,
    );
  }
}

// ── GlassTextField (kept for backward compat) ─────────────────────────────────
class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final bool obscureText;
  final Widget? suffix;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.icon,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: CupertinoColors.white.withValues(alpha: 0.7),
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            placeholderStyle: const TextStyle(color: CupertinoColors.systemGrey2),
            style: const TextStyle(color: CupertinoColors.black),
            obscureText: obscureText,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Icon(icon, color: CupertinoColors.systemGrey),
            ),
            suffix: suffix,
            decoration: BoxDecoration(
              color: CupertinoColors.transparent,
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ),
    );
  }
}

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


