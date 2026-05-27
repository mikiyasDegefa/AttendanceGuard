# WiFi Connection Time Tracker

A Flutter mobile app that tracks WiFi connection time, detects delays, and enforces a fine system — with a 3-person security password protecting all settings.

---

## Features

| Feature | Description |
|---|---|
| 📡 WiFi Detection | Automatically detects when you connect to your target WiFi |
| 🌐 Internet Time | Fetches real time from the internet (worldtimeapi.org), NOT your device clock |
| ⏰ Schedule Tracking | Compares connection time against your expected time |
| ⚠️ Delay Detection | Marks connections as DELAYED if past the grace period |
| 💰 Fine System | Calculates fines — flat fee or per-minute rate (in ETB) |
| 📋 History | Full history log filterable by On Time / Delayed |
| 📊 Summary Stats | Total connections, delay count, total fines |
| 🔒 3-Person Password | Settings locked by combined password from 3 people |

---

## Setup Instructions

### 1. Install Flutter

```bash
# Install Flutter SDK from https://flutter.dev
flutter --version  # should be 3.10+
```

### 2. Get dependencies

```bash
cd wifi_tracker
flutter pub get
```

### 3. Run on Android

```bash
flutter run
```

> **Note:** iOS requires additional entitlements for WiFi SSID access. Android is the primary supported platform.

---

## Android Permissions Required

The app requires these permissions:
- `ACCESS_FINE_LOCATION` — Required on Android 8.1+ to read WiFi SSID
- `ACCESS_WIFI_STATE` — To detect WiFi connections
- `INTERNET` — To fetch internet time

When you first run the app, it will ask for Location permission — this is needed to read the WiFi name (SSID). This is an Android requirement, not something the app uses for GPS.

---

## How the 3-Person Password Works

The settings password is created by combining three people's individual passwords:

```
final_password = SHA256(person1_password + person2_password + person3_password)
```

- **Person 1**, **Person 2**, and **Person 3** each choose their own secret part
- All three parts must be entered together in order to unlock settings
- If any one person forgets their part, settings cannot be changed
- The password is stored as a SHA-256 hash — never in plain text

### Setting the password:
1. Go to Settings (gear icon)
2. Scroll to "Security" section
3. Tap "Set 3-Person Password"
4. Each person enters and confirms their part
5. Tap "Set Password"

### Unlocking settings:
- All three people enter their individual passwords when prompted

---

## How Fine Calculation Works

```
Expected time: 08:00
Grace period: 5 minutes
Connected at: 08:23 (internet time)

Delay = 23 minutes
Fine (per-minute @ 1.00 ETB/min) = 23.00 ETB
Fine (flat @ 50.00 ETB) = 50.00 ETB
```

- Connections within the grace period are marked **ON TIME** (no fine)
- Connections after the grace period are marked **DELAYED**
- The fine amount is stored with each history record

---

## Internet Time Sources

The app tries these in order:
1. `https://worldtimeapi.org/api/ip` — Primary
2. `https://timeapi.io/api/Time/current/zone?timeZone=UTC` — Fallback
3. Device time — Last resort (shown in status if used)

---

## Project Structure

```
lib/
├── main.dart                     # App entry point
├── models/
│   ├── app_settings.dart         # Settings data model
│   └── connection_record.dart    # History record model
├── services/
│   ├── storage_service.dart      # SharedPreferences persistence
│   ├── time_service.dart         # Internet NTP time fetcher
│   ├── wifi_service.dart         # WiFi SSID detection
│   ├── password_service.dart     # 3-person SHA-256 password
│   └── tracker_service.dart      # Core business logic
└── screens/
    ├── home_screen.dart          # Dashboard & status
    ├── history_screen.dart       # Connection history log
    └── settings_screen.dart      # Settings + password UI
```

---

## Suggested Enhancements

- 📤 **Export to CSV/Excel** — Export history for reporting
- 📱 **Push notifications** — Alert when connection is approaching expected time
- 🔔 **Background service** — Monitor WiFi even when app is closed
- 👤 **Multiple profiles** — Track different people / shifts
- 📈 **Charts** — Weekly/monthly delay trends
- ☁️ **Cloud sync** — Back up history to Firebase

---

## Dependencies

```yaml
shared_preferences: ^2.2.2      # Local storage
network_info_plus: ^5.0.3       # WiFi SSID reading
http: ^1.2.0                    # Internet time fetch
intl: ^0.19.0                   # Date formatting
crypto: ^3.0.3                  # SHA-256 password hashing
connectivity_plus: ^6.0.3       # Network state monitoring
permission_handler: ^11.3.0     # Runtime permissions
```
