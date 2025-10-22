import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';

class AuthService {
  AppUser? _currentUser;
  final StreamController<AppUser?> _controller = StreamController<AppUser?>.broadcast();
  String? _token;

  Stream<AppUser?> get userStream => _controller.stream;
  AppUser? get currentUser => _currentUser;
  String? get token => _token;
  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer ' + _token!,
      };

  Future<AppUser> signIn({required String email, required String password}) async {
    final url = '${dotenv.env['API_URL']}/auth/login';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'] as String?;
      _currentUser = AppUser.fromJson(data['user']);
      _controller.add(_currentUser);
      return _currentUser!;
    } else {
      throw Exception('Failed to sign in');
    }
  }

  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final url = '${dotenv.env['API_URL']}/auth/register';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      // Backend returns user data directly: { id, name, email, role }
      _currentUser = AppUser.fromJson(data);
      _controller.add(_currentUser);
      return _currentUser!;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to sign up');
    }
  }

  Future<Map<String, dynamic>> createStaffAccount({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final url = '${dotenv.env['API_URL']}/auth/register';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      // Return user data without affecting current session
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to create account');
    }
  }

  Future<void> signOut() async {
    _currentUser = null;
    _token = null;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}
