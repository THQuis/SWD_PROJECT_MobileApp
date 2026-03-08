import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/organization_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_drawer.dart';
import 'add_organization_dialog.dart';
import 'edit_organization_dialog.dart';

class OrganizationsScreen extends StatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  State<OrganizationsScreen> createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends State<OrganizationsScreen> {
  final OrganizationService _orgService = OrganizationService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allOrgs = [];
  List<dynamic> _filteredOrgs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
  }

  Future<void> _loadOrganizations() async {
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

      final data = await _orgService.fetchOrganizations(token);
      setState(() {
        _allOrgs = data;
        _filteredOrgs = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Load organizations error: $e");
      setState(() {
        _error = "Error loading organizations: $e";
        _isLoading = false;
      });
    }
  }

  void _filterOrgs(String query) {
    setState(() {
      _filteredOrgs = _allOrgs.where((o) {
        final name = (o['name'] ?? '').toLowerCase();
        final desc = (o['description'] ?? '').toLowerCase();
        final q = query.toLowerCase();
        return name.contains(q) || desc.contains(q);
      }).toList();
    });
  }

  void _openAddOrgDialog() {
    showDialog(
      context: context,
      builder: (_) => AddOrganizationDialog(
        onSuccess: () {
          _loadOrganizations();
        },
      ),
    );
  }

  void _openEditOrgDialog(dynamic org) {
    showDialog(
      context: context,
      builder: (_) => EditOrganizationDialog(
        organization: org,
        onSuccess: () {
          _loadOrganizations();
        },
      ),
    );
  }

  Future<void> _deleteOrg(dynamic org) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2C),
        title: const Text("Delete Organization", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to delete ${org['name']}?",
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

        final success = await _orgService.deleteOrganization(token, org['orgId']);
        if (success) {
          _loadOrganizations();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Organization deleted successfully")),
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
          'Organizations',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOrganizations,
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
                      _orgsTable(),
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
          'Administration / Organizations',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 8),
        const Text(
          'Organizations Management',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Manage tenant organizations and their details.',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _openAddOrgDialog,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Add Organization'),
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
          ElevatedButton(onPressed: _loadOrganizations, child: const Text("Retry")),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2C).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _filterOrgs,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, color: Colors.white38),
                hintText: "Search by name or description...",
                hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _iconButton(Icons.sort_rounded),
        const SizedBox(width: 12),
        _iconButton(Icons.refresh_rounded, onTap: _loadOrganizations),
      ],
    );
  }

  Widget _iconButton(IconData icon, {VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C).withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white70, size: 20),
        onPressed: onTap,
      ),
    );
  }

  Widget _orgsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: 1050,
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
                  SizedBox(width: 200, child: Text('NAME', style: _tableHeaderStyle)),
                  SizedBox(width: 350, child: Text('DESCRIPTION', style: _tableHeaderStyle)),
                  SizedBox(width: 150, child: Text('TOTAL SITES', style: _tableHeaderStyle)),
                  SizedBox(width: 150, child: Text('CREATED AT', style: _tableHeaderStyle)),
                  const Text('ACTIONS', style: _tableHeaderStyle),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // Table Rows
            if (_filteredOrgs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(48.0),
                child: Text("No organizations found", style: TextStyle(color: Colors.white38)),
              )
            else
              ..._filteredOrgs.map((org) => _orgRow(org)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _orgRow(dynamic org) {
    final name = org['name'] ?? 'Unknown';
    final desc = org['description'] ?? 'No description provided';
    final sites = (org['siteCount'] ?? 0).toString();
    final createdAt = org['createdAt'] ?? 'N/A';

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            SizedBox(width: 200, child: Text(name, style: _rowTextStyle.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            SizedBox(width: 350, child: Text(desc, style: _rowTextStyle.copyWith(color: Colors.white70), overflow: TextOverflow.ellipsis)),
            SizedBox(width: 150, child: Center(child: Text(sites, style: _rowTextStyle.copyWith(fontWeight: FontWeight.bold)))),
            SizedBox(width: 150, child: Text(createdAt, style: _rowTextStyle.copyWith(color: Colors.white38, fontSize: 13))),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: Colors.white.withOpacity(0.3), size: 18),
                  onPressed: () => _openEditOrgDialog(org),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: Colors.white.withOpacity(0.3), size: 18),
                  onPressed: () => _deleteOrg(org),
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
