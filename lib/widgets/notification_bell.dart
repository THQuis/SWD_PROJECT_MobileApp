import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import 'notification_bottom_sheet.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final NotificationService _service = NotificationService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
    _refreshUnreadCount();
  }

  void _refreshUnreadCount() {
    final token = AuthService.token;
    final userId = AuthService.userId;
    if (token != null && userId != null) {
      _service.fetchUnreadCount(token, userId);
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const NotificationBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _service.unreadCount;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
          onPressed: _showNotifications,
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
