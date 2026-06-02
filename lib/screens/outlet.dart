import 'dart:async';
import 'package:flutter/material.dart';
import '../models/outlet_model.dart';
import '../widget/energy_chart.dart';
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

  @override
  State<OutletScreen> createState() => _OutletScreenState();
}

class _OutletScreenState extends State<OutletScreen>
    with SingleTickerProviderStateMixin {
  final OutletService _service = OutletService();
  final ApiService _api = ApiService();
  late TabController _tabController;

  // Energy data
  List<double> _hourlyData = List.filled(24, 0.0);
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
    _tabController = TabController(length: 3, vsync: this);
    _service.addListener(() => setState(() {}));
    _loadAllData();

    // Auto refresh energy every 30 seconds
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _loadAllData());
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
      final hourly = List<double>.filled(24, 0.0);

      for (final record in history) {
        final timeStr = record['timestamp']?.toString() ?? '';
        final time = DateTime.tryParse(timeStr);
        if (time != null) {
          final kwh = double.tryParse(
              record['energy_kwh']?.toString() ?? '0') ?? 0.0;
          hourly[time.hour] += kwh;
        }
      }

      if (mounted) {
        setState(() {
          _hourlyData = hourly;
          _loadingEnergy = false;
        });
      }
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
    final formatted =
        '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}'
        'T${_pad(dt.hour)}:${_pad(dt.minute)}:00+03:00';
    return formatted;
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

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
          _buildStatusBanner(outlet),
          _buildStatCards(outlet),
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
                    color: AppColors.primary.withValues(alpha: 0.15),
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
                      color: Colors.black.withValues(alpha: 0.15),
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

  // ── STATUS BANNER ─────────────────────────────────────
  Widget _buildStatusBanner(OutletModel outlet) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: outlet.isOn
            ? AppColors.primary.withValues(alpha: 0.1)
            : (_isDark ? AppColors.surfaceLight
            : AppColors.lightSurface),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: outlet.isOn
                ? AppColors.primary.withValues(alpha: 0.3)
                : (_isDark ? AppColors.border
                : AppColors.lightBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: outlet.isOn
                    ? AppColors.primary : AppColors.textMuted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              outlet.isOn
                  ? 'Outlet is Powered ON'
                  : 'Outlet is Powered OFF',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: outlet.isOn
                    ? AppColors.primary
                    : (_isDark ? AppColors.textMuted
                    : AppColors.lightTextMuted),
              ),
            ),
          ]),
          Text(
            outlet.isOn
                ? '${outlet.wattsFormatted} · ${outlet.voltageFormatted}'
                : '0W · 0V',
            style: TextStyle(
                fontSize: 12,
                color: _isDark
                    ? AppColors.textMuted
                    : AppColors.lightTextMuted),
          ),
        ],
      ),
    );
  }

  // ── STAT CARDS ────────────────────────────────────────
  Widget _buildStatCards(OutletModel outlet) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(children: [
        _statCard('${outlet.kwhToday.toStringAsFixed(2)} kWh',
            'Used Today'),
        const SizedBox(width: 10),
        _statCard(outlet.runtimeFormatted, 'Runtime'),
        const SizedBox(width: 10),
        _statCard(outlet.isOn
            ? outlet.voltageFormatted : '0V', 'Voltage'),
      ]),
    );
  }

  Widget _statCard(String value, String label) {
    final surfaceColor =
    _isDark ? AppColors.surfaceLight : AppColors.lightSurface;
    final borderColor =
    _isDark ? AppColors.border : AppColors.lightBorder;
    final textColor =
    _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final mutedColor =
    _isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 10, color: mutedColor),
              textAlign: TextAlign.center),
        ]),
      ),
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
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
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
    final hasData = _hourlyData.any((v) => v > 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
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
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _loadingEnergy
                          ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
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
                isLoading: _loadingEnergy,
                isDark: _isDark,
                title: 'Energy Usage',
                subtitle: 'kWh per hour today',
              ),

              // Dynamic time labels based on real data
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _buildTimeLabels(),
                ),
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
    final textColor =
    _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final mutedColor =
    _isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Schedule',
                style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 4),
            Text('Set when this outlet powers ON and OFF',
                style: TextStyle(fontSize: 12, color: mutedColor)),
            const SizedBox(height: 16),

            // Existing schedules from backend
            if (_loadingSchedules)
              const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ))
            else if (_schedules.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isDark ? AppColors.surfaceLight
                      : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isDark
                      ? AppColors.border : AppColors.lightBorder),
                ),
                child: Row(children: [
                  Icon(Icons.schedule_rounded,
                      color: mutedColor, size: 18),
                  const SizedBox(width: 10),
                  Text('No schedules yet. Add one below.',
                      style: TextStyle(fontSize: 12,
                          color: mutedColor)),
                ]),
              )
            else
              ..._schedules.map((s) => _buildScheduleCard(s)),

            const SizedBox(height: 16),

            // Add new schedule button
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _showAddScheduleSheet(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Schedule',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final surfaceColor =
    _isDark ? AppColors.surfaceLight : AppColors.lightSurface;
    final borderColor =
    _isDark ? AppColors.border : AppColors.lightBorder;
    final textColor =
    _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final mutedColor =
    _isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    final startTime = _formatScheduleTime(
        schedule['start_time']?.toString() ?? '');
    final endTime = schedule['end_time'] != null
        ? _formatScheduleTime(schedule['end_time'].toString())
        : 'Indefinite';
    final repeat = schedule['repeat_pattern']?.toString() ?? 'daily';
    final scheduleId = schedule['id'] as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.schedule_rounded,
              color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$startTime → $endTime',
                    style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w700, color: textColor)),
                Text('Repeats $repeat',
                    style: TextStyle(fontSize: 11, color: mutedColor)),
              ]),
        ),
        if (scheduleId != null)
          GestureDetector(
            onTap: () => _deleteSchedule(scheduleId),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_rounded,
                  color: AppColors.red, size: 16),
            ),
          ),
      ]),
    );
  }

  String _formatScheduleTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
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
    TimeOfDay? onTime;
    TimeOfDay? offTime;
    bool noEndTime = false;

    showModalBottomSheet(
      context: context,
      backgroundColor:
      _isDark ? AppColors.surface : AppColors.lightSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24,
              MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: _isDark ? AppColors.border
                          : AppColors.lightBorder,
                      borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 16),
                Text('Add Schedule',
                    style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _isDark ? AppColors.textPrimary
                            : AppColors.lightTextPrimary)),
                const SizedBox(height: 20),

                // ON Time picker
                _timePicker(
                  label: 'ON Time',
                  icon: Icons.wb_sunny_rounded,
                  color: AppColors.primary,
                  time: onTime,
                  onTap: () async {
                    final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now());
                    if (picked != null) {
                      setModal(() => onTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),

                // OFF Time picker
                if (!noEndTime)
                  _timePicker(
                    label: 'OFF Time',
                    icon: Icons.nightlight_rounded,
                    color: AppColors.purple,
                    time: offTime,
                    onTap: () async {
                      final picked = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(
                              hour: 23, minute: 0));
                      if (picked != null) {
                        setModal(() => offTime = picked);
                      }
                    },
                  ),

                // No end time toggle (for devices like fridge)
                Row(children: [
                  Checkbox(
                    value: noEndTime,
                    onChanged: (v) =>
                        setModal(() => noEndTime = v ?? false),
                    activeColor: AppColors.primary,
                  ),
                  Text('No end time (runs indefinitely)',
                      style: TextStyle(
                          fontSize: 12,
                          color: _isDark ? AppColors.textMuted
                              : AppColors.lightTextMuted)),
                ]),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: onTime == null ? null : () async {
                      Navigator.pop(ctx);
                      await _saveSchedule(
                          onTime!, noEndTime ? null : offTime);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Schedule',
                        style: TextStyle(
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  Widget _timePicker({
    required String label,
    required IconData icon,
    required Color color,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    final surfaceColor =
    _isDark ? AppColors.surfaceLight : AppColors.lightSurface;
    final borderColor =
    _isDark ? AppColors.border : AppColors.lightBorder;
    final textColor =
    _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final mutedColor =
    _isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                      fontSize: 11, color: mutedColor)),
                  Text(
                    time != null ? time.format(context) : 'Tap to set',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: time != null ? color : mutedColor),
                  ),
                ]),
          ),
          Icon(Icons.edit_rounded, color: mutedColor, size: 16),
        ]),
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
              color: AppColors.primary, strokeWidth: 2));
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
                  style: TextStyle(
                      color: mutedColor, fontSize: 12)),
              Text('Activity appears when outlet is used',
                  style: TextStyle(
                      color: mutedColor, fontSize: 10)),
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
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.red.withValues(alpha: 0.1),
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

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
