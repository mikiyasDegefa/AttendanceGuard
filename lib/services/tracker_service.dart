// lib/services/tracker_service.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/app_settings.dart';
import '../models/connection_record.dart';
import 'storage_service.dart';
import 'time_service.dart';
import 'wifi_service.dart';

class TrackerService {
  final StorageService _storage = StorageService();
  final WifiService _wifi = WifiService();

  StreamSubscription? _connectivitySub;
  bool _wasConnected = false;

  Function(ConnectionRecord)? onNewRecord;
  Function(String)? onStatusMessage;

  void startMonitoring() {
    _connectivitySub = _wifi.connectivityStream.listen(_onConnectivityChanged);
    _checkCurrentState();
  }

  void stopMonitoring() {
    _connectivitySub?.cancel();
  }

  Future<void> _checkCurrentState() async {
    final settings = await _storage.loadSettings();
    if (settings.targetSSID.isEmpty) return;
    final connected = await _wifi.isConnectedToTarget(settings.targetSSID, settings.targetBSSID);
    if (connected && !_wasConnected) {
      _wasConnected = true;
      await _handleNewConnection(settings);
    } else if (!connected) {
      _wasConnected = false;
    }
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final settings = await _storage.loadSettings();
    if (settings.targetSSID.isEmpty) return;

    final isWifi = results.contains(ConnectivityResult.wifi);

    if (isWifi) {
      await Future.delayed(const Duration(seconds: 2));
      final onTarget = await _wifi.isConnectedToTarget(settings.targetSSID, settings.targetBSSID);
      if (onTarget && !_wasConnected) {
        _wasConnected = true;
        await _handleNewConnection(settings);
      }
    } else {
      _wasConnected = false;
      onStatusMessage?.call('Disconnected from WiFi');
    }
  }

  Future<void> _handleNewConnection(AppSettings settings) async {
    onStatusMessage?.call('Attendance detected! Fetching internet time…');

    DateTime internetTime;
    try {
      internetTime = await TimeService.getInternetTime();
    } catch (_) {
      internetTime = DateTime.now();
    }

    final expectedTime = DateTime(
      internetTime.year,
      internetTime.month,
      internetTime.day,
      settings.expectedHour,
      settings.expectedMinute,
    );

    final diffMinutes = internetTime.difference(expectedTime).inMinutes;
    final isDelayed = diffMinutes > settings.gracePeriodMinutes;
    final delayMinutes = isDelayed ? diffMinutes : 0;

    double fine = 0.0;
    if (isDelayed) {
      fine = settings.useFlatFine
          ? settings.flatFine
          : delayMinutes * settings.finePerMinute;
    }

    // Get current BSSID to store in the record
    final network = await _wifi.getCurrentNetwork();

    final record = ConnectionRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      wifiSSID: settings.targetSSID,
      wifiBSSID: network?.bssid ?? settings.targetBSSID,
      connectedAt: internetTime,
      expectedTime: expectedTime,
      status: isDelayed ? ConnectionStatus.delayed : ConnectionStatus.onTime,
      fineAmount: fine,
      delayMinutes: delayMinutes,
    );

    await _storage.saveRecord(record);
    onNewRecord?.call(record);

    final msg = isDelayed
        ? '⚠️ Late by $delayMinutes min — Fine: ETB ${fine.toStringAsFixed(2)}'
        : '✅ Attendance marked on time!';
    onStatusMessage?.call(msg);
  }

  Future<ConnectionRecord?> checkNow() async {
    final settings = await _storage.loadSettings();
    if (settings.targetSSID.isEmpty) return null;
    final onTarget = await _wifi.isConnectedToTarget(settings.targetSSID, settings.targetBSSID);
    if (!onTarget) return null;
    _wasConnected = true;
    await _handleNewConnection(settings);
    final history = await _storage.loadHistory();
    return history.isNotEmpty ? history.first : null;
  }

  Future<List<ConnectionRecord>> getHistory() => _storage.loadHistory();
  Future<AppSettings> getSettings() => _storage.loadSettings();
  Future<void> saveSettings(AppSettings s) => _storage.saveSettings(s);
  // NOTE: No delete/clear exposed — history is permanent by design
}
