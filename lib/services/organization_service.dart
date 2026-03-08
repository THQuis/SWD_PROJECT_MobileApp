import 'dart:convert';
import 'package:http/http.dart' as http;

class OrganizationService {
  static const String baseUrl = 'https://swd-project-api.onrender.com/api';

  Future<List<dynamic>> fetchOrganizations(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/organizations'),
        headers: {
          'Authorization': 'Bearer $token',
          'accept': '*/*',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        if (body is List) {
          return body;
        } else if (body is Map && body.containsKey('data')) {
          return body['data'] ?? [];
        }
        return [];
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  Future<bool> addOrganization(String token, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/organizations'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'accept': '*/*',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200 || response.statusCode == 201) return true;

    String errorMsg = 'Server error: ${response.statusCode}';
    try {
      final errorData = jsonDecode(response.body);
      errorMsg = errorData['message'] ?? errorMsg;
    } catch (_) {}
    throw Exception(errorMsg);
  }

  Future<bool> updateOrganization(String token, int orgId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/organizations/$orgId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'accept': '*/*',
      },
      body: jsonEncode(data),
    );

    return response.statusCode == 200;
  }

  Future<bool> deleteOrganization(String token, int orgId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/organizations/$orgId'),
      headers: {
        'Authorization': 'Bearer $token',
        'accept': '*/*',
      },
    );

    return response.statusCode == 200;
  }
}
