import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme.dart';
import '../services/auth.dart';
import 'welcome.dart';
import 'home.dart';
import 'auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _progressController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _logoController, curve: const Interval(0.0, 0.5)),
    );
    _progress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _logoController.forward();

    Future.delayed(const Duration(milliseconds: 400), () {
      _progressController.forward();
    });

    // Check auth after animation
    Future.delayed(const Duration(milliseconds: 2500), () {
      _checkAuthAndNavigate();
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    final authService = AuthService();
    final isLoggedIn = await authService.checkAuth();
    await authService.loadUserFromToken();
    await authService.loadSavedProfile();

    if (!mounted) return;

    if (isLoggedIn) {
      // Check if PIN is set
      final prefs = await SharedPreferences.getInstance();
      final hasPin = (prefs.getString('app_pin') ?? '').isNotEmpty;
      final hasBiometric =
          prefs.getBool('biometric_enabled') ?? false;

      if (hasPin || hasBiometric) {
        // Show PIN/biometric gate before home
        Navigator.pushReplacement(context,
            MaterialPageRoute(
                builder: (_) => const AuthGateScreen()));
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(
                builder: (_) => const HomeScreen()));
      }
    } else {
      Navigator.pushReplacement(context,
          MaterialPageRoute(
              builder: (_) => const WelcomeScreen()));
    }
  }




  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: Center(
        child: FadeTransition(
          opacity: _logoFade,
          child: ScaleTransition(
            scale: _logoScale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo rings
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 160, height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    Container(
                      width: 130, height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, AppColors.secondary],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Colors.black,
                        size: 44,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text('SMART OUTLET',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
                        color: context.textPrimary, letterSpacing: 4)),
                const SizedBox(height: 8),
                Text('SMART OUTLET CONTROL',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: context.textMuted, letterSpacing: 3)),
                const SizedBox(height: 48),
                // Progress bar
                Container(
                  width: 180, height: 3,
                  decoration: BoxDecoration(
                    color: context.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (_, __) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progress.value,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                        ),
                      ),
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
