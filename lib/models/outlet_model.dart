enum ScheduleMode { none, indefinite, startOnly, endOnly, startAndEnd }

class OutletModel {
  final String id;
  int? backendId;       // Real backend integer ID e.g. 5
  int outletNumber;
  bool isOn;
  double voltage;
  double watts;
  double kwhToday;
  int runtimeMinutes;
  String? onTime;
  String? offTime;
  String deviceName;
  String deviceType;
  String roomName;
  bool wifiConnected;
  String wifiName;
  String wifiPassword;
  int wifiSignalStrength;
  bool isIndefinite;
  String? claimCode;
  bool isClaimed = false;
  String? claimExpiresAt;

  OutletModel({
    required this.id,
    required this.outletNumber,
    this.backendId,
    this.isOn = false,
    this.voltage = 0.0,
    this.watts = 0.0,
    this.kwhToday = 0.0,
    this.runtimeMinutes = 0,
    this.onTime,
    this.offTime,
    this.deviceName = 'Empty',
    this.deviceType = 'empty',
    this.roomName = '',
    this.wifiConnected = false,
    this.wifiName = '',
    this.wifiPassword = '',
    this.wifiSignalStrength = 0,
    this.isIndefinite = false,
    this.isClaimed = true,
    this.claimCode,
    this.claimExpiresAt,
  });

  // ── CREATE FROM BACKEND JSON ───────────────────────
  factory OutletModel.fromJson(
      Map<String, dynamic> json,
      int outletNumber,
      ) {
    // Get ID — this becomes both id and backendId
    final id = json['id']?.toString() ?? '';
    final backendId = int.tryParse(id);

    // Get status
    final status = (json['status'] ?? 'OFF')
        .toString().toUpperCase();
    final isOn = status == 'ON';

    return OutletModel(
      id: id,
      backendId: backendId,       // ← same as id but as integer
      outletNumber: outletNumber,
      isOn: isOn,
      deviceName: json['device_name']?.toString() ??
          json['name']?.toString() ?? 'Unknown Device',
      deviceType: json['device_type']?.toString() ?? 'power',
      roomName: json['location']?.toString() ?? '',
      // Energy fields — correct field names from backend
      voltage: _toDouble(json['voltage']),
      watts: _toDouble(json['power']),        // backend sends 'power'
      kwhToday: _toDouble(json['energy_kwh']), // backend sends 'energy_kwh'
      runtimeMinutes: json['runtime_minutes'] is int
          ? json['runtime_minutes'] as int
          : 0,
      isClaimed: json['is_claimed'] == true ||
          json['claimed'] == true ||
          (json['claim_code'] == null),
      claimCode: json['claim_code']?.toString(),
    );
  }

  // ── CONVERT TO JSON ───────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_name': deviceName,
      'location': roomName,
      'status': isOn ? 'ON' : 'OFF',
      'voltage': voltage,
      'power': watts,
      'energy_kwh': kwhToday,
    };
  }

  // ── SAFE DOUBLE CONVERSION ────────────────────────
  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  ScheduleMode get scheduleMode {
    if (onTime == null && offTime == null) return ScheduleMode.none;
    if (isIndefinite) return ScheduleMode.indefinite;
    if (onTime != null && offTime == null) return ScheduleMode.startOnly;
    if (onTime == null && offTime != null) return ScheduleMode.endOnly;
    return ScheduleMode.startAndEnd;
  }

  // ── HELPERS ───────────────────────────────────────
  bool get isEmpty => deviceType == 'empty' ||
      deviceName == 'Empty';

  bool get hasWifi => wifiName.isNotEmpty;

  String get runtimeFormatted {
    if (runtimeMinutes == 0) return '0m';
    final h = runtimeMinutes ~/ 60;
    final m = runtimeMinutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  String get voltageFormatted {
    if (!isOn || voltage == 0) return '0V';
    return '${voltage.toStringAsFixed(1)}V';
  }

  String get wattsFormatted {
    if (!isOn || watts == 0) return '0W';
    return '${watts.toStringAsFixed(1)}W';
  }

  String get kwhFormatted =>
      '${kwhToday.toStringAsFixed(2)} kWh';

  String get status => wifiConnected ? 'online' : 'offline';

  String get statusText {
    if (isEmpty) return 'Empty outlet';
    if (isOn) return 'Active · $voltageFormatted';
    return 'Inactive';
  }
}