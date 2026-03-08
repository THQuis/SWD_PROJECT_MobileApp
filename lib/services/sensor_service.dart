import 'dart:convert';
import 'package:http/http.dart' as http;

class SensorService {
  static const String baseUrl = 'https://swd-project-api.onrender.com/api';

  Future<Map<String, dynamic>> fetchSensors(String token, {
    int? siteId,
    int? hubId,
    int? typeId,
    String? status,
    int? pageNumber,
    int? pageSize,
  }) async {
    try {
      final queryParams = <String, String>{};
      // Try both snake_case and camelCase to be resilient to backend variations
      if (siteId != null) {
        queryParams['site_id'] = siteId.toString();
        queryParams['siteId'] = siteId.toString();
      }
      if (hubId != null) {
        queryParams['hub_id'] = hubId.toString();
        queryParams['hubId'] = hubId.toString();
      }
      if (typeId != null) {
        queryParams['type'] = typeId.toString();
        queryParams['typeId'] = typeId.toString();
      }
      if (status != null) queryParams['status'] = status;
      if (pageNumber != null) queryParams['pageNumber'] = pageNumber.toString();
      if (pageSize != null) queryParams['pageSize'] = pageSize.toString();

      final uri = Uri.parse('$baseUrl/sensors').replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'accept': '*/*',
        },
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        if (body is Map) {
          return {
            'data': body['data'] ?? [],
            'totalCount': body['totalCount'] ?? 0,
            'totalPages': body['totalPages'] ?? 1,
            'pageNumber': body['pageNumber'] ?? 1,
            'message': body['message'],
          };
        }
        return {'data': [], 'totalCount': 0, 'totalPages': 0};
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  Future<List<dynamic>> fetchSensorTypes(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sensors/types'),
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

  Future<bool> addSensor(String token, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sensors'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'accept': '*/*',
      },
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 201) return true;
    
    try {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
    } catch (_) {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  Future<bool> updateSensor(String token, int sensorId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/sensors/$sensorId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'accept': '*/*',
      },
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 30));

    return response.statusCode == 200;
  }

  Future<bool> deleteSensor(String token, int sensorId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/sensors/$sensorId'),
      headers: {
        'Authorization': 'Bearer $token',
        'accept': '*/*',
      },
    ).timeout(const Duration(seconds: 30));

    return response.statusCode == 200;
  }
}
