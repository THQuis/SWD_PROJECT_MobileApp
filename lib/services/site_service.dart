import 'dart:convert';
import 'package:http/http.dart' as http;

class SiteService {
  static const String baseUrl = 'https://swd-project-api.onrender.com/api';

  Future<List<dynamic>> fetchSites(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/site'),
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

  Future<bool> addSite(String token, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/site'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'accept': '*/*',
      },
      body: jsonEncode(data),
    );

    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<bool> updateSite(String token, int siteId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/site/$siteId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'accept': '*/*',
      },
      body: jsonEncode(data),
    );

    return response.statusCode == 200;
  }

  Future<bool> deleteSite(String token, int siteId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/site/$siteId'),
      headers: {
        'Authorization': 'Bearer $token',
        'accept': '*/*',
      },
    );

    return response.statusCode == 200;
  }
}
