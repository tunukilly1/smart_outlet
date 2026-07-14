import 'package:flutter/material.dart';
import '../theme/theme.dart';
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
  bool _autoRefresh = true;
  bool _alertsEnabled = true;

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
  }

  bool get _isLight => _themeProvider.isLight;

  Color get _bg =>
      _isLight ? AppColors.lightBackground : AppColors.background;
  Color get _surface =>
      _isLight ? AppColors.lightSurface : AppColors.surfaceColor;
  Color get _border =>
      _isLight ? AppColors.lightBorder : AppColors.border;
  Color get _textPrimary =>
      _isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
  Color get _textMuted =>
      _isLight ? AppColors.lightTextMuted : AppColors.textMuted;
  Color get _textSecondary =>
      _isLight ? AppColors.lightTextSecondary : AppColors.textSecondary;

  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildProfileCard(),
                    const SizedBox(height: 24),

                    // ── APP SECTION ──────────────────
                    _sectionLabel('APP'),
                    _buildGroupCard([
                      _GroupRow(
                        icon: Icons.notifications_rounded,
                        iconBg: AppColors.secondary.withValues(alpha: 0.15),
                        iconColor: AppColors.secondary,
                        label: 'Notifications',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NotificationsScreen()),
                        ),
                      ),
                      _divider(),
                      _GroupRow(
                        icon: _isLight
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        iconBg: AppColors.amber.withValues(alpha: 0.15),
                        iconColor: AppColors.amber,
                        label: _isLight ?  : 'Dark Mode', 'Light Mode'
                        subtitle: _isLight
                            : 'Tap to switch to light',
                          ? 'Tap to switch to dark'
                        trailing: Switch(
                          value: _isLight,
                          onChanged: (_) => _themeProvider.toggleTheme(),
                          activeColor: AppColors.primary,
                          inactiveTrackColor: _border,
                          thumbColor: WidgetStateProperty.all(Colors.white),
                        ),
                        onTap: () => _themeProvider.toggleTheme(),
                      ),
                      _divider(),
                      _GroupRow(
                        icon: Icons.lock_rounded,
                        iconBg: AppColors.purple.withValues(alpha: 0.15),
                        iconColor: AppColors.purple,
                        label: 'Security',
                        subtitle: 'PIN & biometrics',
                        onTap: () => _showComingSoon('Security'),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // ── ACCOUNT SECTION ──────────────
                    _sectionLabel('ACCOUNT'),
                    _buildGroupCard([
                      _GroupRow(
                        icon: Icons.person_rounded,
                        iconBg: AppColors.primary.withValues(alpha: 0.12),
                        iconColor: AppColors.primary,
                        label: 'Edit Profile',
                        subtitle: 'Update your name, email and phone',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditProfileScreen()),
                        ),
                      ),
                      _divider(),
                      _GroupRow(
                        icon: Icons.delete_outline_rounded,
                        iconBg: AppColors.red.withValues(alpha: 0.12),
                        iconColor: AppColors.red,
                        label: 'Delete Account',
                        subtitle: 'Permanently remove your account',
                        onTap: _showDeleteConfirm,
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // ── PREFERENCES SECTION ──────────
                    _sectionLabel('PREFERENCES'),
                    _buildGroupCard([
                      _GroupRow(
                        icon: Icons.sync_rounded,
                        iconBg: AppColors.primary.withValues(alpha: 0.12),
                        iconColor: AppColors.primary,
                        label: 'Auto Refresh',
                        subtitle: 'Update device status every 30 seconds',
                        trailing: Switch(
                          value: _autoRefresh,
                          onChanged: (v) => setState(() => _autoRefresh = v),
                          activeColor: AppColors.primary,
                          inactiveTrackColor: _border,
                          thumbColor: WidgetStateProperty.all(Colors.white),
                        ),
                        onTap: () =>
                            setState(() => _autoRefresh = !_autoRefresh),
                      ),
                      _divider(),
                      _GroupRow(
                        icon: Icons.warning_amber_rounded,
                        iconBg: AppColors.amber.withValues(alpha: 0.15),
                        iconColor: AppColors.amber,
                        label: 'Safety Alerts',
                        subtitle: 'Show alerts for overvoltage and overload',
                        trailing: Switch(
                          value: _alertsEnabled,
                          onChanged: (v) =>
                              setState(() => _alertsEnabled = v),
                          activeColor: AppColors.primary,
                          inactiveTrackColor: _border,
                          thumbColor: WidgetStateProperty.all(Colors.white),
                        ),
                        onTap: () =>
                            setState(() => _alertsEnabled = !_alertsEnabled),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // ── ABOUT SECTION ────────────────
                    _sectionLabel('ABOUT'),
                    _buildGroupCard([
                      _GroupRow(
                        icon: Icons.info_outline_rounded,
                        iconBg: AppColors.primary.withValues(alpha: 0.12),
                        iconColor: AppColors.primary,
                        label: 'App Version',
                        subtitle: '1.0.0  ·  Build 2026',
                        onTap: null,
                        showChevron: false,
                      ),

                      _divider(),
                      _GroupRow(
                        icon: Icons.electrical_services_rounded,
                        iconBg: AppColors.primary.withValues(alpha: 0.12),
                        iconColor: AppColors.primary,
                        label: 'About Smart electic outlet',
                        subtitle: 'Version info and project details',
                        onTap: _showAboutDialog,
                      ),
                    ]),

                    const SizedBox(height: 32),
                    _buildLogoutButton(),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── WIDGETS ───────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child:
              Icon(Icons.arrow_back_rounded, color: _textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final auth = AuthService();
    final initial =
    auth.username.isNotEmpty ? auth.username[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 22,
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
                    auth.username.isEmpty ? 'My Profile' : auth.username,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    auth.email.isEmpty ? 'No email set' : auth.email,
                    style: TextStyle(fontSize: 12, color: _textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: _textMuted,
        ),
      ),
    );
  }

  Widget _buildGroupCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() =>
      Divider(height: 1, indent: 56, endIndent: 0, color: _border);

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: _surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: Text('Log Out',
                    style: TextStyle(
                        color: _textPrimary, fontWeight: FontWeight.w700)),
                content: Text('Are you sure you want to log out?',
                    style: TextStyle(color: _textMuted)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child:
                    Text('Cancel', style: TextStyle(color: _textMuted)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Log Out',
                        style: TextStyle(
                            color: AppColors.red,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
            if (confirmed == true && mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    (route) => false,
              );
            }
          },
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text(
            'Log Out',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.red.withValues(alpha: 0.1),
            foregroundColor: AppColors.red,
            elevation: 0,
            side: BorderSide(color: AppColors.red.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  // ── DIALOGS ───────────────────────────────────────────

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
              ),
              child: const Icon(Icons.electrical_services_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Smart electric outlet',
                style: TextStyle(
                    color: _textPrimary, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart Electric Outlet System',
              style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
            const SizedBox(height: 10),
            Text(
              'Smart electric outlet system is a smart home IoT system that allows users to remotely '
                  'monitor and control electric outlets from anywhere. It provides '
                  'real-time energy monitoring, automated scheduling, and safety '
                  'alerts for overvoltage and overload conditions.',
              style: TextStyle(color: _textMuted, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 14),
            _aboutRow('Version', '1.0.0'),
            _aboutRow('Platform', 'Android (Flutter)'),
            _aboutRow('Backend', 'Django REST Framework'),
            _aboutRow('Hardware', 'ESP32 Microcontroller'),
            _aboutRow('Released', '2026'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _aboutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label  ',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary)),
          Text(value,
              style: TextStyle(fontSize: 12, color: _textMuted)),
        ],
      ),
    );
  }

  void _showDeleteConfirm() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Account',
            style: TextStyle(
                color: _textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently delete your account and all associated devices and data. This action cannot be undone.',
          style: TextStyle(color: _textMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Delete',
                style: TextStyle(
                    color: AppColors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$feature coming soon'),
      backgroundColor: AppColors.surfaceColor,
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ── ROW WIDGET ────────────────────────────────────────────

class _GroupRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  const _GroupRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
    isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final mutedColor =
    isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textColor)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!,
                        style: TextStyle(fontSize: 11, color: mutedColor)),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (showChevron && onTap != null)
              Icon(Icons.chevron_right_rounded, color: mutedColor, size: 18),
          ],
        ),
      ),
    );
  }
}
