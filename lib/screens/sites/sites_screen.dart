import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/site_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/notification_bell.dart';
import '../hubs/hubs_screen.dart';
import 'add_site_dialog.dart';
import 'edit_site_dialog.dart';

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
  String _searchQuery = '';

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
        _filteredSites = _computeFilteredSites();
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
      _searchQuery = query;
      _filteredSites = _computeFilteredSites();
    });
  }

  List<dynamic> _computeFilteredSites() {
    final query = _searchQuery.trim().toLowerCase();
    return _allSites.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final address = (s['address'] ?? '').toString().toLowerCase();
      final org = (s['orgName'] ?? '').toString().toLowerCase();

      final matchQuery = query.isEmpty ||
          name.contains(query) ||
          address.contains(query) ||
          org.contains(query);

      return matchQuery;
    }).toList();
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

  void _openEditSiteDialog(dynamic site) {
    showDialog(
      context: context,
      builder: (_) => EditSiteDialog(
        site: site,
        onSuccess: () {
          _loadSites();
        },
      ),
    );
  }

  Future<void> _deleteSite(dynamic site) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2C),
        title: const Text("Delete Site", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to delete ${site['name']}?",
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

        final success = await _siteService.deleteSite(token, site['siteId']);
        if (success) {
          _loadSites();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Site deleted successfully")),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      "Failed to delete site. It might have active hubs.")),
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
        actions: const [
          NotificationBell(),
          SizedBox(width: 8),
        ],
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
                      _statsStrip(),
                      const SizedBox(height: 16),
                      _searchBar(),
                      const SizedBox(height: 24),
                      _sitesGrid(),
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _filterSites,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, color: Colors.white38),
                hintText: "Search by site, address, org...",
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
                _filterSites('');
              },
              icon: const Icon(Icons.close_rounded, color: Colors.white38),
            ),
        ],
      ),
    );
  }

  // ================= HEADER =================
  Widget _header() {
    return _glassContainer(
      opacity: 0.08,
      borderRadius: 20,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0EA5E9).withOpacity(0.18),
              const Color(0xFF1A1F2C).withOpacity(0.35),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    'Manage environmental monitoring sites with faster navigation and cleaner actions.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _openAddSiteDialog,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add New Site'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: const Color(0xFF0EA5E9).withOpacity(0.35),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsStrip() {
    final withHub = _allSites
        .where((s) => (int.tryParse((s['hubCount'] ?? 0).toString()) ?? 0) > 0)
        .length;
    final withoutHub = _allSites.length - withHub;

    return Row(
      children: [
        Expanded(
          child: _miniStat('Total Sites', _allSites.length.toString(),
              const Color(0xFF60A5FA)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStat(
              'With Hubs', withHub.toString(), const Color(0xFF34D399)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStat(
              'No Hubs', withoutHub.toString(), const Color(0xFFFBBF24)),
        ),
      ],
    );
  }

  Widget _miniStat(String title, String value, Color color) {
    return _glassContainer(
      opacity: 0.06,
      borderRadius: 14,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.55), fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sitesGrid() {
    if (_filteredSites.isEmpty) {
      return _glassContainer(
        opacity: 0.04,
        borderRadius: 16,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child:
                Text('No sites found', style: TextStyle(color: Colors.white38)),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
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
          children: _filteredSites
              .map((site) => SizedBox(
                    width: cardWidth,
                    child: _siteCard(site),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _siteCard(dynamic site) {
    final name = site['name'] ?? 'Unknown Site';
    final address = site['address'] ?? 'No address provided';
    final org = site['orgName'] ?? 'Co.opmart';
    final hubsCount = site['hubCount']?.toString() ?? '0';
    final hasHub = (int.tryParse(hubsCount) ?? 0) > 0;
    final List<int> hubIds = _extractHubIds(site);

    return _glassContainer(
      opacity: 0.06,
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    org,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.64), fontSize: 12),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasHub
                        ? const Color(0xFF0F1E16)
                        : const Color(0xFF25160F),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: hasHub
                          ? const Color(0xFF153322)
                          : const Color(0xFF4D2F16),
                    ),
                  ),
                  child: Text(
                    hasHub ? 'READY' : 'NEED HUB',
                    style: TextStyle(
                      color: hasHub
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HubsScreen(
                    initialSiteName: name,
                    initialHubIds: hubIds,
                  ),
                ),
              ),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF22D3EE),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined,
                    color: Colors.white.withOpacity(0.35), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.58), fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2C).withOpacity(0.55),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    '$hubsCount hubs',
                    style: const TextStyle(
                      color: Color(0xFF93C5FD),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Edit Site',
                  icon: Icon(Icons.edit_outlined,
                      color: Colors.white.withOpacity(0.45), size: 18),
                  onPressed: () => _openEditSiteDialog(site),
                ),
                IconButton(
                  tooltip: 'Delete Site',
                  icon: Icon(Icons.delete_outline_rounded,
                      color: Colors.white.withOpacity(0.45), size: 18),
                  onPressed: () => _deleteSite(site),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<int> _extractHubIds(dynamic site) {
    if (site is! Map) return [];
    final hubs = site['hubs'];
    if (hubs is! List) return [];

    final ids = <int>[];
    for (final h in hubs) {
      if (h is! Map) continue;
      final dynamic id =
          h['hubId'] ?? h['id'] ?? h['Id'] ?? h['ID'] ?? h['hub_id'];
      if (id is int) {
        ids.add(id);
      } else {
        final parsed = int.tryParse(id?.toString() ?? '');
        if (parsed != null) ids.add(parsed);
      }
    }
    return ids;
  }
}
