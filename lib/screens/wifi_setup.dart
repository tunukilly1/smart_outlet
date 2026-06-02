import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../models/outlet_model.dart';
import '../services/outlet_service.dart';

class WifiSetupScreen extends StatefulWidget {
  final OutletModel outlet;
  final bool isEditing;

  const WifiSetupScreen({
    super.key,
    required this.outlet,
    this.isEditing = false,
  });

  @override
  State<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends State<WifiSetupScreen> {
  final OutletService _service = OutletService();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isScanning = false;
  String? _selectedNetwork;
  int _selectedSignal = 0;

  // Mock available networks — in real app use wifi_scan package
  final List<Map<String, dynamic>> _availableNetworks = [
    {'name': 'HomeNetwork_5G', 'strength': 4, 'secured': true},
    {'name': 'HomeNetwork_2.4G', 'strength': 4, 'secured': true},
    {'name': 'Office_WiFi', 'strength': 3, 'secured': true},
    {'name': 'Neighbor_Net', 'strength': 2, 'secured': true},
    {'name': 'Guest_Network', 'strength': 2, 'secured': false},
    {'name': 'AndroidAP_4F2', 'strength': 1, 'secured': true},
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill if editing existing WiFi
    if (widget.isEditing && widget.outlet.hasWifi) {
      _selectedNetwork = widget.outlet.wifiName;
      _passwordController.text = widget.outlet.wifiPassword;
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _scanNetworks() async {
    setState(() => _isScanning = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _isScanning = false);
  }

  void _saveWifi() {
    if (_selectedNetwork == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please select a WiFi network'),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    // Save WiFi to outlet
    _service.updateOutletWifi(
      outletId: widget.outlet.id,
      wifiName: _selectedNetwork!,
      wifiPassword: _passwordController.text,
      signalStrength: _selectedSignal,
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('WiFi saved for Outlet ${widget.outlet.outletNumber}'),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
    ));

    Navigator.pop(context);
  }

  void _forgetWifi() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: const Text('Forget Network',
            style: TextStyle(color: AppColors.textPrimary,
                fontWeight: FontWeight.w700)),
        content: Text(
          'Remove "${widget.outlet.wifiName}" from Outlet ${widget.outlet.outletNumber}?',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              _service.updateOutletWifi(
                outletId: widget.outlet.id,
                wifiName: '',
                wifiPassword: '',
                signalStrength: 0,
              );
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Forget',
                style: TextStyle(color: AppColors.red,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : AppColors.lightBackground;
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final mutedColor = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final surfaceColor = isDark ? AppColors.surfaceColor : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.border : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Icon(Icons.arrow_back_rounded,
                      color: textColor, size: 18),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isEditing ? 'Edit WiFi' : 'Connect to WiFi',
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.w700, color: textColor),
                      ),
                      Text(
                        'Outlet ${widget.outlet.outletNumber} · ${widget.outlet.deviceName}',
                        style: TextStyle(fontSize: 12, color: mutedColor),
                      ),
                    ]),
              ),
              if (widget.isEditing && widget.outlet.hasWifi)
                GestureDetector(
                  onTap: _forgetWifi,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.red.withOpacity(0.3)),
                    ),
                    child: const Text('Forget',
                        style: TextStyle(fontSize: 12,
                            color: AppColors.red,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Current WiFi if editing
                    if (widget.isEditing && widget.outlet.hasWifi) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.25)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.wifi_rounded,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Currently Connected',
                                    style: TextStyle(fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600)),
                                Text(widget.outlet.wifiName,
                                    style: TextStyle(fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: textColor)),
                              ])),
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Available Networks header
                    Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Available Networks',
                                  style: TextStyle(fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textColor)),
                              Text('Select a network for this outlet',
                                  style: TextStyle(fontSize: 11,
                                      color: mutedColor)),
                            ]),
                      ),
                      GestureDetector(
                        onTap: _scanNetworks,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.primaryBorder),
                          ),
                          child: _isScanning
                              ? const SizedBox(
                              width: 50, height: 16,
                              child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    SizedBox(width: 12, height: 12,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary)),
                                    SizedBox(width: 6),
                                    Text('Scanning',
                                        style: TextStyle(fontSize: 11,
                                            color: AppColors.primary)),
                                  ]))
                              : const Text('Scan',
                              style: TextStyle(fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // Networks list
                    Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: List.generate(
                            _availableNetworks.length, (i) {
                          final network = _availableNetworks[i];
                          final isSelected =
                              _selectedNetwork == network['name'];
                          final strength = network['strength'] as int;
                          final secured = network['secured'] as bool;

                          return Column(children: [
                            GestureDetector(
                              onTap: () => setState(() {
                                _selectedNetwork = network['name'] as String;
                                _selectedSignal = strength;
                              }),
                              child: Container(
                                color: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(children: [
                                  // Signal bars
                                  SizedBox(
                                    width: 24,
                                    child: Row(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                        children: List.generate(4, (bar) {
                                          final active = bar < strength;
                                          final h = 6.0 + (bar * 4);
                                          return Container(
                                            margin:
                                            const EdgeInsets.only(right: 2),
                                            width: 4, height: h,
                                            decoration: BoxDecoration(
                                              color: active
                                                  ? (isSelected
                                                  ? AppColors.primary
                                                  : textColor)
                                                  : borderColor,
                                              borderRadius:
                                              BorderRadius.circular(1),
                                            ),
                                          );
                                        })),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(network['name'] as String,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: isSelected
                                                    ? AppColors.primary
                                                    : textColor,
                                              )),
                                          Text(secured ? 'Secured' : 'Open',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: mutedColor)),
                                        ]),
                                  ),
                                  Row(children: [
                                    if (secured)
                                      Icon(Icons.lock_rounded,
                                          size: 14, color: mutedColor),
                                    const SizedBox(width: 8),
                                    AnimatedContainer(
                                      duration:
                                      const Duration(milliseconds: 200),
                                      width: 22, height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : borderColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check_rounded,
                                          size: 13, color: Colors.black)
                                          : null,
                                    ),
                                  ]),
                                ]),
                              ),
                            ),
                            if (i < _availableNetworks.length - 1)
                              Divider(
                                  color: borderColor, height: 1, indent: 54),
                          ]);
                        }),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Password field
                    if (_selectedNetwork != null) ...[
                      Text('PASSWORD',
                          style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: mutedColor, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: textColor, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Enter WiFi password',
                          hintStyle: TextStyle(color: mutedColor),
                          filled: true,
                          fillColor: surfaceColor,
                          prefixIcon: Icon(Icons.lock_rounded,
                              color: mutedColor, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: mutedColor, size: 20,
                            ),
                            onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: borderColor)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: AppColors.primary, width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Password is saved securely on this device only',
                        style: TextStyle(fontSize: 11, color: mutedColor),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Connect button
                    SizedBox(
                      width: double.infinity, height: 54,
                      child: ElevatedButton(
                        onPressed: _selectedNetwork != null ? _saveWifi : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor:
                          AppColors.primary.withOpacity(0.3),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          widget.isEditing ? 'Update WiFi' : 'Connect Outlet',
                          style: const TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}
