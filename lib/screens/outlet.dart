import 'dart:async';
import 'package:flutter/material.dart';
import '../models/outlet_model.dart';
import '../widget/energy_chart.dart';
import '../widget/nav_bar.dart';
import '../services/outlet_service.dart';
import '../services/api_service.dart';
import '../theme/theme.dart';

class OutletScreen extends StatefulWidget {
  final OutletModel outlet;
  final String roomName;

  const OutletScreen({
    super.key,
    required this.outlet,
    required this.roomName,
  });

  OutletModel get _liveOutlet =>
      OutletService().getOutletById(outlet.id) ?? outlet;

  @override
  State<OutletScreen> createState() => _OutletScreenState();
}

class _OutletScreenState extends State<OutletScreen>
    with SingleTickerProviderStateMixin {
  final OutletService _service = OutletService();
  final ApiService _api = ApiService();
  late TabController _tabController;
  int _selectedIndex = 0;

  // Energy data
  List<double> _hourlyData = List.filled(24, 0.0);
  List<Map<String, dynamic>> _allReadings= [];
  bool _loadingEnergy = false;

  // Schedule data from backend
  List<Map<String, dynamic>> _schedules = [];
  bool _loadingSchedules = false;

  // Auto refresh timer
  Timer? _refreshTimer;

  // Helper to get real backend device ID
  int? get _backendId =>
      widget.outlet.backendId ?? int.tryParse(widget.outlet.id);

  bool get _isDark =>
      Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    OutletService().addListener(_onServiceChange);
    _tabController = TabController(length: 3, vsync: this);
    _service.addListener(() => setState(() {}));
    _loadAllData();

    // Auto refresh energy every 30 seconds
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 30), (_) {
      if (mounted) _fetchEnergyHistory();

      //=> _loadAllData()
    });
  }
  void _onServiceChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _fetchEnergyHistory(),
      _fetchSchedules(),
    ]);
  }

  // ── FETCH ENERGY FROM BACKEND ─────────────────────────
  Future<void> _fetchEnergyHistory() async {
    final deviceId = _backendId;
    if (deviceId == null) {
      setState(() => _loadingEnergy = false);
      return;
    }

    setState(() => _loadingEnergy = true);
    try {
      final history = await _api.getEnergyHistory(deviceId);

      if (history.isEmpty) {
        setState(() => _loadingEnergy = false);
        return;
      }

      // Sort by timestamp oldest first
      final sorted = List<Map<String, dynamic>>.from(
          history.map((e) => Map<String, dynamic>.from(e)));
      sorted.sort((a, b) {
        final ta = DateTime.tryParse(
            a['timestamp']?.toString() ?? '') ?? DateTime(2000);
        final tb = DateTime.tryParse(
            b['timestamp']?.toString() ?? '') ?? DateTime(2000);
        return ta.compareTo(tb);
      });

      // Filter to today's readings only
      final now = DateTime.now();
      final todayReadings = sorted.where((r) {
        final t = DateTime.tryParse(
          (r['timestamp']?.toString() ?? '')
              .replaceAll('Z', '')
              .replaceAll('+00:00', '')
              .replaceAll('+03:00', ''),
        );
        if (t == null) return false;
        return t.year == now.year &&
            t.month == now.month &&
            t.day == now.day;
      }).toList();

      debugPrint('Today readings: ${todayReadings.length}');
      debugPrint('Today date: ${now.year}-${now.month}-${now.day}');

// IMPORTANT: Only show today's readings
// If none exist for today, show empty (no energy today message)
      setState(() {
        _allReadings = todayReadings; // ← do NOT fall back to all readings
        _loadingEnergy = false;
      });
      if (todayReadings.isEmpty) {
        // Show all readings if none from today
        setState(() {
          _allReadings = sorted;
          _loadingEnergy = false;
        });
        return;
      }

      setState(() {
        _allReadings = todayReadings;
        _loadingEnergy = false;
      });
    } catch (e) {
      debugPrint('Energy fetch error: $e');
      if (mounted) setState(() => _loadingEnergy = false);
    }
  }
  // ── FETCH SCHEDULES FROM BACKEND ──────────────────────
  Future<void> _fetchSchedules() async {
    final deviceId = _backendId;
    if (deviceId == null) return;

    setState(() => _loadingSchedules = true);
    try {
      final allSchedules = await _api.getSchedules();
      // Filter schedules for this device only
      final deviceSchedules = allSchedules
          .where((s) =>
      s['device']?.toString() == deviceId.toString())
          .map((s) => Map<String, dynamic>.from(s))
          .toList();

      if (mounted) {
        setState(() {
          _schedules = deviceSchedules;
          _loadingSchedules = false;
        });
      }
    } catch (e) {
      debugPrint('Schedule fetch error: $e');
      if (mounted) setState(() => _loadingSchedules = false);
    }
  }

  // ── SAVE SCHEDULE TO BACKEND ──────────────────────────
  Future<void> _saveSchedule(
      TimeOfDay onTime, TimeOfDay? offTime) async {
    final deviceId = _backendId;
    if (deviceId == null) {
      _showSnack('Cannot save — device not synced with backend',
          AppColors.red);
      return;
    }

    try {
      // Build Tanzania UTC+3 timestamps
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day,
          onTime.hour, onTime.minute);
      final startStr = _toTzString(start);

      String? endStr;
      if (offTime != null) {
        var end = DateTime(now.year, now.month, now.day,
            offTime.hour, offTime.minute);
        // If end is before start, add 1 day
        if (end.isBefore(start)) {
          end = end.add(const Duration(days: 1));
        }
        endStr = _toTzString(end);
      }

      await _api.createSchedule(
        deviceId: deviceId,
        startTime: startStr,
        endTime: endStr,
        repeatPattern: 'daily',
      );

      _showSnack('Schedule saved successfully', AppColors.primary);
      await _fetchSchedules();
    } catch (e) {
      _showSnack('Failed to save schedule: ${e.toString()}',
          AppColors.red);
    }
  }

  // Convert DateTime to Tanzania UTC+3 string
  String _toTzString(DateTime dt) {
    // Send local time with Tanzania UTC+3 offset
    // Backend expects ISO 8601 with offset to schedule correctly
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}'
        'T${_pad(dt.hour)}:${_pad(dt.minute)}:00+03:00';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
//-------TOGGLE METHOD--------------------------
  Future<void> _toggleSchedule(int scheduleId) async {
    try {
      await _api.toggleSchedule(scheduleId);
      await _fetchSchedules();
    } catch (e) {
      _showSnack('Failed to toggle schedule', AppColors.red);
    }
  }

  // ── DELETE SCHEDULE FROM BACKEND ──────────────────────
  Future<void> _deleteSchedule(int scheduleId) async {
    try {
      await _api.deleteSchedule(scheduleId);
      _showSnack('Schedule deleted', AppColors.amber);
      await _fetchSchedules();
    } catch (e) {
      _showSnack('Failed to delete schedule', AppColors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final outlet = _service.getOutletById(widget.outlet.id) ??
        widget.outlet;
    return Scaffold(
      backgroundColor:
      _isDark ? AppColors.background : AppColors.lightBackground,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(outlet),
          _buildHealthCard(outlet),
          _buildTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEnergyTab(),
                _buildScheduleTab(),
                _buildHistoryTab(),

              ],
            ),
          ),
        ]),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── HEADER ────────────────────────────────────────────
  Widget _buildHeader(OutletModel outlet) {
    final textColor =
    _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final surfaceColor =
    _isDark ? AppColors.surfaceLight : AppColors.lightSurface;
    final borderColor =
    _isDark ? AppColors.border : AppColors.lightBorder;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Icon(Icons.arrow_back_rounded,
                color: textColor, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(outlet.deviceName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
                const SizedBox(height: 2),
                Text(widget.roomName,
                    style: TextStyle(
                        fontSize: 11, color: _isDark
                        ? AppColors.textMuted
                        : AppColors.lightTextMuted)),
              ]),
        ),
        // Toggle switch
        GestureDetector(
          onTap: () async {
            try {
              await _service.toggleOutlet(outlet.id);
            } catch (e) {
              _showSnack('Failed to sync with server',
                  AppColors.red);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 52, height: 30,
            decoration: BoxDecoration(
              color: outlet.isOn
                  ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(15),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              alignment: outlet.isOn
                  ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 24, height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4)],
                ),
                child: Icon(Icons.power_settings_new_rounded,
                    size: 14,
                    color: outlet.isOn
                        ? AppColors.primary : AppColors.textMuted),
              ),
            ),
          ),
        ),
      ]),
    );
  }



   // ── HEALTH CARD ───────────────────────────────────────
  Widget _buildHealthCard(OutletModel outlet) {
    final isHealthy = outlet.watts < 3000 && outlet.voltage < 260;
    final surfaceColor =
    _isDark ? AppColors.surfaceLight : AppColors.lightSurface;
    final borderColor =
    _isDark ? AppColors.border : AppColors.lightBorder;
    final mutedColor =
    _isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(children: [
        Icon(
          isHealthy
              ? Icons.check_circle_rounded
              : Icons.warning_rounded,
          color: isHealthy ? AppColors.primary : AppColors.red,
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Outlet Health',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
                Text(
                  outlet.isOn
                      ? (isHealthy ? 'Optimal' : 'Warning')
                      : 'Outlet Off',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: outlet.isOn
                          ? (isHealthy
                          ? AppColors.primary : AppColors.red)
                          : mutedColor),
                ),
              ]),
        ),
        Text(
          outlet.isOn
              ? '${outlet.watts.toStringAsFixed(0)}W draw'
              : '0W draw',
          style: TextStyle(fontSize: 12, color: mutedColor),
        ),
      ]),
    );
  }

  // ── TABS ──────────────────────────────────────────────
  Widget _buildTabs() {
    final surfaceColor =
    _isDark ? AppColors.surfaceLight : AppColors.lightSurface;
    final mutedColor =
    _isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        indicatorSize:TabBarIndicatorSize.tab,
        labelPadding: EdgeInsets.symmetric(vertical:12, horizontal:16),
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        dividerColor:Colors.transparent,
        labelColor: Colors.black,
        unselectedLabelColor: mutedColor,
        labelStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: 'Energy'),
          Tab(text: 'Schedule'),
          Tab(text: 'History'),
        ],
      ),
    );
  }

  // ── ENERGY TAB ────────────────────────────────────────
  Widget _buildEnergyTab() {
    final surfaceColor =
    _isDark ? AppColors.surfaceLight : AppColors.lightSurface;
    final borderColor =
    _isDark ? AppColors.border : AppColors.lightBorder;
    final textColor =
    _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final mutedColor =
    _isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(5  ),
          border: Border.all(color: borderColor),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Energy Usage', style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: textColor)),
                        Text('kWh per hour today',
                            style: TextStyle(fontSize: 11,
                                color: mutedColor)),
                      ]),
                  // Refresh button
                  GestureDetector(
                    onTap: _fetchEnergyHistory,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _loadingEnergy
                          ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 5,
                              color: AppColors.primary))
                          : const Icon(Icons.refresh_rounded,
                          size: 16, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              EnergyChartWidget(
                hourlyData: _hourlyData,
                allReadings: _allReadings,
                isLoading: _loadingEnergy,
                isDark: _isDark,

              ),

            ]),
      ),
    );
  }

  // Build time labels dynamically
  List<Widget> _buildTimeLabels() {
    final mutedColor =
    _isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final now = DateTime.now();
    final labels = <String>[];

    // Show 5 time markers across 24 hours
    for (int i = 0; i < 5; i++) {
      final hour = (i * 6) % 24;
      final dt = DateTime(now.year, now.month, now.day, hour);
      labels.add(_formatHour(dt));
    }

    return labels.map((l) => Text(l,
        style: TextStyle(fontSize: 9, color: mutedColor))).toList();
  }

  String _formatHour(DateTime dt) {
    final h = dt.hour;
    if (h == 0) return '12am';
    if (h < 12) return '${h}am';
    if (h == 12) return '12pm';
    return '${h - 12}pm';
  }

  // ── SCHEDULE TAB ──────────────────────────────────────
  Widget _buildScheduleTab() {
    final textColor = _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final mutedColor = _isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final surfaceColor = _isDark ? AppColors.surfaceLight : AppColors.lightSurface;
    final borderColor = _isDark ? AppColors.border : AppColors.lightBorder;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.schedule_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Schedules', style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: textColor)),
              Text('Automate when this outlet powers on or off',
                  style: TextStyle(fontSize: 12, color: mutedColor)),
            ]),
          ]),

          const SizedBox(height: 24),

          // Schedule list / empty / loading
          if (_loadingSchedules)
            Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2),
            ))
          else if (_schedules.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(children: [
                Icon(Icons.schedule_outlined, size: 36, color: mutedColor),
                const SizedBox(height: 10),
                Text('No schedules yet',
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 4),
                Text('Tap the button below to create one',
                    style: TextStyle(fontSize: 12, color: mutedColor)),
              ]),
            )
          else
            ..._schedules.map((s) => _buildScheduleCard(s)),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _showAddScheduleSheet,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add New Schedule',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final textColor = _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final mutedColor = _isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final surfaceColor = _isDark ? AppColors.surfaceLight : AppColors.lightSurface;
    final borderColor = _isDark ? AppColors.border : AppColors.lightBorder;

    final bool isActive = (schedule['status']?.toString() ?? 'active') == 'active';
    final rawStart = schedule['start_time']?.toString() ?? '';
    final rawEnd = schedule['end_time']?.toString();
    final startTime = rawStart.isNotEmpty ? _formatScheduleTime(rawStart) : null;
    final endTime = rawEnd != null ? _formatScheduleTime(rawEnd) : null;
    final repeat = schedule['repeat_pattern']?.toString() ?? '';
    final scheduleId = schedule['id'] as int?;

    // Build a human-readable summary line
    String summary;
    if (startTime != null && endTime != null) {
      summary = 'ON at $startTime · OFF at $endTime';
    } else if (startTime != null) {
      summary = 'Turns ON at $startTime · runs indefinitely';
    } else if (endTime != null) {
      summary = 'Turns OFF at $endTime';
    } else {
      summary = 'Runs indefinitely';
    }

    final repeatLabel = repeat.isEmpty
        ? 'No repeat'
        : repeat[0].toUpperCase() + repeat.substring(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Left accent bar
        Container(
          width: 4, height: 52,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : mutedColor.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(summary, style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.repeat_rounded, size: 13, color: mutedColor),
                const SizedBox(width: 4),
                Text(repeatLabel,
                    style: TextStyle(fontSize: 12, color: mutedColor)),
              ]),
            ],
          ),
        ),
        if (scheduleId != null) ...[
          Transform.scale(
            scale: 0.75,
            child: Switch(
              value: isActive,
              activeColor: Colors.white,
              activeTrackColor: AppColors.primary,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: mutedColor.withValues(alpha: 0.3),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              onChanged: (_) => _toggleSchedule(scheduleId),
            ),
          ),
          GestureDetector(
            onTap: () => _deleteSchedule(scheduleId),
            child: Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Icon(Icons.delete_outline_rounded,
                  color: AppColors.red, size: 20),
            ),
          ),
        ],
      ]),
    );
  }

  String _formatScheduleTime(String isoString) {
    try {
      // Parse without any timezone conversion, Backend already stores correct Tanzania time
      final cleanString = isoString.replaceAll('Z', '').replaceAll('+03:00', '');
      final dt = DateTime.parse(cleanString);
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = h < 12 ? 'AM' : 'PM';
      final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$hour:$m $period';
    } catch (_) {
      return isoString;
    }
  }
  void _showAddScheduleSheet() {
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    bool isIndefinite = false;
    String repeatPattern = 'daily';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? AppColors.surface : AppColors.lightSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final textColor = _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
          final mutedColor = _isDark ? AppColors.textMuted : AppColors.lightTextMuted;
          final surfaceColor = _isDark ? AppColors.surfaceLight : AppColors.lightSurface;
          final borderColor = _isDark ? AppColors.border : AppColors.lightBorder;

          // Reusable time display tile
          Widget timeTile(TimeOfDay t, VoidCallback onTap, {bool isEnd = false}) {
            return GestureDetector(
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Icon(isEnd ? Icons.power_settings_new_rounded
                      : Icons.wb_sunny_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 12),
                  Text(t.format(ctx),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                  const Spacer(),
                  Icon(Icons.edit_rounded, color: mutedColor, size: 15),
                ]),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                24, 12, 24, MediaQuery.of(ctx).viewInsets.bottom + 28),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )),
                  const SizedBox(height: 20),

                  Text('Add Schedule', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
                  const SizedBox(height: 4),
                  Text('Choose what to automate',
                      style: TextStyle(fontSize: 12, color: mutedColor)),
                  const SizedBox(height: 20),

                  // ── Turn ON row ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(children: [
                      Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.wb_sunny_rounded,
                              color: AppColors.primary, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Turn ON', style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: textColor)),
                            Text('Set a start time',
                                style: TextStyle(fontSize: 11, color: mutedColor)),
                          ],
                        )),
                        Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: startTime != null,
                            activeColor: Colors.white,
                            activeTrackColor: AppColors.primary,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: mutedColor.withValues(alpha: 0.2),
                            trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return AppColors.primary;
                              }
                              return mutedColor.withValues(alpha: 0.3);
                            }),
                            onChanged: (val) async {
                              if (val) {
                                final t = await showTimePicker(
                                    context: context,
                                    initialTime: const TimeOfDay(hour: 7, minute: 0));
                                if (t != null) setModal(() => startTime = t);
                              } else {
                                setModal(() => startTime = null);
                              }
                            },
                          ),
                        ),
                      ]),
                      if (startTime != null)
                        timeTile(startTime!, () async {
                          final t = await showTimePicker(
                              context: context, initialTime: startTime!);
                          if (t != null) setModal(() => startTime = t);
                        }),
                    ]),
                  ),

                  const SizedBox(height: 10),

                  // ── Turn OFF row ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(children: [
                      Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: (isIndefinite ? mutedColor : AppColors.red)
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.power_settings_new_rounded,
                              color: isIndefinite ? mutedColor : AppColors.red,
                              size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Turn OFF', style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: isIndefinite ? mutedColor : textColor)),
                            Text(isIndefinite
                                ? 'Disabled — running indefinitely'
                                : 'Set an end time',
                                style: TextStyle(fontSize: 11, color: mutedColor)),
                          ],
                        )),
                        Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: endTime != null && !isIndefinite,
                            activeColor: Colors.white,
                            activeTrackColor: AppColors.primary,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: mutedColor.withValues(alpha: 0.2),
                            trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return AppColors.primary;
                              }
                              return mutedColor.withValues(alpha: 0.3);
                            }),
                            onChanged: isIndefinite ? null : (val) async {
                              if (val) {
                                final t = await showTimePicker(
                                    context: context,
                                    initialTime: const TimeOfDay(hour: 22, minute: 0));
                                if (t != null) setModal(() => endTime = t);
                              } else {
                                setModal(() => endTime = null);
                              }
                            },
                          ),
                        ),
                      ]),
                      if (endTime != null && !isIndefinite)
                        timeTile(endTime!, () async {
                          final t = await showTimePicker(
                              context: context, initialTime: endTime!);
                          if (t != null) setModal(() => endTime = t);
                        }, isEnd: true),
                    ]),
                  ),

                  const SizedBox(height: 10),

                  // ── Run indefinitely ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isIndefinite
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : borderColor,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(
                              alpha: isIndefinite ? 0.15 : 0.07),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.all_inclusive_rounded,
                            color: AppColors.primary, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Run indefinitely', style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: textColor)),
                          Text('Stays on until manually turned off',
                              style: TextStyle(fontSize: 11, color: mutedColor)),
                        ],
                      )),
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: isIndefinite,
                        activeColor: Colors.white,
                        activeTrackColor: AppColors.primary,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: mutedColor.withValues(alpha: 0.2),
                        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return AppColors.primary;
                          }
                          return mutedColor.withValues(alpha: 0.3);
                        }),
                        onChanged: (val) => setModal(() {
                          isIndefinite = val;
                          if (val) endTime = null;
                        }),
                      ),
                    ),
                    ]),
                  ),

                  const SizedBox(height: 20),

                  // ── Repeat ─────────────────────────────────────────
                  Text('REPEAT', style: TextStyle(
                      fontSize: 10, color: mutedColor,
                      fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      {'label': 'Daily', 'value': 'daily'},
                      {'label': 'Weekly', 'value': 'weekly'},
                      {'label': 'Once', 'value': 'once'},
                      {'label': 'None', 'value': ''},
                    ].map((opt) {
                      final selected = repeatPattern == opt['value'];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModal(() => repeatPattern = opt['value']!),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : surfaceColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected ? AppColors.primary : borderColor,
                              ),
                            ),
                            child: Text(opt['label']!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: selected ? AppColors.primary : mutedColor,
                                )),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // ── Save button ────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : () async {
                        if (_backendId == null) {
                          _showSnack('Cannot save — device not synced with backend',
                              AppColors.red);
                          return;
                        }
                        if (startTime == null && endTime == null && !isIndefinite) {
                          _showSnack('Set a start time, end time, or choose Run Indefinitely.',
                              AppColors.red);
                          return;
                        }
                        setModal(() => isSaving = true);

                        final now = DateTime.now();
                        String? startIso;
                        String? endIso;

                        DateTime? startDt;
                        if (startTime != null) {
                          startDt = DateTime(now.year, now.month,
                              now.day, startTime!.hour, startTime!.minute);
                          // If time already passed today, schedule for tomorrow
                          if (startDt.isBefore(now)) {
                            startDt = startDt.add(const Duration(days: 1));
                          }
                          startIso = _toTzString(startDt);
                        }

                        if (endTime != null && !isIndefinite) {
                          var endDt = DateTime(now.year, now.month,
                              now.day, endTime!.hour, endTime!.minute);

                          if (startDt != null) {
                            // If end is before start, it must be the next day
                            if (endDt.isBefore(startDt)) {
                              endDt = endDt.add(const Duration(days: 1));
                            }
                          } else {
                            // Only OFF time set, check against now
                            if (endDt.isBefore(now)) {
                              endDt = endDt.add(const Duration(days: 1));
                            }
                          }
                          endIso = _toTzString(endDt);
                        }

                        try {
                          await _api.saveSchedule(
                            deviceId: _backendId!,
                            startTime: startIso,
                            endTime: endIso,
                            repeatPattern: repeatPattern,
                          );
                          if (mounted) Navigator.pop(context);
                          _fetchSchedules();
                        } catch (e) {
                          setModal(() => isSaving = false);
                          _showSnack('Failed to save schedule. Try again.', AppColors.red);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : const Text('Save Schedule',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ]),
          );
        },
      ),
    );
}

   // ── HISTORY TAB ───────────────────────────────────────
  Widget _buildHistoryTab() {
    final textColor =
    _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final mutedColor =
    _isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return FutureBuilder<Map<String, dynamic>>(
      future: _api.getControlLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 5));
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.history_rounded,
                  color: mutedColor, size: 32),
              const SizedBox(height: 8),
              Text('Could not load history',
                  style: TextStyle(color: mutedColor,
                      fontSize: 12)),
            ]),
          );
        }

        final allLogs = snapshot.data!['control_logs']
        as List<dynamic>? ?? [];
        final backendId = _backendId;

        // Filter logs for this device only
        final logs = backendId != null
            ? allLogs.where((l) =>
        l['device']?.toString() ==
            backendId.toString()).toList()
            : allLogs;

        if (logs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.history_rounded,
                  color: mutedColor, size: 32),
              const SizedBox(height: 8),
              Text('No activity yet',
                  style: TextStyle(color: mutedColor, fontSize: 12)),
            ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            final action = log['action']?.toString() ?? 'ON';
            final isOn = action.toUpperCase() == 'ON';
            final source = log['control_source']?.toString() ?? '';
            final timeStr = log['timestamp']?.toString() ?? '';
            final time = DateTime.tryParse(timeStr);

            final sourceLabel = source == 'mobile_app'
                ? 'Via App'
                : source == 'schedule'
                ? 'Auto Schedule'
                : source == 'schedule_ended'
                ? 'Schedule Ended'
                : source;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isDark ? AppColors.surfaceLight
                    : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isDark
                    ? AppColors.border : AppColors.lightBorder),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isOn
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isOn ? Icons.power_rounded
                        : Icons.power_off_rounded,
                    color: isOn ? AppColors.primary : AppColors.red,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Turned ${action.toUpperCase()}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textColor),
                        ),
                        Text(sourceLabel,
                            style: TextStyle(
                                fontSize: 11, color: mutedColor)),
                      ]),
                ),
                Text(
                  time != null ? _timeAgo(time) : '',
                  style: TextStyle(
                      fontSize: 11, color: mutedColor),
                ),
              ]),
            );
          },
        );
      },
    );
  }
  String _timeAgo(DateTime dt) {
    try {
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds < 0) return 'just now';
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';

      final day   = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final hour  = dt.hour.toString().padLeft(2, '0');
      final min   = dt.minute.toString().padLeft(2, '0');
      return '$day/$month $hour:$min';
    } catch (_) {
      return dt.toString();
    }
  }

  // ─── BOTTOM NAV ──────
  Widget _buildBottomNav() {
    return BottomNavWidget(
      selectedIndex: _selectedIndex,
      onTap: (i) => setState(() => _selectedIndex = i),
    );
  }
}
