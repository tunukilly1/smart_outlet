import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Reusable energy chart widget with proper Y axis labels and values
/// Used in both outlet_screen.dart and energy_screen.dart
class EnergyChartWidget extends StatelessWidget {
  final List<double> hourlyData;
  final bool isLoading;
  final bool isDark;
  final String title;
  final String subtitle;

  const EnergyChartWidget({
    super.key,
    required this.hourlyData,
    required this.isLoading,
    required this.isDark,
    this.title = 'Energy Usage',
    this.subtitle = 'kWh per hour today',
  });

  Color get _surfaceColor =>
      isDark ? AppColors.surfaceLight : AppColors.lightSurface;
  Color get _borderColor =>
      isDark ? AppColors.border : AppColors.lightBorder;
  Color get _textColor =>
      isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get _mutedColor =>
      isDark ? AppColors.textMuted : AppColors.lightTextMuted;

  bool get _hasData => hourlyData.any((v) => v > 0);
  double get _maxValue => hourlyData.isEmpty
      ? 0.0
      : hourlyData.reduce((a, b) => a > b ? a : b);
  double get _totalKwh =>
      hourlyData.fold(0.0, (sum, v) => sum + v);

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
          _buildHeader(),
          const SizedBox(height: 16),
          _buildContent(),
          if (_hasData && !isLoading) ...[
            const SizedBox(height: 8),
            _buildTimeLabels(),
            const SizedBox(height: 12),
            _buildSummaryRow(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textColor)),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 11, color: _mutedColor)),
          ],
        ),
        if (_hasData && !isLoading)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:
              AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.primary
                      .withValues(alpha: 0.2)),
            ),
            child: Text(
              '${_totalKwh.toStringAsFixed(3)} kWh',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
            ),
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2),
        ),
      );
    }

    if (!_hasData) {
      return SizedBox(
        height: 140,
        child: Center(
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
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Y axis with real values
        SizedBox(
          width: 44,
          height: 140,
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _yLabel(_maxValue),
              _yLabel(_maxValue * 0.75),
              _yLabel(_maxValue * 0.5),
              _yLabel(_maxValue * 0.25),
              _yLabel(0.0),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 140,
            child: CustomPaint(
              painter: EnergyLinePainter(
                data: hourlyData,
                maxVal: _maxValue,
                lineColor: AppColors.primary,
                fillColor: AppColors.primary
                    .withValues(alpha: 0.15),
                gridColor: _borderColor,
              ),
            ),
          ),
        ),
      ],
    );
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

  Widget _buildTimeLabels() {
    final now = DateTime.now();
    final hours = [0, 6, 12, 18, 23];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: hours.map((h) {
        final dt =
        DateTime(now.year, now.month, now.day, h);
        return Text(_formatHour(dt),
            style: TextStyle(
                fontSize: 9, color: _mutedColor));
      }).toList(),
    );
  }

  String _formatHour(DateTime dt) {
    final h = dt.hour;
    if (h == 0) return '12am';
    if (h < 12) return '${h}am';
    if (h == 12) return '12pm';
    return '${h - 12}pm';
  }

  Widget _buildSummaryRow() {
    final peakHour = hourlyData.indexOf(
        hourlyData.reduce((a, b) => a > b ? a : b));
    final peakTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        peakHour);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color:
            AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('Today total',
              '${_totalKwh.toStringAsFixed(3)} kWh'),
          Container(
              width: 1, height: 28, color: _borderColor),
          _summaryItem(
              'Peak hour', _formatHour(peakTime)),
          Container(
              width: 1, height: 28, color: _borderColor),
          _summaryItem('Peak value',
              '${_maxValue.toStringAsFixed(3)} kWh'),
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
          style:
          TextStyle(fontSize: 9, color: _mutedColor)),
    ]);
  }
}

// ── LINE CHART PAINTER ────────────────────────────────────

class EnergyLinePainter extends CustomPainter {
  final List<double> data;
  final double maxVal;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  EnergyLinePainter({
    required this.data,
    required this.maxVal,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (maxVal == 0 || data.isEmpty) return;

    // Horizontal grid lines
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final step = size.width / (data.length - 1);
    final fillPath = Path();
    final linePath = Path();
    bool started = false;

    for (int i = 0; i < data.length; i++) {
      final x = i * step;
      final y = size.height -
          ((data[i] / maxVal) * size.height * 0.90);

      if (!started) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
        started = true;
      } else {
        final prevX = (i - 1) * step;
        final prevY = size.height -
            ((data[i - 1] / maxVal) * size.height * 0.90);
        final cpX = (prevX + x) / 2;
        linePath.cubicTo(cpX, prevY, cpX, y, x, y);
        fillPath.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Fill
    canvas.drawPath(
        fillPath, Paint()..color = fillColor
      ..style = PaintingStyle.fill);

    // Line
    canvas.drawPath(
        linePath,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    // Dots and value labels
    for (int i = 0; i < data.length; i++) {
      if (data[i] == 0) continue;
      final x = i * step;
      final y = size.height -
          ((data[i] / maxVal) * size.height * 0.90);

      // White background dot
      canvas.drawCircle(Offset(x, y), 4,
          Paint()..color = Colors.white
            ..style = PaintingStyle.fill);
      // Colored dot
      canvas.drawCircle(Offset(x, y), 3,
          Paint()..color = lineColor
            ..style = PaintingStyle.fill);

      // Value label above dot
      final val = data[i];
      final label = val < 0.01
          ? val.toStringAsFixed(4)
          : val < 0.1
          ? val.toStringAsFixed(3)
          : val.toStringAsFixed(2);

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
              fontSize: 7,
              color: lineColor,
              fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - 16));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
