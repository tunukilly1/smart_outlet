import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../models/outlet_model.dart';
import 'api_service.dart';

class OutletService extends ChangeNotifier {
  static final OutletService _instance = OutletService._internal();
  factory OutletService() => _instance;
  OutletService._internal();

  final ApiService _api = ApiService();

  List<RoomModel> _rooms = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  List<RoomModel> get rooms => _rooms;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  int get totalOutlets =>
      _rooms.fold(0, (sum, r) => sum + r.totalOutlets);
  int get totalActiveOutlets =>
      _rooms.fold(0, (sum, r) => sum + r.activeCount);
  double get totalKwhToday =>
      _rooms.fold(0.0, (sum, r) => sum + r.totalKwh);

  // --- FETCH ENERGY DATA FROM BACKEND
  Future<void> _fetchLatestEnergy() async {
    try {
      for (final room in _rooms) {
        for (final outlet in room.outlets) {
          final deviceId = outlet.backendId;
          if (deviceId == null) continue;

          final history = await _api.getEnergyHistory(deviceId);
          if (history.isEmpty) continue;

          // Get the latest energy record
          final latest = history.first;
          outlet.voltage = _toDouble(
              latest['voltage'] ?? 220.0);
          outlet.watts = _toDouble(
              latest['power'] ?? 0.0);
          outlet.kwhToday = _toDouble(
              latest['energy_kwh'] ?? 0.0);

          debugPrint(
              'Energy for ${outlet.deviceName}: '
                  '${outlet.voltage}V '
                  '${outlet.watts}W '
                  '${outlet.kwhToday}kWh');
        }
      }
    } catch (e) {
      debugPrint('_fetchLatestEnergy error: $e');
    }
  }

  // ── FETCH ALL DEVICES FROM BACKEND ----------
  Future<void> fetchAndSync() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final devices = await _api.getDevices();

      debugPrint('=== FETCHED ${devices.length} devices ===');
      for (final d in devices) {
        debugPrint('Device: $d');
      }

      // Group devices by location to create rooms
      final Map<String, List<OutletModel>> grouped = {};

      for (final device in devices) {
        final location = (device['location'] ??
            device['room'] ?? 'Uncategorized').toString();


        final outlet = OutletModel.fromJson(
          device,
          (grouped[location]?.length ?? 0) + 1,
        );
        // Override deviceType with inferred type if not set
        if (outlet.deviceType == 'power' || outlet.deviceType.isEmpty) {
          outlet.deviceType = _inferDeviceType(outlet.deviceName);
        }

        // ← CRITICAL: Save backend ID
        outlet.backendId = int.tryParse(device['id'].toString());
        debugPrint(
            'Outlet: ${outlet.deviceName} backendId: ${outlet.backendId}');

        grouped.putIfAbsent(location, () => []);
        grouped[location]!.add(outlet);
      }

      // Build new rooms from backend
      final backendRooms = grouped.entries
          .where((e) => e.value.isNotEmpty)
          .map((entry) => RoomModel(
        id: entry.key
            .toLowerCase()
            .replaceAll(' ', '_'),
        name: entry.key,
        icon: _inferRoomIcon(entry.key),
        outlets: entry.value,
      ))
          .toList();

      // Smart merge: match by BOTH id AND name
      for (final backendRoom in backendRooms) {
        // Check by id first
        final byId = _rooms.indexWhere(
                (r) => r.id == backendRoom.id);
        // Also check by name (catches local rooms with same name)
        final byName = _rooms.indexWhere(
                (r) => r.name.toLowerCase() ==
                backendRoom.name.toLowerCase());

        if (byId >= 0) {
          // Update by ID match
          _rooms[byId].outlets
            ..clear()
            ..addAll(backendRoom.outlets);
        } else if (byName >= 0) {
          // Update by name match — replace local room with backend room
          _rooms[byName] = backendRoom;
        } else {
          // Completely new room — add it
          _rooms.add(backendRoom);
        }
      }

// Remove rooms not in backend EXCEPT local-only rooms
      _rooms.removeWhere((r) =>
      !r.id.startsWith('room_') &&
          !backendRooms.any((br) =>
          br.id == r.id ||
              br.name.toLowerCase() == r.name.toLowerCase()));

      // Also match local outlets with backend IDs
      // (for outlets added via app before this fix)
      _matchLocalOutletsWithBackend(devices);

      await _fetchLatestEnergy();

      _isInitialized = true;
      _error = null;
      debugPrint('=== BUILT ${_rooms.length} rooms ===');
      debugPrint('Total outlets: $totalOutlets');
      debugPrint('Active outlets: $totalActiveOutlets');
    } catch (e) {
      _error = 'Failed to load devices. Pull down to retry.';
      debugPrint('fetchAndSync error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── MATCH LOCAL OUTLETS WITH BACKEND ──────────────────
  // Finds backendId for locally-added outlets by matching name
  void _matchLocalOutletsWithBackend(List<dynamic> devices) {
    for (final room in _rooms) {
      for (final outlet in room.outlets) {
        if (outlet.backendId != null) continue;
        // Try to match by device name and location
        for (final device in devices) {
          final dName =
          (device['device_name'] ?? '').toString().toLowerCase();
          final oName = outlet.deviceName.toLowerCase();
          final dLocation =
          (device['location'] ?? '').toString().toLowerCase();
          final rName = room.name.toLowerCase();

          if (dName == oName && dLocation == rName) {
            outlet.backendId = int.tryParse(
                device['id'].toString());
            debugPrint(
                'Matched ${outlet.deviceName} → backendId: ${outlet.backendId}');
            break;
          }
        }
      }
    }
  }

  // ── TOGGLE OUTLET ─────────────────────────────────────
  Future<void> toggleOutlet(String outletId) async {
    final outlet = getOutletById(outletId);
    if (outlet == null) return;

    // Toggle locally first
    outlet.isOn = !outlet.isOn;
    notifyListeners();

    final backendId =
        outlet.backendId ?? int.tryParse(outletId);
    if (backendId == null) {
      debugPrint('No backendId for outlet $outletId');
      return;
    }

    try {
      await _api.controlDevice(
          deviceId: backendId, turnOn: outlet.isOn);
    } catch (e) {
      // Revert on failure
      outlet.isOn = !outlet.isOn;
      notifyListeners();
      debugPrint('Toggle error: $e');
      rethrow;
    }
  }

  // ── ADD ROOM ──────────────────────────────────────────
  void addRoom(String name, String icon) {
    _rooms.add(RoomModel(
      id: 'room_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      icon: icon,
      outlets: [],
    ));
    notifyListeners();
  }

  // ── ADD OUTLET ────────────────────────────────────────
  void addOutlet(String roomId, OutletModel outlet) {
    final room = getRoomById(roomId);
    if (room != null) {
      room.outlets.add(outlet);
      notifyListeners();
    }
  }

  // ── PLUG DEVICE ───────────────────────────────────────
  void plugDevice(
      String outletId, String deviceName, String deviceType) {
    final outlet = getOutletById(outletId);
    if (outlet != null) {
      outlet.deviceName = deviceName;
      outlet.deviceType = deviceType;
      notifyListeners();
    }
  }

  // ── UNPLUG DEVICE ─────────────────────────────────────
  void unplugDevice(String outletId) {
    final outlet = getOutletById(outletId);
    if (outlet != null) {
      outlet.deviceName = 'Empty';
      outlet.deviceType = 'empty';
      outlet.isOn = false;
      notifyListeners();
    }
  }

  // ── DELETE OUTLET ─────────────────────────────────────
  void deleteOutlet(String roomId, String outletId) {
    final room = getRoomById(roomId);
    if (room != null) {
      room.outlets.removeWhere((o) => o.id == outletId);
      if (room.outlets.isEmpty) {
        _rooms.removeWhere((r) => r.id == roomId);
      }
      notifyListeners();
    }
  }

  // ── UPDATE SCHEDULE (local) ───────────────────────────
  void updateSchedule(
      String outletId, String onTime, String offTime) {
    final outlet = getOutletById(outletId);
    if (outlet != null) {
      outlet.onTime = onTime;
      outlet.offTime = offTime;
      notifyListeners();
    }
  }

  // ── UPDATE WIFI ──────────────────────────────────────
  void updateOutletWifi({
    required String outletId,
    required String wifiName,
    required String wifiPassword,
    required int signalStrength,
  }) {
    final outlet = getOutletById(outletId);
    if (outlet != null) {
      outlet.wifiName = wifiName;
      outlet.wifiPassword = wifiPassword;
      outlet.wifiSignalStrength = signalStrength;
      outlet.wifiConnected = wifiName.isNotEmpty;
      notifyListeners();
    }
  }

  // ── HELPERS ───────────────────────────────────────────
  RoomModel? getRoomById(String id) {
    try {
      return _rooms.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  OutletModel? getOutletById(String id) {
    for (final room in _rooms) {
      for (final outlet in room.outlets) {
        if (outlet.id == id) return outlet;
      }
    }
    return null;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  String _inferDeviceType(String name) {
    final l = name.toLowerCase();
    if (l.contains('tv') || l.contains('television')) return 'tv';
    if (l.contains('lamp') || l.contains('light') ||
        l.contains('bulb')) return 'lamp';
    if (l.contains('fan')) return 'fan';
    if (l.contains('router') || l.contains('wifi')) return 'router';
    if (l.contains('speaker') || l.contains('sound')) {
      return 'speaker';
    }
    if (l.contains('fridge') || l.contains('refrigerator')) {
      return 'fridge';
    }
    if (l.contains('microwave') || l.contains('oven')) {
      return 'microwave';
    }
    if (l.contains('charger') || l.contains('phone')) {
      return 'charger';
    }
    return 'power';
  }

  String _inferRoomIcon(String name) {
    final l = name.toLowerCase();
    if (l.contains('living') || l.contains('lounge')) return '🛋️';
    if (l.contains('bedroom') || l.contains('bed')) return '🛏️';
    if (l.contains('kitchen')) return '🍳';
    if (l.contains('bathroom') || l.contains('bath')) return '🚿';
    if (l.contains('office') || l.contains('study')) return '💼';
    if (l.contains('garage')) return '🚗';
    if (l.contains('garden') || l.contains('outdoor')) return '🪴';
    if (l.contains('dining')) return '🍽️';
    if (l.contains('gym') || l.contains('fitness')) return '🏋️';
    if (l.contains('game') || l.contains('gaming')) return '🎮';
    return '🔌';
  }
}
