import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/alert_service.dart';
import '../../services/site_service.dart';
import '../login/login_screen.dart';
import 'alert_rules_screen.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/notification_bell.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final AlertService _alertService = AlertService();
  final SiteService _siteService = SiteService();

  List<dynamic> alerts = [];
  List<dynamic> sites = [];
  int? selectedSiteId;
  bool isLoading = true;
  String? error;

  // Pagination state
  int currentPage = 1;
  int totalAlerts = 0;
  bool hasMore = true;
  bool isLoadMore = false;
  final ScrollController _scrollController = ScrollController();

  // Search state
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _checkAuthAndLoad();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadInitialData();
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!isLoadMore && hasMore && !isLoading && error == null) {
        _loadMore();
      }
    }
  }

  Future<void> _checkAuthAndLoad() async {
    if (AuthService.token == null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    await _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      currentPage = 1;
      hasMore = true;
      error = null;
    });
    try {
      final token = AuthService.token!;
      // Only fetch sites if we don't have them yet to avoid dropdown flickering
      if (sites.isEmpty) {
        final sitesData = await _siteService.fetchSites(token);
        if (mounted) {
          setState(() {
            sites = sitesData;
          });
        }
      }

      await _loadAlerts(refresh: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _loadAlerts({bool refresh = false}) async {
    if (!mounted) return;
    if (refresh) {
      setState(() {
        isLoading = true;
        currentPage = 1;
        error = null;
      });
    }
    
    try {
      final token = AuthService.token!;
      final result = await _alertService.fetchAlerts(
        token,
        siteId: selectedSiteId,
        sensorName: _searchController.text.trim(),
        page: currentPage,
        limit: 20,
      );

      if (!mounted) return;
      
      final newAlerts = result['alerts'] as List<dynamic>;
      final total = result['total'] ?? 0;

      setState(() {
        if (refresh) {
          alerts = newAlerts;
        } else {
          alerts.addAll(newAlerts);
        }
        totalAlerts = total;
        isLoading = false;
        isLoadMore = false;
        hasMore = alerts.length < totalAlerts;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
        isLoadMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (isLoadMore || !hasMore) return;
    setState(() => isLoadMore = true);
    currentPage++;
    await _loadAlerts();
  }

  Future<void> _onRefresh() async {
    await _loadInitialData();
  }

  Color _severityColor(String? level) {
    if (level == null) return Colors.greenAccent;
    final lower = level.toLowerCase();
    if (lower.contains('critical') || lower.contains('high')) return Colors.redAccent;
    if (lower.contains('warning') || lower.contains('medium')) return Colors.orangeAccent;
    return Colors.greenAccent;
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
          'Alerts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: const [
          NotificationBell(),
          SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildSearchBar(),
              const SizedBox(height: 12),
              _buildFilters(),
              const SizedBox(height: 16),
              if (isLoading && alerts.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                ))
              else if (error != null && alerts.isEmpty)
                Center(child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text('Error: $error', 
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 10),
                      ElevatedButton(onPressed: _onRefresh, child: const Text('Retry'))
                    ],
                  ),
                ))
              else if (alerts.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Text('No alerts found', style: TextStyle(color: Colors.grey)),
                ))
              else ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    width: 900,
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      children: [
                        _tableHeader(),
                        const Divider(color: Colors.white12, height: 1),
                        ...alerts.map((a) {
                          final severityStr = (a['severity'] ?? a['Priority'] ?? a['priority'] ?? 'Normal').toString();
                          Color color = Colors.blueAccent;
                          if (severityStr.toLowerCase() == 'high' || severityStr.toLowerCase() == 'critical') {
                            color = Colors.redAccent;
                          } else if (severityStr.toLowerCase() == 'medium' || severityStr.toLowerCase() == 'warning') {
                            color = Colors.orangeAccent;
                          }
                          return _alertRow(a, color);
                        }).toList(),
                      ],
                    ),
                  ),
                ),
                if (isLoadMore)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 2),
                  )),
                const SizedBox(height: 80),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Alert History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'System anomalies.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            if (totalAlerts > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Showing ${alerts.length} of $totalAlerts',
                  style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AlertRulesScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF141414),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('RULES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search by sensor name...',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
          suffixIcon: _searchController.text.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                onPressed: () {
                  _searchController.clear();
                  _loadInitialData();
                },
              )
            : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final List<dynamic> uniqueSites = [];
    final Set<int> seenIds = {};
    for (var s in sites) {
      final idValue = s['siteId'] ?? s['id'] ?? s['Id'] ?? s['ID'];
      if (idValue == null) continue;
      final intId = idValue is int ? idValue : int.tryParse(idValue.toString());
      if (intId != null && !seenIds.contains(intId)) {
        uniqueSites.add(s);
        seenIds.add(intId);
      }
    }

    // Double check that selectedSiteId is actually in the unique list
    final bool siteExists = selectedSiteId == null || seenIds.contains(selectedSiteId);
    final int? currentValue = siteExists ? selectedSiteId : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: currentValue,
          dropdownColor: const Color(0xFF141414),
          hint: const Text('All Sites', style: TextStyle(color: Colors.white70, fontSize: 14)),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
          isExpanded: true,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('All Sites', style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
            ...uniqueSites.map((s) {
              final id = int.tryParse((s['siteId'] ?? s['id'] ?? s['Id'] ?? s['ID']).toString());
              return DropdownMenuItem<int?>(
                value: id,
                child: Text(s['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 14)),
              );
            }),
          ],
          onChanged: (val) {
            setState(() {
              selectedSiteId = val;
            });
            _loadInitialData();
          },
        ),
      ),
    );
  }

  Widget _tableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      child: Row(
        children: [
          Container(width: 110, alignment: Alignment.centerLeft, child: const Text('TIME', style: _tableHeaderStyle)),
          Container(width: 190, alignment: Alignment.centerLeft, child: const Text('SENSOR', style: _tableHeaderStyle)),
          Container(width: 450, alignment: Alignment.centerLeft, child: const Text('MESSAGE', style: _tableHeaderStyle)),
          Container(width: 100, alignment: Alignment.center, child: const Text('SEV', style: _tableHeaderStyle)),
        ],
      ),
    );
  }

  static const _tableHeaderStyle = TextStyle(
    color: Colors.white54,
    fontSize: 11,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.8,
  );

  Widget _alertRow(dynamic a, Color color) {
    // Check for both camelCase and snake_case keys for robustness
    final timeStr = a['updatedAt'] ?? a['updated_at'] ?? a['createdAt'] ?? a['created_at'] ?? a['timestamp'] ?? a['Time'] ?? a['time'] ?? '';
    String _get(dynamic m, List<String> keys, String fallback) {
      if (m == null) return fallback;
      if (m is! Map) {
        final str = m.toString().trim();
        return str.isNotEmpty ? str : fallback;
      }
      for (var k in keys) {
        if (m[k] != null && m[k].toString().trim().isNotEmpty) return m[k].toString();
      }
      // Check deeply nested common objects
      final nested = ['trigger', 'rule', 'alertRule', 'sensor', 'site'];
      for (var n in nested) {
        if (m[n] != null) {
          final res = _get(m[n], keys, '');
          if (res.isNotEmpty) return res;
        }
      }
      return fallback;
    }

    final message = _get(a, ['message', 'Message', 'description', 'Description', 'note', 'Note', 'content', 'alertMessage', 'alert_message', 'msg', 'ruleName', 'rule_name', 'name', 'RuleName', 'Rule_Name', 'Title', 'title', 'Header', 'header', 'Body', 'body'], '');
    final sensorName = _get(a, ['sensorName', 'SensorName', 'sensor_name', 'Sensor', 'sensor', 'name', 'Sensor_Name'], 'Unknown');
    final severityStr = _get(a, ['severity', 'Priority', 'priority', 'Severity'], 'Normal');

    String timeFormatted = timeStr;
    if (timeStr.length > 16) {
      try {
        final dt = DateTime.parse(timeStr).toLocal();
        timeFormatted = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}\n${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
      } catch (_) {}
    } else if (timeStr.isEmpty) {
      timeFormatted = '-';
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Row(
          children: [
            Container(
              width: 110,
              alignment: Alignment.centerLeft,
              child: Text(timeFormatted, style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.3)),
            ),
            Container(
              width: 190,
              alignment: Alignment.centerLeft,
              child: Text(sensorName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ),
            Container(
              width: 450,
              alignment: Alignment.centerLeft,
              child: Text(
                message.isEmpty ? '-' : message,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            Container(
              width: 100,
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  severityStr.substring(0, 1).toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF222222)),
      );
}
