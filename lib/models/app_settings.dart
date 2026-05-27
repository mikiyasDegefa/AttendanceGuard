// lib/models/app_settings.dart

class AppSettings {
  final String targetSSID;
  final String targetBSSID;       // WiFi MAC address — harder to clone/spoof
  final int expectedHour;
  final int expectedMinute;
  final double finePerMinute;
  final double flatFine;
  final bool useFlatFine;
  final String passwordHash;
  final int gracePeriodMinutes;

  AppSettings({
    this.targetSSID = '',
    this.targetBSSID = '',
    this.expectedHour = 8,
    this.expectedMinute = 0,
    this.finePerMinute = 1.0,
    this.flatFine = 50.0,
    this.useFlatFine = false,
    this.passwordHash = '',
    this.gracePeriodMinutes = 5,
  });

  AppSettings copyWith({
    String? targetSSID,
    String? targetBSSID,
    int? expectedHour,
    int? expectedMinute,
    double? finePerMinute,
    double? flatFine,
    bool? useFlatFine,
    String? passwordHash,
    int? gracePeriodMinutes,
  }) {
    return AppSettings(
      targetSSID: targetSSID ?? this.targetSSID,
      targetBSSID: targetBSSID ?? this.targetBSSID,
      expectedHour: expectedHour ?? this.expectedHour,
      expectedMinute: expectedMinute ?? this.expectedMinute,
      finePerMinute: finePerMinute ?? this.finePerMinute,
      flatFine: flatFine ?? this.flatFine,
      useFlatFine: useFlatFine ?? this.useFlatFine,
      passwordHash: passwordHash ?? this.passwordHash,
      gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'targetSSID': targetSSID,
        'targetBSSID': targetBSSID,
        'expectedHour': expectedHour,
        'expectedMinute': expectedMinute,
        'finePerMinute': finePerMinute,
        'flatFine': flatFine,
        'useFlatFine': useFlatFine,
        'passwordHash': passwordHash,
        'gracePeriodMinutes': gracePeriodMinutes,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      targetSSID: json['targetSSID'] ?? '',
      targetBSSID: json['targetBSSID'] ?? '',
      expectedHour: json['expectedHour'] ?? 8,
      expectedMinute: json['expectedMinute'] ?? 0,
      finePerMinute: (json['finePerMinute'] as num?)?.toDouble() ?? 1.0,
      flatFine: (json['flatFine'] as num?)?.toDouble() ?? 50.0,
      useFlatFine: json['useFlatFine'] ?? false,
      passwordHash: json['passwordHash'] ?? '',
      gracePeriodMinutes: json['gracePeriodMinutes'] ?? 5,
    );
  }
}
