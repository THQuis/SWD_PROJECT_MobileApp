import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/alert_service.dart';
import '../login/login_screen.dart';
import '../../widgets/app_drawer.dart';
import 'alerts_screen.dart';
import 'add_edit_alert_rule_dialog.dart';

class AlertRulesScreen extends StatefulWidget {
  const AlertRulesScreen({super.key});

  @override
  State<AlertRulesScreen> createState() => _AlertRulesScreenState();
}

class _AlertRulesScreenState extends State<AlertRulesScreen> {
  final AlertService _alertService = AlertService();

  List<dynamic> rules = [];
  bool isLoading = true;
  String? error;

  // Pagination state
  int currentPage = 1;
  int totalRules = 0;
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
      rules = [];
    });
    await _loadRules(refresh: true);
  }

  Future<void> _loadRules({bool refresh = false}) async {
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
      final result = await _alertService.fetchAlertRules(
        token,
        search: _searchController.text.trim(),
        page: currentPage,
        limit: 20,
      );

      if (!mounted) return;

      final newRules = result['rules'] as List<dynamic>;
      final total = result['total'] ?? 0;

      setState(() {
        if (refresh) {
          rules = newRules;
        } else {
          rules.addAll(newRules);
        }
        totalRules = total;
        isLoading = false;
        isLoadMore = false;
        hasMore = rules.length < totalRules;
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
    await _loadRules();
  }

  Future<void> _onRefresh() async {
    await _loadInitialData();
  }

  Future<void> _showAddEditRuleDialog([dynamic rule]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AddEditAlertRuleDialog(rule: rule),
    );

    if (result == true) {
      _loadInitialData();
    }
  }

  Future<void> _deleteRule(int ruleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text('Confirm Delete', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this alert rule?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final token = AuthService.token!;
        final success = await _alertService.deleteAlertRule(token, ruleId);
        if (success) {
          _loadInitialData();
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete rule')));
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
          'Alert Rules',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
              const SizedBox(height: 16),
              if (isLoading && rules.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                ))
              else if (error != null && rules.isEmpty)
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
              else if (rules.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Text('No alert rules found', style: TextStyle(color: Colors.grey)),
                ))
              else ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    width: 790,
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      children: [
                        _tableHeader(),
                        const Divider(color: Colors.white12, height: 1),
                        ...rules.map((r) => _ruleRow(r)).toList(),
                      ],
                    ),
                  ),
                ),
                if (isLoadMore)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 2),
                  )),
                if (!hasMore && rules.isNotEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('All rules loaded', style: TextStyle(color: Colors.white24, fontSize: 12)),
                  )),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditRuleDialog(),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'System Rules',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Configure thresholds.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () => _showAddEditRuleDialog(),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('CREATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AlertsScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF141414),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('HISTORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
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
          hintText: 'Search rules or sensors...',
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

  Widget _tableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      child: Row(
        children: [
          Container(width: 200, alignment: Alignment.centerLeft, child: const Text('RULE NAME', style: _tableHeaderStyle)),
          Container(width: 150, alignment: Alignment.centerLeft, child: const Text('CONDITION', style: _tableHeaderStyle)),
          Container(width: 150, alignment: Alignment.centerLeft, child: const Text('THRESHOLD', style: _tableHeaderStyle)),
          Container(width: 120, alignment: Alignment.center, child: const Text('PRIORITY', style: _tableHeaderStyle)),
          Container(width: 120, alignment: Alignment.center, child: const Text('ACTIONS', style: _tableHeaderStyle)),
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

  Widget _ruleRow(dynamic r) {
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
      final nested = ['rule', 'trigger', 'alertRule', 'sensor', 'site'];
      for (var n in nested) {
        if (m[n] != null) {
          final res = _get(m[n], keys, '');
          if (res.isNotEmpty) return res;
        }
      }
      return fallback;
    }

    final name = _get(r, ['name', 'ruleName', 'rule_name', 'RuleName'], 'Untitled');
    final sensor = _get(r, ['sensorName', 'sensor_name', 'Sensor', 'SensorName', 'name'], 'All Sensors');
    final condition = _get(r, ['conditionType', 'condition_type', 'Condition'], 'MinMax');
    final min = r['minValue'] ?? r['threshold_min'] ?? r['min_value'] ?? 0;
    final max = r['maxValue'] ?? r['threshold_max'] ?? r['max_value'] ?? 100;
    final priority = _get(r, ['priority', 'Priority'], 'Normal');

    Color prioColor = Colors.greenAccent;
    if (priority.toLowerCase() == 'high') prioColor = Colors.redAccent;
    if (priority.toLowerCase() == 'medium') prioColor = Colors.orangeAccent;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Row(
          children: [
            Container(
              width: 200,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  Text(sensor, style: const TextStyle(color: Colors.white38, fontSize: 11), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Container(
              width: 150,
              alignment: Alignment.centerLeft,
              child: Text(condition, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
            Container(
              width: 150,
              alignment: Alignment.centerLeft,
              child: Text('$min - $max', style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            Container(
              width: 120,
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: prioColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: prioColor.withOpacity(0.3)),
                ),
                child: Text(
                  priority.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: prioColor),
                ),
              ),
            ),
            Container(
              width: 120,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 18),
                    onPressed: () => _showAddEditRuleDialog(r),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                    onPressed: () => _deleteRule(r['ruleId']),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
