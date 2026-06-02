import 'package:flutter/material.dart';
import '../theme/theme.dart';
import 'home.dart';
import 'welcome.dart';
import 'notifications.dart';
import 'edit_profile_screen.dart';
import '../services/auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_handleThemeChange);
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_handleThemeChange);
    super.dispose();
  }

  void _handleThemeChange() {
    if (mounted) {
      setState(() {});
    }
  }
  bool get _isLight => _themeProvider.isLight;

  // Dynamic colors based on theme
  Color get _bg => _isLight ? AppColors.lightBackground : context.bgColor;
  Color get _surface => _isLight ? AppColors.lightSurface : context.surfaceColor;
  Color get _borderColor => _isLight ? AppColors.lightBorder : context.borderColor;
  Color get _textPrimary => _isLight ? AppColors.lightTextPrimary : context.textPrimary;
  Color get _textMuted => _isLight ? AppColors.lightTextMuted : context.textMuted;
  Color get _textSecondary => _isLight ? AppColors.lightTextSecondary : context.textSecondary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              child: Column(children: [
                _buildProfileCard(),

                const SizedBox(height: 16),
                _buildGroup(
                  title: 'APP',
                  items: [
                    _SettingItem(
                      icon: Icons.notifications_rounded,
                      iconBg: AppColors.secondary.withOpacity(0.15),
                      iconColor: AppColors.secondary,
                      label: 'Notifications',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                    ),
                    _SettingItem(
                      icon: _isLight
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      iconBg: AppColors.amber.withOpacity(0.15),
                      iconColor: AppColors.amber,
                      label: _isLight ? 'Light Mode' : 'Dark Mode',
                      subtitle: _isLight
                          ? 'Tap to switch to dark'
                          : 'Tap to switch to light',
                      trailing: Switch(
                        value: _isLight,
                        onChanged: (_) => _themeProvider.toggleTheme(),
                        inactiveTrackColor: context.borderColor,
                        thumbColor: WidgetStateProperty.all(Colors.white),
                      ),
                      onTap: () => _themeProvider.toggleTheme(),
                    ),
                    _SettingItem(
                      icon: Icons.lock_rounded,
                      iconBg: AppColors.purple.withOpacity(0.15),
                      iconColor: AppColors.purple,
                      label: 'Security',
                      subtitle: 'PIN & biometrics',
                      onTap: () => _showComingSoon('Security'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGroup(
                  title: 'ACCOUNT',
                  items: [
                    _SettingItem(
                      icon: Icons.person_rounded,
                      iconBg: AppColors.secondary.withOpacity(0.15),
                      iconColor: AppColors.secondary,
                      label: 'Edit Profile',
                      subtitle: 'Update your details',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                    ),
                    _SettingItem(
                      icon: Icons.delete_rounded,
                      iconBg: AppColors.red.withOpacity(0.15),
                      iconColor: AppColors.red,
                      label: 'Delete Account',
                      subtitle: 'Permanently remove account',
                      onTap: () => _showDeleteConfirm(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildLogoutButton(context),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor),
            ),
            child: Icon(Icons.arrow_back_rounded, color: _textPrimary, size: 18),
          ),
        ),
        const SizedBox(width: 16),
        Text('Settings', style: TextStyle(fontSize: 20,
            fontWeight: FontWeight.w700, color: _textPrimary)),
      ]),
    );
  }

  Widget _buildProfileCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const EditProfileScreen())),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor),
        ),
        child: Row(children: [
          Container(
            width: 54, height: 54,
             alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary]),
            ),
            child: Text(
              AuthService().username.isNotEmpty
                  ? AuthService().username[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    AuthService().username.isEmpty
                        ? 'My Profile'
                        : AuthService().username,
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                    AuthService().email.isEmpty
                        ? 'No email'
                        : AuthService().email,
                    style: TextStyle(fontSize: 13, color: _textMuted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: _textMuted),
        ]),
      ),
    );
  }

  Widget _buildGroup({
    required String title,
    required List<_SettingItem> items,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: _textMuted, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            children: List.generate(items.length, (i) => Column(children: [
              _buildRow(items[i]),
              if (i < items.length - 1)
                Divider(color: _borderColor, height: 1, indent: 56),
            ])),
          ),
        ),
      ]),
    );
  }

  Widget _buildRow(_SettingItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: item.iconBg, borderRadius: BorderRadius.circular(9)),
            child: Icon(item.icon, color: item.iconColor, size: 17),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: TextStyle(fontSize: 14, color: _textSecondary)),
                if (item.subtitle != null)
                  Text(item.subtitle!, style: TextStyle(fontSize: 11, color: _textMuted)),
              ])),
          item.trailing ??
              Icon(Icons.chevron_right_rounded, color: _textMuted, size: 18),
        ]),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity, height: 54,
        child: ElevatedButton(
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.red.withOpacity(0.1),
            foregroundColor: AppColors.red,
            elevation: 0,
            side: BorderSide(color: AppColors.red.withOpacity(0.3)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Sign Out',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$feature coming soon!'),
      backgroundColor: AppColors.surfaceColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showDeleteConfirm() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete Account',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
            'Are you sure? This cannot be undone.',
            style: TextStyle(color: _textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: _textMuted))),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.red,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final Color iconBg, iconColor;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingItem({
    required this.icon, required this.iconBg, required this.iconColor,
    required this.label, this.subtitle, this.trailing, required this.onTap,
  });
}
