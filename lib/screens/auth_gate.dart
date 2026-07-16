import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme.dart';
import 'home.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _biometricAvailable = false;
  bool _pinEnabled = false;
  bool _biometricEnabled = false;

  // PIN entry state
  String _enteredPin = '';
  String _savedPin = '';
  String _errorMessage = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _savedPin = prefs.getString('app_pin') ?? '';
    _pinEnabled = _savedPin.isNotEmpty;
    _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;

    // Check if device supports biometrics
    try {
      _biometricAvailable = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {
      _biometricAvailable = false;
    }

    setState(() => _isLoading = false);

    // If biometric is enabled and available, trigger it immediately
    if (_biometricEnabled && _biometricAvailable) {
      await Future.delayed(const Duration(milliseconds: 300));
      _authenticateWithBiometric();
    }
  }

  // ── BIOMETRIC ─────────────────────────────────────
  Future<void> _authenticateWithBiometric() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to open Smart Outlet App',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (authenticated && mounted) _goHome();
    } catch (e) {
      setState(() =>
      _errorMessage = 'Biometric failed. Use PIN instead.');
    }
  }

  // ── PIN CHECK ─────────────────────────────────────
  void _onKeyTap(String key) {
    if (_enteredPin.length >= 4) return;
    setState(() {
      _enteredPin += key;
      _errorMessage = '';
    });
    if (_enteredPin.length == 4) {
      Future.delayed(const Duration(milliseconds: 100), _checkPin);
    }
  }

  void _onDelete() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = '';
    });
  }

  void _checkPin() {
    if (_enteredPin == _savedPin) {
      _goHome();
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN. Try again.';
        _enteredPin = '';
      });
    }
  }

  void _goHome() {
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeProvider().isDark;
    final bg = isDark ? AppColors.background : AppColors.lightBackground;
    final textColor = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;
    final mutedColor =
    isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(
            child: CircularProgressIndicator(
                color: AppColors.primary)),
      );
    }

    // If no PIN and no biometric set up — go straight home
    if (!_pinEnabled && !_biometricEnabled) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _goHome());
      return Scaffold(backgroundColor: bg);
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                      colors: [AppColors.primary,
                        AppColors.secondary]),
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: Colors.black, size: 32),
              ),
              const SizedBox(height: 24),
              Text('Welcome back',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textColor)),
              const SizedBox(height: 6),
              Text('Enter your PIN to continue',
                  style: TextStyle(fontSize: 13, color: mutedColor)),
              const SizedBox(height: 40),

              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _enteredPin.length;
                  return Container(
                    width: 16, height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.2),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                  );
                }),
              ),

              // Error message
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(_errorMessage,
                    style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 12)),
              ],

              const SizedBox(height: 40),

              // Number pad
              _buildPad(mutedColor),

              // Biometric button
              if (_biometricEnabled && _biometricAvailable) ...[
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _authenticateWithBiometric,
                  child: Column(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primary
                                .withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.fingerprint_rounded,
                          color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(height: 6),
                    Text('Use fingerprint',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPad(Color mutedColor) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'DEL'],
    ];
    return Column(
      children: keys.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: row.map((key) {
            if (key.isEmpty) return const SizedBox(width: 70);
            return GestureDetector(
              onTap: () {
                if (key == 'DEL') {
                  _onDelete();
                } else {
                  _onKeyTap(key);
                }
              },
              child: Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  color: key == 'DEL'
                      ? AppColors.red.withValues(alpha: 0.08)
                      : AppColors.primary.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: key == 'DEL'
                      ? const Icon(Icons.backspace_rounded,
                      size: 20, color: AppColors.red)
                      : Text(key,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: mutedColor)),
                ),
              ),
            );
          }).toList(),
        ),
      )).toList(),
    );
  }
}
