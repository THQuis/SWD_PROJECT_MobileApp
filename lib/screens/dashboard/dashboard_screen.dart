import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import '../../services/dashboard_service.dart';
import '../../services/auth_service.dart';
import '../../services/hub_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/notification_bell.dart';
import '../login/login_screen.dart';
import '../../widgets/history_chart_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _service = DashboardService();
  final HubService _hubService = HubService();

  Map<String, dynamic>? stats;
  Map<String, dynamic>? environment;
  List<dynamic> alerts = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLogin();
    });
  }

  void _checkLogin() {
    if (AuthService.token == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      _loadDashboard();
    }
  }

  Future<void> _loadDashboard() async {
    try {
      final token = AuthService.token!;

      final statsData = await _service.getStats(token);
      final alertData = await _service.getAlerts(token);

      // Fetch hubs to get a valid hubId
      final hubs = await _hubService.fetchHubs(token);

      Map<String, dynamic>? envData;
      if (hubs.isNotEmpty) {
        // Use the first hub's ID (check for different possible key names)
        final firstHub = hubs[0];
        final hubId = firstHub['hubId'] ?? firstHub['id'] ?? firstHub['Id'] ?? firstHub['ID'] ?? firstHub['hub_id'];
        if (hubId != null) {
          envData = await _service.getCurrentEnvironment(token, hubId is int ? hubId : int.parse(hubId.toString()));
        }
      }

      setState(() {
        stats = statsData;
        alerts = alertData;
        environment = envData;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Dashboard error: $e");
      setState(() => isLoading = false);
    }
  }

  // ================= ENV PARSE =================

  double _getEnvValue(String type) {
    if (environment == null) return 0;
    
    // Handle both { "sensors": [...] } and direct list [...]
    final List<dynamic> sensors = (environment is List) 
        ? environment as List 
        : (environment?["sensors"] is List ? environment!["sensors"] as List : []);

    for (var s in sensors) {
      final String? typeName = (s["typeName"] ?? s["type_name"] ?? s["type"] ?? s["sensorType"])?.toString().toLowerCase();
      final String typeLower = type.toLowerCase();
      
      // Check for both English and common Vietnamese type names
      bool match = false;
      if (typeName == typeLower) match = true;
      else if (typeLower == "temperature" && (typeName == "nhiệt độ" || typeName == "nhiet do")) match = true;
      else if (typeLower == "humidity" && (typeName == "độ ẩm" || typeName == "do am")) match = true;
      else if (typeLower == "pressure" && (typeName == "áp suất" || typeName == "ap suat")) match = true;

      if (match &&
          s["readings"] != null &&
          (s["readings"] as List).isNotEmpty) {
        final readings = s["readings"] as List;
        return (readings[0]["value"] ?? readings[0]["Value"] ?? 0).toDouble();
      }
    }
    return 0;
  }

  String _getEnvName(String type) {
    if (environment == null) return '';
    
    final List<dynamic> sensors = (environment is List) 
        ? environment as List 
        : (environment?["sensors"] is List ? environment!["sensors"] as List : []);

    for (var s in sensors) {
      final String? typeName = (s["typeName"] ?? s["type_name"] ?? s["type"] ?? s["sensorType"])?.toString().toLowerCase();
      final String typeLower = type.toLowerCase();
      
      bool match = false;
      if (typeName == typeLower) match = true;
      else if (typeLower == "temperature" && (typeName == "nhiệt độ" || typeName == "nhiet do")) match = true;
      else if (typeLower == "humidity" && (typeName == "độ ẩm" || typeName == "do am")) match = true;
      else if (typeLower == "pressure" && (typeName == "áp suất" || typeName == "ap suat")) match = true;

      if (match) {
        return s["name"] ?? s["sensorName"] ?? '';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final temp = _getEnvValue("Temperature");
    final humidity = _getEnvValue("Humidity");
    final pressure = _getEnvValue("Pressure");
    final tempName = _getEnvName("Temperature");
    final humidName = _getEnvName("Humidity");
    final pressName = _getEnvName("Pressure");

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Dashboard",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        centerTitle: false,
        actions: const [
          NotificationBell(),
          SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ================= STATS =================
                    // ================= REFRESH =================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Overview",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _loadDashboard,
                          icon: const Icon(Icons.refresh, color: Colors.blueAccent, size: 20),
                          label: const Text("Refresh",
                              style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.blueAccent.withOpacity(0.1),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        _statCard(
                          icon: Icons.location_city,
                          title: "Sites",
                          value: stats?["total_sites"]?.toString() ?? "0",
                          color: Colors.blueAccent,
                        ),
                        _statCard(
                          icon: Icons.router,
                          title: "Hubs",
                          value: stats?["total_hubs"]?.toString() ?? "0",
                          color: Colors.purpleAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _statCard(
                          icon: Icons.sensors,
                          title: "Sensors",
                          value: stats?["active_sensors"]?.toString() ?? "0",
                          color: Colors.greenAccent,
                        ),
                        _statCard(
                          icon: Icons.warning_amber_rounded,
                          title: "Alerts",
                          value: stats?["active_alerts"]?.toString() ?? "0",
                          color: Colors.orangeAccent,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // ================= ENVIRONMENT =================
                    const Text("Current Environment",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    // Hub status badge
                    if (environment?['hubStatus'] == 'offline')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12)),
                          child: const Text("HUB OFFLINE",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),

                    // individual cards for each metric, wrap to next line on narrow
                    Column(
                      children: [
                        _envCard(
                          title: "Temperature",
                          value: temp,
                          start: const Color(0xFFFF5F6D),
                          end: const Color(0xFFFFC371),
                          icon: Icons.thermostat_rounded,
                          sensorName: tempName,
                        ),
                        const SizedBox(height: 12),
                        _envCard(
                          title: "Humidity",
                          value: humidity,
                          start: const Color(0xFF2193b0),
                          end: const Color(0xFF6dd5ed),
                          icon: Icons.water_drop_rounded,
                          sensorName: humidName,
                        ),
                        const SizedBox(height: 12),
                        _envCard(
                          title: "Pressure",
                          value: pressure,
                          start: const Color(0xFF8E2DE2),
                          end: const Color(0xFF4A00E0),
                          icon: Icons.speed_rounded,
                          sensorName: pressName,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // ================= CHART =================
                    const SizedBox(height: 30),

                    const Text("Historical Chart",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),

                    const SizedBox(height: 12),

                    HistoryChartWidget(),

                    // ================= ALERTS =================
                    const Text("Recent Alerts",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    if (alerts.isEmpty)
                      const Center(
                        child: Text("No active alerts at the moment",
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                      )
                    else
                      Column(
                        children: alerts.take(5).map((a) => _alertItem(a)).toList(),
                      )
                  ],
                ),
              ),
            ),
    );
  }

  Widget _glassContainer(
      {required Widget child,
      double opacity = 0.1,
      double blur = 20.0,
      double borderRadius = 16.0}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _statCard(
      {required IconData icon, required String title, required String value, required Color color}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: _glassContainer(
          opacity: 0.05,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 16),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(title,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _envCard({
    required String title,
    required double value,
    required Color start,
    required Color end,
    required IconData icon,
    String? sensorName,
  }) {
    final display = title == "Temperature"
        ? "${value.toStringAsFixed(1)}°C"
        : title == "Humidity"
            ? "${value.toStringAsFixed(1)}%"
            : "${value.toStringAsFixed(1)} hPa";

    bool hubOffline = environment?['hubStatus'] == 'offline';

    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [start, end],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: start.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            bottom: -20,
            child: Icon(icon, color: Colors.white.withOpacity(0.15), size: 100),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      if (sensorName != null) ...[
                        const SizedBox(height: 4),
                        Text(sensorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(display,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    if (hubOffline)
                      const Row(
                        children: [
                          Icon(Icons.cloud_off, color: Colors.white70, size: 14),
                          SizedBox(width: 4),
                          Text("Offline", style: TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertItem(dynamic alert) {
    final name = alert["sensorName"] ?? "Alert";
    final hubName = alert["hubName"] ?? "Unknown Hub";
    final value = alert["value"]?.toString() ?? '';
    final status = alert["status"]?.toString().toUpperCase() ?? 'HIGH';
    final updated = alert["updatedAt"]?.toString() ?? '';

    Color statusColor = Colors.redAccent;
    if (status == 'LOW') statusColor = Colors.orangeAccent;
    if (status == 'NORMAL') statusColor = Colors.greenAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: _glassContainer(
        opacity: 0.05,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(hubName,
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text("${value}°C",
                    style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(status,
                          style: TextStyle(
                              color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LineChartData _buildChart() {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.white.withOpacity(0.05),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (value, meta) {
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '${value.toInt()}h',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 5,
            getTitlesWidget: (value, meta) {
              return Text(
                '${value.toInt()}°',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
              );
            },
            reservedSize: 30,
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: const [
            FlSpot(0, 20),
            FlSpot(1, 22),
            FlSpot(2, 21),
            FlSpot(3, 23),
            FlSpot(4, 25),
            FlSpot(5, 24),
            FlSpot(6, 26),
          ],
          isCurved: true,
          color: Colors.orangeAccent,
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.orangeAccent.withOpacity(0.3),
                Colors.orangeAccent.withOpacity(0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}