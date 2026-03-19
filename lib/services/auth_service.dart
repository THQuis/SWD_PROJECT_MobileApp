import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {

static const String baseUrl =
  'https://swd-project-api.onrender.com/api';

  static String? _token;
  static String? _role;
  static Map<String, dynamic>? _user;

  // ================= LOGIN =================
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 30)); // Tăng lên 30s cho Render

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      _token = data['token'] ?? 
               (data['data'] != null ? data['data']['token'] : null) ??
               data['accessToken']; // Một số bộ API dùng accessToken
      
      print("🔑 LOGIN RESPONSE: $data");

      // Lấy role dựa trên cấu trúc của Web FE (data.user.role)
      final user = data['user'] ?? data['data']?['user'] ?? data;
      _user = user;
      
      if (user != null) {
        _role = user['role']?.toString() ?? user['roleName']?.toString() ?? user['roleId']?.toString();
      } else {
        // Fallback cho cấu trúc phẳng
        _role = data['roleName']?.toString() ?? 
                data['role']?.toString() ?? 
                data['roleId']?.toString();
      }
      
      print("👤 DETECTED ROLE: $_role");

      return data;
    } else {
      print('Login Error Body: ${response.body}');
      throw Exception('Login failed: ${response.statusCode}');
    }
  }

  // ================= REGISTER =================
  static Future<void> register({
    required String email,
    required String fullName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/createAccount'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'orgId': 1,
        'siteId': 1,
        'fullName': fullName,
        'email': email,
        'roleId': 1,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Register failed: ${response.body}');
    }
  }

  // ================= LOGOUT =================
  static void logout() {
    _token = null;
    _role = null;
    _user = null;
  }

  static String? get token => _token;
  static String? get role => _role;
  static Map<String, dynamic>? get user => _user;

  static int? get userId {
    if (_user == null) return null;
    // Map various possible keys from backend response
    final id = _user!['userId'] ?? 
               _user!['id'] ?? 
               _user!['Userid'] ?? 
               _user!['UserId'] ?? 
               _user!['user_id'] ??
               (_user!['data'] is Map ? _user!['data']['userId'] : null);
               
    if (id == null) return null;
    if (id is int) return id;
    return int.tryParse(id.toString());
  }
}
