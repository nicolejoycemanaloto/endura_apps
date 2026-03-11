import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'constants.dart';
import 'core/storage/hive_service.dart';
import 'core/storage/hive_boxes.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'features/home/home_shell.dart';
import 'features/profile/user_repository.dart';
import 'signin.dart';
import 'signup.dart';

/// Global theme notifier instance.
final themeNotifier = ThemeNotifier();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const AuthGate());
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _hasUser = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _handleStartup();
  }

  Future<void> _handleStartup() async {
    await Future.delayed(const Duration(seconds: 3));
    final box = Hive.box(HiveBoxes.database);
    final username = box.get("username");
    final loggedIn = box.get("loggedIn") == true;

    // Ensure a profile exists for this user
    if (username != null && UserRepository.getProfile() == null) {
      await UserRepository.createFromAuth(username);
    }

    if (mounted) {
      setState(() {
        _hasUser = username != null;
        _isLoggedIn = loggedIn;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        final brightness = themeNotifier.brightness;
        final theme = brightness == Brightness.dark
            ? AppTheme.darkTheme
            : brightness == Brightness.light
                ? AppTheme.lightTheme
                : AppTheme.lightTheme; // system default fallback

        return CupertinoApp(
          title: "Endura",
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: _isLoading
              ? const SplashScreen()
              : (_isLoggedIn
                  ? const HomeShell()
                  : (_hasUser ? const SigninPage() : const SignupPage())),
        );
      },
    );
  }
}

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

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  final List<String> _loadingTexts = [
    'Initializing',
    'Loading modules',
    'Setting up',
    'Almost ready',
    'Starting'
  ];
  int _currentTextIndex = 0;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Cycle through loading texts
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          _currentTextIndex = (_currentTextIndex + 1) % _loadingTexts.length;
        });
        return true;
      }
      return false;
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: ModernBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // GIF Animation
              Image.asset(
                'assets/splash/splash.gif',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 25),
              const Text(
                "Endura",
                style: TextStyle(
                  fontFamily: '.SF Pro Display',
                  color: kPrimary,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 30),
              // Wave Loading Text
              AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _loadingTexts[_currentTextIndex],
                        style: const TextStyle(
                          fontFamily: '.SF Pro Display',
                          color: kPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(3, (index) {
                        final delay = index * 0.2;
                        final value = (_waveController.value - delay) % 1.0;
                        final opacity = (1 - (value * 2 - 1).abs()).clamp(0.3, 1.0);
                        final offset = (1 - (value * 2 - 1).abs()) * 8;

                        return Transform.translate(
                          offset: Offset(0, -offset),
                          child: Opacity(
                            opacity: opacity,
                            child: const Text(
                              '●',
                              style: TextStyle(
                                color: kPrimary,
                                fontSize: 16,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}