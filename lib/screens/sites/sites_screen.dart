import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/site_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_drawer.dart';
import 'add_site_dialog.dart';

class SitesScreen extends StatefulWidget {
  const SitesScreen({super.key});

  @override
  State<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends State<SitesScreen> {
  final SiteService _siteService = SiteService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allSites = [];
  List<dynamic> _filteredSites = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
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

      final data = await _siteService.fetchSites(token);
      setState(() {
        _allSites = data;
        _filteredSites = data;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint("Load sites error: $e");
      setState(() {
        _error = "Error loading sites: $e";
        _isLoading = false;
      });
    }
  }

  void _filterSites(String query) {
    setState(() {
      _filteredSites = _allSites
          .where((s) =>
              (s['name'] ?? '').toLowerCase().contains(query.toLowerCase()) ||
              (s['address'] ?? '').toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _openAddSiteDialog() {
    showDialog(
      context: context,
      builder: (_) => AddSiteDialog(
        onSuccess: () {
          _loadSites();
        },
      ),
    );
  }

  Widget _glassContainer(
      {required Widget child,
      double opacity = 0.05,
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
          'Sites Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSites,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 24),
                    if (_error != null) _errorView(),
                    if (_error == null) ...[
                      _searchBar(),
                      const SizedBox(height: 24),
                      _sitesList(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _errorView() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
        const SizedBox(height: 16),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loadSites,
          child: const Text("Retry"),
        ),
      ],
    );
  }

  Widget _searchBar() {
    return _glassContainer(
      opacity: 0.08,
      borderRadius: 12,
      child: TextField(
        controller: _searchController,
        onChanged: _filterSites,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          hintText: "Search sites...",
          hintStyle: const TextStyle(color: Colors.white38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  // ================= HEADER =================
  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'IoT Sites Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Manage environmental monitoring sites.',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _openAddSiteDialog,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Add New Site'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A1F2C),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  // ================= SITES LIST =================
  Widget _sitesList() {
    if (_filteredSites.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 100),
          child: Text("No sites found", style: TextStyle(color: Colors.white38)),
        ),
      );
    }
    return Column(
      children: _filteredSites.map((site) {
        final id = site['id']?.toString() ?? 'N/A';
        final name = site['name'] ?? 'Unknown Site';
        final address = site['address'] ?? 'No address provided';
        final org = site['orgName'] ?? 'Co.opmart';
        final hubs = site['hubCount']?.toString() ?? '0';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: _glassContainer(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(id,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(org, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(address,
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Text(hubs,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, color: Colors.white.withOpacity(0.3), size: 20),
                      const SizedBox(width: 8),
                      Icon(Icons.delete_outline_rounded, color: Colors.white.withOpacity(0.3), size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

}
