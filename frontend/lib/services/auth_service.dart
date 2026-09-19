import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../models/auth_user.dart";
import "api_client.dart";

class LoginResponse {
  final String accessToken;
  final AuthUser user;

  const LoginResponse({required this.accessToken, required this.user});
}

class AuthService {
  static const String _urgentSupportText =
      "Acil: Destek birimi ile iletişime geçin.";

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<LoginResponse> loginWithPin(String pin) async {
    try {
      final response = await ApiClient.dio.post(
        "/auth/login/pin",
        data: {"pin_code": pin},
        options: Options(extra: {"showGlobalError": false}),
      );

      if (response.statusCode != 200) {
        throw Exception("Giriş işlemi tamamlanamadı. Lütfen tekrar deneyin.");
      }

      final data = response.data as Map<String, dynamic>;
      final token = (data["access_token"] ?? "").toString();
      final userJson = data["user"] as Map<String, dynamic>? ?? {};

      if (token.isEmpty) {
        throw Exception("Giriş işlemi tamamlanamadı. Lütfen tekrar deneyin.");
      }

      if (userJson.isEmpty || userJson["role_id"] == null) {
        throw Exception("Kullanıcı bilgileri alınamadı. $_urgentSupportText");
      }

      ApiClient.setAccessToken(token);
      if (_isMobilePlatform) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("access_token", token);
        } catch (_) {}
      }

      return LoginResponse(
        accessToken: token,
        user: AuthUser.fromJson(userJson),
      );
    } on DioException catch (e) {
      final serverMessage = e.response?.data is Map<String, dynamic>
          ? (e.response?.data["message"]?.toString() ?? "")
          : "";

      if (serverMessage.isNotEmpty && !_containsTechnicalTerms(serverMessage)) {
        throw Exception(serverMessage);
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception(
          "Sisteme şu an ulaşılamıyor. Lütfen kısa süre sonra tekrar deneyin. $_urgentSupportText",
        );
      }

      if (e.type == DioExceptionType.connectionError) {
        throw Exception("Sistem bağlantısı kurulamadı. $_urgentSupportText");
      }

      final statusCode = e.response?.statusCode;
      if (statusCode != null) {
        if (statusCode >= 500) {
          throw Exception("Sistem şu an hizmet veremiyor. $_urgentSupportText");
        }
        throw Exception("Giriş işlemi tamamlanamadı. Lütfen tekrar deneyin.");
      }

      throw Exception("Giriş işlemi tamamlanamadı. Lütfen tekrar deneyin.");
    }
  }

  bool _containsTechnicalTerms(String message) {
    final lower = message.toLowerCase();
    return lower.contains("token") ||
        lower.contains("backend") ||
        lower.contains("api") ||
        lower.contains("http") ||
        lower.contains("server") ||
        lower.contains("sunucu");
  }

  Future<void> logout() async {
    ApiClient.setAccessToken(null);
    if (!_isMobilePlatform) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("access_token");
    } catch (_) {}
  }
}
