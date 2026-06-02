import 'package:flutter/material.dart';
//import '../services/wifi_service.dart';
import '../theme/theme.dart';
import '../models/room_model.dart';
import '../models/outlet_model.dart';
import '../services/outlet_service.dart';
import '../services/device_api.dart';
//import '../widget/wifi_picker.dart';
import 'outlet.dart';

class RoomScreen extends StatefulWidget {
  final RoomModel room;
  const RoomScreen({super.key, required this.room});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final OutletService _service = OutletService();
  final DeviceApiService _deviceApi = DeviceApiService();

  void _handleServiceChange() => setState(() {});

  @override
  void initState() {
    super.initState();
    _service.addListener(_handleServiceChange);
  }

  @override
  void dispose() {
    _service.removeListener(_handleServiceChange);
    super.dispose();
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'tv': return Icons.tv_rounded;
      case 'lamp': return Icons.light_rounded;
      case 'router': return Icons.router_rounded;
      case 'speaker': return Icons.speaker_rounded;
      case 'fan': return Icons.air_rounded;
      case 'fridge': return Icons.kitchen_rounded;
      case 'microwave': return Icons.microwave_rounded;
      case 'charger': return Icons.electrical_services_rounded;
      case 'empty': return Icons.power_off_rounded;
      default: return Icons.power_rounded;
    }
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgColor => _isDark ? AppColors.background : AppColors.lightBackground;
  Color get _surfaceColor => _isDark ? AppColors.surfaceColor : AppColors.lightSurface;
  Color get _borderColor => _isDark ? AppColors.border : AppColors.lightBorder;
  Color get _textColor => _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get _mutedColor => _isDark ? AppColors.textMuted : AppColors.lightTextMuted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildRoomSummary(),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: widget.room.outlets.length + 1,
              itemBuilder: (context, index) {
                if (index == widget.room.outlets.length) return _buildAddOutletCard();
                return _buildOutletCard(widget.room.outlets[index]);
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor),
            ),
            child: Icon(Icons.arrow_back_rounded, color: _textColor, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Text(widget.room.icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(widget.room.name,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textColor)),
        ),
        TextButton(
          onPressed: () => _showManageSheet(),
          child: const Text('Manage', style: TextStyle(color: AppColors.primary, fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _buildRoomSummary() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
        ),
        child: Row(children: [
          _SummaryItem(icon: Icons.power_rounded, value: '${widget.room.totalOutlets}',
              label: 'Outlets', color: AppColors.purple),
          Container(width: 1, height: 36, color: _borderColor),
          _SummaryItem(icon: Icons.bolt_rounded, value: '${widget.room.activeCount}',
              label: 'Active', color: AppColors.primary),
          Container(width: 1, height: 36, color: _borderColor),
          _SummaryItem(icon: Icons.electric_meter_rounded,
              value: widget.room.totalKwh.toStringAsFixed(1),
              label: 'kWh', color: AppColors.amber),
        ]),
      ),
    );
  }

  Widget _buildOutletCard(OutletModel outlet) {
    final bool isOn = outlet.isOn;
    final bool isEmpty = outlet.isEmpty;
    final IconData icon = _getIcon(outlet.deviceType);

    return GestureDetector(
      onTap: () {
        if (!isEmpty) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => OutletScreen(outlet: outlet, roomName: widget.room.name),
          ));
        } else {
          _showPlugDeviceSheet(outlet);
        }
      },
      onLongPress: () => _showOutletOptions(outlet),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isEmpty ? _bgColor : isOn
              ? AppColors.primary.withOpacity(0.07) : _surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isEmpty ? _borderColor : isOn
                ? AppColors.primary.withOpacity(0.25) : _borderColor,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isOn ? AppColors.primary.withOpacity(0.15) : _borderColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Outlet ${outlet.outletNumber}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: isOn ? AppColors.primary : _mutedColor)),
            ),
            const Spacer(),
            if (!isEmpty)
              GestureDetector(
                onTap: () async {
                  // Toggle locally first for instant UI response
                  _service.toggleOutlet(outlet.id);

                  // Only sync to backend if outlet has a valid backend ID
                  final backendId = outlet.backendId ?? int.tryParse(outlet.id);
                  if (backendId == null || backendId == 0) {
                    // No backend ID yet — just toggle locally
                    return;
                  }

                  try {
                    await _deviceApi.controlDevice(
                      deviceId: backendId,
                      turnOn: outlet.isOn, // use updated state
                    );
                  } catch (e) {
                    // Revert only if backend actually exists
                    _service.toggleOutlet(outlet.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Failed to sync with server'),
                        backgroundColor: AppColors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38, height: 22,
                  decoration: BoxDecoration(
                    color: isOn ? AppColors.primary : _borderColor,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 16, height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: isEmpty ? _borderColor.withOpacity(0.5)
                  : isOn ? AppColors.primary.withOpacity(0.15) : _borderColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                color: isEmpty ? _mutedColor.withOpacity(0.4)
                    : isOn ? AppColors.primary : _mutedColor,
                size: 22),
          ),
          const SizedBox(height: 10),
          Text(isEmpty ? 'Empty' : outlet.deviceName,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: isEmpty ? _mutedColor : _textColor),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(
            isEmpty ? 'Tap to plug · Hold for options'
                : isOn ? 'Active · ${outlet.voltageFormatted}' : 'Hold for options',
            style: TextStyle(fontSize: 10,
                color: isEmpty ? _mutedColor.withOpacity(0.6)
                    : isOn ? AppColors.primary : _mutedColor),
          ),
          if (!isEmpty && isOn) ...[
            const SizedBox(height: 6),
            Text(outlet.wattsFormatted, style: TextStyle(fontSize: 10, color: _mutedColor)),
          ],
        ]),
      ),
    );
  }

  void _showOutletOptions(OutletModel outlet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? AppColors.surface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(outlet.isEmpty ? 'Outlet ${outlet.outletNumber}' : outlet.deviceName,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textColor)),
              Text('Outlet ${outlet.outletNumber} · ${widget.room.name}',
                  style: TextStyle(fontSize: 12, color: _mutedColor)),
              const SizedBox(height: 16),
              if (!outlet.isEmpty) ...[
                _ManageOption(
                  icon: Icons.electrical_services_rounded,
                  color: AppColors.amber,
                  label: 'Unplug Device',
                  onTap: () {
                    Navigator.pop(ctx);
                    _service.unplugDevice(outlet.id);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${outlet.deviceName} unplugged'),
                      backgroundColor: AppColors.amber,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                ),
                const SizedBox(height: 10),
              ],
              _ManageOption(
                icon: Icons.delete_rounded,
                color: AppColors.red,
                label: 'Delete Outlet',
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirm(outlet);
                },
              ),
            ]),
      ),
    );
  }

  void _showDeleteConfirm(OutletModel outlet) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete Outlet ${outlet.outletNumber}',
            style: TextStyle(color: _textColor, fontWeight: FontWeight.w700)),
        content: Text(
          outlet.isEmpty ? 'Delete this empty outlet?'
              : 'Delete outlet with ${outlet.deviceName}? This cannot be undone.',
          style: TextStyle(color: _mutedColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _mutedColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _service.deleteOutlet(widget.room.id, outlet.id);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Outlet deleted'),
                backgroundColor: AppColors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ));
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddOutletCard() {
    return GestureDetector(
      onTap: () => _showAddOutletSheet(),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(height: 10),
          Text('Add Outlet',
              style: TextStyle(fontSize: 12, color: _mutedColor, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  void _showAddOutletSheet() {
    final nameController = TextEditingController();
    String selectedType = 'lamp';
    //String? selectedWifiSSID;
    //String selectedWifiPassword = '';
    final types = [
      {'type': 'lamp', 'icon': Icons.light_rounded, 'label': 'Lamp'},
      {'type': 'tv', 'icon': Icons.tv_rounded, 'label': 'TV'},
      {'type': 'fan', 'icon': Icons.air_rounded, 'label': 'Fan'},
      {'type': 'router', 'icon': Icons.router_rounded, 'label': 'Router'},
      {'type': 'speaker', 'icon': Icons.speaker_rounded, 'label': 'Speaker'},
      {'type': 'fridge', 'icon': Icons.kitchen_rounded, 'label': 'Fridge'},
      {'type': 'charger', 'icon': Icons.electrical_services_rounded, 'label': 'Charger'},
      {'type': 'microwave', 'icon': Icons.microwave_rounded, 'label': 'Microwave'},
      {'type': 'other', 'icon': Icons.devices_other_rounded, 'label': 'other'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? AppColors.surface : AppColors.lightSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          maxChildSize: 0.98,
          minChildSize: 0.5,
          expand: false,
          builder: (ctx, scrollController) => SingleChildScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24,
                  MediaQuery.of(ctx).viewInsets.bottom + 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: _borderColor,
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Add New Outlet', style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w700, color: _textColor)),
                const SizedBox(height: 4),
                Text('Outlet ${widget.room.outlets.length + 1} · ${widget.room.name}',
                    style: TextStyle(fontSize: 12, color: _mutedColor)),
                const SizedBox(height: 20),
                Text('DEVICE NAME', style: TextStyle(fontSize: 10, color: _mutedColor,
                    fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: _textColor),
                  decoration: InputDecoration(
                    hintText: 'e.g. Samsung TV, Bedside Lamp',
                    hintStyle: TextStyle(color: _mutedColor),
                    filled: true, fillColor: _surfaceColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _borderColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('DEVICE TYPE', style: TextStyle(fontSize: 10, color: _mutedColor,
                    fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: types.map((t) {
                    final selected = t['type'] == selectedType;
                    return GestureDetector(
                      onTap: () => setModal(() => selectedType = t['type'] as String),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary.withOpacity(0.15) : _surfaceColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selected ? AppColors.primary : _borderColor),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(t['icon'] as IconData, size: 15,
                              color: selected ? AppColors.primary : _mutedColor),
                          const SizedBox(width: 6),
                          Text(t['label'] as String, style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected ? AppColors.primary : _mutedColor)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                if (selectedType == 'other') ...[
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (val) => setModal(() => selectedType = val.toLowerCase().trim()),
                    style: TextStyle(color: _textColor),
                    decoration: InputDecoration(
                      hintText: 'Describe your device (e.g. Iron, Kettle)',
                      hintStyle: TextStyle(color: _mutedColor),
                      filled: true,
                      fillColor: _surfaceColor,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _borderColor)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _borderColor)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary)),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty) return;

                      int? savedBackendId;
                      String errorMessage = '';

                      // Show loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      );

                      try {
                        await _deviceApi.registerDevice(
                          deviceName: nameController.text,
                          location: widget.room.name,
                        );
                        savedBackendId = _deviceApi.lastRegisteredId;
                        debugPrint('SUCCESS: backendId = $savedBackendId');
                      } catch (e) {
                        errorMessage = e.toString();
                        debugPrint('REGISTER ERROR: $e');
                      }

                      // Close loading dialog
                      if (context.mounted) Navigator.pop(context);

                      if (savedBackendId == null && context.mounted) {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Registration Error'),
                            content: Text(
                              errorMessage.isEmpty
                                  ? 'No error but backendId is null.'
                                  : errorMessage,
                              style: const TextStyle(fontSize: 12),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                        return;
                      }

                      final outletId =
                          'outlet_${DateTime.now().millisecondsSinceEpoch}';

                      final newOutlet = OutletModel(
                        id: outletId,
                        outletNumber: widget.room.outlets.length + 1,
                        deviceName: nameController.text,
                        deviceType: selectedType,
                        backendId: savedBackendId,
                      );

                      _service.addOutlet(widget.room.id, newOutlet);

                      if (context.mounted) {
                        Navigator.pop(context); // Close "Add Outlet" sheet
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${nameController.text} added and synced!'),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Add Outlet',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _showPlugDeviceSheet(OutletModel outlet) {
    final nameController = TextEditingController();
    String selectedType = 'lamp';
    //String? selectedWifiSSID;
    //String selectedWifiPassword = '';
    final types = [
      {'type': 'lamp', 'icon': Icons.light_rounded, 'label': 'Lamp'},
      {'type': 'tv', 'icon': Icons.tv_rounded, 'label': 'TV'},
      {'type': 'fan', 'icon': Icons.air_rounded, 'label': 'Fan'},
      {'type': 'router', 'icon': Icons.router_rounded, 'label': 'Router'},
      {'type': 'speaker', 'icon': Icons.speaker_rounded, 'label': 'Speaker'},
      {'type': 'fridge', 'icon': Icons.kitchen_rounded, 'label': 'Fridge'},
      {'type': 'charger', 'icon': Icons.electrical_services_rounded, 'label': 'Charger'},
      {'type': 'microwave', 'icon': Icons.microwave_rounded, 'label': 'Microwave'},
      {'type': 'other', 'icon': Icons.devices_other_rounded, 'label': 'other'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? AppColors.surface : AppColors.lightSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          maxChildSize: 0.98,
          minChildSize: 0.5,
          expand: false,
          builder: (ctx, scrollController) => SingleChildScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24,
                  MediaQuery.of(ctx).viewInsets.bottom + 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: _borderColor,
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Plug device into Outlet ${outlet.outletNumber}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textColor)),
                const SizedBox(height: 4),
                Text('What device are you plugging in?',
                    style: TextStyle(fontSize: 12, color: _mutedColor)),
                const SizedBox(height: 20),
                Text('DEVICE NAME', style: TextStyle(fontSize: 10, color: _mutedColor,
                    fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: _textColor),
                  decoration: InputDecoration(
                    hintText: 'Device name (e.g. Samsung TV)',
                    hintStyle: TextStyle(color: _mutedColor),
                    filled: true, fillColor: _surfaceColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _borderColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('DEVICE TYPE', style: TextStyle(fontSize: 10, color: _mutedColor,
                    fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: types.map((t) {
                    final selected = t['type'] == selectedType;
                    return GestureDetector(
                      onTap: () => setModal(() => selectedType = t['type'] as String),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary.withOpacity(0.15) : _surfaceColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selected ? AppColors.primary : _borderColor),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(t['icon'] as IconData, size: 15,
                              color: selected ? AppColors.primary : _mutedColor),
                          const SizedBox(width: 6),
                          Text(t['label'] as String, style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected ? AppColors.primary : _mutedColor)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                if (selectedType == 'other') ...[
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (val) => setModal(() => selectedType = val.toLowerCase().trim()),
                    style: TextStyle(color: _textColor),
                    decoration: InputDecoration(
                      hintText: 'Describe your device (e.g. Iron, Kettle)',
                      hintStyle: TextStyle(color: _mutedColor),
                      filled: true,
                      fillColor: _surfaceColor,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _borderColor)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _borderColor)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary)),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty) return;
                      _service.plugDevice(outlet.id, nameController.text, selectedType);
                      try {
                        await _deviceApi.registerDevice(
                          deviceName: nameController.text,
                          location: widget.room.name,
                        );
                      } catch (_) {}
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Plug In Device',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _showManageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? AppColors.surface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.room.name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textColor)),
              Text('${widget.room.totalOutlets} outlets · ${widget.room.activeCount} active',
                  style: TextStyle(fontSize: 12, color: _mutedColor)),
              const SizedBox(height: 16),
              _ManageOption(
                icon: Icons.add_rounded, color: AppColors.primary, label: 'Add Outlet',
                onTap: () { Navigator.pop(ctx); _showAddOutletSheet(); },
              ),
              const SizedBox(height: 10),
              _ManageOption(
                icon: Icons.power_settings_new_rounded, color: AppColors.amber, label: 'Turn All Off',
                onTap: () {
                  for (final o in widget.room.outlets) { if (o.isOn) _service.toggleOutlet(o.id); }
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 10),
              _ManageOption(
                icon: Icons.delete_rounded, color: AppColors.red, label: 'Delete Room',
                onTap: () { Navigator.pop(ctx); Navigator.pop(context); },
              ),
            ]),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _SummaryItem({required this.icon, required this.value,
    required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ]),
    );
  }
}

class _ManageOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _ManageOption({required this.icon, required this.color,
    required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceColor : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.border : AppColors.lightBorder;
    final textColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    final mutedColor = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surfaceColor, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(children: [
          Container(width: 34, height: 34,
              decoration: BoxDecoration(color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: color, size: 17)),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, color: mutedColor, size: 18),
        ]),
      ),
    );
  }
}
