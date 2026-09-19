import "package:flutter/foundation.dart";

import "../models/auth_user.dart";
import "../services/auth_service.dart";

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider(this._authService);

  bool _isLoading = false;
  String _pin = "";
  String? _errorMessage;
  AuthUser? _currentUser;

  bool get isLoading => _isLoading;
  String get pin => _pin;
  String? get errorMessage => _errorMessage;
  AuthUser? get currentUser => _currentUser;
  bool get isAdmin => _currentUser?.roleId == 1;

  void addDigit(String digit) {
    if (_isLoading || _pin.length >= 6) return;
    _pin += digit;
    _errorMessage = null;
    notifyListeners();
  }

  void removeDigit() {
    if (_isLoading || _pin.isEmpty) return;
    _pin = _pin.substring(0, _pin.length - 1);
    _errorMessage = null;
    notifyListeners();
  }

  void clearPin() {
    if (_isLoading) return;
    _pin = "";
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> submitPinIfReady() async {
    if (_pin.length != 6 || _isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    _currentUser = null;
    notifyListeners();

    try {
      final response = await _authService.loginWithPin(_pin);
      _currentUser = response.user;
      _isLoading = false;
      _pin = "";
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      _currentUser = null;
      _pin = "";
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitCredentials({
    required String username,
    required String password,
  }) async {
    if (_isLoading) return false;

    final normalizedPin = password.trim();
    if (normalizedPin.length != 6 || int.tryParse(normalizedPin) == null) {
      _errorMessage = "Şifre 6 haneli PIN olmalıdır.";
      notifyListeners();
      return false;
    }

    final expectedName = username.trim().toLowerCase();

    _isLoading = true;
    _errorMessage = null;
    _currentUser = null;
    notifyListeners();

    try {
      final response = await _authService.loginWithPin(normalizedPin);
      final actualName = response.user.fullName.trim().toLowerCase();

      if (expectedName.isNotEmpty && expectedName != actualName) {
        await _authService.logout();
        throw Exception("Kullanıcı adı veya şifre hatalı.");
      }

      _currentUser = response.user;
      _isLoading = false;
      _pin = "";
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      _currentUser = null;
      _pin = "";
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
    } finally {
      _currentUser = null;
      _pin = "";
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    }
  }
}
