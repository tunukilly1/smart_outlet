import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../services/auth.dart';
import 'login.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authService = AuthService();
  bool _obscurePassword = true;

  // Password strength indicators
  bool _hasLength = false;
  bool _hasUpper = false;
  bool _hasLower = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;

  @override
  void initState() {
    super.initState();
    _authService.addListener(() => setState(() {}));
    _passwordController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength() {
    final p = _passwordController.text;
    setState(() {
      _hasLength = p.length >= 8;
      _hasUpper = p.contains(RegExp(r'[A-Z]'));
      _hasLower = p.contains(RegExp(r'[a-z]'));
      _hasNumber = p.contains(RegExp(r'[0-9]'));
      _hasSpecial =
          p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool get _passwordValid =>
      _hasLength && _hasUpper && _hasLower &&
          _hasNumber && _hasSpecial;

  Future<void> _register() async {
    // Validate all fields
    if (_usernameController.text.isEmpty ||
        _firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    // Validate password
    final passError =
    AuthService.validatePassword(_passwordController.text);
    if (passError != null) {
      _showError(passError);
      return;
    }

    // Validate phone
    final phoneError =
    AuthService.validatePhone(_phoneController.text.trim());
    if (phoneError != null) {
      _showError(phoneError);
      return;
    }

    final success = await _authService.register(
      username: _usernameController.text.trim(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      // Go to login after successful registration
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
            'Account created! Please log in.'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ));
      Navigator.pushReplacement(context,
          MaterialPageRoute(
              builder: (_) => const LoginScreen()));
    } else {
      _showError(_authService.error ?? 'Registration failed');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              // Logo
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                      colors: [AppColors.primary,
                        AppColors.secondary]),
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: Colors.black, size: 26),
              ),
              const SizedBox(height: 24),
              Text('Create account',
                  style: TextStyle(fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary)),
              const SizedBox(height: 4),
              Text(
                  'Smart outlet control starts here',
                  style: TextStyle(fontSize: 13,
                      color: context.textMuted)),

              // Server notice
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.amber
                      .withOpacity(0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded,
                      size: 13, color: AppColors.amber),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'First request may take 30-60 seconds.',
                    style: TextStyle(fontSize: 11,
                        color: AppColors.amber),
                  )),
                ]),
              ),

              const SizedBox(height: 20),
              _label('Username'),
              _field(_usernameController, 'e.g. JohnDoe',
                  Icons.person_rounded),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('First Name'),
                      _field(_firstNameController, 'John',
                          Icons.badge_rounded),
                    ])),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Last Name'),
                      _field(_lastNameController, 'Doe',
                          Icons.badge_outlined),
                    ])),
              ]),
              const SizedBox(height: 12),
              _label('Email'),
              _field(_emailController, 'you@example.com',
                  Icons.email_rounded,
                  type: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _label('Phone Number'),
              _field(_phoneController,
                  '+255712345678 or 0712345678',
                  Icons.phone_rounded,
                  type: TextInputType.phone),

              const SizedBox(height: 12),
              _label('Password'),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(
                    color: context.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Min 8 chars, upper, lower, number, symbol',
                  hintStyle:  TextStyle(
                      color: context.textMuted, fontSize: 12),
                  prefixIcon:  Icon(Icons.lock_rounded,
                      color: context.textMuted, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: context.textMuted, size: 18,
                    ),
                    onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: context.surfaceColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: context.borderColor)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: context.borderColor)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                ),
              ),

              // Password strength indicators
              if (_passwordController.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: [
                    _strengthChip('8+ chars', _hasLength),
                    _strengthChip('Uppercase', _hasUpper),
                    _strengthChip('Lowercase', _hasLower),
                    _strengthChip('Number', _hasNumber),
                    _strengthChip('Symbol', _hasSpecial),
                  ],
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _authService.isLoading
                      ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _authService.isLoading
                      ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black))
                      : const Text('Create Account',
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     Text('Already have an account? ',
                        style: TextStyle(color: context.textMuted,
                            fontSize: 13)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen())),
                      child: const Text('Sign In',
                          style: TextStyle(color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text.toUpperCase(),
        style:  TextStyle(fontSize: 9,
            fontWeight: FontWeight.w700,
            color: context.textMuted, letterSpacing: 1.2)),
  );

  Widget _field(TextEditingController ctrl, String hint,
      IconData icon, {TextInputType? type}) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        style:  TextStyle(
            color: context.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:  TextStyle(
              color: context.textMuted, fontSize: 12),
          prefixIcon: Icon(icon,
              color: context.textMuted, size: 18),
          filled: true, fillColor: context.surfaceColor,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: context.borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: context.borderColor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.primary)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
        ),
      );

  Widget _strengthChip(String label, bool met) => Container(
    padding:  EdgeInsets.symmetric(
        horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: met
          ? AppColors.primary.withOpacity(0.15)
          : context.surfaceColor,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
          color: met ? AppColors.primary : context.borderColor),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(met ? Icons.check_rounded : Icons.close_rounded,
          size: 11,
          color: met ? AppColors.primary : context.textMuted),
      SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 10,
          color: met ? AppColors.primary : context.textMuted,
          fontWeight: FontWeight.w600)),
    ]),
  );
}
