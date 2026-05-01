import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';
import 'secure_storage_service.dart';

class AuthService {
  AppUser? _currentUser;
  final StreamController<AppUser?> _controller = StreamController<AppUser?>.broadcast();
  String? _token;
  final SecureStorageService _storage = SecureStorageService();

  // Flags for auth state
  bool _isInitialized = false;
  bool _hasPin = false;
  bool _biometricEnabled = false;
  bool _isUnlocked = false;

  Stream<AppUser?> get userStream => _controller.stream;
  AppUser? get currentUser => _currentUser;
  String? get token => _token;
  bool get isInitialized => _isInitialized;
  bool get hasPin => _hasPin;
  bool get biometricEnabled => _biometricEnabled;
  bool get isUnlocked => _isUnlocked;
  SecureStorageService get storage => _storage;

  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ========== INITIALIZATION ==========

  /// Initialize auth service - check for existing session
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final hasSession = await _storage.hasActiveSession();
      if (hasSession) {
        _token = await _storage.getToken();
        final userData = await _storage.getUserData();
        if (userData != null && _token != null) {
          _currentUser = AppUser(
            id: userData['id'],
            name: userData['name'],
            email: userData['email'],
            role: UserRole.admin,
          );
          _hasPin = userData['hasPin'] ?? false;
          _biometricEnabled = userData['biometricEnabled'] ?? false;

          // Verify token is still valid by fetching user info
          try {
            await _fetchUserInfo();
          } catch (e) {
            // Token expired or invalid, clear session
            await signOut();
          }
        }
      }
    } catch (e) {
      // Ignore errors during initialization
    }

    _isInitialized = true;
  }

  /// Fetch user info from server to verify session and update PIN/biometric status
  Future<void> _fetchUserInfo() async {
    final url = '${dotenv.env['API_URL']}/auth/me';
    final response = await http.get(Uri.parse(url), headers: authHeaders);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _hasPin = data['hasPin'] ?? false;
      _biometricEnabled = data['biometricEnabled'] ?? false;

      await _storage.updatePinStatus(_hasPin);
      await _storage.updateBiometricStatus(_biometricEnabled);
    } else {
      throw Exception('Session expired');
    }
  }

  // ========== SIGN IN ==========

  Future<AppUser> signIn({required String email, required String password}) async {
    final url = '${dotenv.env['API_URL']}/auth/login';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'] as String?;

        final userData = data['user'];
        _currentUser = AppUser.fromJson(userData);
        _hasPin = userData['hasPin'] ?? false;
        _biometricEnabled = userData['biometricEnabled'] ?? false;

        // Persist session
        if (_token != null) {
          await _storage.saveToken(_token!);
          await _storage.saveUserData(
            userId: _currentUser!.id,
            name: _currentUser!.name,
            email: _currentUser!.email,
            hasPin: _hasPin,
            biometricEnabled: _biometricEnabled,
          );
        }

        // If user has PIN, they need to unlock still
        // If no PIN, they're fully authenticated
        if (!_hasPin) {
          _isUnlocked = true;
        }

        _controller.add(_currentUser);
        return _currentUser!;
      } else if (response.statusCode == 401) {
        final error = jsonDecode(response.body);
        final message = error['message'] ?? 'Invalid credentials';
        if (message.toLowerCase().contains('password')) {
          throw Exception('Incorrect password. Please try again.');
        } else if (message.toLowerCase().contains('email') || message.toLowerCase().contains('user')) {
          throw Exception('Email not found. Please check your email.');
        } else {
          throw Exception('Invalid email or password.');
        }
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Invalid request. Please check your input.');
      } else {
        throw Exception('Login failed. Please try again later.');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error. Please check your connection.');
    }
  }

  // ========== SIGN UP ==========

  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final url = '${dotenv.env['API_URL']}/auth/register';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      _currentUser = AppUser.fromJson(data);
      _controller.add(_currentUser);
      return _currentUser!;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to sign up');
    }
  }

  // ========== PROFILE MANAGEMENT ==========

  Future<AppUser> updateProfile({required String name, required String email}) async {
    final url = '${dotenv.env['API_URL']}/auth/update-profile';
    final response = await http.put(
      Uri.parse(url),
      headers: authHeaders,
      body: jsonEncode({
        'name': name,
        'email': email,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _currentUser = AppUser.fromJson(data);
      
      // Update saved data
      if (_currentUser != null) {
        await _storage.saveUserData(
          userId: _currentUser!.id,
          name: _currentUser!.name,
          email: _currentUser!.email,
          hasPin: _hasPin,
          biometricEnabled: _biometricEnabled,
        );
      }
      
      _controller.add(_currentUser);
      return _currentUser!;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to update profile');
    }
  }

  Future<bool> changePassword({required String currentPassword, required String newPassword}) async {
    final url = '${dotenv.env['API_URL']}/auth/change-password';
    final response = await http.put(
      Uri.parse(url),
      headers: authHeaders,
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to change password');
    }
  }

  // ========== PIN MANAGEMENT ==========

  /// Set up a new PIN (4-6 digits)
  Future<bool> setupPin(String pin) async {
    if (pin.length < 4 || pin.length > 6 || !RegExp(r'^\d+$').hasMatch(pin)) {
      throw Exception('PIN must be 4-6 digits');
    }

    final url = '${dotenv.env['API_URL']}/auth/set-pin';
    final response = await http.post(
      Uri.parse(url),
      headers: authHeaders,
      body: jsonEncode({'pin': pin}),
    );

    if (response.statusCode == 200) {
      _hasPin = true;
      _isUnlocked = true;
      await _storage.updatePinStatus(true);
      await _storage.saveLocalPin(pin);
      return true;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to set PIN');
    }
  }

  /// Verify PIN (tries server first, falls back to local)
  Future<bool> verifyPin(String pin) async {
    // Try server verification first
    try {
      final url = '${dotenv.env['API_URL']}/auth/verify-pin';
      final response = await http.post(
        Uri.parse(url),
        headers: authHeaders,
        body: jsonEncode({'pin': pin}),
      );

      if (response.statusCode == 200) {
        _isUnlocked = true;
        _controller.add(_currentUser);
        return true;
      } else if (response.statusCode == 401) {
        return false;
      }
    } catch (e) {
      // Server unavailable, try local verification
    }

    // Fallback to local verification
    final isValid = await _storage.verifyLocalPin(pin);
    if (isValid) {
      _isUnlocked = true;
      _controller.add(_currentUser);
    }
    return isValid;
  }

  /// Change PIN
  Future<bool> changePin(String currentPin, String newPin) async {
    // First verify current PIN
    final isValid = await verifyPin(currentPin);
    if (!isValid) {
      throw Exception('Current PIN is incorrect');
    }

    // Then set new PIN
    return await setupPin(newPin);
  }

  /// Remove PIN
  Future<bool> removePin(String currentPin) async {
    // First verify current PIN
    final isValid = await verifyPin(currentPin);
    if (!isValid) {
      throw Exception('Current PIN is incorrect');
    }

    final url = '${dotenv.env['API_URL']}/auth/pin';
    final response = await http.delete(Uri.parse(url), headers: authHeaders);

    if (response.statusCode == 200) {
      _hasPin = false;
      _biometricEnabled = false;
      await _storage.updatePinStatus(false);
      await _storage.updateBiometricStatus(false);
      await _storage.deleteLocalPin();
      return true;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to remove PIN');
    }
  }

  // ========== BIOMETRIC ==========

  Future<bool> isBiometricAvailable() async {
    return await _storage.isBiometricAvailable();
  }

  Future<bool> enableBiometric() async {
    if (!_hasPin) {
      throw Exception('Please set up a PIN first');
    }

    final url = '${dotenv.env['API_URL']}/auth/toggle-biometric';
    final response = await http.post(
      Uri.parse(url),
      headers: authHeaders,
      body: jsonEncode({'enabled': true}),
    );

    if (response.statusCode == 200) {
      _biometricEnabled = true;
      await _storage.updateBiometricStatus(true);
      return true;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to enable biometric');
    }
  }

  Future<bool> disableBiometric() async {
    final url = '${dotenv.env['API_URL']}/auth/toggle-biometric';
    final response = await http.post(
      Uri.parse(url),
      headers: authHeaders,
      body: jsonEncode({'enabled': false}),
    );

    if (response.statusCode == 200) {
      _biometricEnabled = false;
      await _storage.updateBiometricStatus(false);
      return true;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to disable biometric');
    }
  }

  Future<bool> authenticateWithBiometric() async {
    if (!_biometricEnabled) return false;

    final success = await _storage.authenticateWithBiometrics();
    if (success) {
      _isUnlocked = true;
      _controller.add(_currentUser);
    }
    return success;
  }

  // ========== LOCK / UNLOCK ==========

  void lockApp() {
    _isUnlocked = false;
    _controller.add(_currentUser);
  }

  bool get needsUnlock => _currentUser != null && _hasPin && !_isUnlocked;
  bool get needsPinSetup => _currentUser != null && !_hasPin && _isUnlocked;

  // ========== SIGN OUT ==========

  Future<void> signOut() async {
    _currentUser = null;
    _token = null;
    _hasPin = false;
    _biometricEnabled = false;
    _isUnlocked = false;
    _isInitialized = false;
    await _storage.clearAll();
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}
