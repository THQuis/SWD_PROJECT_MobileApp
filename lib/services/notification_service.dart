import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String time;
  final String? location;
  final double? value;
  final String? severity;
  bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    this.location,
    this.value,
    this.severity,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // Robust mapping for ID and Title
    final id = json['id'] ?? json['Id'] ?? json['notiId'] ?? json['NotiId'] ?? 0;
    final severity = json['severity'] ?? json['Severity'];
    final message = json['message'] ?? json['Message'] ?? '';
    final time = json['time'] ?? json['Time'] ?? json['sentAt'] ?? json['SentAt'] ?? '';
    
    return NotificationModel(
      id: id is int ? id : int.tryParse(id.toString()) ?? 0,
      title: severity != null ? "$severity Alert" : "Cảnh báo hệ thống",
      message: message,
      time: time,
      location: json['location'] ?? json['Location'],
      value: (json['value'] ?? json['Value'] as num?)?.toDouble(),
      severity: severity,
      isRead: json['isRead'] ?? json['IsRead'] ?? false,
    );
  }
}

class NotificationService extends ChangeNotifier {
  static const String baseUrl = 'https://swd-project-api.onrender.com/api/notifications';

  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  Future<void> fetchNotifications(String token, int userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'accept': '*/*',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> notiList = data['data'] ?? [];
        _notifications = notiList.map((json) => NotificationModel.fromJson(json)).toList();
        _unreadCount = data['unreadCount'] ?? 0;
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUnreadCount(String token, int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/$userId/unread-count'),
        headers: {
          'Authorization': 'Bearer $token',
          'accept': '*/*',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _unreadCount = data['unread_count'] ?? 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching unread count: $e");
    }
  }

  Future<void> markAsRead(String token, int id) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$id/read'),
        headers: {
          'Authorization': 'Bearer $token',
          'accept': '*/*',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final index = _notifications.indexWhere((n) => n.id == id);
        if (index != -1 && !_notifications[index].isRead) {
          _notifications[index].isRead = true;
          if (_unreadCount > 0) _unreadCount--;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error marking notification as read: $e");
    }
  }

  Future<void> markAllAsRead(String token) async {
    // Backend doesn't have a mark all endpoint, we'll mark unread ones sequentially
    final unread = _notifications.where((n) => !n.isRead).toList();
    for (var n in unread) {
      await markAsRead(token, n.id);
    }
  }
}
