// lib/services/storage_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/connection_record.dart';
import '../models/app_settings.dart';

class StorageService {
  static const String _settingsKey = 'app_settings';
  static const String _historyKey = 'connection_history';

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw));
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  // ── History ───────────────────────────────────────────────────────────────

  Future<List<ConnectionRecord>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => ConnectionRecord.fromJson(e)).toList()
        ..sort((a, b) => b.connectedAt.compareTo(a.connectedAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRecord(ConnectionRecord record) async {
    final history = await loadHistory();
    history.add(record);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      jsonEncode(history.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> deleteRecord(String id) async {
    final history = await loadHistory();
    history.removeWhere((r) => r.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      jsonEncode(history.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
