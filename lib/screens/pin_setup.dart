import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});
  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();

  String _pin = '';
  String _confirmPin = '';
  bool _confirming = false;
  String _error = '';
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    _loadCurrentSettings();
  }

  Future<void> _checkBiometric() async {
    try {
      final available = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      setState(() => _biometricAvailable = available);
    } catch (_) {}
  }

  Future<void> _loadCurrentSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    });
  }

  void _onKeyTap(String key) {
    if (_confirming) {
      if (_confirmPin.length >= 4) return;
      setState(() { _confirmPin += key; _error = ''; });
      if (_confirmPin.length == 4) {
        Future.delayed(const Duration(milliseconds: 100), _checkConfirm);
      }
    } else {
      if (_pin.length >= 4) return;
      setState(() { _pin += key; _error = ''; });
      if (_pin.length == 4) {
        Future.delayed(const Duration(milliseconds: 200), () {
          setState(() => _confirming = true);
        });
      }
    }
  }

  void _onDelete() {
    if (_confirming) {
      if (_confirmPin.isEmpty) return;
      setState(() => _confirmPin =
          _confirmPin.substring(0, _confirmPin.length - 1));
    } else {
      if (_pin.isEmpty) return;
      setState(() =>
      _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  Future<void> _checkConfirm() async {
    if (_confirmPin == _pin) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_pin', _pin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('PIN set successfully'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
        Navigator.pop(context);
      }
    } else {
      setState(() {
        _error = 'PINs do not match. Try again.';
        _pin = '';
        _confirmPin = '';
        _confirming = false;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', value);
    setState(() => _biometricEnabled = value);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(value
          ? 'Fingerprint enabled'
          : 'Fingerprint disabled'),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_pin');
    await prefs.setBool('biometric_enabled', false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('PIN removed'),
        backgroundColor: AppColors.amber,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeProvider().isDark;
    final bg = isDark ? AppColors.background : AppColors.lightBackground;
    final surface =
    isDark ? AppColors.surfaceLight : AppColors.lightSurface;
    final border =
    isDark ? AppColors.border : AppColors.lightBorder;
    final textColor =
    isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final mutedColor =
    isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    final current = _confirming ? _confirmPin : _pin;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Icon(Icons.arrow_back_rounded,
                      color: textColor, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              Text('PIN & Security',
                  style: TextStyle(fontSize: 20,
                      fontWeight: FontWeight.w700, color: textColor)),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Text(
                    _confirming ? 'Confirm your PIN' : 'Set a 4-digit PIN',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _confirming
                        ? 'Enter the same PIN again'
                        : 'This PIN will be required every time you open the app',
                    style: TextStyle(fontSize: 12,
                        color: mutedColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // PIN dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final filled = i < current.length;
                      return Container(
                        width: 16, height: 16,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled
                              ? AppColors.primary
                              : AppColors.primary
                              .withValues(alpha: 0.2),
                          border: Border.all(
                              color: AppColors.primary
                                  .withValues(alpha: 0.4)),
                        ),
                      );
                    }),
                  ),

                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(_error,
                        style: const TextStyle(
                            color: AppColors.red, fontSize: 12),
                        textAlign: TextAlign.center),
                  ],

                  const SizedBox(height: 32),

                  // Numpad
                  ...[
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                    ['', '0', 'DEL'],
                  ].map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly,
                      children: row.map((key) {
                        if (key.isEmpty) {
                          return const SizedBox(width: 70);
                        }
                        return GestureDetector(
                          onTap: () => key == 'DEL'
                              ? _onDelete()
                              : _onKeyTap(key),
                          child: Container(
                            width: 70, height: 70,
                            decoration: BoxDecoration(
                              color: key == 'DEL'
                                  ? AppColors.red
                                  .withValues(alpha: 0.08)
                                  : AppColors.primary
                                  .withValues(alpha: 0.06),
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: key == 'DEL'
                                ? const Icon(
                                Icons.backspace_rounded,
                                size: 20,
                                color: AppColors.red)
                                : Text(key,
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: mutedColor))),
                          ),
                        );
                      }).toList(),
                    ),
                  )),

                  const SizedBox(height: 24),

                  // Biometric toggle
                  if (_biometricAvailable)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border),
                      ),
                      child: Row(children: [
                        const Icon(Icons.fingerprint_rounded,
                            color: AppColors.primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text('Fingerprint unlock',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textColor)),
                            Text('Use fingerprint to open app',
                                style: TextStyle(
                                    fontSize: 11, color: mutedColor)),
                          ],
                        )),
                        Switch(
                          value: _biometricEnabled,
                          onChanged: _toggleBiometric,
                          activeColor: AppColors.primary,
                          activeTrackColor: AppColors.primary,
                          activeThumbColor: Colors.white
                        ),
                      ]),
                    ),

                  const SizedBox(height: 16),

                  // Remove PIN button
                  TextButton(
                    onPressed: _removePin,
                    child: const Text('Remove PIN',
                        style: TextStyle(
                            color: AppColors.red, fontSize: 13)),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
