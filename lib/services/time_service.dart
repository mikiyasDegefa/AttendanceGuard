// lib/services/time_service.dart
//
// Fetches accurate internet time via HTTP headers (worldtimeapi.org).
// Falls back to device time if network is unavailable.

import 'dart:async';
import 'package:http/http.dart' as http;

class TimeService {
  static const List<String> _ntpUrls = [
    'https://worldtimeapi.org/api/ip',
    'https://timeapi.io/api/Time/current/zone?timeZone=UTC',
  ];

  /// Returns current time from the internet.
  /// Falls back to device time on failure.
  static Future<DateTime> getInternetTime() async {
    // Try worldtimeapi first
    try {
      final response = await http
          .get(Uri.parse(_ntpUrls[0]))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        // The response body contains JSON with "utc_datetime"
        final body = response.body;
        final match = RegExp(r'"utc_datetime"\s*:\s*"([^"]+)"').firstMatch(body);
        if (match != null) {
          return DateTime.parse(match.group(1)!).toLocal();
        }
      }
    } catch (_) {}

    // Try timeapi.io as fallback
    try {
      final response = await http
          .get(Uri.parse(_ntpUrls[1]))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = response.body;
        final match = RegExp(r'"dateTime"\s*:\s*"([^"]+)"').firstMatch(body);
        if (match != null) {
          // timeapi returns local datetime
          return DateTime.parse(match.group(1)!);
        }
      }
    } catch (_) {}

    // Last resort: device time
    return DateTime.now();
  }

  /// Returns true if we successfully reached the internet for time.
  static Future<bool> isInternetTimeAvailable() async {
    try {
      final response = await http
          .head(Uri.parse('https://worldtimeapi.org'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}
