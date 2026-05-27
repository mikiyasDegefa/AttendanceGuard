// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/tracker_service.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const AttendanceGuardApp());
}

class AttendanceGuardApp extends StatelessWidget {
  const AttendanceGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AttendanceGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00D4FF),
          secondary: const Color(0xFF7B61FF),
          surface: const Color(0xFF141828),
          background: const Color(0xFF0A0E1A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: HomeScreen(tracker: TrackerService()),
    );
  }
}
