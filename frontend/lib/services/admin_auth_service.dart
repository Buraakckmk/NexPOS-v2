import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "api_client.dart";

/// Admin PIN doğrulaması için servis
class AdminAuthService {
  /// PIN doğrula - Sadece role_id 1 (Admin) için true dönülür
  static Future<bool> verifyAdminPin(String pinCode) async {
    try {
      final response = await ApiClient.dio.post(
        "/auth/verify-admin",
        data: {"pin_code": pinCode},
        options: Options(extra: {"showGlobalError": false}),
      );

      final data = response.data as Map<String, dynamic>;
      final isAdmin = data["is_admin"] ?? false;

      if (isAdmin) {
        final fullName = (data["full_name"] ?? "").toString();
        debugPrint("Admin doğrulandı: $fullName");
      }

      return isAdmin;
    } catch (e) {
      debugPrint("Admin PIN doğrulama hatası: $e");
      return false;
    }
  }
}
