import 'dart:convert';
import 'package:http/http.dart' as http;

class AlertService {
  static const String baseUrl = 'https://swd-project-api.onrender.com/api';

  Future<Map<String, dynamic>> fetchAlerts(String token, {int? siteId, String? sensorName, int page = 1, int limit = 20}) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(), // Dashboard usually uses 'page' and 'limit'
        'limit': limit.toString(),
      };
      if (siteId != null) queryParams['siteId'] = siteId.toString();
      if (sensorName != null && sensorName.isNotEmpty) queryParams['sensorName'] = sensorName;

      final uri = Uri.parse('$baseUrl/notifications/history').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'accept': '*/*',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          return {
            'alerts': data['data'] ?? [],
            'total': data['total'] ?? 0,
          };
        } else if (data is List) {
          return {
            'alerts': data,
            'total': data.length,
          };
        }
        return {'alerts': [], 'total': 0};
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  Future<Map<String, dynamic>> fetchAlertRules(String token, {String? search, int page = 1, int limit = 20}) async {
    try {
      final queryParams = <String, String>{
        'pageNumber': page.toString(),
        'pageSize': limit.toString(),
      };
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('$baseUrl/alerts/rules').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'accept': '*/*',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'rules': data['data'] ?? [],
          'total': data['totalCount'] ?? 0,
        };
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  Future<bool> createAlertRule(String token, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/alerts/rules'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'accept': '*/*',
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 20));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception('Create error: $e');
    }
  }

  Future<bool> updateAlertRule(String token, int ruleId, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/alerts/rules/$ruleId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'accept': '*/*',
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 20));

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Update error: $e');
    }
  }

  Future<bool> deleteAlertRule(String token, int ruleId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/alerts/rules/$ruleId'),
        headers: {
          'Authorization': 'Bearer $token',
          'accept': '*/*',
        },
      ).timeout(const Duration(seconds: 20));

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Delete error: $e');
    }
  }
}
