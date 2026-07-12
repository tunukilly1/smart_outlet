import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _api = ApiService();

  String _username = '';
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _phone = '';
  String _location = '';
  bool _isLoading = false;
  String? _error;

  String get username => _username;
  String get firstName => _firstName;
  String get lastName => _lastName;
  String get fullName => '$_firstName $_lastName'.trim();
  String get email => _email;
  String get phone => _phone;
  String get location => _location;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── CHECK AUTH ON APP START ────────────────────────────
  Future<bool> checkAuth() async {
    final loggedIn = await _api.isLoggedIn();
    if (loggedIn) await loadUserFromToken();
    return loggedIn;
  }

  // ── DECODE JWT TO GET USERNAME ────────────────────────
  Future<void> loadUserFromToken() async {
    try {
    // First try loading saved username directly
    final saved = await _api.getSavedUsername();
    if (saved != null && saved.isNotEmpty) {
    _username = saved;
    notifyListeners();
    return;
    }
    // Fallback: decode JWT
    final token = await _api.getAccessToken();
    if (token == null || token.isEmpty) return;
    final parts = token.split('.');
    if (parts.length != 3) return;
    final payload = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(payload));
    final data = jsonDecode(decoded) as Map<String, dynamic>;
    // Try username field first, avoid user_id number
    _username = data['username']?.toString() ?? '';
    notifyListeners();
    } catch (e) {
    debugPrint('loadUserFromToken error: $e');
    }
    }
  Future<void> loadSavedProfile() async {
    try {
      // Load from backend first
      final data = await ApiService().getUserProfile();
      _username = data['username']?.toString() ?? _username;
      _email = data['email']?.toString() ?? '';
      _phone = data['phone']?.toString() ?? '';
      _location = data['location']?.toString() ?? '';
      notifyListeners();
    } catch (_) {
      // Fallback to locally saved prefs
      final prefs = await SharedPreferences.getInstance();
      _email = prefs.getString('profile_email') ?? '';
      _phone = prefs.getString('profile_phone') ?? '';
      _location = prefs.getString('profile_location') ?? '';
      notifyListeners();
    }
  }

  // ── REGISTER ──────────────────────────────────────────
  Future<bool> register({
    required String username,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phone,
  }) async {
    // Clear any old tokens first — prevents old user data leaking
    await _api.clearTokens();
    _username = '';
    _firstName = '';
    _lastName = '';
    _email = '';
    _phone = '';

    _setLoading(true);
    _error = null;

    try {
      await _api.register(
        username: username,
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        phone: phone,
      );

      // Auto-login after registration
      final loginData = await _api.login(
        username: username,
        password: password,
      );

      await _api.saveTokens(
          loginData['access'], loginData['refresh']);

      _username = username;
      _firstName = firstName;
      _lastName = lastName;
      _email = email;
      _phone = phone;

      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _error = _parseError(e);
      return false;
    }
  }

  // ── LOGIN ─────────────────────────────────────────────
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final data = await _api.login(
        username: username,
        password: password,
      );

      await _api.saveTokens(data['access'], data['refresh']);
      //save username from user input
      _username = username;
      //saves to secure storage
      await _api.saveUsername(username);
     // await loadUserFromToken();

      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _error = _parseError(e);
      return false;
    }
  }

  // ── LOGOUT ────────────────────────────────────────────
  Future<void> logout() async {
    await _api.clearTokens();
    _username = '';
    _firstName = '';
    _lastName = '';
    _email = '';
    _phone = '';
    _location = '';
    notifyListeners();
  }

  Future<void> updateProfile({
    required String username,
    required String email,
    required String phone,
    required String location,
  }) async {
    try {
      // Save to backend
      await ApiService().updateUserProfile(
        username: username,
        email: email,
        phone: phone,
        location: location,
      );
    } catch (e) {
      debugPrint('Profile update backend error: $e');
    }
    // Update local state
    _username = username;
    _email = email;
    _phone = phone;
    _location = location;

    // Save locally as fallback
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_email', email);
    await prefs.setString('profile_phone', phone);
    await prefs.setString('profile_location', location);

    notifyListeners();
  }

  // ── PASSWORD VALIDATION ───────────────────────────────
  static String? validatePassword(String password) {
    if (password.length < 8) return 'At least 8 characters';
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'At least one uppercase letter';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'At least one lowercase letter';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'At least one number';
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'At least one special character (!@#\$%^&*)';
    }
    return null; // valid
  }

  // ── PHONE VALIDATION ──────────────────────────────────
  static String? validatePhone(String phone) {
    final regex = RegExp(r'^(\+2556|\+2557|06|07)\d{8}$');
    if (!regex.hasMatch(phone)) {
      return 'Use Tanzanian format: +255712345678 or 0712345678';
    }
    return null; // valid
  }

  // ── PARSE ERRORS FROM BACKEND ─────────────────────────
  String _parseError(dynamic e) {
    try {
      final response = (e as dynamic).response;
      if (response != null) {
        final data = response.data;
        if (data is Map) {
          // Show first error from backend
          for (final key in data.keys) {
            final val = data[key];
            if (val is List && val.isNotEmpty) return val[0].toString();
            if (val is String) return val;
          }
        }
        if (response.statusCode == 401) {
          return 'Invalid username or password';
        }
        if (response.statusCode == 400) {
          return 'Please check your details and try again';
        }
      }
    } catch (_) {}

    final msg = e.toString();
    if (msg.contains('timeout') || msg.contains('connection')) {
      return 'Server is waking up, please wait 30 seconds and try again';
    }
    if (msg.contains('SocketException')) {
      return 'No internet connection';
    }
    return 'Something went wrong. Please try again';
  }
}
