import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../services/api_service.dart';
import '../services/outlet_service.dart';

class EnergyScreen extends StatefulWidget {
  const EnergyScreen({super.key});
  @override
  State<EnergyScreen> createState() => _EnergyScreenState();
}

class _EnergyScreenState extends State<EnergyScreen> {
  final ScrollController _chartScroll = ScrollController();
  final ApiService _api = ApiService();
  final OutletService _service = OutletService();
  final ThemeProvider _theme = ThemeProvider();
  _DayData? _selectedDay;
  int? _selectedIndex;
  bool _isLoading = true;
  String _error = '';

  List<_DeviceEnergy> _deviceEnergies = [];
  double _totalKwhMonth = 0.0;
  List<_DayData> _dailyData = [];

  static const double _ratePerKwh = 100.0;

  bool get _isLight => _theme.isLight;
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

  @override
  void initState() {
    super.initState();
    _theme.addListener(() { if (mounted) setState(() {}); });
    _loadData();
  }
  @override
  void dispose() {
    _chartScroll.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      final List<_DeviceEnergy> devs = [];
      // Build 30-day map keyed by date string 'yyyy-MM-dd'
      final Map<String, double> dayMap = {};
      final now = DateTime.now();
      for (int i = 0; i < 30; i++) {
        final d = now.subtract(Duration(days: i));
        dayMap['${d.year}-${_p(d.month)}-${_p(d.day)}'] = 0.0;
      }

      for (final room in _service.rooms) {
        for (final outlet in room.outlets) {
          final id = outlet.backendId;
          if (id == null) continue;
          try {
            final history = await _api.getEnergyHistory(id);
            double total = 0.0;
            double peak = 0.0;
            for (final r in history) {
              final kwh = _d(r['energy_kwh']);
              final pwr = _d(r['power']);
              final raw = (r['timestamp'] ?? '').toString()
                  .replaceAll('Z', '').replaceAll('+00:00', '')
                  .replaceAll('+03:00', '');
              final t = DateTime.tryParse(raw);
              total += kwh;
              if (pwr > peak) peak = pwr;
              if (t != null) {
                final key = '${t.year}-${_p(t.month)}-${_p(t.day)}';
                if (dayMap.containsKey(key)) {
                  dayMap[key] = (dayMap[key] ?? 0) + kwh;
                }
              }
            }
            if (history.isNotEmpty) {
              devs.add(_DeviceEnergy(
                name: outlet.deviceName,
                room: room.name,
                kwh: total,
                //cost: total * _ratePerKwh,
                peakWatts: peak,
              ));
            }
          } catch (_) {}
        }
      }

      devs.sort((a, b) => b.kwh.compareTo(a.kwh));

      // Build daily list: 29 days ago first, today LAST (rightmost on chart)
      final List<_DayData> days = [];
      for (int i = 29; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final key = '${d.year}-${_p(d.month)}-${_p(d.day)}';
        final label = i == 0
            ? 'Today'
            : i == 1
            ? 'Yesterday'
            : '${_p(d.day)}/${_p(d.month)}';
        days.add(_DayData(
            label: label,
            shortDate: '${_p(d.day)}/${_p(d.month)}',
            kwh: dayMap[key] ?? 0.0));
      }

      if (mounted) {
        setState(() {
          _deviceEnergies = devs;
          _totalKwhMonth = devs.fold(0.0, (s, d) => s + d.kwh);
          _dailyData = days;
          _isLoading = false;
        });
        // After frame renders, scroll chart to today (rightmost)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_chartScroll.hasClients) {
            _chartScroll.jumpTo(_chartScroll.position.maxScrollExtent);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load energy data'; _isLoading = false; });
    }
  }

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static String _p(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header()),
              if (_isLoading)
                const SliverToBoxAdapter(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator(
                      color: AppColors.primary)),
                ))
              else if (_error.isNotEmpty)
                SliverToBoxAdapter(child: _errorView())
              else ...[
                  SliverToBoxAdapter(child: _summaryCard()),
                  SliverToBoxAdapter(child: _dailyChart()),
                  SliverToBoxAdapter(child: _rankingHeader()),
                  SliverToBoxAdapter(child: _rankingList()),
                ],
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER ───────────────────────────────────────
  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Icon(Icons.arrow_back_rounded,
              color: _textPrimary, size: 18),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Energy', style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w800,
              color: _textPrimary)),
          Text('Last 30 days — all outlets', style: TextStyle(
              fontSize: 13, color: _textMuted)),
        ],
      )),
      GestureDetector(
        onTap: _loadData,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Icon(Icons.refresh_rounded,
              color: _textMuted, size: 18),
        ),
      ),
    ]),
  );

  // ── SUMMARY CARD ─────────────────────────────────
  Widget _summaryCard() {
    final avg = _totalKwhMonth / 30;
   // final cost = _totalKwhMonth * _ratePerKwh;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Total this month',
            style: TextStyle(fontSize: 12, color: Colors.white70,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('${_totalKwhMonth.toStringAsFixed(2)} kWh',
            style: const TextStyle(fontSize: 36,
                fontWeight: FontWeight.w800, color: Colors.white)),
     //   const SizedBox(height: 4),
       // Text('Est. cost: Tsh ${cost.toStringAsFixed(0)}',
            //style: const TextStyle(fontSize: 13, color: Colors.white70)),
        const SizedBox(height: 16),
        Row(children: [
          _chip(Icons.trending_up_rounded,
              'Avg ${avg.toStringAsFixed(2)} kWh/day'),
          const SizedBox(width: 10),
          _chip(Icons.devices_rounded,
              '${_deviceEnergies.length} devices'),
        ]),
      ]),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.white),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(
          fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
    ]),
  );

  // ── DAILY CHART ───────────────────────────────────
  Widget _dailyChart() {
    final maxKwh = _dailyData.isEmpty
        ? 1.0
        : _dailyData.map((d) => d.kwh).reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxKwh == 0 ? 1.0 : maxKwh;
    final hasData = _dailyData.any((d) => d.kwh > 0);

    // 4 Y-axis levels
    final yLevels = [
      effectiveMax,
      effectiveMax * 0.75,
      effectiveMax * 0.5,
      effectiveMax * 0.25,
      0.0,
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Daily Usage',
            style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.w700, color: _textPrimary)),
        Text(
          hasData
              ? 'Scroll right for today  ·  kWh per day'
              : 'No data yet — ESP32 readings will appear here',
          style: TextStyle(fontSize: 11, color: _textMuted),
        ),
        const SizedBox(height: 14),

        if (!hasData)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bar_chart_rounded,
                    color: _textMuted, size: 36),
                const SizedBox(height: 8),
                Text('No energy data for this period',
                    style: TextStyle(color: _textMuted, fontSize: 12)),
              ]),
            ),
          )
        else
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Fixed Y-axis
            SizedBox(
              width: 46,
              height: 160,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: yLevels.map((v) => Text(
                  _formatKwh(v),
                  style: TextStyle(fontSize: 9, color: _textMuted),
                  textAlign: TextAlign.right,
                )).toList(),
              ),
            ),
            const SizedBox(width: 6),
            // Scrollable bar chart — today on the RIGHT
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: GestureDetector(
                  onTapDown: (details) {
                    final barW = 44.0;
                    final index = (details.localPosition.dx / barW).floor();
                    if (index >= 0 && index < _dailyData.length) {
                      setState(() {
                        _selectedIndex = index;
                        _selectedDay = _dailyData[index];
                      });
                    }
                  },
                  child: SizedBox(
                    width: _dailyData.length * 44.0,
                    height: 160,
                    child: CustomPaint(
                      painter: _DailyBarPainter(
                        data: _dailyData,
                        maxVal: effectiveMax,
                        barColor: AppColors.primary,
                        gridColor: _border,
                        labelColor: _textMuted,
                        selectedIndex: _selectedIndex,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Icon(Icons.swipe_left_rounded, size: 12, color: _textMuted),
          const SizedBox(width: 4),
          Text('Scroll left for earlier days',
              style: TextStyle(fontSize: 9, color: _textMuted)),
        ]),
        if (_selectedDay != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(Icons.circle, size: 8, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedDay!.label == 'Today' || _selectedDay!.label == 'Yesterday'
                      ? _selectedDay!.label
                      : _selectedDay!.shortDate,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
              ),
              if (_selectedDay!.kwh == 0)
                Text('No readings',
                    style: TextStyle(fontSize: 12, color: _textMuted))
              else
                Text('${_selectedDay!.kwh.toStringAsFixed(4)} kWh',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
            ]),
          ),
        ],
      ]),
    );
  }

  String _formatKwh(double v) {
    if (v == 0) return '0';
    if (v < 0.01) return v.toStringAsFixed(4);
    if (v < 0.1) return v.toStringAsFixed(3);
    if (v < 1) return v.toStringAsFixed(2);
    return v.toStringAsFixed(1);
  }

  // ── RANKING HEADER ────────────────────────────────
  Widget _rankingHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Device Ranking',
              style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w700, color: _textPrimary)),
          Text('Sorted by highest consumption',
              style: TextStyle(fontSize: 12, color: _textMuted)),
        ]),
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => AllDevicesEnergyScreen(
                devices: _deviceEnergies,
                isLight: _isLight,
              ))),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: const Row(children: [
              Text('See all',
                  style: TextStyle(fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded,
                  size: 13, color: AppColors.primary),
            ]),
          ),
        ),
      ],
    ),
  );

  // ── RANKING LIST (top 5 preview) ─────────────────
  Widget _rankingList() {
    if (_deviceEnergies.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Center(child: Column(children: [
          Icon(Icons.devices_rounded, color: _textMuted, size: 32),
          const SizedBox(height: 8),
          Text('No device energy data yet',
              style: TextStyle(color: _textMuted, fontSize: 12)),
        ])),
      );
    }

    final preview = _deviceEnergies.take(5).toList();
    final maxKwh = _deviceEnergies.first.kwh;

    return Column(children: [
      ...preview.asMap().entries.map((e) =>
          _rankCard(e.key + 1, e.value, maxKwh)),
      if (_deviceEnergies.length > 5)
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => AllDevicesEnergyScreen(
                devices: _deviceEnergies,
                isLight: _isLight,
              ))),
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'View all ${_deviceEnergies.length} devices',
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded,
                    size: 15, color: AppColors.primary),
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _rankCard(int rank, _DeviceEnergy dev, double maxKwh) {
    final pct = maxKwh == 0 ? 0.0 : dev.kwh / maxKwh;
    final medalColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
        ? const Color(0xFFC0C0C0)
        : rank == 3
        ? const Color(0xFFCD7F32)
        : _textMuted;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => AllDevicesEnergyScreen(
            devices: _deviceEnergies,
            isLight: _isLight,
          ))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(children: [
          Row(children: [
            // Rank badge
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: medalColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(
                rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
                style: TextStyle(fontSize: rank <= 3 ? 14 : 11,
                    fontWeight: FontWeight.w700,
                    color: rank > 3 ? _textMuted : null),
              )),
            ),
            const SizedBox(width: 10),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.electrical_services_rounded,
                  color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dev.name, style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary)),
                Text(dev.room, style: TextStyle(
                    fontSize: 11, color: _textMuted)),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${dev.kwh.toStringAsFixed(3)} kWh',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              //Text('Tsh ${dev.cost.toStringAsFixed(0)}',
                 // style: TextStyle(fontSize: 11, color: _textMuted)),
            ]),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: _border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 5,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _errorView() => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(children: [
      Icon(Icons.cloud_off_rounded, size: 40, color: _textMuted),
      const SizedBox(height: 12),
      Text(_error,
          textAlign: TextAlign.center,
          style: TextStyle(color: _textMuted, fontSize: 13)),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: _loadData,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Try Again'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]),
  );
}

// ALL DEVICES ENERGY SCREEN
// ════════════════════════════════════════════════════════
class AllDevicesEnergyScreen extends StatelessWidget {
  final List<_DeviceEnergy> devices;
  final bool isLight;

  const AllDevicesEnergyScreen({
    super.key,
    required this.devices,
    required this.isLight,
  });

  Color get _bg =>
      isLight ? AppColors.lightBackground : AppColors.background;
  Color get _surface =>
      isLight ? AppColors.lightSurface : AppColors.surfaceColor;
  Color get _border =>
      isLight ? AppColors.lightBorder : AppColors.border;
  Color get _textPrimary =>
      isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
  Color get _textMuted =>
      isLight ? AppColors.lightTextMuted : AppColors.textMuted;

  @override
  Widget build(BuildContext context) {
    final maxKwh = devices.isEmpty ? 1.0 : devices.first.kwh;
    final totalKwh = devices.fold(0.0, (s, d) => s + d.kwh);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Icon(Icons.arrow_back_rounded,
                      color: _textPrimary, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('All Devices',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary)),
                  Text(
                    '${devices.length} devices  ·  '
                        '${totalKwh.toStringAsFixed(3)} kWh total',
                    style: TextStyle(fontSize: 12, color: _textMuted),
                  ),
                ],
              )),
            ]),
          ),

          // Device list
          Expanded(
            child: devices.isEmpty
                ? Center(child: Text('No device data',
                style: TextStyle(color: _textMuted)))
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              itemCount: devices.length,
              itemBuilder: (context, i) {
                final dev = devices[i];
                final pct = maxKwh == 0 ? 0.0 : dev.kwh / maxKwh;
                final rank = i + 1;

                final medalColor = rank == 1
                    ? const Color(0xFFFFD700)
                    : rank == 2
                    ? const Color(0xFFC0C0C0)
                    : rank == 3
                    ? const Color(0xFFCD7F32)
                    : _textMuted;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        // Rank
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: medalColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: Text(
                            rank <= 3
                                ? ['🥇', '🥈', '🥉'][rank - 1]
                                : '#$rank',
                            style: TextStyle(
                                fontSize: rank <= 3 ? 15 : 11,
                                fontWeight: FontWeight.w700,
                                color: rank > 3 ? _textMuted : null),
                          )),
                        ),
                        const SizedBox(width: 10),
                        // Device icon
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                              Icons.electrical_services_rounded,
                              color: AppColors.primary,
                              size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dev.name,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary)),
                            Text(dev.room,
                                style: TextStyle(
                                    fontSize: 12, color: _textMuted)),
                          ],
                        )),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${dev.kwh.toStringAsFixed(3)} kWh',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary),
                            ),
                            /*Text(
                              'Tsh ${dev.cost.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontSize: 11, color: _textMuted),
                            ),*/
                          ],
                        ),
                      ]),
                      const SizedBox(height: 12),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          backgroundColor: _border,
                          valueColor: AlwaysStoppedAnimation(
                              rank == 1
                                  ? const Color(0xFFFFD700)
                                  : rank == 2
                                  ? const Color(0xFFC0C0C0)
                                  : rank == 3
                                  ? const Color(0xFFCD7F32)
                                  : AppColors.primary),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(pct * 100).toStringAsFixed(0)}% of highest',
                            style: TextStyle(
                                fontSize: 10, color: _textMuted),
                          ),
                          Text(
                            'Peak: ${dev.peakWatts.toStringAsFixed(0)}W',
                            style: TextStyle(
                                fontSize: 10, color: _textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// BAR CHART PAINTER WITH Y-AXIS ALIGNED BARS
// ════════════════════════════════════════════════════════
class _DailyBarPainter extends CustomPainter {
  final List<_DayData> data;
  final double maxVal;
  final Color barColor;
  final Color gridColor;
  final Color labelColor;
  final int? selectedIndex;

  const _DailyBarPainter({
    required this.data,
    required this.maxVal,
    required this.barColor,
    required this.gridColor,
    required this.labelColor,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || maxVal == 0) return;

    const double labelH = 36.0; // height reserved for labels
    final chartH = size.height - labelH;
    final barW = size.width / data.length;
    final barPad = barW * 0.2;

    // Grid lines (4 horizontal)
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = chartH * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final x = i * barW;
      final isToday = d.label == 'Today';

      // Bar height
      final hasData = d.kwh > 0;
      final barHeight = hasData
          ? (d.kwh / maxVal * chartH).clamp(4.0, chartH)
          : 0.0;

      // Bar
      if (barHeight > 0) {
        final barPaint = Paint()
          ..color = (i == selectedIndex)
              ? barColor
              : isToday
              ? barColor
              : barColor.withValues(alpha: 0.45)
          ..style = PaintingStyle.fill;

        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(
            x + barPad,
            chartH - barHeight,
            barW - barPad * 2,
            barHeight,
          ),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(rect, barPaint);

        // Value label above bar
        if (barHeight > 14) {
          final vText = d.kwh < 0.01
              ? d.kwh.toStringAsFixed(4)
              : d.kwh < 0.1
              ? d.kwh.toStringAsFixed(3)
              : d.kwh.toStringAsFixed(2);
          final vTp = TextPainter(
            text: TextSpan(
              text: vText,
              style: TextStyle(
                  fontSize: 7,
                  color: isToday ? barColor : barColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          vTp.paint(canvas,
              Offset(x + barW / 2 - vTp.width / 2, chartH - barHeight - 11));
        }


      } else {
        // Empty day — draw a faint thin bar so the column is always visible
        final emptyPaint = Paint()
          ..color = barColor.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill;

        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(
            x + barPad,
            chartH - 2,
            barW - barPad * 2,
            2,
          ),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        );
        canvas.drawRRect(rect, emptyPaint);
      }

      // X-axis label below
      final label = isToday
          ? 'Today'
          : d.label == 'Yesterday'
          ? 'Yest.'
          : d.shortDate;
      final lTp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
              fontSize: isToday ? 9 : 8,
              color: isToday ? barColor : labelColor,
              fontWeight:
              isToday ? FontWeight.w700 : FontWeight.w400),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: barW);
      lTp.paint(canvas,
          Offset(x + barW / 2 - lTp.width / 2, chartH + 6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => true;
}

// ── DATA MODELS ───────────────────────────────────────────
class _DeviceEnergy {
  final String name;
  final String room;
  final double kwh;
  //final double cost;
  final double peakWatts;

  const _DeviceEnergy({
    required this.name,
    required this.room,
    required this.kwh,
   // required this.cost,
    required this.peakWatts,
  });
}

class _DayData {
  final String label;
  final String shortDate;
  final double kwh;

  const _DayData({
    required this.label,
    required this.shortDate,
    required this.kwh,
  });
}
