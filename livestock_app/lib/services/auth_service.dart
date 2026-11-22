
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String baseUrl;

  AuthService({required this.baseUrl});

  static const String _accessKey = 'access_token';
  static const String _refreshKey = 'refresh_token';

  // LOGIN
  Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        data['detail'] ?? 'Login failed. Check your credentials.',
      );
    }

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_accessKey, data['access']);
    await preferences.setString(_refreshKey, data['refresh']);

    return await getCurrentUser();
  }

  // ACTIVATE SHEPHERD INVITATION
  Future<void> activateInvitation({
    required String token,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/invitations/activate/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'password': password,
      }),
    );

    final data = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : null;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map
          ? data['detail'] ?? data['error'] ?? 'Invitation activation failed.'
          : 'Invitation activation failed.';

      throw Exception(message);
    }
  }

  // GET STORED ACCESS TOKEN
  Future<String?> getAccessToken() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_accessKey);
  }

  // GET CURRENT USER
  Future<Map<String, dynamic>> getCurrentUser() async {
    final token = await getAccessToken();

    if (token == null) {
      throw Exception('No active session.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/auth/me/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Could not retrieve user information.');
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  // CHECK WHETHER A SESSION EXISTS
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null;
  }

  // LOGOUT
  Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_accessKey);
    await preferences.remove(_refreshKey);
  }
}
