import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application-wide constants.
class AppConstants {
  AppConstants._();

  // ── API ──────────────────────────────────────────────────────────────────
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'https://api.example.com/';
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 15000;

  // ── Secure Storage Keys ────────────────────────────────────────────────
  static const String tokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';

  // ── App Info ───────────────────────────────────────────────────────────
  static String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';
}
