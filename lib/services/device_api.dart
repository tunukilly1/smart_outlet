import 'package:flutter/material.dart';
import 'api_service.dart';

class DeviceApiService extends ChangeNotifier {
  static final DeviceApiService _instance =
  DeviceApiService._internal();
  factory DeviceApiService() => _instance;
  DeviceApiService._internal();

  final ApiService _api = ApiService();

  List<dynamic> _devices = [];
  List<dynamic> _alerts = [];
  bool _isLoading = false;
  String? _error;
  int? _lastRegisteredId;

  List<dynamic> get devices => _devices;
  List<dynamic> get alerts => _alerts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get lastRegisteredId => _lastRegisteredId;
  int get unreadAlerts => _alerts.length;

  // ── FETCH ALL DEVICES ─────────────────────────────────
  Future<void> fetchDevices() async {
    _isLoading = true;
    notifyListeners();
    try {
      _devices = await _api.getDevices();
      _error = null;
    } catch (e) {
      _error = 'Failed to load devices';
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── CONTROL DEVICE ────────────────────────────────────
  Future<bool> controlDevice({
    required int deviceId,
    required bool turnOn,
  }) async {
    try {
      await _api.controlDevice(
          deviceId: deviceId, turnOn: turnOn);
      for (final device in _devices) {
        if (device['id'] == deviceId) {
          device['status'] = turnOn ? 'ON' : 'OFF';
          break;
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to control device';
      notifyListeners();
      return false;
    }
  }

  // ── REGISTER NEW DEVICE ───────────────────────────────
  Future<bool> registerDevice({
    required String deviceName,
    required String location,
  }) async {
    try {
      final response = await _api.registerDevice(
        deviceName: deviceName,
        location: location,
      );

      // Print full response to logcat
      debugPrint('=== REGISTER RESPONSE ===');
      debugPrint('Full: $response');
      debugPrint('Type: ${response.runtimeType}');
      debugPrint('Keys: ${response.keys.toList()}');
      debugPrint('========================');

      // Extract ID from ALL possible response formats
      _lastRegisteredId = _extractId(response);
      debugPrint('Extracted backendId: $_lastRegisteredId');

      // If ID still null, fetch all devices and find the new one
      if (_lastRegisteredId == null) {
        debugPrint('ID null — fetching all devices to find new one');
        await _findNewDeviceId(deviceName, location);
      }

      _devices.add(response);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('registerDevice ERROR: $e');
      try {
        final err = e as dynamic;
        debugPrint('Status: ${err.response?.statusCode}');
        debugPrint('Data: ${err.response?.data}');
      } catch (_) {}
      _error = 'Failed to register device';
      _lastRegisteredId = null;
      notifyListeners();
      return false;
    }
  }

  // Extract ID from any response format
  int? _extractId(Map<String, dynamic> response) {
    // Format 1: {"id": 5, ...}
    if (response['id'] != null) {
      return int.tryParse(response['id'].toString());
    }
    // Format 2: {"device_id": 5, ...}
    if (response['device_id'] != null) {
      return int.tryParse(response['device_id'].toString());
    }
    // Format 3: {"pk": 5, ...}
    if (response['pk'] != null) {
      return int.tryParse(response['pk'].toString());
    }
    // Format 4: {"device": {"id": 5, ...}}
    if (response['device'] != null && response['device'] is Map) {
      final device = response['device'] as Map;
      if (device['id'] != null) {
        return int.tryParse(device['id'].toString());
      }
    }
    // Format 5: {"data": {"id": 5, ...}}
    if (response['data'] != null && response['data'] is Map) {
      final data = response['data'] as Map;
      if (data['id'] != null) {
        return int.tryParse(data['id'].toString());
      }
    }
    // Format 6: {"message": "...", "id": 5}
    for (final key in response.keys) {
      final val = response[key];
      if (val is int && key.toLowerCase().contains('id')) {
        return val;
      }
    }
    return null;
  }

  // Find newly created device by fetching all devices
  Future<void> _findNewDeviceId(
      String deviceName, String location) async {
    try {
      final allDevices = await _api.getDevices();
      debugPrint('All devices after register: $allDevices');

      // Find device matching name and location
      for (final device in allDevices) {
        final dName = (device['device_name'] ??
            device['name'] ?? '').toString().toLowerCase();
        final dLocation = (device['location'] ?? '')
            .toString().toLowerCase();

        if (dName == deviceName.toLowerCase() &&
            dLocation == location.toLowerCase()) {
          _lastRegisteredId =
              int.tryParse(device['id'].toString());
          debugPrint(
              'Found device after fetch: $_lastRegisteredId');
          break;
        }
      }
    } catch (e) {
      debugPrint('_findNewDeviceId error: $e');
    }
  }

  // ── GET ENERGY HISTORY ────────────────────────────────
  Future<List<dynamic>> getEnergyHistory(int deviceId) async {
    try {
      return await _api.getEnergyHistory(deviceId);
    } catch (e) {
      return [];
    }
  }

  // ── FETCH ALERTS ──────────────────────────────────────
  Future<void> fetchAlerts() async {
    try {
      _alerts = await _api.getAlerts();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load alerts';
    }
  }

  void clearAlerts() {
    _alerts = [];
    notifyListeners();
  }

  int get activeDeviceCount =>
      _devices.where((d) => d['status'] == 'ON').length;
}
