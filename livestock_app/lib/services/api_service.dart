
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  final String baseUrl;
  final AuthService auth;

  ApiService({
    required this.baseUrl,
    required this.auth,
  });

  Future<Map<String, String>> _headers() async {
    final token = await auth.getAccessToken();

    if (token == null) {
      throw Exception('Not authenticated. Please log in.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(),
    );

    return _handleResponse(response);
  }

  Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    final data = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : null;

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return data;
    }

    if (response.statusCode == 401) {
      throw Exception('Session expired. Please log in again.');
    }

    throw Exception(
      data is Map
          ? data['detail'] ?? data['error'] ?? 'Request failed.'
          : 'Request failed (${response.statusCode}).',
    );
  }
}
