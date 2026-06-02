import 'package:flutter/material.dart';
import '../services/device_api.dart';
import '../theme/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loadingNotifications = true;
  final DeviceApiService _deviceApi = DeviceApiService();
  void _markAllRead() {
    setState(() {
      for (final n in _notifications) {
        n['read'] = true;
      }
    });
  }
  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _loadingNotifications = true);
    try {
      await _deviceApi.fetchAlerts();
      setState(() {
        _notifications = _deviceApi.alerts.map((alert) => {
          'title': alert['alert_type'] ?? 'Alert',
          'body': 'Value: ${alert['measured_value']} · Threshold: ${alert['threshold']}',
          'time': _formatTime(alert['timestamp']),
          'icon': _alertIcon(alert['alert_type']),
          'color': AppColors.red,
          'read': false,
        }).toList();
        _loadingNotifications = false;
      });
    } catch (e) {
      setState(() => _loadingNotifications = false);
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '—';
    final time = DateTime.tryParse(timestamp);
    if (time == null) return '—';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  IconData _alertIcon(String? type) {
    if (type == 'OVERLOAD') return Icons.warning_rounded;
    if (type == 'OVERVOLTAGE') return Icons.electric_bolt_rounded;
    return Icons.notifications_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['read'] == false).length;
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, unreadCount),
            Expanded(
              child: _loadingNotifications
                  ? const Center(child: CircularProgressIndicator(
                  color: AppColors.primary))
                  : _notifications.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                itemCount: _notifications.length,
                itemBuilder: (context, index) =>
                    _buildNotificationCard(_notifications[index], index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int unreadCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderColor),
              ),
              child: Icon(Icons.arrow_back_rounded, color: context.textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notifications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.textPrimary)),
                if (unreadCount > 0)
                  Text('$unreadCount unread',
                      style: const TextStyle(fontSize: 12, color: AppColors.primary)),
              ],
            ),
          ),
          if (unreadCount > 0)
            GestureDetector(
              onTap: _markAllRead,
              child: const Text('Mark all read',
                  style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, int index) {
    final isRead = notification['read'] as bool;
    return GestureDetector(
      onTap: () => setState(() => _notifications[index]['read'] = true),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isRead ? context.surfaceColor : (notification['color'] as Color),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? context.borderColor : (notification['color'] as Color),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: (notification['color'] as Color),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(notification['icon'] as IconData,
                    color: notification['color'] as Color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(notification['title'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                              color: context.textPrimary,
                            )),
                      ),
                      if (!isRead)
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: notification['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Text(notification['body'] as String,
                        style:  TextStyle(fontSize: 12, color: context.textMuted, height: 1.4)),
                    const SizedBox(height: 6),
                    Text(notification['time'] as String,
                        style:  TextStyle(fontSize: 11, color: context.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded, size: 48, color: context.textMuted),
          SizedBox(height: 12),
          Text('No notifications yet', style: TextStyle(color: context.textMuted, fontSize: 14)),
        ],
      ),
    );
  }
}
// TODO Implement this library.// TODO Implement this library.