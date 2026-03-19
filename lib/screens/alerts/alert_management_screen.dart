import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/notification_bell.dart';
import 'alerts_screen.dart';
import 'alert_rules_screen.dart';
import 'add_edit_alert_rule_dialog.dart';

class AlertManagementScreen extends StatefulWidget {
  final int initialTabIndex;
  const AlertManagementScreen({super.key, this.initialTabIndex = 0});

  @override
  State<AlertManagementScreen> createState() => _AlertManagementScreenState();
}

class _AlertManagementScreenState extends State<AlertManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<AlertRulesScreenState> _rulesKey = GlobalKey<AlertRulesScreenState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      setState(() {}); // Update to show/hide FAB
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddEditRuleDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const AddEditAlertRuleDialog(),
    );
    if (result == true) {
      _rulesKey.currentState?.loadInitialData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0E0E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "System Alerts",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: const [
          NotificationBell(),
          SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: "ALERT HISTORY"),
            Tab(text: "ALERT RULES"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const AlertsScreen(),
          AlertRulesScreen(key: _rulesKey),
        ],
      ),
      floatingActionButton: _tabController.index == 1 
        ? FloatingActionButton(
            onPressed: _showAddEditRuleDialog,
            backgroundColor: Colors.blueAccent,
            child: const Icon(Icons.add, color: Colors.white),
          )
        : null,
    );
  }
}