// lib/services/wifi_service.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class WifiNetwork {
  final String ssid;
  final String bssid; // MAC address of the access point

  WifiNetwork({required this.ssid, required this.bssid});

  @override
  String toString() => '$ssid ($bssid)';
}

class WifiService {
  final _connectivity = Connectivity();
  final _networkInfo = NetworkInfo();

  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  /// Returns the currently connected WiFi's SSID (name), stripping Android quotes.
  Future<String?> getCurrentSSID() async {
    try {
      final ssid = await _networkInfo.getWifiName();
      if (ssid == null) return null;
      return ssid.replaceAll('"', '');
    } catch (_) {
      return null;
    }
  }

  /// Returns the currently connected WiFi's BSSID (MAC address of the router).
  Future<String?> getCurrentBSSID() async {
    try {
      final bssid = await _networkInfo.getWifiBSSID();
      return bssid;
    } catch (_) {
      return null;
    }
  }

  /// Returns both SSID and BSSID of the current WiFi connection.
  Future<WifiNetwork?> getCurrentNetwork() async {
    try {
      final ssid = await getCurrentSSID();
      final bssid = await getCurrentBSSID();
      if (ssid == null || bssid == null) return null;
      return WifiNetwork(ssid: ssid, bssid: bssid);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isConnectedToWifi() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  /// Checks SSID AND BSSID (MAC) match.
  /// If targetBSSID is empty, falls back to SSID-only check.
  Future<bool> isConnectedToTarget(String targetSSID, String targetBSSID) async {
    if (!await isConnectedToWifi()) return false;
    final network = await getCurrentNetwork();
    if (network == null) return false;

    final ssidMatch = network.ssid.toLowerCase() == targetSSID.toLowerCase();

    // If a BSSID is stored, enforce it for anti-spoofing
    if (targetBSSID.isNotEmpty) {
      final bssidMatch = network.bssid.toLowerCase() == targetBSSID.toLowerCase();
      return ssidMatch && bssidMatch;
    }

    return ssidMatch;
  }
}
