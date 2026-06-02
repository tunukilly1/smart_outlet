import 'package:flutter/material.dart';
import '../services/wifi_service.dart';
import '../theme/theme.dart';

class WiFiPickerWidget extends StatefulWidget {
  final String? selectedSSID;
  final Function(String ssid, String password) onNetworkSelected;
  final bool isDark;

  const WiFiPickerWidget({
    super.key,
    required this.selectedSSID,
    required this.onNetworkSelected,
    required this.isDark,
  });

  @override
  State<WiFiPickerWidget> createState() => _WiFiPickerWidgetState();
}

class _WiFiPickerWidgetState extends State<WiFiPickerWidget> {
  final WiFiService _wifiService = WiFiService();
  String? _selectedSSID;
  String _password = '';
  bool _passwordVisible = false;
  final TextEditingController _passwordController = TextEditingController();

  Color get surfaceColor => widget.isDark
      ? AppColors.surfaceColor : AppColors.lightSurfaceLight;
  Color get borderColor => widget.isDark
      ? AppColors.border : AppColors.lightBorder;
  Color get textColor => widget.isDark
      ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get mutedColor => widget.isDark
      ? AppColors.textMuted : AppColors.lightTextMuted;
  Color get bgColor => widget.isDark
      ? AppColors.background : AppColors.lightBackground;

  @override
  void initState() {
    super.initState();
    _selectedSSID = widget.selectedSSID;
    _wifiService.addListener(() => setState(() {}));
    // Auto scan on open
    _wifiService.scanNetworks();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(children: [
          Text('WiFi Network',
              style: TextStyle(fontSize: 11, color: mutedColor,
                  fontWeight: FontWeight.w600, letterSpacing: 1)),
          const Spacer(),
          GestureDetector(
            onTap: () => _wifiService.scanNetworks(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: _wifiService.isScanning
                  ? const SizedBox(
                  width: 50, height: 14,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 10, height: 10,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: AppColors.primary)),
                        SizedBox(width: 5),
                        Text('Scanning',
                            style: TextStyle(fontSize: 10,
                                color: AppColors.primary)),
                      ]))
                  : const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.refresh_rounded,
                    size: 12, color: AppColors.primary),
                SizedBox(width: 4),
                Text('Scan',
                    style: TextStyle(fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 10),

        // Error state
        if (_wifiService.error != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.red.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 14, color: AppColors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_wifiService.error!,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.red)),
              ),
            ]),
          )

        // Loading state
        else if (_wifiService.isScanning && _wifiService.networks.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
                SizedBox(height: 10),
                Text('Scanning for networks...',
                    style: TextStyle(fontSize: 12,
                        color: AppColors.textMuted)),
              ]),
            ),
          )

        // Empty state
        else if (_wifiService.networks.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.wifi_off_rounded, size: 28, color: mutedColor),
                  const SizedBox(height: 8),
                  Text('No networks found', style: TextStyle(
                      fontSize: 12, color: mutedColor)),
                  const SizedBox(height: 4),
                  Text('Tap Scan to search again', style: TextStyle(
                      fontSize: 10, color: mutedColor)),
                ]),
              ),
            )

          // Networks list
          else
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: _wifiService.networks.asMap().entries.map((entry) {
                  final i = entry.key;
                  final network = entry.value;
                  final isSelected = _selectedSSID == network.ssid;
                  final isLast = i == _wifiService.networks.length - 1;

                  return Column(children: [
                    // Network row
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedSSID = network.ssid;
                          _password = '';
                          _passwordController.clear();
                        });
                      },
                      child: Container(
                        color: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(children: [
                          // Signal strength bars
                          SizedBox(
                            width: 22,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(4, (bar) {
                                final active = bar < network.signalStrength;
                                final h = 5.0 + (bar * 4);
                                return Container(
                                  margin: const EdgeInsets.only(right: 2),
                                  width: 3, height: h,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? (isSelected
                                        ? AppColors.primary
                                        : textColor.withOpacity(0.6))
                                        : borderColor,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(network.ssid,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected
                                            ? AppColors.primary : textColor,
                                      )),
                                  Text(
                                    network.isSecured ? 'Secured' : 'Open',
                                    style: TextStyle(
                                        fontSize: 10, color: mutedColor),
                                  ),
                                ]),
                          ),
                          if (network.isSecured)
                            Icon(Icons.lock_rounded,
                                size: 13, color: mutedColor),
                          const SizedBox(width: 8),
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: isSelected
                                ? AppColors.primary : mutedColor,
                          ),
                        ]),
                      ),
                    ),

                    // Password field when selected and secured
                    if (isSelected && network.isSecured)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _passwordController,
                                obscureText: !_passwordVisible,
                                style: TextStyle(color: textColor, fontSize: 13),
                                onChanged: (val) {
                                  _password = val;
                                  widget.onNetworkSelected(
                                      _selectedSSID!, val);
                                },
                                onEditingComplete: () {
                                  widget.onNetworkSelected(_selectedSSID!, _password);
                                  FocusScope.of(context).unfocus();
                                },
                                onTapOutside: (_) {
                                  widget.onNetworkSelected(_selectedSSID!, _password);
                                  FocusScope.of(context).unfocus();
                                },
                                decoration: InputDecoration(
                                  hintText: 'Enter WiFi password',
                                  hintStyle: TextStyle(
                                      color: mutedColor, fontSize: 12),
                                  prefixIcon: Icon(Icons.wifi_password_rounded,
                                      size: 16, color: mutedColor),
                                  filled: true,
                                  fillColor: bgColor,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: borderColor)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: borderColor)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: AppColors.primary)),
                                  contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  suffixIcon: GestureDetector(
                                    onTap: () => setState(
                                            () => _passwordVisible = !_passwordVisible),
                                    child: Icon(
                                      _passwordVisible
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off_rounded,
                                      color: mutedColor, size: 18,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Edit hint
                              Row(children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 11, color: mutedColor),
                                const SizedBox(width: 4),
                                Text('You can edit this later in outlet settings',
                                    style: TextStyle(
                                        fontSize: 10, color: mutedColor)),
                              ]),
                            ]),
                      ),

                    // Open network — no password needed
                    if (isSelected && !network.isSecured) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.2)),
                          ),
                          child: const Row(children: [
                            Icon(Icons.lock_open_rounded,
                                size: 13, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text('Open network — no password needed',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.primary)),
                          ]),
                        ),
                      ),
                      // Auto notify parent for open networks
                      Builder(builder: (_) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          widget.onNetworkSelected(network.ssid, '');
                        });
                        return const SizedBox.shrink();
                      }),
                    ],

                    if (!isLast)
                      Divider(color: borderColor, height: 1, indent: 48),
                  ]);
                }).toList(),
              ),
            ),

        // Selected network confirmation
        if (_selectedSSID != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.wifi_rounded, size: 13, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('Selected: $_selectedSSID',
                style: const TextStyle(fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500)),
          ]),
        ],
      ],
    );
  }
}
