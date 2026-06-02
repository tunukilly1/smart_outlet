import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth.dart';
import '../theme/theme.dart';
import '../services/outlet_service.dart';
import '../models/room_model.dart';
import 'room.dart';
import 'settings.dart';
import 'all_rooms.dart';
import 'notifications.dart';
import '../services/device_api.dart';
import 'energy.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final OutletService _service = OutletService();
  final DeviceApiService _deviceApi = DeviceApiService();
  int _selectedIndex = 0;

  Timer? _refreshTimer;

  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  int get _notificationCount => _deviceApi.unreadAlerts;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final name = AuthService().username;
    if (hour < 12) return 'Good morning, $name 👋';
    if (hour < 17) return 'Good afternoon, $name 👋';
    return 'Good evening, $name 👋';
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _controller, curve: Curves.easeOut));
    _controller.forward();

    // Listen to service changes — rebuilds UI when data arrives
    _service.addListener(_onServiceChange);
    _deviceApi.addListener(_onDeviceApiChange);

    // Load data from backend on startup
    _loadData();

    _refreshTimer = Timer.periodic(
        const Duration(seconds: 30), (_) {
      // Only refresh if we are on home screen (not inside a room)
      if (mounted && _selectedIndex == 0 &&
          Navigator.of(context).canPop() == false) {
        _loadData();
      }
    });
  }


  Future<void> _loadData() async {
    await _service.fetchAndSync();
    await _deviceApi.fetchDevices();
    await _deviceApi.fetchAlerts();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChange);
    _deviceApi.removeListener(_onDeviceApiChange);
    _controller.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onServiceChange() => setState(() {});
  void _onDeviceApiChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
          body: FadeTransition(
        opacity: _fadeAnim,
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(child: _buildStatCards()),
                  SliverToBoxAdapter(child: _buildQuickActions()),
                  SliverToBoxAdapter(child: _buildSectionHeader()),
                  // Show loading spinner while fetching
                  if (_service.isLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                  color: AppColors.primary),
                              SizedBox(height: 12),
                              Text('Loading devices...',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    )

                  // Show error if fetch failed
                  else if (_service.error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_rounded,
                                size: 40, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text(_service.error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadData,
                              icon: const Icon(
                                  Icons.refresh_rounded, size: 16),
                              label: const Text('Try Again'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )

                  // Show empty state with Add Room button
                  else if (_service.rooms.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bedroom_parent_rounded,
                                size: 40, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text('No rooms added yet',
                                style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showAddRoomDialog,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add First Room'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )

                  // Show real rooms grid from backend
                  else
                    SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              if (index == _service.rooms.length) {
                                return _buildAddRoomCard();
                              }
                              return _buildRoomCard(
                                  _service.rooms[index]);
                            },
                            childCount: _service.rooms.length + 1,
                          ),
                          gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.1,
                          ),
                        ),
                      ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_getGreeting(),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                    color: context.textPrimary)),
          ]),
        ),
        GestureDetector(
          onTap: () {
            _deviceApi.clearAlerts();
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          },
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _notificationCount > 0
                  ? AppColors.primary.withOpacity(0.1)
                  : context.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _notificationCount > 0
                    ? AppColors.primary.withOpacity(0.3)
                    : context.borderColor,
              ),
            ),
            child: Stack(children: [
              Center(
                child: Icon(
                  _notificationCount > 0
                      ? Icons.notifications_rounded
                      : Icons.notifications_none_rounded,
                  color: _notificationCount > 0
                      ? AppColors.primary
                      : context.textSecondary,
                  size: 22,
                ),
              ),
              if (_notificationCount > 0)
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_notificationCount',
                        style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ─── STAT CARDS ───────────────────────────────────────────
  Widget _buildStatCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(children: [
        Expanded(child: _StatCard(
          value: _service.isLoading
              ? '—'
              : '${_service.totalOutlets}',
          label: 'Outlets',
          icon: Icons.power_rounded,
          gradient: [AppColors.purpleDark, AppColors.purple],
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
          value: _service.isLoading
              ? '—'
              : '${_service.totalActiveOutlets}',
          label: 'Active',
          icon: Icons.bolt_rounded,
          gradient: [AppColors.tealDark, AppColors.teal],
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
          value: _service.isLoading
              ? '—'
              : _service.totalKwhToday.toStringAsFixed(1),
          label: 'kWh',
          icon: Icons.electric_meter_rounded,
          gradient: [AppColors.amberDark, AppColors.amber],
        )),
      ]),
    );
  }
  // ─── QUICK ACTIONS ────────────────────────────────────────
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: context.textPrimary)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _QuickActionButton(
              icon: Icons.power_settings_new_rounded,
              label: 'All OFF',
              color: AppColors.red,
              onTap: () async {
                int count = 0;
                for (final room in _service.rooms) {
                  for (final outlet in room.outlets) {
                    if (outlet.isOn) {
                      await _service.toggleOutlet(outlet.id);
                      count++;
                    }
                  }
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(count > 0
                        ? '$count outlets turned off'
                        : 'All outlets already off'),
                    backgroundColor: AppColors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ));
                }
              },
            )),
            const SizedBox(width: 10),
            Expanded(child: _QuickActionButton(
              icon: Icons.wb_sunny_rounded,
              label: 'All ON',
              color: AppColors.primary,
              onTap: () async {
                int count = 0;
                for (final room in _service.rooms) {
                  for (final outlet in room.outlets) {
                    if (!outlet.isOn && !outlet.isEmpty) {
                      await _service.toggleOutlet(outlet.id);
                      count++;
                    }
                  }
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(count > 0
                        ? '$count outlets turned on'
                        : 'All outlets already on'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ));
                }
              },
            )),
            const SizedBox(width: 10),
            Expanded(child: _QuickActionButton(
              icon: Icons.refresh_rounded,
              label: 'Refresh',
              color: AppColors.secondary,
              onTap: () async {
                await _loadData();
                _service.fetchAndSync();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Devices refreshed'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ));
              },
            )),
          ]),
        ],
      ),
    );
  }

  // ─── SECTION HEADER ───────────────────────────────────────
  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(children: [
        Text('Rooms',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: context.textPrimary)),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AllRoomsScreen())),
          child: Row(children: [
            const Text('View all rooms',
                style: TextStyle(fontSize: 13, color: AppColors.primary,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 11, color: AppColors.primary),
          ]),
        ),
      ]),
    );
  }
  //------- ROOM CARD------------------------
  Widget _buildRoomCard(RoomModel room) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => RoomScreen(room: room))),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: room.hasActiveOutlet
                ? AppColors.primary.withValues(alpha: 0.2)
                : context.borderColor,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: room.hasActiveOutlet
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : context.borderColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(room.icon,
                  style: const TextStyle(fontSize: 20))),
            ),
            const Spacer(),
            if (room.hasActiveOutlet)
              Container(width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle)),
          ]),
          const Spacer(),
          Text(room.name,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: context.textPrimary)),
          const SizedBox(height: 2),
          Text('${room.totalOutlets} outlets · ${room.activeCount} on',
              style:  TextStyle(fontSize: 11, color: context.textMuted)),
        ]),
      ),
    );
  }


  //-------------------ADD ROOM CARD-------------------
  Widget _buildAddRoomCard() {
    return GestureDetector(
      onTap: _showAddRoomDialog,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 22),
          ),
           SizedBox(height: 8),
          Text('Add Room',
              style: TextStyle(fontSize: 12, color: context.textMuted)),
        ]),
      ),
    );
  }

  //--------------------ADD ROOM DIALOG----------------
  void _showAddRoomDialog() {
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Room',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: nameController,
                style:  TextStyle(
                  color: context.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter room name',
                  filled: true,
                  fillColor: context.surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.borderColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) {
                      return;
                    }

                    final icon = _getRoomIcon(
                      nameController.text,
                    );

                    _service.addRoom(
                      nameController.text.trim(),
                      icon,
                    );

                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Create Room',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── BOTTOM NAV ───────────────────────────────────────────
  Widget _buildBottomNav() {
    final items = [
      {
        'icon': Icons.home_rounded,
        'label': 'Home',
      },
      {
        'icon': Icons.bolt_rounded,
        'label': 'Energy',
      },
      {
        'icon': Icons.settings_rounded,
        'label': 'Settings',
      },
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: context.surfaceColor,
          border: Border(
            top: BorderSide(
              color: context.borderColor,
            ),
          ),
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final active = _selectedIndex == index;

            return Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });

                  if (index == 1) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EnergyScreen(),
                      ),
                    );
                  } else if (index == 2) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      items[index]['icon'] as IconData,
                      size: 24,
                      color: active
                          ? AppColors.primary
                          : context.textMuted,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items[index]['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: active
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: active
                            ? AppColors.primary
                            : context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  String _getRoomIcon(String roomName) {
    final name = roomName.toLowerCase();

    if (name.contains('living')) return '🛋️';
    if (name.contains('bed')) return '🛏️';
    if (name.contains('kitchen')) return '🍳';
    if (name.contains('bath')) return '🚿';
    if (name.contains('office')) return '💼';
    if (name.contains('game')) return '🎮';
    if (name.contains('study')) return '📚';
    if (name.contains('garage')) return '🚗';
    if (name.contains('dining')) return '🍽️';
    if (name.contains('guest')) return '🧳';
    if (name.contains('gym')) return '🏋️';
    return '🔌';
  }
}

// ─── HELPER WIDGETS ───────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final List<Color> gradient;

  const _StatCard({required this.value, required this.label,
    required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: gradient),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 18),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 22,
            fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({required this.icon, required this.label,
    required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 10, color: color,
              fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
