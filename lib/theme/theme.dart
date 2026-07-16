import 'package:flutter/material.dart';

class AppColors {
  // ── BRAND COLORS (same in both themes) ─────────────────
  static const Color primary = Color(0xFD0095E5);
  static const Color primaryDark = Color(0xFF0075B4);
  static const Color secondary = Color(0x9900C6D8);
  static const Color purple = Color(0xD57F77DD);
  static const Color purpleDark = Color(0xCF534AB7);
  static const Color teal = Color(0xFD1D939E);
  static const Color tealDark = Color(0xAD0F6E56);
  static const Color amber = Color(0xA9BA7517);
  static const Color amberDark = Color(0xBA854F0B);
  static const Color red = Color(0x73E24B4A);
  static const Color primaryBorder = Color(0x3300E5A0);
  static const Color primarySurface = Color(0x1400E5A0);

  // ── DARK THEME COLORS ──────────────────────────────────
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF13131A);
  static const Color surfaceLight = Color(0xFF13131A);
  static const Color surfaceColor = Color(0xFF1C1C26);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9A9AB0);
  static const Color textMuted = Color(0xFF4A4A5E);
  static const Color border = Color(0xFF1E1E2E);
  static const Color borderLight = Color(0xFF2A2A3E);
  static const Color redSurface = Color(0x1AE24B4A);

  // ── LIGHT THEME COLORS ─────────────────────────────────
  static const Color lightBackground = Color(0xFFF5F5F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLight = Color(0xFFF0F0F5);
  static const Color lightTextPrimary = Color(0xFF0A0A0F);
  static const Color lightTextSecondary = Color(0xFF4A4A6A);
  static const Color lightTextMuted = Color(0xFF9A9AB0);
  static const Color lightBorder = Color(0xFFE0E0EA);
}

class AppTheme {
  // ── DARK THEME ─────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    ),
    cardColor: AppColors.surfaceColor,
    dividerColor: AppColors.border,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
            ? Colors.white : AppColors.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
            ? AppColors.primary : AppColors.border,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.textPrimary,
          fontSize: 28, fontWeight: FontWeight.w800),
      titleLarge: TextStyle(color: AppColors.textPrimary,
          fontSize: 18, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(color: AppColors.textSecondary, fontSize: 15),
      bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      bodySmall: TextStyle(color: AppColors.textMuted, fontSize: 11),
    ),
  );

  // ── LIGHT THEME ────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
    ),
    cardColor: AppColors.lightSurface,
    dividerColor: AppColors.lightBorder,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightBackground,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.lightTextPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
            ? Colors.white : AppColors.lightTextMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
            ? AppColors.primary : AppColors.lightBorder,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.lightTextPrimary,
          fontSize: 28, fontWeight: FontWeight.w800),
      titleLarge: TextStyle(color: AppColors.lightTextPrimary,
          fontSize: 18, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(color: AppColors.lightTextSecondary, fontSize: 15),
      bodyMedium: TextStyle(color: AppColors.lightTextSecondary, fontSize: 13),
      bodySmall: TextStyle(color: AppColors.lightTextMuted, fontSize: 11),
    ),
  );
}

// ── THEME PROVIDER ─────────────────────────────────────────
class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider _instance = ThemeProvider._internal();
  factory ThemeProvider() => _instance;
  ThemeProvider._internal();

  bool _isLight = true;

  bool get isLight => _isLight;
  bool get isDark => !_isLight;

  void toggleTheme() {
    _isLight = !_isLight;
    notifyListeners();
  }
}

// ── THEME EXTENSION ────────────────────────────────────────
// Use this in any screen to get correct colors based on current theme
extension ThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Backgrounds
  Color get bgColor => isDark
      ? AppColors.background : AppColors.lightBackground;
  Color get surface => isDark
      ? AppColors.surface : AppColors.lightSurface;
  Color get surfaceColor => isDark
      ? AppColors.surfaceColor : AppColors.lightSurface;
  Color get surfaceLight => isDark
      ? AppColors.surface : AppColors.lightSurfaceLight;
  Color get cardColor => isDark
      ? AppColors.surfaceColor : AppColors.lightSurface;

  // Text
  Color get textPrimary => isDark
      ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get textSecondary => isDark
      ? AppColors.textSecondary : AppColors.lightTextSecondary;
  Color get textMuted => isDark
      ? AppColors.textMuted : AppColors.lightTextMuted;

  // Borders
  Color get borderColor => isDark
      ? AppColors.border : AppColors.lightBorder;
}
