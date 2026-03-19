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
  const HubsScreen({super.key, this.initialSiteName});

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

  @override
  void initState() {
    super.initState();
    _loadHubs().then((_) {
      if (widget.initialSiteName != null) {
        _searchController.text = widget.initialSiteName!;
        _filterHubs(widget.initialSiteName!);
      }
    });
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
      setState(() {
        _allHubs = data;
        _filteredHubs = data;
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

  void _filterHubs(String query) {
    setState(() {
      _filteredHubs = _allHubs.where((h) {
        final name = (h['name'] ?? '').toLowerCase();
        final site = (h['siteName'] ?? '').toLowerCase();
        final mac = (h['macAddress'] ?? '').toLowerCase();
        final q = query.toLowerCase();
        return name.contains(q) || site.contains(q) || mac.contains(q);
      }).toList();
    });
  }

  void _openAddHubDialog() {
    showDialog(
      context: context,
      builder: (_) => AddHubDialog(
        onSuccess: () {
          _loadHubs();
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
          _loadHubs();
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
            child: const Text("DELETE", style: TextStyle(color: Colors.redAccent)),
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
          _loadHubs();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Hub deleted successfully")),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Failed to delete hub. It might have active sensors.")),
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
    final title = widget.initialSiteName != null ? "Hubs in ${widget.initialSiteName}" : "Hubs Management";

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: const [
          NotificationBell(),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHubs,
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
                      _filterControls(),
                      const SizedBox(height: 24),
                      _hubsTable(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _backToSites() {
    return GestureDetector(
      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SitesScreen())),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.arrow_back, color: Color(0xFF0EA5E9), size: 16),
          SizedBox(width: 8),
          Text(
            "Back to Sites",
            style: TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _header(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
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
                'Configure and monitor gateway devices across all store locations.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _openAddHubDialog,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Add New Hub'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A1F2C),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _filterControls() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _searchBar(),
        _dropdownFilter("All Status"),
        _dropdownFilter("Default"),
        _dropdownFilter("ASC", icon: Icons.arrow_upward_rounded),
      ],
    );
  }

  Widget _dropdownFilter(String text, {IconData icon = Icons.keyboard_arrow_down}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C).withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon == Icons.arrow_upward_rounded) Icon(icon, color: Colors.white70, size: 16),
          if (icon == Icons.arrow_upward_rounded) const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          if (icon == Icons.keyboard_arrow_down) const SizedBox(width: 8),
          if (icon == Icons.keyboard_arrow_down) Icon(icon, color: Colors.white38, size: 16),
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
      width: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C).withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _filterHubs,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search, color: Colors.white38, size: 18),
          hintText: "Search by name or MAC...",
          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _hubsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: 1050, // width for all columns
        decoration: BoxDecoration(
          color: const Color(0xFF141414).withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            // Table Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  SizedBox(width: 150, child: Text('HUB NAME', style: _tableHeaderStyle)),
                  SizedBox(width: 150, child: Text('SITE NAME', style: _tableHeaderStyle)),
                  SizedBox(width: 180, child: Text('MAC ADDRESS', style: _tableHeaderStyle)),
                  SizedBox(width: 150, child: Text('SENSORS', style: _tableHeaderStyle)),
                  SizedBox(width: 100, child: Text('STATUS', style: _tableHeaderStyle)),
                  SizedBox(width: 200, child: Text('LAST HANDSHAKE', style: _tableHeaderStyle)),
                  const Text('ACTIONS', style: _tableHeaderStyle),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // Table Rows
            if (_filteredHubs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(48.0),
                child: Text("No hubs found", style: TextStyle(color: Colors.white38)),
              )
            else
              ..._filteredHubs.map((hub) => _hubRow(hub)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _hubRow(dynamic hub) {
    final name = hub['name'] ?? 'Unknown Hub';
    final site = hub['siteName'] ?? 'Unassigned';
    final mac = hub['macAddress'] ?? 'N/A';
    final bool online = hub['isOnline'] ?? false;
    final lastHandshake = "23:27:20 17/3/2026"; // Mock or format from BE data

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            // HUB NAME
            SizedBox(
              width: 150,
              child: Text(
                name,
                style: _rowTextStyle.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            // SITE NAME
            SizedBox(
              width: 150,
              child: Text(
                site,
                style: _rowTextStyle.copyWith(color: Colors.white38),
              ),
            ),
            // MAC ADDRESS
            SizedBox(
              width: 180,
              child: Text(
                mac,
                style: _rowTextStyle.copyWith(color: Colors.white38, fontSize: 13),
              ),
            ),
            // SENSORS (Interactive button)
            SizedBox(
              width: 150,
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SensorsScreen(
                        initialHubId: hub['hubId'],
                        initialHubName: name,
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F2C).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          "View Sensors",
                          style: TextStyle(
                            color: Color(0xFF0EA5E9),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, color: Color(0xFF0EA5E9), size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // STATUS
            SizedBox(
              width: 100,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: online ? const Color(0xFF0F1E16) : const Color(0xFF1E0F0F),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: online ? const Color(0xFF153322) : const Color(0xFF331515)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: online ? const Color(0xFF10B981) : Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      online ? 'ONLINE' : 'OFFLINE',
                      style: TextStyle(
                        color: online ? const Color(0xFF10B981) : Colors.redAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // LAST HANDSHAKE
            SizedBox(
              width: 200,
              child: Text(
                lastHandshake,
                style: _rowTextStyle.copyWith(color: Colors.white38, fontSize: 12),
              ),
            ),
            // ACTIONS
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: Colors.white.withOpacity(0.3), size: 18),
                  onPressed: () => _openEditHubDialog(hub),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: Colors.white.withOpacity(0.3), size: 18),
                  onPressed: () => _deleteHub(hub),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const _tableHeaderStyle = TextStyle(
    color: Colors.white54,
    fontSize: 11,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.8,
  );

  static const _rowTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
  );
}
