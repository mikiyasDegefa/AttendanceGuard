// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/connection_record.dart';
import '../models/app_settings.dart';
import '../services/tracker_service.dart';
import '../services/wifi_service.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final TrackerService tracker;
  const HomeScreen({super.key, required this.tracker});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final WifiService _wifi = WifiService();

  String _statusMessage = 'Monitoring attendance WiFi…';
  String? _currentSSID;
  String? _currentBSSID;
  bool _isConnected = false;
  AppSettings _settings = AppSettings();
  ConnectionRecord? _lastRecord;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.tracker.onNewRecord = (record) {
      if (mounted) setState(() => _lastRecord = record);
    };
    widget.tracker.onStatusMessage = (msg) {
      if (mounted) setState(() => _statusMessage = msg);
    };
    widget.tracker.startMonitoring();
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.tracker.stopMonitoring();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final settings = await widget.tracker.getSettings();
    final network = await _wifi.getCurrentNetwork();
    final isOnTarget = settings.targetSSID.isNotEmpty &&
        await _wifi.isConnectedToTarget(settings.targetSSID, settings.targetBSSID);
    final history = await widget.tracker.getHistory();
    if (mounted) {
      setState(() {
        _settings = settings;
        _currentSSID = network?.ssid;
        _currentBSSID = network?.bssid;
        _isConnected = isOnTarget;
        _statusMessage = isOnTarget
            ? 'Connected to ${settings.targetSSID}'
            : settings.targetSSID.isEmpty
                ? 'No attendance WiFi configured. Go to Settings.'
                : 'Not connected to attendance WiFi';
        _lastRecord = history.isNotEmpty ? history.first : null;
      });
    }
  }

  Future<void> _checkNow() async {
    setState(() => _isChecking = true);
    await widget.tracker.checkNow();
    await _refresh();
    setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    final expectedTime =
        '${_settings.expectedHour.toString().padLeft(2, '0')}:${_settings.expectedMinute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.co_present_rounded,
                  color: Color(0xFF00D4FF), size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'AttendanceGuard',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white70),
            tooltip: 'Attendance History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => HistoryScreen(tracker: widget.tracker)),
            ).then((_) => _refresh()),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white70),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => SettingsScreen(tracker: widget.tracker)),
            ).then((_) => _refresh()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFF00D4FF),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Status card ──────────────────────────────────────────────
              _StatusCard(
                isConnected: _isConnected,
                ssid: _currentSSID,
                bssid: _currentBSSID,
                targetSSID: _settings.targetSSID,
                statusMessage: _statusMessage,
              ),
              const SizedBox(height: 20),

              // ── Info tiles ───────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _InfoTile(
                      icon: Icons.access_time_rounded,
                      label: 'Check-in Time',
                      value: expectedTime,
                      color: const Color(0xFF00D4FF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoTile(
                      icon: Icons.timer_outlined,
                      label: 'Grace Period',
                      value: '${_settings.gracePeriodMinutes} min',
                      color: const Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InfoTile(
                      icon: Icons.attach_money_rounded,
                      label: 'Late Fine',
                      value: _settings.useFlatFine
                          ? 'ETB ${_settings.flatFine.toStringAsFixed(0)} flat'
                          : 'ETB ${_settings.finePerMinute.toStringAsFixed(2)}/min',
                      color: const Color(0xFFFF6B6B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoTile(
                      icon: Icons.router_rounded,
                      label: 'MAC Verified',
                      value: _settings.targetBSSID.isNotEmpty ? 'Yes ✓' : 'No',
                      color: _settings.targetBSSID.isNotEmpty
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFFB347),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Mark attendance button ───────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isChecking ? null : _checkNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: const Color(0xFF0A0E1A),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  icon: _isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF0A0E1A)),
                        )
                      : const Icon(Icons.how_to_reg_rounded),
                  label: Text(
                    _isChecking ? 'Marking Attendance…' : 'Mark Attendance Now',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Last record ──────────────────────────────────────────────
              if (_lastRecord != null) ...[
                const Text(
                  'LAST ATTENDANCE',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                _LastRecordCard(record: _lastRecord!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final bool isConnected;
  final String? ssid;
  final String? bssid;
  final String targetSSID;
  final String statusMessage;

  const _StatusCard({
    required this.isConnected,
    required this.ssid,
    required this.bssid,
    required this.targetSSID,
    required this.statusMessage,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isConnected ? const Color(0xFF4CAF50) : const Color(0xFF666680);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141828),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.12),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(
              isConnected
                  ? Icons.how_to_reg_rounded
                  : Icons.wifi_off_rounded,
              color: color,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isConnected ? 'ATTENDANCE WIFI DETECTED' : 'NOT ON ATTENDANCE WIFI',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            statusMessage,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (ssid != null && ssid!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_rounded,
                          color: Colors.white38, size: 13),
                      const SizedBox(width: 6),
                      Text(ssid!,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  if (bssid != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.router_rounded,
                            color: Colors.white24, size: 11),
                        const SizedBox(width: 6),
                        Text(bssid!,
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            )),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141828),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LastRecordCard extends StatelessWidget {
  final ConnectionRecord record;
  const _LastRecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final isDelayed = record.status == ConnectionStatus.delayed;
    final color =
        isDelayed ? const Color(0xFFFF6B6B) : const Color(0xFF4CAF50);
    final fmt = DateFormat('MMM dd, yyyy  HH:mm');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141828),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isDelayed ? '⚠️ LATE' : '✅ ON TIME',
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              Text(record.wifiSSID,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          _Row('Checked in', fmt.format(record.connectedAt)),
          _Row('Expected', fmt.format(record.expectedTime)),
          _Row('MAC', record.wifiBSSID,
              mono: true, valueColor: Colors.white38),
          if (isDelayed) ...[
            _Row('Late by', '${record.delayMinutes} minutes'),
            _Row('Fine', 'ETB ${record.fineAmount.toStringAsFixed(2)}',
                valueColor: const Color(0xFFFF6B6B)),
          ],
        ],
      ),
    );
  }

  Widget _Row(String label, String value,
      {Color? valueColor, bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: mono ? 11 : 13,
                fontWeight: FontWeight.w600,
                fontFamily: mono ? 'monospace' : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
