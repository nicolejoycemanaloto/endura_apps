import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lottie/lottie.dart';import 'package:lottie/lottie.dart';
import 'constants.dart';
import 'core/providers/theme_provider.dart';
import 'core/storage/hive_service.dart';
import 'core/storage/hive_boxes.dart';
import 'core/theme/app_theme.dart';
import 'package:endura/core/notifications/workout_notification_service.dart';
import 'features/home/home_shell.dart';
import 'features/profile/user_repository.dart';
import 'signin.dart';
import 'signup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFFFFFFFF),
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  final container = ProviderContainer();
  await container.read(workoutNotificationServiceProvider).initialize();

  runApp(UncontrolledProviderScope(
    container: container,
    child: const AuthGate(),
  ));
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
    return AppRoot(
      isLoading: _isLoading,
      hasUser: _hasUser,
      isLoggedIn: _isLoggedIn,
    );
  }
}

class AppRoot extends ConsumerWidget {
  final bool isLoading;
  final bool hasUser;
  final bool isLoggedIn;

  const AppRoot({
    super.key,
    required this.isLoading,
    required this.hasUser,
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeProvider);
    final brightness = switch (mode) {
      'dark' => Brightness.dark,
      'light' => Brightness.light,
      _ => null,
    };
    final theme = brightness == Brightness.dark
        ? AppTheme.darkTheme
        : brightness == Brightness.light
            ? AppTheme.lightTheme
            : AppTheme.lightTheme;

    return CupertinoApp(
      title: "Endura",
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: isLoading
          ? const SplashScreen()
          : (isLoggedIn
              ? const HomeShell()
              : (hasUser ? const SigninPage() : const SignupPage())),
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
  late AnimationController _fadeController;
  late Animation<double> _logoFadeIn;
  late Animation<double> _textFadeIn;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _logoFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _textFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF8B6F9F),
              const Color(0xFF6B5B8C),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with scale and fade animation
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _logoFadeIn,
                  child: Lottie.asset(
                    'assets/splash/splash.json',
                    width: 160,
                    height: 160,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 60),
              // Brand name with fade-in animation
              FadeTransition(
                opacity: _textFadeIn,
                child: const Text(
                  "Endura",
                  style: TextStyle(
                    fontFamily: '.SF Pro Display',
                    color: Colors.white,
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2.0,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Subtle tagline with fade
              FadeTransition(
                opacity: _textFadeIn,
                child: Text(
                  "Relentless Performance",
                  style: TextStyle(
                    fontFamily: '.SF Pro Display',
                    color: Colors.white.withAlpha(200),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.8,
                    decoration: TextDecoration.none,
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

