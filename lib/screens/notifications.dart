import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _api = ApiService();
  final ThemeProvider _theme = ThemeProvider();

  bool _isLoading = true;
  String _error = '';
  List<Map<String, dynamic>> _alerts = [];

  // Filter state
  String _filter = 'ALL'; // ALL, OVERLOAD, OVERVOLTAGE

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
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    setState(() { _isLoading = true; _error = ''; });
    try {
      final data = await _api.getAlerts();
      // Sort newest first
      final list = List<Map<String, dynamic>>.from(
          data.map((e) => Map<String, dynamic>.from(e)));
      list.sort((a, b) {
        final ta = _parseTime(a['timestamp']?.toString() ?? '');
        final tb = _parseTime(b['timestamp']?.toString() ?? '');
        return tb.compareTo(ta);
      });
      if (mounted) setState(() { _alerts = list; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Could not load alerts. Pull down to retry.';
        _isLoading = false;
      });
    }
  }

  DateTime _parseTime(String raw) {
    try {
      final clean = raw
          .replaceAll('Z', '')
          .replaceAll('+00:00', '')
          .replaceAll('+03:00', '');
      return DateTime.parse(clean);
    } catch (_) {
      return DateTime(2000);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'ALL') return _alerts;
    return _alerts.where((a) {
      final type = (a['alert_type'] ?? a['type'] ?? '')
          .toString().toUpperCase();
      return type.contains(_filter);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          if (!_isLoading && _error.isEmpty) _buildFilterRow(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchAlerts,
              color: AppColors.primary,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(
                  color: AppColors.primary))
                  : _error.isNotEmpty
                  ? _buildError()
                  : _filtered.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                itemCount: _filtered.length,
                itemBuilder: (_, i) =>
                    _buildAlertCard(_filtered[i]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── HEADER ───────────────────────────────────────
  Widget _buildHeader() {
    final unread = _alerts.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Safety Alerts',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary)),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$unread',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              Text('Overvoltage & overload events',
                  style: TextStyle(fontSize: 12, color: _textMuted)),
            ],
          ),
        ),
        GestureDetector(
          onTap: _fetchAlerts,
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
  }

  // ── FILTER ROW ────────────────────────────────────
  Widget _buildFilterRow() {
    final options = ['ALL', 'OVERLOAD', 'OVERVOLTAGE'];
    return Container(
      height: 38,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: options.map((opt) {
          final active = _filter == opt;
          return GestureDetector(
            onTap: () => setState(() => _filter = opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? _filterColor(opt)
                    : _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active
                        ? _filterColor(opt)
                        : _border),
              ),
              child: Text(
                opt == 'ALL'
                    ? 'All (${_alerts.length})'
                    : opt == 'OVERLOAD'
                    ? 'Overload (${_countOf('OVERLOAD')})'
                    : 'Overvoltage (${_countOf('OVERVOLTAGE')})',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : _textMuted),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  int _countOf(String type) => _alerts.where((a) {
    final t = (a['alert_type'] ?? a['type'] ?? '')
        .toString().toUpperCase();
    return t.contains(type);
  }).length;

  Color _filterColor(String type) {
    if (type == 'OVERCURRENT') return AppColors.primary;
    if (type == 'OVERLOAD') return AppColors.red;
    if (type == 'OVERVOLTAGE') return AppColors.amber;
    return AppColors.primary;
  }

  // ── ALERT CARD ────────────────────────────────────
  Widget _buildAlertCard(Map<String, dynamic> alert) {
    // ── 1. Read alert_type directly from the API response ──────────────────
    // Backend returns: "undervoltage", "overvoltage", "overcurrent", "overload"
    final String rawType =
    (alert['alert_type'] ?? alert['type'] ?? '').toString().toLowerCase();

    // ── 2. Derive colour, icon, and display title from alert_type ──────────
    Color alertColor;
    IconData alertIcon;
    String alertTitle;

    switch (rawType) {
      case 'overcurrent':
        alertColor = AppColors.red;
        alertIcon = Icons.bolt_rounded;
        alertTitle = 'Overcurrent Detected';
        break;
      case 'overload':
        alertColor = AppColors.red;
        alertIcon = Icons.bolt_rounded;
        alertTitle = 'Overload Detected';
        break;
      case 'overvoltage':
        alertColor = AppColors.amber;
        alertIcon = Icons.electric_bolt_rounded;
        alertTitle = 'Overvoltage Detected';
        break;
      case 'undervoltage':
        alertColor = AppColors.amber;
        alertIcon = Icons.electric_bolt_rounded;
        alertTitle = 'Undervoltage Detected';
        break;
      default:
        alertColor = AppColors.primary;
        alertIcon = Icons.warning_rounded;
        // If backend sends an unexpected type, still show it as-is
        alertTitle = rawType.isNotEmpty
            ? '${rawType[0].toUpperCase()}${rawType.substring(1)} Detected'
            : 'Safety Alert';
    }

    // ── 3. Correct unit per alert type ─────────────────────────────────────
    final String unit;
    switch (rawType) {
      case 'overcurrent':
        unit = 'A';
        break;
      case 'overload':
        unit = 'W';
        break;
      case 'overvoltage':
      case 'undervoltage':
        unit = 'V';
        break;
      default:
        unit = '';
    }

    // ── 4. Correct threshold default per alert type ─────────────────────────
    final double defaultThreshold;
    switch (rawType) {
      case 'overcurrent':
        defaultThreshold = 7.0;
        break;
      case 'overload':
        defaultThreshold = 3000.0;
        break;
      case 'overvoltage':
        defaultThreshold = 260.0;
        break;
      case 'undervoltage':
        defaultThreshold = 170.0;
        break;
      default:
        defaultThreshold = 0.0;
    }

    // ── 5. Read values — always use measured_value first ───────────────────
    final double measuredValue =
    _toDouble(alert['measured_value'] ?? alert['value'] ?? 0);

    final double threshold = _toDouble(
        alert['threshold_value'] ??
            alert['threshold'] ??
            defaultThreshold);

    // ── 6. Device name and timestamp ────────────────────────────────────────
    final String deviceName =
    (alert['device_name'] ?? alert['device'] ?? 'Device ${alert['device_id'] ?? ''}')
        .toString();

    final String timeRaw =
    (alert['timestamp'] ?? alert['created_at'] ?? alert['time'] ?? '')
        .toString();
    final DateTime? time = _parseTimeOrNull(timeRaw);

    // ── 7. Advice message per alert type ───────────────────────────────────
    final String adviceText;
    switch (rawType) {
      case 'overcurrent':
        adviceText =
        'Current exceeded ${threshold.toStringAsFixed(1)}A. Unplug high-draw appliances immediately to protect the outlet.';
        break;
      case 'overload':
        adviceText =
        'Power draw exceeded ${threshold.toStringAsFixed(0)}W. Unplug high-wattage devices immediately to prevent damage.';
        break;
      case 'overvoltage':
        adviceText =
        'Voltage exceeded ${threshold.toStringAsFixed(0)}V (Tanzania standard: 220–240V). Check your power supply.';
        break;
      case 'undervoltage':
        adviceText =
        'Voltage dropped below ${threshold.toStringAsFixed(0)}V. This may damage sensitive appliances.';
        break;
      default:
        adviceText = 'An abnormal electrical condition was detected. Please check your outlet.';
    }

    // ── 8. Build card UI (unchanged from your original) ────────────────────
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        // Alert header strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: alertColor.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(left: BorderSide(color: alertColor, width: 4)),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: alertColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(alertIcon, color: alertColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alertTitle,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: alertColor)),
                  Text(deviceName,
                      style: TextStyle(fontSize: 11, color: _textMuted)),
                ],
              ),
            ),
            Text(
              time != null ? _timeAgo(time) : '',
              style: TextStyle(fontSize: 11, color: _textMuted),
            ),
          ]),
        ),

        // Alert details
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Expanded(child: _detailChip(
                label: 'Measured',
                value: '${measuredValue.toStringAsFixed(1)} $unit',
                color: alertColor,
              )),
              const SizedBox(width: 10),
              Expanded(child: _detailChip(
                label: 'Threshold',
                value: '${threshold.toStringAsFixed(1)} $unit',
                color: _textMuted,
              )),
              const SizedBox(width: 10),
              Expanded(child: _detailChip(
                label: 'Exceeded by',
                value: '+${(measuredValue - threshold).abs().toStringAsFixed(1)} $unit',
                color: alertColor,
              )),
            ]),
            if (time != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.access_time_rounded, size: 12, color: _textMuted),
                const SizedBox(width: 4),
                Text(_formatFullTime(time),
                    style: TextStyle(fontSize: 11, color: _textMuted)),
              ]),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: alertColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: alertColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 13, color: alertColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(adviceText,
                        style: TextStyle(fontSize: 11, color: _textMuted)),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _detailChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 9,
                color: _textMuted)),
      ]),
    );
  }

  // ── EMPTY STATE ───────────────────────────────────
  Widget _buildEmpty() {
    return ListView(children: [
      SizedBox(
        height: 400,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_rounded,
                  size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              _filter == 'ALL'
                  ? 'No safety alerts'
                  : 'No $_filter alerts',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              _filter == 'ALL'
                  ? 'All outlets are within safe electrical limits'
                  : 'No events of this type recorded',
              style: TextStyle(
                  fontSize: 13, color: _textMuted),
              textAlign: TextAlign.center,
            ),

          ],
        ),
      ),
    ]);
  }

  Widget _thresholdRow(
      IconData icon, Color color, String label, String value) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text('$label: ',
          style: TextStyle(fontSize: 12, color: _textPrimary,
              fontWeight: FontWeight.w600)),
      Text(value,
          style: TextStyle(fontSize: 12, color: _textMuted)),
    ]);
  }

  // ── ERROR STATE ───────────────────────────────────
  Widget _buildError() {
    return ListView(children: [
      SizedBox(
        height: 400,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 40, color: _textMuted),
            const SizedBox(height: 12),
            Text(_error,
                textAlign: TextAlign.center,
                style: TextStyle(color: _textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchAlerts,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
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
    ]);
  }

  // ── HELPERS ───────────────────────────────────────
  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  String _formatFullTime(DateTime t) {
    final p = (int n) => n.toString().padLeft(2, '0');
    return '${t.day}/${t.month}/${t.year}  '
        '${p(t.hour)}:${p(t.minute)}:${p(t.second)}';
  }

  DateTime _parseTimeOrNull(String raw) {
    try {
      final clean = raw
          .replaceAll('Z', '')
          .replaceAll('+00:00', '')
          .replaceAll('+03:00', '');
      return DateTime.parse(clean);
    } catch (_) {
      return DateTime.now();
    }
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
