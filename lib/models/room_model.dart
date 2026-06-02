import 'outlet_model.dart';

class RoomModel {
  final String id;
  final String name;
  final String icon;
  final List<OutletModel> outlets;

  RoomModel({
    required this.id,
    required this.name,
    required this.icon,
    List<OutletModel>? outlets,
  }) : outlets = outlets ?? [];

  // ─────────────────────────────────────────────
  // DYNAMIC JSON PARSER
  // ─────────────────────────────────────────────

  factory RoomModel.fromDevices(
      String roomName,
      List<dynamic> devices,
      String icon,
      ) {
    return RoomModel(
      id: roomName.toLowerCase(),

      name: roomName,

      icon: icon,

      outlets: List.generate(
        devices.length,
            (index) => OutletModel.fromJson(
          devices[index],
          index + 1,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────

  int get totalOutlets => outlets.length;

  int get activeCount =>
      outlets.where((o) => o.isOn).length;

  double get totalKwh =>
      outlets.fold(0.0, (sum, o) => sum + o.kwhToday);

  bool get hasActiveOutlet =>
      outlets.any((o) => o.isOn);
}