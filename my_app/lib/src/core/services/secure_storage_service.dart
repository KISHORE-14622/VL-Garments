import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class SecureStorageService {
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _userNameKey = 'user_name';
  static const _userEmailKey = 'user_email';
  static const _hasPinKey = 'has_pin';
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _pinKey = 'user_pin';

  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;

  SecureStorageService()
      : _secureStorage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        ),
        _localAuth = LocalAuthentication();

  // ========== TOKEN MANAGEMENT ==========

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _secureStorage.delete(key: _tokenKey);
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ========== USER DATA ==========

  Future<void> saveUserData({
    required String userId,
    required String name,
    required String email,
    required bool hasPin,
    required bool biometricEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_userNameKey, name);
    await prefs.setString(_userEmailKey, email);
    await prefs.setBool(_hasPinKey, hasPin);
    await prefs.setBool(_biometricEnabledKey, biometricEnabled);
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    if (userId == null) return null;

    return {
      'id': userId,
      'name': prefs.getString(_userNameKey) ?? '',
      'email': prefs.getString(_userEmailKey) ?? '',
      'hasPin': prefs.getBool(_hasPinKey) ?? false,
      'biometricEnabled': prefs.getBool(_biometricEnabledKey) ?? false,
    };
  }

  Future<void> updatePinStatus(bool hasPin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasPinKey, hasPin);
  }

  Future<void> updateBiometricStatus(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasPinKey) ?? false;
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  // ========== LOCAL PIN STORAGE (for offline verification) ==========

  Future<void> saveLocalPin(String pin) async {
    await _secureStorage.write(key: _pinKey, value: pin);
  }

  Future<String?> getLocalPin() async {
    return await _secureStorage.read(key: _pinKey);
  }

  Future<bool> verifyLocalPin(String pin) async {
    final storedPin = await getLocalPin();
    return storedPin == pin;
  }

  Future<void> deleteLocalPin() async {
    await _secureStorage.delete(key: _pinKey);
  }

  // ========== BIOMETRIC AUTHENTICATION ==========

  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  Future<bool> authenticateWithBiometrics({String reason = 'Authenticate to access VL Garments'}) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  // ========== CLEAR ALL DATA ==========

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_hasPinKey);
    await prefs.remove(_biometricEnabledKey);
  }

  // ========== SESSION CHECK ==========

  Future<bool> hasActiveSession() async {
    final token = await getToken();
    final userData = await getUserData();
    return token != null && token.isNotEmpty && userData != null;
  }
}
