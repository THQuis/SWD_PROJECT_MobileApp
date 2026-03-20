import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/hub_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/notification_bell.dart';
import '../sensors/sensors_screen.dart';
import '../sites/sites_screen.dart';
import 'add_hub_dialog.dart';
import 'edit_hub_dialog.dart';

class HubsScreen extends StatefulWidget {
  final String? initialSiteName;
  final List<int>? initialHubIds;
  const HubsScreen({super.key, this.initialSiteName, this.initialHubIds});

  @override
  State<HubsScreen> createState() => _HubsScreenState();
}

class _HubsScreenState extends State<HubsScreen> {
  final HubService _hubService = HubService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allHubs = [];
  List<dynamic> _filteredHubs = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    if (widget.initialHubIds != null && widget.initialHubIds!.isNotEmpty) {
      _loadHubsByIds(widget.initialHubIds!);
    } else {
      _loadHubs().then((_) {
        if (widget.initialSiteName != null) {
          _searchController.text = widget.initialSiteName!;
          _filterHubs(widget.initialSiteName!);
        }
      });
    }
  }

  Future<void> _refreshData() {
    if (widget.initialHubIds != null && widget.initialHubIds!.isNotEmpty) {
      return _loadHubsByIds(widget.initialHubIds!);
    }
    return _loadHubs();
  }

  Future<void> _loadHubs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = AuthService.token;
      if (token == null) {
        setState(() {
          _error = "No session found. Please login again.";
          _isLoading = false;
        });
        return;
      }

      final data = await _hubService.fetchHubs(token);
      final enrichedData = await _hubService.enrichHubsWithDetails(token, data);
      setState(() {
        _allHubs = enrichedData;
        _filteredHubs = _computeFilteredHubs();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Load hubs error: $e");
      setState(() {
        _error = "Error loading hubs: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHubsByIds(List<int> hubIds) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = AuthService.token;
      if (token == null) {
        setState(() {
          _error = "No session found. Please login again.";
          _isLoading = false;
        });
        return;
      }

      final data = await _hubService.fetchHubsByIds(token, hubIds);
      setState(() {
        _allHubs = data;
        _filteredHubs = _computeFilteredHubs();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Load hubs by id error: $e");
      setState(() {
        _error = "Error loading hubs: $e";
        _isLoading = false;
      });
    }
  }

  void _filterHubs(String query) {
    setState(() {
      _searchQuery = query;
      _filteredHubs = _computeFilteredHubs();
    });
  }

  List<dynamic> _computeFilteredHubs() {
    final q = _searchQuery.trim().toLowerCase();
    return _allHubs.where((h) {
      final name = (h['name'] ?? '').toString().toLowerCase();
      final site = (h['siteName'] ?? '').toString().toLowerCase();
      final mac = (h['macAddress'] ?? '').toString().toLowerCase();
      final online = h['isOnline'] == true;

      final queryMatch =
          q.isEmpty || name.contains(q) || site.contains(q) || mac.contains(q);
      final statusMatch = _statusFilter == 'all' ||
          (_statusFilter == 'online' && online) ||
          (_statusFilter == 'offline' && !online);
      return queryMatch && statusMatch;
    }).toList();
  }

  void _setStatusFilter(String value) {
    setState(() {
      _statusFilter = value;
      _filteredHubs = _computeFilteredHubs();
    });
  }

  void _openAddHubDialog() {
    showDialog(
      context: context,
      builder: (_) => AddHubDialog(
        onSuccess: () {
          _refreshData();
        },
      ),
    );
  }

  void _openEditHubDialog(dynamic hub) {
    showDialog(
      context: context,
      builder: (_) => EditHubDialog(
        hub: hub,
        onSuccess: () {
          _refreshData();
        },
      ),
    );
  }

  Future<void> _deleteHub(dynamic hub) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2C),
        title: const Text("Delete Hub", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to delete ${hub['name']}?",
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text("DELETE", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final token = AuthService.token;
        if (token == null) return;

        final success = await _hubService.deleteHub(token, hub['hubId']);
        if (success) {
          _refreshData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Hub deleted successfully")),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      "Failed to delete hub. It might have active sensors.")),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.initialSiteName != null
        ? "Hubs in ${widget.initialSiteName}"
        : "Hubs Management";

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: const [
          NotificationBell(),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _backToSites(),
                    const SizedBox(height: 16),
                    _header(title),
                    const SizedBox(height: 32),
                    if (_error != null) _errorView(),
                    if (_error == null) ...[
                      _statsStrip(),
                      const SizedBox(height: 16),
                      _searchBar(),
                      const SizedBox(height: 12),
                      _statusChips(),
                      const SizedBox(height: 24),
                      _hubsGrid(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _backToSites() {
    return GestureDetector(
      onTap: () => Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const SitesScreen())),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.arrow_back, color: Color(0xFF0EA5E9), size: 16),
          SizedBox(width: 8),
          Text(
            "Back to Sites",
            style: TextStyle(
                color: Color(0xFF0EA5E9),
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _header(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0EA5E9).withOpacity(0.16),
            const Color(0xFF1A1F2C).withOpacity(0.35),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage, troubleshoot, and jump into sensors from one streamlined view.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _openAddHubDialog,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add New Hub'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                    color: const Color(0xFF0EA5E9).withOpacity(0.35)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsStrip() {
    final total = _allHubs.length;
    final online = _allHubs.where((h) => h['isOnline'] == true).length;
    final offline = total - online;

    return Row(
      children: [
        Expanded(
          child: _miniStat(
              'Total Hubs', total.toString(), const Color(0xFF60A5FA)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              _miniStat('Online', online.toString(), const Color(0xFF10B981)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              _miniStat('Offline', offline.toString(), const Color(0xFFEF4444)),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadHubs, child: const Text("Retry")),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C).withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _filterHubs,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, color: Colors.white38, size: 18),
                hintText: "Search by hub, site, MAC...",
                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
                _filterHubs('');
              },
              icon: const Icon(Icons.close_rounded, color: Colors.white38),
            ),
        ],
      ),
    );
  }

  Widget _statusChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip('All', 'all'),
        _chip('Online', 'online'),
        _chip('Offline', 'offline'),
      ],
    );
  }

  Widget _chip(String label, String value) {
    final selected = _statusFilter == value;
    return InkWell(
      onTap: () => _setStatusFilter(value),
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF0EA5E9).withOpacity(0.2)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? const Color(0xFF0EA5E9).withOpacity(0.75)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF67E8F9) : Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _hubsGrid() {
    if (_filteredHubs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: const Center(
          child: Text('No hubs found', style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final int columns = width > 1200
          ? 3
          : width > 760
              ? 2
              : 1;
      final cardWidth = (width - ((columns - 1) * 14)) / columns;

      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: _filteredHubs
            .map((hub) => SizedBox(width: cardWidth, child: _hubCard(hub)))
            .toList(),
      );
    });
  }

  Widget _hubCard(dynamic hub) {
    final name = hub['name'] ?? 'Unknown Hub';
    final site = hub['siteName'] ?? 'Unassigned';
    final mac = hub['macAddress'] ?? 'N/A';
    final bool online = hub['isOnline'] ?? false;
    final sensorCount = (hub['sensorCount'] ?? 0).toString();
    final lastHandshake = _formatHandshake(hub['lastHandshake']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: online
                        ? const Color(0xFF0F1E16)
                        : const Color(0xFF1E0F0F),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: online
                          ? const Color(0xFF153322)
                          : const Color(0xFF331515),
                    ),
                  ),
                  child: Text(
                    online ? 'ONLINE' : 'OFFLINE',
                    style: TextStyle(
                      color:
                          online ? const Color(0xFF10B981) : Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              site,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.68), fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              'MAC: $mac',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45), fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              'Last Handshake: $lastHandshake',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45), fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SensorsScreen(
                        initialHubId: hub['hubId'],
                        initialHubName: name,
                      ),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F2C).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF0EA5E9).withOpacity(0.25)),
                    ),
                    child: Text(
                      '$sensorCount sensors',
                      style: const TextStyle(
                        color: Color(0xFF0EA5E9),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.edit_outlined,
                      color: Colors.white.withOpacity(0.45), size: 18),
                  onPressed: () => _openEditHubDialog(hub),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      color: Colors.white.withOpacity(0.45), size: 18),
                  onPressed: () => _deleteHub(hub),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatHandshake(dynamic raw) {
    if (raw == null) return 'N/A';
    final source = raw.toString();
    final dt = DateTime.tryParse(source);
    if (dt == null) return source;
    final local = dt.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }
}
