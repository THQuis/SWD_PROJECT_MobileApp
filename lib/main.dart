import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Screens
import 'screens/login/login_screen.dart';
import 'screens/register/register_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/sites/sites_screen.dart';
import 'screens/hubs/hubs_screen.dart';
import 'screens/sensors/sensors_screen.dart';
import 'screens/alerts/alerts_screen.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    setupFCM();
  }

  Future<void> setupFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    String? token = await messaging.getToken();
    print("🔥 FCM TOKEN: $token");

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("📩 Foreground message: ${message.notification?.title}");
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/dashboard',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/sites': (context) => const SitesScreen(),
        '/hubs': (context) => const HubsScreen(),
        '/sensors': (context) => const SensorsScreen(),
        '/alerts': (context) => const AlertsScreen(),
      },
    );
  }
}