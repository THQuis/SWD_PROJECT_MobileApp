import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/hub_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_drawer.dart';
import 'add_hub_dialog.dart';
import 'edit_hub_dialog.dart';

class HubsScreen extends StatefulWidget {
  const HubsScreen({super.key});

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
    _loadHubs();
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

  Widget _glassContainer({required Widget child, double borderRadius = 16.0}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414).withOpacity(0.05),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Hubs Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
                    _header(),
                    const SizedBox(height: 32),
                    if (_error != null) _errorView(),
                    if (_error == null) ...[
                      _searchBar(),
                      const SizedBox(height: 24),
                      _hubsTable(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hubs Management',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Configure and monitor gateway devices across all store locations.',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _openAddHubDialog,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Add New Hub'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A1F2C),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
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
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C).withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _filterHubs,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search, color: Colors.white38),
          hintText: "Search hubs by name, site, or MAC...",
          hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _hubsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: 850, // Increased width to ensure no overflow
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
                  SizedBox(width: 180, child: Text('HUB NAME', style: _tableHeaderStyle)),
                  SizedBox(width: 150, child: Text('SITE NAME', style: _tableHeaderStyle)),
                  SizedBox(width: 200, child: Text('MAC ADDRESS', style: _tableHeaderStyle)),
                  SizedBox(width: 100, child: Text('STATUS', style: _tableHeaderStyle)),
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

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            SizedBox(width: 180, child: Text(name, style: _rowTextStyle.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            SizedBox(width: 150, child: Text(site, style: _rowTextStyle.copyWith(color: Colors.white70), overflow: TextOverflow.ellipsis)),
            SizedBox(width: 200, child: Text(mac, style: _rowTextStyle.copyWith(color: Colors.white38, fontSize: 13), overflow: TextOverflow.ellipsis)),
            SizedBox(
              width: 100,
              child: Text(
                online ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(
                  color: online ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: Colors.white.withOpacity(0.3), size: 18),
                  onPressed: () => _openEditHubDialog(hub),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: Colors.white.withOpacity(0.3), size: 18),
                  onPressed: () => _deleteHub(hub),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
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
