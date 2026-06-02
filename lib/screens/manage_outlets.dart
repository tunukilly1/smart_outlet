import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/wifi_service.dart';
import '../theme/theme.dart';
import '../services/outlet_service.dart';
import '../models/outlet_model.dart';
import '../services/device_api.dart';
import '../widget/wifi_picker.dart';

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
  late TabController _tabController;
  int _selectedTab = 0;

  List<double> _hourlyData = List.filled(24, 0.0);
  bool _loadingEnergy = false;
  Future<void> _fetchEnergyHistory() async {
    // Use backendId (real integer ID from backend)
    final deviceId = widget.outlet.backendId ??
        int.tryParse(widget.outlet.id);

    if (deviceId == null) {
      setState(() => _loadingEnergy = false);
      return;
    }

    setState(() => _loadingEnergy = true);
    try {
      final history = await ApiService().getEnergyHistory(deviceId);
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

      setState(() {
        _hourlyData = hourly;
        _loadingEnergy = false;
      });
    } catch (e) {
      setState(() => _loadingEnergy = false);
    }
  }
  List<Map<String, dynamic>> _monthLogs = [];
  Future<void> _fetchMonthHistory() async {
    try {
      final history = await ApiService()
          .getEnergyHistory(int.parse(widget.outlet.id));

      setState(() {
        _monthLogs = history.map((record) {
          final time = DateTime.tryParse(record['timestamp'] ?? '');
          return {
            'date': time != null
                ? '${_dayName(time.weekday)}, ${_monthName(time.month)} ${time.day}'
                : 'Unknown',
            'onTime': '—',
            'offTime': '—',
            'kwh': (record['energy_kwh'] ?? 0.0) as double,
            'runtime': '—',
          };
        }).toList();
      });
    } catch (e) {}
  }

  String _dayName(int day) {
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return days[(day - 1) % 7];
  }

  String _monthName(int month) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[month - 1];
  }

  OutletModel get _outlet =>
      _service.getOutletById(widget.outlet.id) ?? widget.outlet;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _service.addListener(() => setState(() {}));
    _fetchEnergyHistory();
    _fetchMonthHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  IconData get _deviceIcon {
    switch (_outlet.deviceType) {
      case 'tv': return Icons.tv_rounded;
      case 'lamp': return Icons.light_rounded;
      case 'router': return Icons.router_rounded;
      case 'speaker': return Icons.speaker_rounded;
      case 'fan': return Icons.air_rounded;
      case 'fridge': return Icons.kitchen_rounded;
      case 'microwave': return Icons.microwave_rounded;
      case 'charger': return Icons.electrical_services_rounded;
      default: return Icons.power_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final outlet = _outlet;
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, outlet),
              _buildOutletInfo(outlet),
              _buildStatusCard(outlet),
              _buildEnergyStats(outlet),
              _buildHealthIndicator(outlet),
              _buildEnergyGraph(),
              _buildScheduleSection(outlet),
              _buildAutoShutoff(),
              _buildEnergyAlert(),
              _buildPluggedDevice(context, outlet),
              _buildViewHistoryButton(context),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, OutletModel outlet) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: context.surfaceColor, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(Icons.arrow_back_rounded, color: context.textPrimary, size: 18),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Outlet ${outlet.outletNumber}',
                    style:  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(widget.roomName,
                style:  TextStyle(fontSize: 12, color: context.textMuted)),
          ]),
        ),
        // Main ON/OFF toggle
        GestureDetector(
          onTap: () => _service.toggleOutlet(outlet.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 56, height: 32,
            decoration: BoxDecoration(
              color: outlet.isOn ? AppColors.primary : context.borderColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              alignment: outlet.isOn ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 26, height: 26,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(
                  outlet.isOn ? Icons.power_rounded : Icons.power_off_rounded,
                  size: 14,
                  color: outlet.isOn ? AppColors.primary : context.textMuted,
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ─── OUTLET INFO (what's plugged in) ──────────────────────
  Widget _buildOutletInfo(OutletModel outlet) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: outlet.isOn
                ? AppColors.primary.withOpacity(0.15)
                : context.borderColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(_deviceIcon,
              color: outlet.isOn ? AppColors.primary : context.textMuted, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(outlet.deviceName,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary)),
          const SizedBox(height: 2),
          Text('Plugged into Outlet ${outlet.outletNumber}',
              style: TextStyle(fontSize: 12, color: context.textMuted)),
        ])),
      ]),
    );
  }

  // ─── STATUS CARD ──────────────────────────────────────────
  Widget _buildStatusCard(OutletModel outlet) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: outlet.isOn ? AppColors.primary.withOpacity(0.1) : context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: outlet.isOn ? AppColors.primary.withOpacity(0.3) : context.borderColor),
      ),
      child: Row(children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(
              color: outlet.isOn ? AppColors.primary : context.textMuted,
              shape: BoxShape.circle,
            )),
        const SizedBox(width: 10),
        Text(outlet.isOn ? 'Outlet is Powered ON' : 'Outlet is Powered OFF',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: outlet.isOn ? AppColors.primary : context.textMuted)),
        const Spacer(),
        if (outlet.isOn)
          Text('${outlet.watts.toInt()}W · ${outlet.voltageFormatted}',
              style:  TextStyle(fontSize: 12, color: context.textMuted)),
      ]),
    );
  }

  // ─── ENERGY STATS ─────────────────────────────────────────
  Widget _buildEnergyStats(OutletModel outlet) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(children: [
        _EnergyCard(value: '${outlet.kwhToday.toStringAsFixed(1)} kWh', label: 'Used Today'),
        const SizedBox(width: 10),
        _EnergyCard(value: outlet.runtimeFormatted, label: 'Runtime'),
        const SizedBox(width: 10),
        _EnergyCard(value: outlet.voltageFormatted, label: 'Voltage'),
      ]),
    );
  }

  // ─── HEALTH ───────────────────────────────────────────────
  Widget _buildHealthIndicator(OutletModel outlet) {
    String status; Color color; IconData icon;
    if (!outlet.isOn) {
      status = 'Outlet Off'; color = context.textMuted; icon = Icons.pause_circle_rounded;
    } else if (outlet.watts > 500) {
      status = 'High Load'; color = AppColors.red; icon = Icons.warning_rounded;
    } else if (outlet.watts > 200) {
      status = 'Normal Load'; color = AppColors.amber; icon = Icons.check_circle_rounded;
    } else {
      status = 'Optimal'; color = AppColors.primary; icon = Icons.check_circle_rounded;
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Outlet Health', style: TextStyle(fontSize: 11, color: context.textMuted)),
          Text(status, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ]),
        const Spacer(),
        Text('${outlet.watts.toInt()}W draw', style: TextStyle(fontSize: 11, color: context.textMuted)),
      ]),
    );
  }

  // ─── ENERGY GRAPH ─────────────────────────────────────────
  Widget _buildEnergyGraph() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        color: context.surfaceColor, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Energy Usage', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary)),
              Text('kWh per hour today', style: TextStyle(fontSize: 11, color: context.textMuted)),
            ])),
            Container(
              decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: ['Today', 'Week', ].asMap().entries.map((e) {
                  final selected = _selectedTab == e.key;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTab = e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(e.value, style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.black : context.textMuted)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: _loadingEnergy
              ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))
              : _hourlyData.every((v) => v == 0)
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bar_chart_rounded,
                    color: AppColors.textMuted, size: 32),
                const SizedBox(height: 8),
                Text('No energy data yet',
                    style: TextStyle(
                        color: context.textMuted,
                        fontSize: 12)),
              ],
            ),
          )
              : CustomPaint(
            painter: _ChartPainter(data: _hourlyData),
            child: Container(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['12am', '6am', '12pm', '6pm', '11pm']
                .map((t) => Text(t, style: TextStyle(fontSize: 9, color: context.textMuted)))
                .toList(),
          ),
        ),
      ]),
    );
  }
  // ─── SCHEDULE ─────────────────────────────────────────────
  Widget _buildScheduleSection(OutletModel outlet) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Set when this outlet powers ON and OFF',
            style: TextStyle(
              fontSize: 11,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ScheduleButton(
                  label: 'ON Time',
                  value: outlet.onTime,
                  icon: Icons.wb_sunny_rounded,
                  color: AppColors.primary,
                  onTap: () => _pickTime(
                    context,
                    outlet,
                    isOnTime: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ScheduleButton(
                  label: 'OFF Time',
                  value: outlet.offTime,
                  icon: Icons.nights_stay_rounded,
                  color: AppColors.secondary,
                  onTap: () => _pickTime(
                    context,
                    outlet,
                    isOnTime: false,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(
      BuildContext context,
      OutletModel outlet, {
        required bool isOnTime,
      }) async {
    final timeStr = isOnTime ? outlet.onTime : outlet.offTime;
    final parts = timeStr.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    final int minute = int.parse(timeParts[1]);
    final bool isPm = parts[1] == 'PM';

    if (isPm && hour != 12) {
      hour += 12;
    }
    if (!isPm && hour == 12) {
      hour = 0;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: hour,
        minute: minute,
      ),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.primary,
            surface: context.surface,
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: context.surface,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      final formatted = picked.format(context);
      final String onTime = isOnTime ? formatted : outlet.onTime;
      final String offTime = isOnTime ? outlet.offTime : formatted;

      _service.updateSchedule(
        outlet.id,
        onTime,
        offTime,
      );

      try {
        final now = DateTime.now();
        final startTime = _convertToDateTime(onTime, now);
        final endTime = _convertToDateTime(offTime, now);

        await ApiService().createSchedule(
          deviceId: int.parse(outlet.id),
          startTime: startTime.toIso8601String(),
          endTime: endTime.toIso8601String(),
          repeatPattern: 'daily',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Schedule saved successfully',
            ),
          ),
        );
      } catch (e) {
        print('Schedule Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString(),
            ),
          ),
        );
      }
    }
  }

  DateTime _convertToDateTime(
      String time,
      DateTime baseDate,
      ) {
    final parts = time.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    final int minute = int.parse(timeParts[1]);
    final bool isPm = parts[1] == 'PM';

    if (isPm && hour != 12) {
      hour += 12;
    }
    if (!isPm && hour == 12) {
      hour = 0;
    }
    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      hour,
      minute,
    );
  }

  // ─── AUTO SHUTOFF ─────────────────────────────────────────
  Widget _buildAutoShutoff() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.timer_rounded, color: AppColors.amber, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Auto Shutoff', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary)),
          Text('Cut power after set hours', style: TextStyle(fontSize: 11, color: context.textMuted)),
        ])),
        GestureDetector(
          onTap: _showAutoShutoffPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.amber.withOpacity(0.12), borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.amber.withOpacity(0.3)),
            ),
            child: const Text('Set', style: TextStyle(fontSize: 12, color: AppColors.amber, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  void _showAutoShutoffPicker() {
    int selectedHours = 2;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Auto Shutoff Timer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary)),
            const SizedBox(height: 6),
            Text('Outlet will cut power after $selectedHours hours',
                style: TextStyle(fontSize: 12, color: context.textMuted)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              children: [1, 2, 4, 6, 8, 12].map((h) {
                final selected = selectedHours == h;
                return GestureDetector(
                  onTap: () => setModal(() => selectedHours = h),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary.withOpacity(0.15) : context.surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? AppColors.primary : context.borderColor),
                    ),
                    child: Text('$h hr', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: selected ? AppColors.primary : context.textSecondary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Auto shutoff set for $selectedHours hours'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── ENERGY ALERT ─────────────────────────────────────────
  Widget _buildEnergyAlert() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications_active_rounded, color: AppColors.red, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Energy Alert', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary)),
          Text('Alert when kWh exceeds limit', style: TextStyle(fontSize: 11, color: context.textMuted)),
        ])),
        GestureDetector(
          onTap: _showAlertPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.red.withOpacity(0.3)),
            ),
            child: const Text('Set', style: TextStyle(fontSize: 12, color: AppColors.red, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  void _showAlertPicker() {
    double threshold = 3.0;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Energy Alert Threshold',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary)),
            const SizedBox(height: 20),
            Slider(
              value: threshold, min: 0.5, max: 10.0, divisions: 19,
              activeColor: AppColors.red, inactiveColor: context.borderColor,
              onChanged: (val) => setModal(() => threshold = val),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('0.5 kWh', style: TextStyle(fontSize: 11, color: context.textMuted)),
              Text('${threshold.toStringAsFixed(1)} kWh',
                  style:  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.red)),
              Text('10 kWh', style: TextStyle(fontSize: 11, color: context.textMuted)),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Alert set for ${threshold.toStringAsFixed(1)} kWh'),
                    backgroundColor: AppColors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Save Alert', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── PLUGGED DEVICE ───────────────────────────────────────

  Widget _buildPluggedDevice(BuildContext context, OutletModel outlet) {
    final wifiCreds = WiFiService().getCredentials(outlet.id);
    final connectedSSID = wifiCreds?.ssid;

    return Column(children: [
      // Device info card
      Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.electrical_services_rounded,
                color: AppColors.secondary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Plugged Device',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: context.textPrimary)),
            Text(outlet.deviceName,
                style: TextStyle(fontSize: 11, color: context.textMuted)),
          ])),
          GestureDetector(
            onTap: () {
              _service.unplugDevice(outlet.id);
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.red.withOpacity(0.3)),
              ),
              child: const Text('Unplug',
                  style: TextStyle(fontSize: 12, color: AppColors.red,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),

      // WiFi card
      Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.wifi_rounded,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('WiFi Network',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: context.textPrimary)),
            Text(
              connectedSSID ?? 'Not connected to any network',
              style: TextStyle(
                fontSize: 11,
                color: connectedSSID != null
                    ? AppColors.primary : context.textMuted,
              ),
            ),
          ])),
          GestureDetector(
            onTap: () => _showEditWifiSheet(context, outlet),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Text(
                connectedSSID != null ? 'Edit' : 'Connect',
                style: const TextStyle(fontSize: 12,
                    color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
  // ─── VIEW HISTORY ─────────────────────────────────────────
  Widget _buildViewHistoryButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity, height: 52,
        child: OutlinedButton.icon(
          onPressed: () => _showMonthHistory(context),
          icon: const Icon(Icons.history_rounded, size: 18),
          label: const Text('View Monthly History'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primaryBorder, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  void _showMonthHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.bgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(children: [
          Container(margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Monthly History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary)),
                Text('All logs', style: TextStyle(fontSize: 12, color: context.textMuted)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Text(
                  '${_monthLogs.fold(0.0, (s, l) => s + (l['kwh'] as double)).toStringAsFixed(1)} kWh total',
                  style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: _monthLogs.length,
              itemBuilder: (context, index) {
                final log = _monthLogs[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.surfaceColor, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Row(children: [
                    Container(width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(log['date'] as String,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary)),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.wb_sunny_rounded, size: 11, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(log['onTime'] as String, style: TextStyle(fontSize: 11, color: context.textMuted)),
                        const SizedBox(width: 8),
                        const Icon(Icons.nights_stay_rounded, size: 11, color: AppColors.secondary),
                        const SizedBox(width: 4),
                        Text(log['offTime'] as String, style: TextStyle(fontSize: 11, color: context.textMuted)),
                        const SizedBox(width: 8),
                        Icon(Icons.timer_rounded, size: 11, color: context.textMuted),
                        const SizedBox(width: 4),
                        Text(log['runtime'] as String, style: TextStyle(fontSize: 11, color: context.textMuted)),
                      ]),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text((log['kwh'] as double).toStringAsFixed(1),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
                      Text('kWh', style: TextStyle(fontSize: 10, color: context.textMuted)),
                    ]),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  void _showEditWifiSheet(BuildContext context, OutletModel outlet) {
    String? selectedSSID = WiFiService().getCredentials(outlet.id)?.ssid;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24,
                  MediaQuery.of(context).viewInsets.bottom + 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Edit WiFi Network',
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Update network for ${outlet.deviceName}',
                        style: TextStyle(
                            fontSize: 12, color: context.textMuted)),
                    const SizedBox(height: 20),
                    WiFiPickerWidget(
                      selectedSSID: selectedSSID,
                      isDark: Theme.of(context).brightness == Brightness.dark,
                      onNetworkSelected: (ssid, pwd) {
                        setModal(() {
                          selectedSSID = ssid;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          if (selectedSSID != null) {
                            // WiFiService().updateCredentials(
                            //  outlet.id, selectedSSID!, password);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  'WiFi updated to $selectedSSID'),
                              backgroundColor: AppColors.primary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Save Network',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── HELPER WIDGETS ───────────────────────────────────────────

class _EnergyCard extends StatelessWidget {
  final String value;
  final String label;
  const _EnergyCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:  const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.surfaceColor, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(children: [
          Text(value, style:  TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary)),
          const SizedBox(height: 4),
          Text(label, style:  TextStyle(fontSize: 10, color: context.textMuted), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _ScheduleButton extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ScheduleButton({required this.label, required this.value,
    required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(Icons.edit_rounded, size: 13, color: color.withOpacity(0.6)),
          ]),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ]),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> data;
  _ChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return;

    final paintLine = Paint()
      ..color = AppColors.primary ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round ..strokeJoin = StrokeJoin.round;

    final paintFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [AppColors.primary.withOpacity(0.3), AppColors.primary.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    final step = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * step;
      final y = size.height * (1 - (data[i] / maxVal));
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) * step;
        final prevY = size.height * (1 - (data[i - 1] / maxVal));
        final cpX = (prevX + x) / 2;
        path.cubicTo(cpX, prevY, cpX, y, x, y);
        fillPath.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, paintFill);
    canvas.drawPath(path, paintLine);

    final currentHour = DateTime.now().hour;
    if (currentHour < data.length) {
      final x = currentHour * step;
      final y = size.height * (1 - (data[currentHour] / maxVal));
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = AppColors.primary);
      canvas.drawCircle(Offset(x, y), 5,
          Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
// TODO Implement this library.