// lib/models/connection_record.dart

enum ConnectionStatus { onTime, delayed, unknown }

class ConnectionRecord {
  final String id;
  final String wifiSSID;
  final String wifiBSSID;         // MAC address of the access point
  final DateTime connectedAt;     // Internet time (NTP)
  final DateTime expectedTime;
  final ConnectionStatus status;
  final double fineAmount;
  final int delayMinutes;

  ConnectionRecord({
    required this.id,
    required this.wifiSSID,
    required this.wifiBSSID,
    required this.connectedAt,
    required this.expectedTime,
    required this.status,
    required this.fineAmount,
    required this.delayMinutes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'wifiSSID': wifiSSID,
        'wifiBSSID': wifiBSSID,
        'connectedAt': connectedAt.toIso8601String(),
        'expectedTime': expectedTime.toIso8601String(),
        'status': status.name,
        'fineAmount': fineAmount,
        'delayMinutes': delayMinutes,
      };

  factory ConnectionRecord.fromJson(Map<String, dynamic> json) {
    return ConnectionRecord(
      id: json['id'],
      wifiSSID: json['wifiSSID'] ?? '',
      wifiBSSID: json['wifiBSSID'] ?? '',
      connectedAt: DateTime.parse(json['connectedAt']),
      expectedTime: DateTime.parse(json['expectedTime']),
      status: ConnectionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ConnectionStatus.unknown,
      ),
      fineAmount: (json['fineAmount'] as num).toDouble(),
      delayMinutes: json['delayMinutes'] as int,
    );
  }
}
