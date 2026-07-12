import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../screens/energy.dart';
import '../screens/settings.dart';

class BottomNavWidget extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const BottomNavWidget({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  static const List<Map<String, dynamic>> items = [
    {'icon': Icons.home_rounded, 'label': 'Home'},
    {'icon': Icons.bolt_rounded, 'label': 'Energy'},
    {'icon': Icons.settings_rounded, 'label': 'Settings'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceColor : AppColors.lightSurface,
        border: Border(
            top: BorderSide(
                color: isDark
                    ? AppColors.border
                    : AppColors.lightBorder)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 56,
          child: Row(
            children: List.generate(items.length, (i) {
              final active = selectedIndex == i;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    onTap(i);
                    if (i == 1) {
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const EnergyScreen()));
                    } else if (i == 2) {
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const SettingsScreen()));
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[i]['icon'] as IconData,
                        color: active
                            ? AppColors.primary
                            : (isDark
                            ? AppColors.textMuted
                            : AppColors.lightTextMuted),
                        size: 22,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[i]['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: active
                              ? AppColors.primary
                              : (isDark
                              ? AppColors.textMuted
                              : AppColors.lightTextMuted),
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
