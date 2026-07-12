// lib/widgets/claim_code_widget.dart
//
// Shows the claim code returned by POST /api/devices/ and waits for the
// ESP32 to claim it and come online — entirely passive on the app side.
//
// THE APP DOES NOT TALK TO THE ESP32 AT ALL.
// The ESP32 connects to its own hotspot's captive portal at 192.168.4.1,
// the user types the claim code there, and the ESP32 exchanges it with
// the backend directly via POST /api/devices/claim/.
//
// This widget's only jobs are:
//   1. Display the claim code clearly
//   2. Show setup instructions
//   3. Poll the device status endpoint until it comes online
//   4. Offer "Generate new code" if the code expires before claiming

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/theme.dart';
import '../services/device_api.dart';

class ClaimCodeWidget extends StatefulWidget {
  /// The device ID returned by POST /api/devices/
  final int deviceId;

  /// The claim code returned by POST /api/devices/  (e.g. "7F3K9P")
  final String claimCode;

  /// The expiry timestamp returned by POST /api/devices/ (ISO 8601 string)
  final String expiresAt;

  final String deviceName;

  /// Called once the device comes online (status != "offline")
  final VoidCallback onConnected;

  /// Called when the user taps Skip / Close
  final VoidCallback onClose;

  const ClaimCodeWidget({
    super.key,
    required this.deviceId,
    required this.claimCode,
    required this.expiresAt,
    required this.deviceName,
    required this.onConnected,
    required this.onClose,
  });

  @override
  State<ClaimCodeWidget> createState() => _ClaimCodeWidgetState();
}

class _ClaimCodeWidgetState extends State<ClaimCodeWidget> {
  final _api = DeviceApiService();

  late String _claimCode;
  late DateTime? _expiresAt;

  Timer? _pollTimer;
  Timer? _countdownTimer;

  Duration _remaining = Duration.zero;
  bool _expired = false;
  bool _connected = false;
  bool _isRegeneratingCode = false;
  String _error = '';

  // ── theme ─────────────────────────────────────────────
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _surface   => _isDark ? AppColors.surfaceColor : AppColors.lightSurface;
  Color get _border    => _isDark ? AppColors.border       : AppColors.lightBorder;
  Color get _textPri   => _isDark ? AppColors.textPrimary  : AppColors.lightTextPrimary;
  Color get _textMuted => _isDark ? AppColors.textMuted    : AppColors.lightTextMuted;
  Color get _textSec   => _isDark ? AppColors.textSecondary: AppColors.lightTextSecondary;

  @override
  void initState() {
    super.initState();
    _claimCode = widget.claimCode;
    _expiresAt = DateTime.tryParse(widget.expiresAt);
    debugPrint('claim expiresAt raw="${widget.expiresAt}" parsed=$_expiresAt');
    _startCountdown();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── countdown to expiry ────────────────────────────────
  void _startCountdown() {
    _countdownTimer?.cancel();
    _updateRemaining();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    if (_expiresAt == null)  {
      // Backend didn't give a usable timestamp — fall back to a
      // fixed 15-minute window starting from when this widget opened
      _expiresAt = DateTime.now().add(const Duration(minutes: 15));
    }
    final diff = _expiresAt!.difference(DateTime.now());
    if (mounted) {
      setState(() {
        _remaining = diff.isNegative ? Duration.zero : diff;
        _expired = diff.isNegative;
      });
    }
    if (_expired) _countdownTimer?.cancel();
  }

  // ── poll backend every 4s to see if device is online ───
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_connected) return;
      final isOnline = await _api.checkDeviceOnline(widget.deviceId);
      if (isOnline && mounted) {
        setState(() => _connected = true);
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        // brief pause so the user sees the success state before closing
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) widget.onConnected();
      }
    });
  }

  // ── generate a fresh code for the same unclaimed device ─
  Future<void> _regenerateCode() async {
    setState(() {
      _isRegeneratingCode = true;
      _error = '';
    });

    final result = await _api.regenerateClaimCode(widget.deviceId);

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _claimCode = result['claim_code'] as String;
        _expiresAt = DateTime.tryParse(result['expires_at'] as String? ?? '');
        _expired = false;
        _isRegeneratingCode = false;
      });
      _startCountdown();
      _startPolling();
    } else {
      setState(() {
        _isRegeneratingCode = false;
        _error = 'Could not generate a new code. Please try again.';
      });
    }
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_connected) return _buildConnectedState();
    if (_expired) return _buildExpiredState();
    return _buildWaitingState();
  }

  // ── Main state: showing code, waiting for claim ────────
  Widget _buildWaitingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        Text('Set up ${widget.deviceName}',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _textPri)),
        const SizedBox(height: 4),
        Text(
          'Follow these steps on your phone to connect the outlet.',
          style: TextStyle(fontSize: 13, color: _textMuted, height: 1.4),
        ),
        const SizedBox(height: 20),

        // ── Claim code display ────────────────────────
        Center(
          child: Column(children: [
            Text('YOUR CLAIM CODE',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: _textMuted)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _claimCode));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Claim code copied'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    _claimCode.split('').join(' '),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 2,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.copy_rounded,
                      size: 18, color: AppColors.primary),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.timer_outlined, size: 14, color: _textMuted),
              const SizedBox(width: 5),
              Text('Expires in ${_formatRemaining(_remaining)}',
                  style: TextStyle(fontSize: 12, color: _textMuted)),
            ]),
          ]),
        ),

        const SizedBox(height: 24),

        // ── Step instructions ──────────────────────────
        _instructionStep(
          1,
          'Connect your phone\'s WiFi to the network',
          highlight: 'SmartOutlet',
        ),
        const SizedBox(height: 12),
        _instructionStep(
          2,
          'Open a browser and go to',
          highlight: '192.168.4.1',
        ),
        const SizedBox(height: 12),
        _instructionStep(
          3,
          'Select your home WiFi network and enter the password',
        ),
        const SizedBox(height: 12),
        _instructionStep(
          4,
          'Enter the claim code shown above when asked',
        ),

        const SizedBox(height: 20),

        // ── Live waiting indicator ─────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Row(children: [
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Waiting for outlet to connect...',
                  style: TextStyle(fontSize: 13, color: _textSec)),
            ),
          ]),
        ),

        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          _errorBox(_error),
        ],

        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Text('Close — I\'ll finish this later',
                style: TextStyle(fontSize: 12, color: _textMuted)),
          ),
        ),
      ],
    );
  }

  // ── Expired state ───────────────────────────────────────
  Widget _buildExpiredState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(children: [
          const Icon(Icons.timer_off_rounded,
              color: AppColors.amber, size: 26),
          const SizedBox(width: 10),
          Text('Code expired',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textPri)),
        ]),
        const SizedBox(height: 10),
        Text(
          'This claim code is no longer valid. Generate a new one to '
              'continue setting up ${widget.deviceName}.',
          style: TextStyle(fontSize: 13, color: _textMuted, height: 1.5),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          _errorBox(_error),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isRegeneratingCode ? null : _regenerateCode,
            icon: _isRegeneratingCode
                ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(_isRegeneratingCode
                ? 'Generating...'
                : 'Generate New Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Text('Close',
                style: TextStyle(fontSize: 13, color: _textMuted)),
          ),
        ),
      ],
    );
  }

  // ── Connected / success state ───────────────────────────
  Widget _buildConnectedState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              color: AppColors.primary, size: 36),
        ),
        const SizedBox(height: 16),
        Text('Device connected!',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _textPri)),
        const SizedBox(height: 6),
        Text('${widget.deviceName} is now online and ready to use.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _textMuted)),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── small helper widgets ────────────────────────────────
  Widget _instructionStep(int n, String text, {String? highlight}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22, height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text('$n',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                  fontSize: 13, color: _textPri, height: 1.4),
              children: [
                TextSpan(text: '$text '),
                if (highlight != null)
                  TextSpan(
                    text: highlight,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: const TextStyle(fontSize: 12, color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}
