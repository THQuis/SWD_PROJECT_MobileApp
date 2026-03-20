import 'dart:convert';
import 'package:http/http.dart' as http;

class HubService {
  static const String baseUrl = 'https://swd-project-api.onrender.com/api';

  int? _parseHubId(dynamic hub) {
    if (hub is! Map) return null;
    final dynamic id =
        hub['hubId'] ?? hub['id'] ?? hub['Id'] ?? hub['ID'] ?? hub['hub_id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  Future<List<dynamic>> fetchHubs(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/hubs'),
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

  Future<Map<String, dynamic>?> fetchHubById(String token, int hubId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/hubs/$hubId'),
        headers: {
          'Authorization': 'Bearer $token',
          'accept': '*/*',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        if (body is Map && body['data'] is Map) {
          return Map<String, dynamic>.from(body['data']);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> fetchHubsByIds(String token, List<int> hubIds) async {
    if (hubIds.isEmpty) return [];

    final uniqueIds = <int>{...hubIds}.toList();
    final futures = uniqueIds.map((id) => fetchHubById(token, id)).toList();
    final details = await Future.wait(futures);

    final byId = <int, Map<String, dynamic>>{};
    for (final d in details) {
      if (d == null) continue;
      final id = _parseHubId(d);
      if (id != null) byId[id] = d;
    }

    // Preserve the incoming order from site.hubs list.
    return hubIds
        .where((id) => byId.containsKey(id))
        .map((id) => byId[id]!)
        .toList();
  }

  Future<List<dynamic>> enrichHubsWithDetails(
      String token, List<dynamic> hubs) async {
    final futures = hubs.map((hub) async {
      final hubId = _parseHubId(hub);
      if (hubId == null) return hub;

      final detail = await fetchHubById(token, hubId);
      if (detail == null) return hub;

      final merged = Map<String, dynamic>.from(hub as Map);
      merged.addAll(detail);
      return merged;
    }).toList();

    return Future.wait(futures);
  }

  Future<bool> addHub(String token, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/hubs'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'accept': '*/*',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200 || response.statusCode == 201) return true;

    try {
      final errorData = jsonDecode(response.body);
      throw Exception(
          errorData['message'] ?? 'Server error: ${response.statusCode}');
    } catch (_) {
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  Future<bool> updateHub(
      String token, int hubId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/hubs/$hubId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'accept': '*/*',
      },
      body: jsonEncode(data),
    );

    return response.statusCode == 200;
  }

  Future<bool> deleteHub(String token, int hubId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/hubs/$hubId'),
      headers: {
        'Authorization': 'Bearer $token',
        'accept': '*/*',
      },
    );

    return response.statusCode == 200;
  }
}
