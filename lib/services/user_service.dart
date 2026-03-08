import 'dart:convert';
import 'package:http/http.dart' as http;

class UserService {
  static const String baseUrl = 'https://swd-project-api.onrender.com/api';

  Future<Map<String, dynamic>> fetchUsers(String token, {String? search, bool? isActive, int? pageNumber, int? pageSize}) async {
    String url = '$baseUrl/users?';
    if (search != null) url += 'search=$search&';
    if (isActive != null) url += 'isActive=$isActive&';
    if (pageNumber != null) url += 'pageNumber=$pageNumber&';
    if (pageSize != null) url += 'pageSize=$pageSize&';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'accept': '*/*',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          return body;
        } else if (body is List) {
          return {
            'data': body,
            'totalCount': body.length,
          };
        }
        return {'data': [], 'totalCount': 0};
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  Future<bool> createUser(String token, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users'),
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

  Future<bool> updateUser(String token, int userId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'accept': '*/*',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) return true;

    String errorMsg = 'Server error: ${response.statusCode}';
    try {
      final errorData = jsonDecode(response.body);
      errorMsg = errorData['message'] ?? errorMsg;
    } catch (_) {}
    throw Exception(errorMsg);
  }

  Future<bool> activateUser(String token, int userId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId/activate'),
      headers: {
        'Authorization': 'Bearer $token',
        'accept': '*/*',
      },
    );

    if (response.statusCode == 200) return true;
    _handleError(response);
    return false;
  }

  Future<bool> deactivateUser(String token, int userId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId/deactivate'),
      headers: {
        'Authorization': 'Bearer $token',
        'accept': '*/*',
      },
    );

    if (response.statusCode == 200) return true;
    _handleError(response);
    return false;
  }

  void _handleError(http.Response response) {
    String errorMsg = 'Server error: ${response.statusCode}';
    try {
      final errorData = jsonDecode(response.body);
      errorMsg = errorData['message'] ?? errorMsg;
    } catch (_) {}
    throw Exception(errorMsg);
  }
}
