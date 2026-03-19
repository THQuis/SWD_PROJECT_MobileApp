import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class NotificationBottomSheet extends StatefulWidget {
  const NotificationBottomSheet({super.key});

  @override
  State<NotificationBottomSheet> createState() => _NotificationBottomSheetState();
}

class _NotificationBottomSheetState extends State<NotificationBottomSheet> {
  final NotificationService _service = NotificationService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
    _loadNotifications();
  }

  void _loadNotifications() {
    final token = AuthService.token;
    final userId = AuthService.userId;
    if (token != null && userId != null) {
      _service.fetchNotifications(token, userId);
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

  @override
  Widget build(BuildContext context) {
    final notifications = _service.notifications;
    final isLoading = _service.isLoading;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Thông báo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final token = AuthService.token;
                    if (token != null) _service.markAllAsRead(token);
                  },
                  child: const Text(
                    'Đánh dấu đã đọc tất cả',
                    style: TextStyle(color: Colors.blueAccent, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : notifications.isEmpty
                    ? const Center(
                        child: Text(
                          'Không có thông báo nào',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        itemCount: notifications.length,
                        separatorBuilder: (context, index) => const Divider(
                          color: Colors.white10,
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final item = notifications[index];
                          return _buildNotificationItem(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel item) {
    return InkWell(
      onTap: () {
        final token = AuthService.token;
        if (token != null) _service.markAsRead(token, item.id);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: item.isRead ? Colors.transparent : Colors.blueAccent.withOpacity(0.05),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Placeholder
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (item.severity?.toLowerCase() == 'high' || item.severity?.toLowerCase() == 'critical')
                    ? Colors.redAccent.withOpacity(0.1)
                    : Colors.orangeAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.thermostat_rounded,
                color: (item.severity?.toLowerCase() == 'high' || item.severity?.toLowerCase() == 'critical')
                    ? Colors.redAccent
                    : Colors.orangeAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: (item.severity?.toLowerCase() == 'high' || item.severity?.toLowerCase() == 'critical')
                              ? Colors.redAccent
                              : Colors.white,
                          fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (item.location != null)
                        Text(
                          item.location!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(item.time),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Unread Dot
            if (!item.isRead)
              Container(
                margin: const EdgeInsets.only(top: 10, left: 8),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String time) {
    if (time.isEmpty) return '';
    try {
      final dt = DateTime.parse(time).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Vừa xong';
      if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
      if (diff.inHours < 24) return '${diff.inHours} giờ trước';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return time;
    }
  }
}
