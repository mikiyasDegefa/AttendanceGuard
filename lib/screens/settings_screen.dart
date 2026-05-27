// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/tracker_service.dart';
import '../services/wifi_service.dart';
import '../services/password_service.dart';

class SettingsScreen extends StatefulWidget {
  final TrackerService tracker;
  const SettingsScreen({super.key, required this.tracker});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final WifiService _wifi = WifiService();

  bool _unlocked = false;
  bool _loading = true;
  AppSettings _settings = AppSettings();

  int _expectedHour = 8;
  int _expectedMinute = 0;
  int _gracePeriod = 5;
  final _finePerMinCtrl = TextEditingController();
  final _flatFineCtrl = TextEditingController();
  bool _useFlatFine = false;
  bool _hasPassword = false;

  // Selected WiFi network
  String _selectedSSID = '';
  String _selectedBSSID = '';

  // Scan state
  bool _scanning = false;
  String _scanStatus = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _finePerMinCtrl.dispose();
    _flatFineCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final s = await widget.tracker.getSettings();
    setState(() {
      _settings = s;
      _selectedSSID = s.targetSSID;
      _selectedBSSID = s.targetBSSID;
      _expectedHour = s.expectedHour;
      _expectedMinute = s.expectedMinute;
      _gracePeriod = s.gracePeriodMinutes;
      _finePerMinCtrl.text = s.finePerMinute.toStringAsFixed(2);
      _flatFineCtrl.text = s.flatFine.toStringAsFixed(2);
      _useFlatFine = s.useFlatFine;
      _hasPassword = s.passwordHash.isNotEmpty;
      _unlocked = s.passwordHash.isEmpty;
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_selectedSSID.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a WiFi network first'),
          backgroundColor: Color(0xFFFF6B6B),
        ),
      );
      return;
    }
    final updated = _settings.copyWith(
      targetSSID: _selectedSSID,
      targetBSSID: _selectedBSSID,
      expectedHour: _expectedHour,
      expectedMinute: _expectedMinute,
      gracePeriodMinutes: _gracePeriod,
      finePerMinute: double.tryParse(_finePerMinCtrl.text) ?? 1.0,
      flatFine: double.tryParse(_flatFineCtrl.text) ?? 50.0,
      useFlatFine: _useFlatFine,
    );
    await widget.tracker.saveSettings(updated);
    setState(() => _settings = updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved!'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    }
  }

  // ── Scan current WiFi and use it ─────────────────────────────────────────
  Future<void> _scanCurrentWifi() async {
    setState(() {
      _scanning = true;
      _scanStatus = 'Reading current WiFi…';
    });

    final network = await _wifi.getCurrentNetwork();

    if (network != null) {
      setState(() {
        _selectedSSID = network.ssid;
        _selectedBSSID = network.bssid;
        _scanning = false;
        _scanStatus = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected: ${network.ssid}'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } else {
      setState(() {
        _scanning = false;
        _scanStatus = 'Not connected to WiFi. Please connect first.';
      });
    }
  }

  // ── Show WiFi picker dialog ───────────────────────────────────────────────
  void _showWifiPickerDialog() {
    showDialog(
      context: context,
      builder: (_) => _WifiPickerDialog(
        wifiService: _wifi,
        currentSSID: _selectedSSID,
        currentBSSID: _selectedBSSID,
        onSelected: (ssid, bssid) {
          setState(() {
            _selectedSSID = ssid;
            _selectedBSSID = bssid;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showPasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PasswordDialog(
        storedHash: _settings.passwordHash,
        onVerified: () {
          setState(() => _unlocked = true);
          Navigator.pop(context);
        },
        onCancel: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showSetPasswordDialog() {
    showDialog(
      context: context,
      builder: (_) => _SetPasswordDialog(
        onSet: (hash) async {
          final updated = _settings.copyWith(passwordHash: hash);
          await widget.tracker.saveSettings(updated);
          setState(() {
            _settings = updated;
            _hasPassword = true;
          });
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('3-person password set!'),
                backgroundColor: Color(0xFF4CAF50),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF))),
      );
    }

    if (!_unlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showPasswordDialog());
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A0E1A),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Settings', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 64, color: Colors.white24),
              SizedBox(height: 16),
              Text('Settings are locked', style: TextStyle(color: Colors.white38)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFF00D4FF), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ── WiFi Network Selection ──────────────────────────────────────
          _Section(
            title: 'Attendance WiFi Network',
            icon: Icons.wifi_rounded,
            color: const Color(0xFF00D4FF),
            children: [
              // Current selection display
              if (_selectedSSID.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A2A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF4CAF50), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _selectedSSID,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.router_rounded,
                              color: Colors.white38, size: 13),
                          const SizedBox(width: 6),
                          Text(
                            'MAC: $_selectedBSSID',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (_scanStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _scanStatus,
                    style: const TextStyle(color: Color(0xFFFFB347), fontSize: 12),
                  ),
                ),

              // Button: use currently connected WiFi
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _scanning ? null : _scanCurrentWifi,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: const Color(0xFF0A0E1A),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _scanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF0A0E1A)),
                        )
                      : const Icon(Icons.wifi_find_rounded),
                  label: Text(
                    _scanning ? 'Reading WiFi…' : 'Use Current WiFi',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Button: pick from list of nearby networks
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showWifiPickerDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00D4FF),
                    side: const BorderSide(color: Color(0xFF00D4FF), width: 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.list_rounded),
                  label: const Text(
                    'Pick from Scanned Networks',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1830),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.security_rounded,
                        color: Color(0xFF7B61FF), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'MAC address is stored alongside the WiFi name to prevent spoofing — someone cannot fake attendance by creating a hotspot with the same name.',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Schedule ──────────────────────────────────────────────────────
          _Section(
            title: 'Attendance Schedule',
            icon: Icons.schedule_rounded,
            color: const Color(0xFF7B61FF),
            children: [
              _FieldLabel('Expected Check-in Time'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _NumberPicker(
                      label: 'Hour',
                      value: _expectedHour,
                      min: 0,
                      max: 23,
                      onChanged: (v) => setState(() => _expectedHour = v),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(':',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: _NumberPicker(
                      label: 'Minute',
                      value: _expectedMinute,
                      min: 0,
                      max: 59,
                      onChanged: (v) => setState(() => _expectedMinute = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _FieldLabel('Grace Period (minutes before marked Late)'),
              const SizedBox(height: 8),
              _NumberPicker(
                label: 'Minutes',
                value: _gracePeriod,
                min: 0,
                max: 60,
                onChanged: (v) => setState(() => _gracePeriod = v),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Fine System ───────────────────────────────────────────────────
          _Section(
            title: 'Late Fine System',
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFFFF6B6B),
            children: [
              Row(
                children: [
                  const Text('Fine type:',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => setState(() => _useFlatFine = false),
                    child: Row(
                      children: [
                        Radio<bool>(
                          value: false,
                          groupValue: _useFlatFine,
                          activeColor: const Color(0xFF00D4FF),
                          onChanged: (_) => setState(() => _useFlatFine = false),
                        ),
                        const Text('Per minute',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _useFlatFine = true),
                    child: Row(
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: _useFlatFine,
                          activeColor: const Color(0xFF00D4FF),
                          onChanged: (_) => setState(() => _useFlatFine = true),
                        ),
                        const Text('Flat',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_useFlatFine) ...[
                _FieldLabel('Fine per minute (ETB)'),
                _Input(
                  controller: _finePerMinCtrl,
                  hint: 'e.g. 1.00',
                  icon: Icons.timer_rounded,
                  keyboardType: TextInputType.number,
                ),
              ] else ...[
                _FieldLabel('Flat fine amount (ETB)'),
                _Input(
                  controller: _flatFineCtrl,
                  hint: 'e.g. 50.00',
                  icon: Icons.money_rounded,
                  keyboardType: TextInputType.number,
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // ── Password ──────────────────────────────────────────────────────
          _Section(
            title: 'Security — 3-Person Password',
            icon: Icons.lock_rounded,
            color: const Color(0xFFFFB347),
            children: [
              Text(
                _hasPassword
                    ? '✅ Settings are protected by 3-person authentication.'
                    : '⚠️ No password set. Settings are currently unprotected.',
                style: TextStyle(
                  color: _hasPassword
                      ? Colors.white60
                      : const Color(0xFFFFB347),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'All three people must enter their password part together to unlock settings.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showSetPasswordDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFB347),
                    side:
                        const BorderSide(color: Color(0xFFFFB347), width: 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.group_rounded),
                  label: Text(_hasPassword
                      ? 'Change 3-Person Password'
                      : 'Set 3-Person Password'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── WiFi Picker Dialog ──────────────────────────────────────────────────────

class _WifiPickerDialog extends StatefulWidget {
  final WifiService wifiService;
  final String currentSSID;
  final String currentBSSID;
  final void Function(String ssid, String bssid) onSelected;

  const _WifiPickerDialog({
    required this.wifiService,
    required this.currentSSID,
    required this.currentBSSID,
    required this.onSelected,
  });

  @override
  State<_WifiPickerDialog> createState() => _WifiPickerDialogState();
}

class _WifiPickerDialogState extends State<_WifiPickerDialog> {
  bool _loading = true;
  WifiNetwork? _current;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final network = await widget.wifiService.getCurrentNetwork();
      setState(() {
        _current = network;
        _loading = false;
        if (network == null) {
          _error = 'Not connected to any WiFi. Please connect first.';
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not read WiFi info: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1F35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.wifi_rounded, color: Color(0xFF00D4FF), size: 20),
          SizedBox(width: 8),
          Text('Select Attendance WiFi',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const SizedBox(
                height: 80,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF00D4FF)),
                      SizedBox(height: 12),
                      Text('Reading current WiFi…',
                          style: TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
              )
            : _error.isNotEmpty
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: Colors.white24, size: 48),
                      const SizedBox(height: 12),
                      Text(_error,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _scan,
                        icon: const Icon(Icons.refresh_rounded,
                            color: Color(0xFF00D4FF)),
                        label: const Text('Try Again',
                            style: TextStyle(color: Color(0xFF00D4FF))),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Currently connected to:',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      _WifiNetworkTile(
                        network: _current!,
                        isSelected: _current!.ssid == widget.currentSSID &&
                            _current!.bssid == widget.currentBSSID,
                        onTap: () => widget.onSelected(
                            _current!.ssid, _current!.bssid),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'To track a different network, connect your phone to that WiFi first, then come back here.',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: Colors.white38)),
        ),
        if (!_loading && _error.isEmpty)
          ElevatedButton(
            onPressed: _current != null
                ? () => widget.onSelected(_current!.ssid, _current!.bssid)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: const Color(0xFF0A0E1A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Use This Network',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class _WifiNetworkTile extends StatelessWidget {
  final WifiNetwork network;
  final bool isSelected;
  final VoidCallback onTap;

  const _WifiNetworkTile({
    required this.network,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00D4FF).withOpacity(0.1)
              : const Color(0xFF0A0E1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00D4FF)
                : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.wifi_rounded,
                  color: Color(0xFF00D4FF), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    network.ssid,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.router_rounded,
                          color: Colors.white38, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        network.bssid,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF00D4FF), size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Shared helper widgets ────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141828),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white54, fontSize: 12, letterSpacing: 0.5)),
      );
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;

  const _Input({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _NumberPicker extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberPicker({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: value > min ? () => onChanged(value - 1) : null,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6)),
              child:
                  const Icon(Icons.remove, color: Colors.white, size: 16),
            ),
          ),
          Column(
            children: [
              Text(
                value.toString().padLeft(2, '0'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700),
              ),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 10)),
            ],
          ),
          GestureDetector(
            onTap: value < max ? () => onChanged(value + 1) : null,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Password dialogs ─────────────────────────────────────────────────────────

class _PasswordDialog extends StatefulWidget {
  final String storedHash;
  final VoidCallback onVerified;
  final VoidCallback onCancel;

  const _PasswordDialog({
    required this.storedHash,
    required this.onVerified,
    required this.onCancel,
  });

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  final _p3 = TextEditingController();
  String? _error;

  void _verify() {
    final ok = PasswordService.verify(_p1.text, _p2.text, _p3.text, widget.storedHash);
    if (ok) {
      widget.onVerified();
    } else {
      setState(() => _error = 'Incorrect combination. All three parts must match.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1F35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.lock_rounded, color: Color(0xFFFFB347), size: 20),
          SizedBox(width: 8),
          Text('Settings Locked',
              style: TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter all three password parts:',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),
          _PassField(_p1, 'Person 1 password', Icons.person_rounded),
          const SizedBox(height: 10),
          _PassField(_p2, 'Person 2 password', Icons.person_rounded),
          const SizedBox(height: 10),
          _PassField(_p3, 'Person 3 password', Icons.person_rounded),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style:
                    const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel',
              style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          onPressed: _verify,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB347),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child:
              const Text('Unlock', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _SetPasswordDialog extends StatefulWidget {
  final ValueChanged<String> onSet;
  const _SetPasswordDialog({required this.onSet});

  @override
  State<_SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends State<_SetPasswordDialog> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  final _p3 = TextEditingController();
  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  final _c3 = TextEditingController();
  String? _error;

  void _setPassword() {
    if (_p1.text.isEmpty || _p2.text.isEmpty || _p3.text.isEmpty) {
      setState(() => _error = 'All three passwords are required.');
      return;
    }
    if (_p1.text != _c1.text || _p2.text != _c2.text || _p3.text != _c3.text) {
      setState(() => _error = 'Confirmation passwords do not match.');
      return;
    }
    final hash = PasswordService.hashCombinedPassword(_p1.text, _p2.text, _p3.text);
    widget.onSet(hash);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1F35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.group_rounded, color: Color(0xFFFFB347), size: 20),
          SizedBox(width: 8),
          Text('Set 3-Person Password',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Each person sets their own part. All three are required together.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _PersonSection('Person 1', _p1, _c1, const Color(0xFF00D4FF)),
            const SizedBox(height: 12),
            _PersonSection('Person 2', _p2, _c2, const Color(0xFF7B61FF)),
            const SizedBox(height: 12),
            _PersonSection('Person 3', _p3, _c3, const Color(0xFF4CAF50)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFFF6B6B), fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          onPressed: _setPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB347),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Set Password',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _PersonSection extends StatelessWidget {
  final String person;
  final TextEditingController passCtrl;
  final TextEditingController confirmCtrl;
  final Color color;

  const _PersonSection(this.person, this.passCtrl, this.confirmCtrl, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(person,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _PassField(passCtrl, 'Password', Icons.lock_outline_rounded),
          const SizedBox(height: 6),
          _PassField(confirmCtrl, 'Confirm password', Icons.lock_rounded),
        ],
      ),
    );
  }
}

class _PassField extends StatefulWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  const _PassField(this.ctrl, this.hint, this.icon);

  @override
  State<_PassField> createState() => _PassFieldState();
}

class _PassFieldState extends State<_PassField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: widget.ctrl,
        obscureText: _obscure,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle:
              const TextStyle(color: Colors.white24, fontSize: 13),
          prefixIcon: Icon(widget.icon, color: Colors.white38, size: 18),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(
              _obscure
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: Colors.white38,
              size: 18,
            ),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}
