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
  final ApiService _api = ApiService();
  final OutletService _service = OutletService();

  bool _isLoading = true;
  String _error = '';

  List<Map<String, dynamic>> _deviceEnergies = [];
  double _totalKwhMonth = 0.0;
  double _totalCostMonth = 0.0;
  List<double> _dailyData = List.filled(30, 0.0);

  // Tanzania electricity rate per kWh in Tsh
  static const double _ratePerKwh = 100.0;

  bool get _isDark =>
      Theme.of(context).brightness == Brightness.dark;
  Color get _bgColor =>
      _isDark ? AppColors.background : AppColors.lightBackground;
  Color get _surfaceColor =>
      _isDark ? AppColors.surfaceLight : AppColors.lightSurface;
  Color get _borderColor =>
      _isDark ? AppColors.border : AppColors.lightBorder;
  Color get _textColor =>
      _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get _mutedColor =>
      _isDark ? AppColors.textMuted : AppColors.lightTextMuted;

  @override
  void initState() {
    super.initState();
    _loadEnergyData();
  }

  Future<void> _loadEnergyData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final List<Map<String, dynamic>> deviceEnergies = [];
      double totalKwh = 0.0;
      final daily = List<double>.filled(30, 0.0);

      for (final room in _service.rooms) {
        for (final outlet in room.outlets) {
          final deviceId = outlet.backendId;
          if (deviceId == null) continue;

          try {
            final history = await _api.getEnergyHistory(deviceId);

            double deviceKwh = 0.0;
            double devicePeak = 0.0;
            double deviceVoltage = 0.0;

            for (final record in history) {
              final kwh = _toDouble(record['energy_kwh']);
              final power = _toDouble(record['power']);
              final voltage = _toDouble(record['voltage']);
              final timeStr = record['timestamp']?.toString() ?? '';
              final time = DateTime.tryParse(timeStr);

              deviceKwh += kwh;
              if (power > devicePeak) devicePeak = power;
              if (voltage > 0) deviceVoltage = voltage;

              if (time != null) {
                final daysAgo =
                    DateTime.now().difference(time).inDays;
                if (daysAgo >= 0 && daysAgo < 30) {
                  daily[29 - daysAgo] += kwh;
                }
              }
            }

            if (history.isNotEmpty) {
              deviceEnergies.add({
                'name': outlet.deviceName,
                'room': room.name,
                'kwh': deviceKwh,
                'peak_watts': devicePeak,
                'voltage': deviceVoltage,
                'cost': deviceKwh * _ratePerKwh,
                'records': history.length,
              });
              totalKwh += deviceKwh;
            }
          } catch (_) {}
        }
      }

      deviceEnergies.sort((a, b) =>
          (b['kwh'] as double).compareTo(a['kwh'] as double));

      if (mounted) {
        setState(() {
          _deviceEnergies = deviceEnergies;
          _totalKwhMonth = totalKwh;
          _totalCostMonth = totalKwh * _ratePerKwh;
          _dailyData = daily;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load energy data';
          _isLoading = false;
        });
      }
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadEnergyData,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              if (_isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    ),
                  ),
                )
              else if (_error.isNotEmpty)
                SliverToBoxAdapter(child: _buildError())
              else ...[
                  SliverToBoxAdapter(child: _buildSummaryCards()),
                  SliverToBoxAdapter(child: _buildDailyChart()),
                  SliverToBoxAdapter(child: _buildDeviceList()),
                ],
              const SliverToBoxAdapter(
                  child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Energy Usage',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _textColor)),
              Text('Last 30 days · All devices',
                  style:
                  TextStyle(fontSize: 13, color: _mutedColor)),
            ],
          ),
        ),
        GestureDetector(
          onTap: _loadEnergyData,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor),
            ),
            child: Icon(Icons.refresh_rounded,
                color: _mutedColor, size: 18),
          ),
        ),
      ]),
    );
  }

  Widget _buildSummaryCards() {
    final maxDaily = _dailyData.isEmpty
        ? 0.0
        : _dailyData.reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.tealDark, AppColors.teal],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total This Month',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                '${_totalKwhMonth.toStringAsFixed(2)} kWh',
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                'Est. cost: Tsh ${_totalCostMonth.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Row(children: [
                _summaryChip(Icons.devices_rounded,
                    '${_deviceEnergies.length} devices'),
                const SizedBox(width: 10),
                _summaryChip(Icons.bar_chart_rounded,
                    'Peak: ${maxDaily.toStringAsFixed(2)} kWh/day'),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _miniCard(
            icon: Icons.bolt_rounded,
            color: AppColors.amber,
            label: 'Avg Daily',
            value:
            '${(_totalKwhMonth / 30).toStringAsFixed(2)} kWh',
          )),
          const SizedBox(width: 10),
          Expanded(child: _miniCard(
            icon: Icons.payments_rounded,
            color: AppColors.purple,
            label: 'Daily Cost',
            value:
            'Tsh ${(_totalCostMonth / 30).toStringAsFixed(0)}',
          )),
          const SizedBox(width: 10),
          Expanded(child: _miniCard(
            icon: Icons.emoji_events_rounded,
            color: AppColors.primary,
            label: 'Top Device',
            value: _deviceEnergies.isEmpty
                ? 'None'
                : _deviceEnergies.first['name'].toString(),
          )),
        ]),
      ]),
    );
  }

  Widget _summaryChip(IconData icon, String label) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Colors.white),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Colors.white)),
      ]),
    );
  }

  Widget _miniCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style:
              TextStyle(fontSize: 10, color: _mutedColor)),
        ],
      ),
    );
  }

  Widget _buildDailyChart() {
    final maxVal = _dailyData.isEmpty
        ? 1.0
        : _dailyData.reduce((a, b) => a > b ? a : b);
    final hasData = _dailyData.any((v) => v > 0);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Usage — Last 30 Days',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textColor)),
          Text('kWh per day',
              style:
              TextStyle(fontSize: 11, color: _mutedColor)),
          const SizedBox(height: 16),
          if (!hasData)
            Center(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart_rounded,
                        color: _mutedColor, size: 32),
                    const SizedBox(height: 8),
                    Text('No energy data yet',
                        style: TextStyle(
                            color: _mutedColor, fontSize: 12)),
                    Text(
                        'Data appears when ESP32 sends readings',
                        style: TextStyle(
                            color: _mutedColor, fontSize: 10)),
                  ],
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Y axis labels
                SizedBox(
                  width: 40,
                  height: 130,
                  child: Column(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    crossAxisAlignment:
                    CrossAxisAlignment.end,
                    children: [
                      Text(
                        maxVal.toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: 9, color: _mutedColor),
                      ),
                      Text(
                        (maxVal * 0.75).toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: 9, color: _mutedColor),
                      ),
                      Text(
                        (maxVal * 0.5).toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: 9, color: _mutedColor),
                      ),
                      Text(
                        (maxVal * 0.25).toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: 9, color: _mutedColor),
                      ),
                      Text(
                        '0',
                        style: TextStyle(
                            fontSize: 9, color: _mutedColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Bar chart
                Expanded(
                  child: SizedBox(
                    height: 130,
                    child: CustomPaint(
                      painter: _DailyBarChartPainter(
                        data: _dailyData,
                        maxVal: maxVal,
                        barColor: AppColors.primary,
                        gridColor: _borderColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('30d ago',
                  style: TextStyle(
                      fontSize: 9, color: _mutedColor)),
              Text('15d ago',
                  style: TextStyle(
                      fontSize: 9, color: _mutedColor)),
              Text('Today',
                  style: TextStyle(
                      fontSize: 9,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_deviceEnergies.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Center(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.devices_rounded,
                      color: _mutedColor, size: 32),
                  const SizedBox(height: 8),
                  Text('No device energy data yet',
                      style: TextStyle(
                          color: _mutedColor, fontSize: 12)),
                  Text('ESP32 needs to send readings first',
                      style: TextStyle(
                          color: _mutedColor, fontSize: 10)),
                ]),
          ),
        ),
      );
    }

    final maxKwh = _deviceEnergies.first['kwh'] as double;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Device Breakdown',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textColor)),
          const SizedBox(height: 4),
          Text('Sorted by highest consumption',
              style:
              TextStyle(fontSize: 12, color: _mutedColor)),
          const SizedBox(height: 12),
          ..._deviceEnergies
              .map((d) => _buildDeviceCard(d, maxKwh)),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(
      Map<String, dynamic> device, double maxKwh) {
    final kwh = device['kwh'] as double;
    final cost = device['cost'] as double;
    final name = device['name'] as String;
    final room = device['room'] as String;
    final peakWatts = device['peak_watts'] as double;
    final percentage = maxKwh == 0 ? 0.0 : kwh / maxKwh;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                  Icons.electrical_services_rounded,
                  color: AppColors.primary,
                  size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _textColor)),
                  Text(room,
                      style: TextStyle(
                          fontSize: 11, color: _mutedColor)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${kwh.toStringAsFixed(2)} kWh',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                Text('Tsh ${cost.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontSize: 11, color: _mutedColor)),
              ],
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: _borderColor,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(percentage * 100).toStringAsFixed(0)}% of highest',
                style: TextStyle(
                    fontSize: 10, color: _mutedColor),
              ),
              Text(
                'Peak: ${peakWatts.toStringAsFixed(0)}W',
                style: TextStyle(
                    fontSize: 10, color: _mutedColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded,
            size: 40, color: AppColors.textMuted),
        const SizedBox(height: 12),
        Text(_error,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _loadEnergyData,
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
}

// ── BAR CHART PAINTER WITH Y AXIS ─────────────────────────

class _DailyBarChartPainter extends CustomPainter {
  final List<double> data;
  final double maxVal;
  final Color barColor;
  final Color gridColor;

  _DailyBarChartPainter({
    required this.data,
    required this.maxVal,
    required this.barColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (maxVal == 0) return;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;

    // Draw 4 horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Draw bars
    final barWidth = size.width / data.length;
    final barPadding = barWidth * 0.15;

    for (int i = 0; i < data.length; i++) {
      final val = data[i];
      if (val == 0) continue;

      final barHeight = (val / maxVal) * size.height * 0.95;
      final x = i * barWidth + barPadding;
      final y = size.height - barHeight;
      final isToday = i == data.length - 1;

      final barPaint = Paint()
        ..color = isToday
            ? barColor
            : barColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
            x, y, barWidth - (barPadding * 2), barHeight),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, barPaint);

      // Draw value on top of each bar if it fits
      if (barHeight > 20) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: val.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 7,
              color: isToday ? barColor : barColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(
            maxWidth: barWidth - (barPadding * 2));
        textPainter.paint(
          canvas,
          Offset(x, y - 10),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      true;
}
