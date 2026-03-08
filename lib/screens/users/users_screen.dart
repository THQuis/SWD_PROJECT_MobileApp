import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_drawer.dart';
import 'create_user_dialog.dart';
import 'edit_user_dialog.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _userService = UserService();
  bool _isLoading = true;
  List<dynamic> _users = [];
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // Pagination
  int _currentPage = 1;
  int _pageSize = 7; // Changed from 10 to 7 as requested
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  String _selectedStatus = "All Status";
  final List<String> _statusOptions = ["All Status", "Active", "Inactive"];

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final token = AuthService.token;
      if (token == null) return;

      bool? isActiveParam;
      if (_selectedStatus == "Active") isActiveParam = true;
      if (_selectedStatus == "Inactive") isActiveParam = false;

      final result = await _userService.fetchUsers(
        token,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        isActive: isActiveParam, // Pass to API
        pageNumber: _currentPage,
        pageSize: _pageSize,
      );

      setState(() {
        _users = result['data'] ?? [];
        _totalCount = result['totalCount'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading users: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching users: $e")),
        );
      }
    }
  }

  void _openCreateUserDialog() {
    showDialog(
      context: context,
      builder: (_) => CreateUserDialog(
        onSuccess: () => _loadUsers(),
      ),
    );
  }

  void _openEditUserDialog(dynamic user) {
    showDialog(
      context: context,
      builder: (_) => EditUserDialog(
        user: user,
        onSuccess: () => _loadUsers(),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text(
          'Users Administration',
          style: TextStyle(
            color: Colors.white, // Fixed "chữ mờ" issue
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white), // Ensure drawer icon is visible
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerSection(),
            const SizedBox(height: 24),
            _filterAndSearchSection(),
            const SizedBox(height: 20),
            _usersTableSection(),
            const SizedBox(height: 20),
            _paginationControls(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _paginationControls() {
    int totalPages = (_totalCount / _pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
          onPressed: _currentPage > 1 ? () {
            setState(() => _currentPage--);
            _loadUsers();
          } : null,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Page $_currentPage of $totalPages',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
          onPressed: _currentPage < totalPages ? () {
            setState(() => _currentPage++);
            _loadUsers();
          } : null,
        ),
      ],
    );
  }

  Widget _headerSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 600;
        return Flex(
          direction: isWide ? Axis.horizontal : Axis.vertical,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: isWide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IoT Users Administration',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage system access for organizations and site staff.',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
            if (!isWide) const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openCreateUserDialog,
              icon: const Icon(Icons.person_add_rounded, size: 20),
              label: const Text('Create User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _filterAndSearchSection() {
    return _glassContainer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (value) {
                  setState(() {
                    _searchQuery = value;
                    _currentPage = 1;
                  });
                  _loadUsers();
                },
              ),
            ),
            const SizedBox(width: 16),
            _statusFilter(),
            const SizedBox(width: 16),
            _actionButton(Icons.refresh_rounded, _loadUsers),
          ],
        ),
      ),
    );
  }

  Widget _statusFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38),
          items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) {
            setState(() => _selectedStatus = v!);
            _loadUsers();
          },
        ),
      ),
    );
  }

  Widget _usersTableSection() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    if (_users.isEmpty) {
      return _glassContainer(
        child: const Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: Text('No users found.', style: TextStyle(color: Colors.white54, fontSize: 16)),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: 1100,
        decoration: BoxDecoration(
          color: const Color(0xFF141414).withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            _tableHeader(),
            const Divider(color: Colors.white10, height: 1),
            ..._users.map((user) => _tableRow(user)),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _headerCell('FULL NAME', 250),
          _headerCell('EMAIL', 300),
          _headerCell('ROLE', 150),
          _headerCell('SITE', 150),
          _headerCell('STATUS', 100),
          _headerCell('ACTIONS', 100),
        ],
      ),
    );
  }

  Widget _headerCell(String label, double width) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
    );
  }

  Widget _tableRow(dynamic user) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              SizedBox(
                width: 250,
                child: Text(user['fullName'] ?? 'N/A', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              SizedBox(
                width: 300,
                child: Text(user['email'] ?? 'N/A', style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ),
              SizedBox(
                width: 150,
                child: _roleBadge(user['roleName'] ?? 'N/A'),
              ),
              SizedBox(
                width: 150,
                child: Text(user['siteName'] ?? 'Head Office', style: const TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic)),
              ),
              SizedBox(
                width: 100,
                child: _statusBadge(user['isActive'] == true),
              ),
              SizedBox(
                width: 100,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: Colors.white.withOpacity(0.3), size: 18),
                      onPressed: () => _openEditUserDialog(user),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1),
      ],
    );
  }

  Widget _roleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
      ),
      child: Text(
        role.toUpperCase(),
        style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _statusBadge(bool isActive) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.greenAccent : Colors.redAccent,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isActive ? "ACTIVE" : "INACTIVE",
          style: TextStyle(color: isActive ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _glassContainer({required Widget child, double borderRadius = 16.0}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: child,
    );
  }

  Widget _actionButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white70, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}
