import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl; // e.g., http://localhost:5000
  String? _token;

  ApiService({required this.baseUrl});

  set authToken(String? token) => _token = token;

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final res = await http.post(Uri.parse('$baseUrl/api/auth/register'),
        headers: _headers(),
        body: jsonEncode({ 'name': name, 'email': email, 'password': password, 'role': role }));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({ required String email, required String password }) async {
    final res = await http.post(Uri.parse('$baseUrl/api/auth/login'),
        headers: _headers(),
        body: jsonEncode({ 'email': email, 'password': password }));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      _token = body['token'] as String?;
    }
    return body;
  }
}


