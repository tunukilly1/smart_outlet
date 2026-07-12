import 'package:flutter/material.dart';
import '../theme/theme.dart';

class EnergyChartWidget extends StatefulWidget {
  final List<double> hourlyData;
  final List<Map<String, dynamic>> allReadings;
  final bool isLoading;
  final bool isDark;


  const EnergyChartWidget({
    super.key,
    required this.hourlyData,
    required this.isLoading,
    required this.isDark,
    this.allReadings = const [],
  });

  @override
  State<EnergyChartWidget> createState() =>
      _EnergyChartWidgetState();
}

class _EnergyChartWidgetState extends State<EnergyChartWidget> {
  int? _selectedIndex;
  final ScrollController _scrollController = ScrollController();

  Color get _surfaceColor => widget.isDark
      ? AppColors.surfaceLight
      : AppColors.lightSurface;
  Color get _borderColor =>
      widget.isDark ? AppColors.border : AppColors.lightBorder;
  Color get _textColor => widget.isDark
      ? AppColors.textPrimary
      : AppColors.lightTextPrimary;
  Color get _mutedColor =>
      widget.isDark ? AppColors.textMuted : AppColors.lightTextMuted;
  Color get _bgColor => widget.isDark
      ? AppColors.background
      : AppColors.lightBackground;

  List<_EnergyPoint> get _points {
    if (widget.allReadings.isNotEmpty) {
      return widget.allReadings.map((r) {
        // Parse timestamp and keep as-is (no timezone conversion)
        // Backend already stores correct Tanzania time
        String? rawTime = r['timestamp']?.toString();
        DateTime? t;
        if (rawTime != null) {
          // Remove timezone suffix to prevent automatic conversion
          rawTime = rawTime
              .replaceAll('+00:00', '')
              .replaceAll('+03:00', '')
              .replaceAll('Z', '');
          t = DateTime.tryParse(rawTime);
        }
        final kwh = _toDouble(r['energy_kwh']);
        final power = _toDouble(r['power']);
        final voltage = _toDouble(r['voltage']);
        return _EnergyPoint(
          time: t,
          kwh: kwh,
          power: power,
          voltage: voltage,
          timeLabel: t != null
              ? '${_pad(t.hour)}:${_pad(t.minute)}'
              : '',
        );
      }).toList();
    }
    // Fallback to hourly
    final pts = <_EnergyPoint>[];
    for (int h = 0; h < widget.hourlyData.length; h++) {
      if (widget.hourlyData[h] > 0) {
        final now = DateTime.now();
        pts.add(_EnergyPoint(
          time: DateTime(now.year, now.month, now.day, h),
          kwh: widget.hourlyData[h],
          power: 0,
          voltage: 0,
          timeLabel: h < 12
              ? '${h == 0 ? 12 : h}am'
              : '${h == 12 ? 12 : h - 12}pm',
        ));
      }
    }
    return pts;
  }

  bool get _hasData =>
      _points.isNotEmpty || widget.hourlyData.any((v) => v > 0);

  double get _maxKwh {
    if (_points.isEmpty) return 1.0;
    return _points.map((p) => p.kwh).reduce(
            (a, b) => a > b ? a : b);
  }

  double get _totalKwh =>
      _points.fold(0.0, (s, p) => s + p.kwh);

  // Each point gets 28px — wider for fewer points
  double get _chartWidth {
    final count = _points.length;
    if (count <= 10) return 300;
    return (count * 28.0).clamp(300.0, 5000.0);
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildChartArea(),
          if (_hasData && !widget.isLoading) ...[
            const SizedBox(height: 12),
            _buildSelectedInfo(),
            const SizedBox(height: 12),
            _buildSummaryRow(),
          ],
        ],
      ),
    );
  }


  // ── CHART AREA ────────────────────────────────────────
  Widget _buildChartArea() {
    if (widget.isLoading) {
      return const SizedBox(
        height: 400,
        child: Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2),
        ),
      );
    }

    if (!_hasData) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.bar_chart_rounded,
                color: _mutedColor, size: 32),
            const SizedBox(height: 10),
            Text('No energy data yet',
                style: TextStyle(color: _mutedColor, fontSize: 12)),
           /* Text('Data appears when ESP32 sends readings',
                style: TextStyle(color: _mutedColor, fontSize: 10)),*/
          ]),
        ),
      );
    }

    return Column(children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed Y axis
          SizedBox(
            width: 50,
            height: 200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _yLabel(_maxKwh),
                _yLabel(_maxKwh * 0.75),
                _yLabel(_maxKwh * 0.5),
                _yLabel(_maxKwh * 0.25),
                _yLabel(0.0),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Scrollable chart
          Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      _handleTap(details.localPosition),
                  //onHorizontalDragUpdate: (details) =>
                  //_handleTap(details.localPosition),
                child: SizedBox(
                  width: _chartWidth,
                  height: 200,
                  child: CustomPaint(
                    painter: _InteractiveChartPainter(
                      points: _points,
                      maxVal: _maxKwh,
                      selectedIndex: _selectedIndex,
                      lineColor: AppColors.primary,
                      fillColor: AppColors.primary
                          .withOpacity(0.12),
                      gridColor: _borderColor,
                      textColor: _mutedColor,
                      bgColor: _bgColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // Scroll indicator
      if (_points.length > 8)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 54),
          child: Row(children: [
            Icon(Icons.swipe_rounded,
                size: 11, color: _mutedColor),
            const SizedBox(width: 4),
            Text(
              '${_points.length} readings — scroll to explore',
              style: TextStyle(fontSize: 9, color: _mutedColor),
            ),
          ]),
        ),
    ]);
  }

  void _handleTap(Offset localPosition) {
    if (_points.isEmpty) return;
    final pointWidth = _chartWidth / _points.length;
    final index = (localPosition.dx / pointWidth).floor()
        .clamp(0, _points.length - 1);
    setState(() => _selectedIndex = index);
  }

  // ── SELECTED POINT INFO ───────────────────────────────
  Widget _buildSelectedInfo() {
    if (_selectedIndex == null || _points.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_rounded,
                size: 14, color: _mutedColor),
            const SizedBox(width: 6),
            Text('Tap any point on the graph to see exact values',
                style: TextStyle(
                    fontSize: 11, color: _mutedColor)),
          ],
        ),
      );
    }

    final point = _points[_selectedIndex!];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(
              point.time != null
                  ? 'Reading at ${_pad(point.time!.hour)}:${_pad(point.time!.minute)}'
                  : 'Reading ${_selectedIndex! + 1}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _infoChip('⚡ Energy',
                '${point.kwh.toStringAsFixed(4)} kWh'),
            _infoChip('🔌 Power',
                '${point.power.toStringAsFixed(1)}W'),
            _infoChip('🔋 Voltage',
                '${point.voltage.toStringAsFixed(1)}V'),
          ],
        ),
        if (point.time != null) ...[
          const SizedBox(height: 8),
          Text(
            '${point.time!.day}/${point.time!.month}/${point.time!.year} '
                '${_pad(point.time!.hour)}:${_pad(point.time!.minute)}:${_pad(point.time!.second)}',
            style: TextStyle(fontSize: 10, color: _mutedColor),
          ),
        ],
      ]),
    );
  }

  Widget _infoChip(String label, String value) {
    return Column(children: [
      Text(value,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.primary)),
      Text(label,
          style: TextStyle(fontSize: 10, color: _mutedColor)),
    ]);
  }

  // ── SUMMARY ROW ───────────────────────────────────────
  Widget _buildSummaryRow() {
    final peakPoint = _points.isEmpty
        ? null
        : _points.reduce(
            (a, b) => a.kwh > b.kwh ? a : b);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('Total today',
              '${_totalKwh.toStringAsFixed(3)} kWh'),
          Container(
              width: 1, height: 28, color: _borderColor),
          _summaryItem('Peak time',
              peakPoint?.timeLabel ?? '—'),
          Container(
              width: 1, height: 28, color: _borderColor),
          _summaryItem('Peak value',
              peakPoint != null
                  ? '${peakPoint.kwh.toStringAsFixed(3)} kWh'
                  : '—'),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(children: [
      Text(value,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary)),
      Text(label,
          style: TextStyle(fontSize: 9, color: _mutedColor)),
    ]);
  }

  Widget _yLabel(double value) {
    String text;
    if (value == 0) {
      text = '0';
    } else if (value < 0.001) {
      text = value.toStringAsExponential(1);
    } else if (value < 0.01) {
      text = value.toStringAsFixed(4);
    } else if (value < 0.1) {
      text = value.toStringAsFixed(3);
    } else if (value < 1) {
      text = value.toStringAsFixed(2);
    } else {
      text = value.toStringAsFixed(1);
    }
    return Text(text,
        style: TextStyle(fontSize: 8, color: _mutedColor),
        textAlign: TextAlign.right);
  }
}

// ── DATA MODEL ────────────────────────────────────────────

class _EnergyPoint {
  final DateTime? time;
  final double kwh;
  final double power;
  final double voltage;
  final String timeLabel;

  _EnergyPoint({
    required this.time,
    required this.kwh,
    required this.power,
    required this.voltage,
    required this.timeLabel,
  });
}

// ── INTERACTIVE CHART PAINTER ─────────────────────────────

class _InteractiveChartPainter extends CustomPainter {
  final List<_EnergyPoint> points;
  final double maxVal;
  final int? selectedIndex;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final Color textColor;
  final Color bgColor;

  _InteractiveChartPainter({
    required this.points,
    required this.maxVal,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.textColor,
    required this.bgColor,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || maxVal == 0) return;

    final step = size.width / points.length;
    final chartH = size.height - 30; // Reserve 30px for X labels

    // ── GRID LINES ──────────────────────────────────────
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = chartH * (i / 4);
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // ── BUILD PATHS ──────────────────────────────────────
    final fillPath = Path();
    final linePath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = i * step + step / 2;
      final y = chartH - (points[i].kwh / maxVal * chartH * 0.92);

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, chartH);
        fillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) * step + step / 2;
        final prevY = chartH -
            (points[i - 1].kwh / maxVal * chartH * 0.92);
        final cpX = (prevX + x) / 2;
        linePath.cubicTo(cpX, prevY, cpX, y, x, y);
        fillPath.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }
    fillPath.lineTo(
        (points.length - 1) * step + step / 2, chartH);
    fillPath.close();

    canvas.drawPath(
        fillPath,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        linePath,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    // ── DOTS + X LABELS ──────────────────────────────────
    // Show time label every N points based on total count
    final labelEvery = points.length > 60
        ? 20
        : points.length > 30
        ? 10
        : points.length > 15
        ? 5
        : points.length > 8
        ? 3
        : 1;

    for (int i = 0; i < points.length; i++) {
      final x = i * step + step / 2;
      final y = chartH -
          (points[i].kwh / maxVal * chartH * 0.92);
      final isSelected = selectedIndex == i;

      // Selected point vertical line
      if (isSelected) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, chartH),
          Paint()
            ..color = lineColor.withOpacity(0.3)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke,
        );
      }

      // Dot — larger if selected
      final dotRadius = isSelected ? 6.0 : 3.0;
      canvas.drawCircle(Offset(x, y), dotRadius + 1.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(x, y), dotRadius,
          Paint()
            ..color = isSelected ? lineColor : lineColor.withOpacity(0.8)
            ..style = PaintingStyle.fill);

      // X axis time label every N points
      if (i % labelEvery == 0 &&
          points[i].timeLabel.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: points[i].timeLabel,
            style: TextStyle(
                fontSize: 8,
                color: isSelected ? lineColor : textColor,
                fontWeight: isSelected
                    ? FontWeight.w700
                    : FontWeight.w400),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        // Draw label below chart
        tp.paint(canvas,
            Offset(x - tp.width / 2, chartH + 6));
      }

      // Always show label for selected point
      if (isSelected && i % labelEvery != 0 &&
          points[i].timeLabel.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: points[i].timeLabel,
            style: TextStyle(
                fontSize: 8,
                color: lineColor,
                fontWeight: FontWeight.w700),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas,
            Offset(x - tp.width / 2, chartH + 6));
      }
    }

    // ── SELECTED POINT VALUE BADGE ───────────────────────
    if (selectedIndex != null &&
        selectedIndex! < points.length) {
      final i = selectedIndex!;
      final x = i * step + step / 2;
      final y = chartH -
          (points[i].kwh / maxVal * chartH * 0.92);

      final kwh = points[i].kwh;
      final label = kwh < 0.001
          ? kwh.toStringAsFixed(5)
          : kwh < 0.01
          ? kwh.toStringAsFixed(4)
          : kwh < 0.1
          ? kwh.toStringAsFixed(3)
          : kwh.toStringAsFixed(3);

      final valueTp = TextPainter(
        text: TextSpan(
          text: '$label kWh',
          style: const TextStyle(
              fontSize: 9,
              color: Colors.white,
              fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Badge background
      final badgeW = valueTp.width + 12;
      final badgeH = 18.0;
      var badgeX = x - badgeW / 2;
      final badgeY = y - badgeH - 8;

      // Keep badge inside chart bounds
      badgeX = badgeX.clamp(0, size.width - badgeW);

      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(badgeX, badgeY, badgeW, badgeH),
        const Radius.circular(4),
      );
      canvas.drawRRect(
          badgeRect,
          Paint()
            ..color = lineColor
            ..style = PaintingStyle.fill);

      valueTp.paint(canvas,
          Offset(badgeX + 6, badgeY + (badgeH - valueTp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _InteractiveChartPainter old) =>
      old.selectedIndex != selectedIndex ||
          old.points.length != points.length;
}
