import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Screens
import 'screens/login/login_screen.dart';
import 'screens/register/register_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/sites/sites_screen.dart';
import 'screens/hubs/hubs_screen.dart';
import 'screens/sensors/sensors_screen.dart';
import 'screens/alerts/alert_management_screen.dart';
import 'screens/organizations/organizations_screen.dart';
import 'screens/users/users_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'services/auth_service.dart';
import 'services/hub_service.dart';
import 'services/realtime_alert_service.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final HubService _hubService = HubService();
  final RealtimeAlertService _realtimeAlertService = RealtimeAlertService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final Map<int, bool> _hubOnlineState = {};

  Timer? _hubRealtimeBootstrapTimer;
  Set<int> _currentSubscribedHubIds = <int>{};
  String? _lastAlertFingerprint;
  bool _notificationReady = false;
  int _notificationId = 0;

  @override
  void initState() {
    super.initState();
    _setupLocalNotifications();
    setupFCM();
    _startGlobalRealtimeBootstrap();
  }

  @override
  void dispose() {
    _hubRealtimeBootstrapTimer?.cancel();
    _realtimeAlertService.dispose();
    super.dispose();
  }

  Future<void> setupFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    String? fcmToken = await messaging.getToken();
    print("🔥 FCM TOKEN: $fcmToken");

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("📩 Foreground message: ${message.notification?.title}");
      _showGlobalNotice(
        message.notification?.title ?? 'Thông báo mới',
        message.notification?.body ?? 'Bạn có thông báo mới',
      );
    });
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    const alertChannel = AndroidNotificationChannel(
      'realtime_alerts',
      'Realtime Alerts',
      description: 'Realtime hub and sensor alerts',
      importance: Importance.max,
    );

    final androidImpl =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.createNotificationChannel(alertChannel);
    await androidImpl?.requestNotificationsPermission();
    _notificationReady = true;
  }

  void _startGlobalRealtimeBootstrap() {
    _syncGlobalHubRealtime();
    _hubRealtimeBootstrapTimer?.cancel();
    _hubRealtimeBootstrapTimer =
        Timer.periodic(const Duration(seconds: 10), (_) {
      _syncGlobalHubRealtime();
    });
  }

  Future<void> _syncGlobalHubRealtime() async {
    final token = AuthService.token;
    if (token == null) {
      if (_currentSubscribedHubIds.isNotEmpty) {
        _currentSubscribedHubIds = <int>{};
        _hubOnlineState.clear();
        _realtimeAlertService.dispose();
      }
      return;
    }

    try {
      final hubs = await _hubService.fetchHubs(token);
      final hubIds = hubs
          .map((h) {
            if (h is! Map) return null;
            final id = h['hubId'] ?? h['id'];
            if (id is int) return id;
            return int.tryParse(id?.toString() ?? '');
          })
          .whereType<int>()
          .toSet();

      if (_currentSubscribedHubIds.length == hubIds.length &&
          _currentSubscribedHubIds.containsAll(hubIds)) {
        return;
      }

      _currentSubscribedHubIds = hubIds;
      _hubOnlineState.removeWhere((key, _) => !hubIds.contains(key));

      if (hubIds.isEmpty) {
        _realtimeAlertService.dispose();
        return;
      }

      _realtimeAlertService.listenAllHubsRealtime(
        hubIds: hubIds.toList(),
        onChanged: _handleHubRealtimeChanged,
        onError: (error) {
          debugPrint('Global realtime listener error: $error');
        },
      );

      _realtimeAlertService.listenAllHubsAlerts(
        hubIds: hubIds.toList(),
        onChanged: _handleGlobalAlertChanged,
        onError: (error) {
          debugPrint('Global alert listener error: $error');
        },
      );
    } catch (e) {
      debugPrint('Global realtime bootstrap error: $e');
    }
  }

  void _handleHubRealtimeChanged(RealtimeHubSnapshot snapshot) {
    final previousOnline = _hubOnlineState[snapshot.hubId];
    _hubOnlineState[snapshot.hubId] = snapshot.isOnline;

    if (previousOnline != null && previousOnline != snapshot.isOnline) {
      _showGlobalNotice(
        'Hub ${snapshot.hubId} đổi trạng thái',
        snapshot.isOnline ? 'Đang hoạt động' : 'Đang offline',
      );
    }

    final alertMapRaw = snapshot.raw['Alert'] ?? snapshot.raw['alert'];
    if (alertMapRaw != null) {
      String ruleName = 'Realtime Alert';
      String message = '';
      String time = snapshot.lastUpdated;

      if (alertMapRaw is Map) {
        final alertMap = Map<String, dynamic>.from(alertMapRaw);
        ruleName =
            (alertMap['ruleName'] ?? alertMap['name'] ?? 'Realtime Alert')
                .toString();
        message = (alertMap['message'] ??
                alertMap['content'] ??
                alertMap['description'] ??
                alertMap['value'] ??
                '')
            .toString();
        time =
            (alertMap['time'] ?? alertMap['timestamp'] ?? snapshot.lastUpdated)
                .toString();
      } else {
        message = alertMapRaw.toString();
      }

      final fingerprint = '${snapshot.hubId}|$ruleName|$message|$time';
      if (message.isNotEmpty && fingerprint != _lastAlertFingerprint) {
        _lastAlertFingerprint = fingerprint;
        _showGlobalNotice(
          'Hub ${snapshot.hubId} - $ruleName',
          message,
          isWarning: true,
        );
      }
    }
  }

  void _handleGlobalAlertChanged(GlobalRealtimeAlertEvent event) {
    final ruleName = event.alert.ruleName;
    final message = event.alert.message;
    final time = event.alert.time;

    final fingerprint = '${event.hubId}|$ruleName|$message|$time';
    if (message.isEmpty || fingerprint == _lastAlertFingerprint) return;

    _lastAlertFingerprint = fingerprint;
    _showGlobalNotice(
      'Hub ${event.hubId} - $ruleName',
      message,
      isWarning: true,
    );
  }

  void _showGlobalNotice(String title, String message,
      {bool isWarning = false}) {
    _showSystemNotification(title, message, isWarning: isWarning);

    final messenger = _messengerKey.currentState;
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isWarning ? Colors.redAccent : Colors.blueGrey,
        content: Text('$title: $message'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showSystemNotification(String title, String message,
      {bool isWarning = false}) async {
    if (!_notificationReady) return;

    const baseAndroidDetails = AndroidNotificationDetails(
      'realtime_alerts',
      'Realtime Alerts',
      channelDescription: 'Realtime hub and sensor alerts',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      ticker: 'Realtime Alert',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: baseAndroidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      ++_notificationId,
      isWarning ? '⚠ $title' : title,
      message,
      notificationDetails,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/sites': (context) => const SitesScreen(),
        '/hubs': (context) => const HubsScreen(),
        '/sensors': (context) => const SensorsScreen(),
        '/alerts': (context) => const AlertManagementScreen(initialTabIndex: 0),
        '/alert-rules': (context) =>
            const AlertManagementScreen(initialTabIndex: 1),
        '/organizations': (context) => const OrganizationsScreen(),
        '/users': (context) => const UsersScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
