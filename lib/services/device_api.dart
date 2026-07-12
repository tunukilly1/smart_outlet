import 'package:flutter/material.dart';
import 'api_service.dart';

class DeviceApiService extends ChangeNotifier {
  static final DeviceApiService _instance = DeviceApiService._internal();
  factory DeviceApiService() => _instance;
  DeviceApiService._internal();

  final ApiService _api = ApiService();

  List<dynamic> _devices = [];
  List<dynamic> _alerts = [];
  bool _isLoading = false;
  String? _error;
  int? _lastRegisteredId;
  String? _lastClaimCode;
  String? _lastClaimExpiresAt;

  List<dynamic> get devices => _devices;
  List<dynamic> get alerts => _alerts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get lastRegisteredId => _lastRegisteredId;
  String? get lastClaimCode => _lastClaimCode;
  String? get lastClaimExpiresAt => _lastClaimExpiresAt;
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
      await _api.controlDevice(deviceId: deviceId, turnOn: turnOn);
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
      final newDevice = await _api.registerDevice(
        deviceName: deviceName,
        location: location,
      );

      _lastRegisteredId = _extractId(newDevice);
      _lastClaimCode = newDevice['claim_code']?.toString();
      _lastClaimExpiresAt = newDevice['claim_code_expires_at']?.toString() ??
          newDevice['expires_at']?.toString();

      if (_lastRegisteredId == null) {
        await _findNewDeviceId(deviceName, location);
      }

      _devices.add(newDevice);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('registerDevice ERROR: $e');
      _error = 'Failed to register device';
      _lastRegisteredId = null;
      _lastClaimCode = null;
      _lastClaimExpiresAt = null;
      notifyListeners();
      return false;
    }
  }

  Future<bool> checkDeviceOnline(int deviceId) async {
    try {
      final devices = await _api.getDevices();
      for (final d in devices) {
        final id = _extractId(d);
        if (id == deviceId) {
          final status = (d['status'] ?? '').toString().toLowerCase();
          return status.isNotEmpty && status != 'offline';
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }
  Future<Map<String, dynamic>?> regenerateClaimCode(int deviceId) async {
    try {
      final result = await _api.regenerateClaimCode(deviceId);
      _lastClaimCode = result['claim_code']?.toString();
      _lastClaimExpiresAt = result['claim_code_expires_at']?.toString() ??
          result['expires_at']?.toString();
      notifyListeners();
      return result;
    } catch (_) {
      return null;
    }
  }

  // Extract ID from any response format
  int? _extractId(Map<String, dynamic> response) {
    if (response['id'] != null) return int.tryParse(response['id'].toString());
    if (response['device_id'] != null) return int.tryParse(response['device_id'].toString());
    if (response['pk'] != null) return int.tryParse(response['pk'].toString());
    
    if (response['device'] != null && response['device'] is Map) {
      final device = response['device'] as Map;
      if (device['id'] != null) return int.tryParse(device['id'].toString());
    }
    
    if (response['data'] != null && response['data'] is Map) {
      final data = response['data'] as Map;
      if (data['id'] != null) return int.tryParse(data['id'].toString());
    }
    
    return null;
  }

  // Find newly created device by fetching all devices
  Future<void> _findNewDeviceId(String deviceName, String location) async {
    try {
      final allDevices = await _api.getDevices();
      for (final device in allDevices) {
        final dName = (device['device_name'] ?? device['name'] ?? '').toString().toLowerCase();
        final dLocation = (device['location'] ?? '').toString().toLowerCase();

        if (dName == deviceName.toLowerCase() && dLocation == location.toLowerCase()) {
          _lastRegisteredId = _extractId(device);
          break;
        }
      }
    } catch (e) {
      debugPrint('_findNewDeviceId error: $e');
    }
  }

  //----------RENAME DEVICE---------------------------
  Future<void> renameDevice({
    required int deviceId,
    required String newName,
  }) async {
    await _api.renameDevice(deviceId: deviceId, newName: newName);
  }

  //--------DELETE DEVICE----------------------
  Future<void> deleteDevice(int deviceId) async{
    await _api.deleteDevice(deviceId);
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
