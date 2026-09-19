import "package:shared_preferences/shared_preferences.dart";
import "package:flutter/foundation.dart";

class ApiConstants {
  ApiConstants._();

  static const String _serverHostPrefKey = "local_server_host";
  static const String _fixedServerHost = "127.0.0.1";
  static const String _defaultLanHost = String.fromEnvironment(
    "API_SERVER_HOST",
    defaultValue: _fixedServerHost,
  );
  static const int apiPort = int.fromEnvironment(
    "API_PORT",
    defaultValue: 3002,
  );

  static String _serverHost = _defaultLanHost;

  static Future<void> init() async {
    // Desktop kasa cihazlarında backend aynı makinede çalıştığı için
    // kayıtlı LAN host değerini yok sayıp localhost kullanıyoruz.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      _serverHost = "127.0.0.1";
      return;
    }

    _serverHost = _defaultLanHost;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedHost = prefs.getString(_serverHostPrefKey)?.trim();
      if (savedHost != null && savedHost.isNotEmpty) {
        _serverHost = savedHost;
      }
    } catch (_) {
      // Ignore local storage failures and keep default host.
    }
  }

  static Future<bool> setServerHost(String serverHost) async {
    final normalized = serverHost.trim();
    if (normalized.isEmpty) {
      return false;
    }

    _serverHost = normalized;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_serverHostPrefKey, normalized);
    } catch (_) {
      // Host is still set in-memory even if persisting fails.
    }

    return true;
  }

  static String get serverHost => _serverHost;

  static String get baseUrl => "http://$_serverHost:$apiPort/api";
}
