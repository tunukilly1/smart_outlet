import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Represents a WiFi network found during a scan.
@immutable
class WiFiNetwork {
  final String ssid;
  final int level; // dBm
  final int signalStrength; // 1-4 bars
  final bool isSecured;
  final String bssid;

  const WiFiNetwork({
    required this.ssid,
    required this.level,
    required this.signalStrength,
    required this.isSecured,
    required this.bssid,
  });

  /// Convenience getter for open networks
  bool get isOpen => !isSecured;

  /// Convenience getter for strong signals
  bool get isStrong => signalStrength >= 3;

  WiFiNetwork copyWith({
    String? ssid,
    int? level,
    int? signalStrength,
    bool? isSecured,
    String? bssid,
  }) {
    return WiFiNetwork(
      ssid: ssid ?? this.ssid,
      level: level ?? this.level,
      signalStrength: signalStrength ?? this.signalStrength,
      isSecured: isSecured ?? this.isSecured,
      bssid: bssid ?? this.bssid,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WiFiNetwork &&
          runtimeType == other.runtimeType &&
          ssid == other.ssid &&
          bssid == other.bssid;

  @override
  int get hashCode => ssid.hashCode ^ bssid.hashCode;

  @override
  String toString() => 'WiFiNetwork(ssid: $ssid, bssid: $bssid, level: $level dBm, bars: $signalStrength)';
}

/// Represents WiFi credentials for an outlet.
@immutable
class WiFiCredentials {
  final String ssid;
  final String password;

  const WiFiCredentials({required this.ssid, required this.password});

  Map<String, String> toJson() => {
    'ssid': ssid,
    'password': password,
  };

  factory WiFiCredentials.fromJson(Map<String, dynamic> json) {
    return WiFiCredentials(
      ssid: json['ssid'] as String? ?? '',
      password: json['password'] as String? ?? '',
    );
  }

  WiFiCredentials copyWith({String? ssid, String? password}) {
    return WiFiCredentials(
      ssid: ssid ?? this.ssid,
      password: password ?? this.password,
    );
  }
}

/// Service to handle WiFi scanning and credential management for outlets.
class WiFiService extends ChangeNotifier {
  // Singleton pattern
  static final WiFiService _instance = WiFiService._internal();
  factory WiFiService() => _instance;
  
  WiFiService._internal();

  final _storage = const FlutterSecureStorage();
   StreamSubscription<List<WiFiAccessPoint>>? _scanSubscription;
  Timer? _scanTimeout;
  
  List<WiFiNetwork> _networks = [];
  bool _isScanning = false;
  bool _hasPermission = false;
  bool _isInitialized = false;
  String? _error;
  final Map<String, WiFiCredentials> _outletCredentials = {};

  // Getters
  List<WiFiNetwork> get networks => _networks;
  bool get isScanning => _isScanning;
  bool get hasPermission => _hasPermission;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  // ── INITIALIZATION ───────────────────────────────────

  /// Initializes the service by loading credentials.
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadCredentials();
    _isInitialized = true;
    notifyListeners();
  }

  // ── PERSISTENCE ───────────────────────────────────────
  
  static const String _storageKey = 'wifi_outlet_credentials';

  /// Loads saved credentials securely from secure storage
  Future<void> _loadCredentials() async {
    try {
      final String? encodedData = await _storage.read(key: _storageKey);
      if (encodedData != null) {
        final Map<String, dynamic> decoded = json.decode(encodedData);
        _outletCredentials.clear();
        decoded.forEach((key, value) {
          _outletCredentials[key] = WiFiCredentials.fromJson(Map<String, dynamic>.from(value));
        });
      }
    } catch (e) {
      debugPrint("Error loading WiFi credentials: $e");
    }
  }

  /// Saves all current credentials securely to secure storage
  Future<void> _saveAllCredentials() async {
    try {
      final data = _outletCredentials.map((key, value) => MapEntry(key, value.toJson()));
      await _storage.write(
        key: _storageKey, 
        value: json.encode(data),
      );
    } catch (e) {
      debugPrint("Error saving WiFi credentials: $e");
    }
  }

  // ── PERMISSIONS ───────────────────────────────────────

  /// Requests necessary permissions for WiFi scanning.
  /// Includes Fine Location and Nearby Devices for Android 13+.
  Future<bool> requestPermissions() async {
    try {
      final List<Permission> permissions = [
        Permission.location,
      ];

      if (Platform.isAndroid) {
        permissions.add(Permission.nearbyWifiDevices);
      }

      final statuses = await permissions.request();
      _hasPermission = statuses.values.every((status) => status.isGranted);

      if (!_hasPermission) {
        final isPermanentlyDenied = statuses.values.any((s) => s.isPermanentlyDenied);
        _updateState(
          newError: isPermanentlyDenied
              ? 'Permissions permanently denied. Please enable Location and Nearby Devices in app settings.'
              : 'Location and Nearby Devices permissions are required to scan WiFi.',
        );
      } else {
        _updateState(newError: null);
      }

      return _hasPermission;
    } catch (e) {
      _updateState(
        newError: 'Permission request failed: $e',
        newHasPermission: false,
      );
      return false;
    }
  }

  /// Opens the app settings to allow the user to manually grant permissions.
  Future<void> openSettings() async {
    await openAppSettings();
  }

  // ── SCANNING ──────────────────────────────────────────

  /// Starts a WiFi scan and updates the networks list.
  Future<void> scanNetworks({Duration timeout = const Duration(seconds: 15)}) async {
    if (_isScanning) return;

    _updateState(newIsScanning: true, newError: null);

    try {
      if (!_hasPermission) {
        final granted = await requestPermissions();
        if (!granted) {
          _updateState(newIsScanning: false);
          return;
        }
      }

      // Check if scan can be started
      final canStart = await WiFiScan.instance.canStartScan(askPermissions: false);
      if (canStart != CanStartScan.yes) {
        _updateState(
          newIsScanning: false,
          newError: _getErrorMessage(canStart),
        );
        return;
      }

      // 1. Start the scan
      final success = await WiFiScan.instance.startScan();
      if (!success) {
        debugPrint('WiFi scan start reported failure (likely throttled).');
      }

      // 2. Try to get cached results immediately
      final canGetNow = await WiFiScan.instance.canGetScannedResults(askPermissions: false);
      if (canGetNow == CanGetScannedResults.yes) {
        final results = await WiFiScan.instance.getScannedResults();
        _processResults(results);
      }

      // 3. Listen for fresh results
      await _scanSubscription?.cancel();
      _scanTimeout?.cancel();

      _scanTimeout = Timer(timeout, () {
        if (_isScanning) {
          _updateState(
            newIsScanning: false,
            newError: _networks.isEmpty ? "WiFi scan timed out." : null,
          );
          _scanSubscription?.cancel();
          _scanSubscription = null;
        }
      });

      _scanSubscription = WiFiScan.instance.onScannedResultsAvailable.listen((results) {
        _processResults(results);
        _cleanupScan();
      });
    } catch (e) {
      _updateState(
        newIsScanning: false,
        newError: 'WiFi scanning error: $e',
      );
      _cleanupScan();
    }
  }

  /// Internal helper to stop scanning and cleanup resources
  void _cleanupScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _scanTimeout?.cancel();
    _scanTimeout = null;
    _updateState(newIsScanning: false);
  }

  /// Maps WiFiScan enums to user-friendly error messages
  String _getErrorMessage(dynamic result) {
    if (result is CanStartScan || result is CanGetScannedResults) {
      final String name = result.toString().split('.').last;
      return switch (name) {
        'notSupported' => 'WiFi scanning is not supported on this device.',
        'noLocationPermissionRequired' ||
        'noLocationPermissionDenied' =>
          'Location permission is required for WiFi scanning.',
        'noLocationPermissionUpgradeAccuracy' =>
          'Precise location permission is required for WiFi scanning.',
        'noLocationServiceDisabled' =>
          'Location services must be enabled to scan for WiFi.',
        'noWiFiServiceEnabled' => 'WiFi must be turned on to scan.',
        'failed' => 'WiFi scan failed. Please try again in a few moments.',
        _ => 'WiFi scanning is currently unavailable ($name).',
      };
    }
    return 'An unexpected error occurred during WiFi scanning.';
  }

  void _processResults(List<WiFiAccessPoint> results) {
    final Map<String, WiFiAccessPoint> bestResults = {};
    for (final result in results) {
      if (result.ssid.isEmpty) continue;
      
      final existing = bestResults[result.ssid];
      if (existing == null || result.level > existing.level) {
        bestResults[result.ssid] = result;
      }
    }

    _networks = bestResults.values
        .map((r) => WiFiNetwork(
              ssid: r.ssid,
              level: r.level,
              signalStrength: _calculateSignalBars(r.level),
              isSecured: _checkIsSecured(r.capabilities),
              bssid: r.bssid,
            ))
        .toList();

    _networks.sort((a, b) => b.level.compareTo(a.level));
    notifyListeners();
  }

  int _calculateSignalBars(int level) {
    if (level >= -50) return 4;
    if (level >= -65) return 3;
    if (level >= -75) return 2;
    return 1;
  }

  bool _checkIsSecured(String capabilities) {
    final caps = capabilities.toUpperCase();
    return ['WPA', 'WEP', 'PSK', 'SAE', '802.1X'].any(caps.contains);
  }

  /// Clears the current error message.
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// Internal helper to update state and notify listeners consistently
  void _updateState({
    bool? newIsScanning,
    bool? newHasPermission,
    String? newError,
  }) {
    if (newIsScanning != null) _isScanning = newIsScanning;
    if (newHasPermission != null) _hasPermission = newHasPermission;
    _error = newError;
    notifyListeners();
  }

  // ── CREDENTIAL MANAGEMENT ─────────────────────────────

  WiFiCredentials? getCredentials(String outletId) {
    return _outletCredentials[outletId];
  }

  Future<void> updateCredentials(String outletId, String ssid, String password) async {
    _outletCredentials[outletId] = WiFiCredentials(ssid: ssid, password: password);
    await _saveAllCredentials();
    notifyListeners();
  }

  Future<void> removeCredentials(String outletId) async {
    if (_outletCredentials.containsKey(outletId)) {
      _outletCredentials.remove(outletId);
      await _saveAllCredentials();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _scanTimeout?.cancel();
    super.dispose();
  }
}
