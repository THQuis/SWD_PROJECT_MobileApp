import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../services/site_service.dart';

class EditUserDialog extends StatefulWidget {
  final dynamic user;
  final VoidCallback onSuccess;

  const EditUserDialog({super.key, required this.user, required this.onSuccess});

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  final _userService = UserService();
  final _siteService = SiteService();

  String _selectedRole = 'Staff';
  String? _selectedSiteId;
  String _selectedStatus = 'ACTIVE';
  List<dynamic> _sites = [];
  bool _isLoadingSites = true;
  bool _isSubmitting = false;

  final List<String> _roles = ['Staff', 'Manager', 'Admin'];
  final List<String> _statuses = ['ACTIVE', 'INACTIVE'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['fullName']);
    _emailController = TextEditingController(text: widget.user['email']);
    _selectedRole = widget.user['roleName'] ?? 'Staff';
    _selectedSiteId = widget.user['siteId']?.toString();
    _selectedStatus = widget.user['status'] ?? 'ACTIVE';
    _loadSites();
  }

  Future<void> _loadSites() async {
    try {
      final token = AuthService.token;
      if (token == null) return;
      final sites = await _siteService.fetchSites(token);
      setState(() {
        _sites = sites;
        _isLoadingSites = false;
      });
    } catch (e) {
      debugPrint("Error loading sites: $e");
      if (mounted) setState(() => _isLoadingSites = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final token = AuthService.token;
      if (token == null) throw Exception("No session found");

      // 1. Update basic info (Name, Site)
      final profileSuccess = await _userService.updateUser(token, widget.user['userId'], {
        "fullName": _nameController.text.trim(),
        "siteId": _selectedSiteId != null ? int.parse(_selectedSiteId!) : 0,
      });

      // 2. Update status if changed (via activate/deactivate endpoints)
      final bool currentStatus = widget.user['isActive'] == true;
      final bool newStatus = _selectedStatus == 'ACTIVE';
      
      if (currentStatus != newStatus) {
        if (newStatus) {
          await _userService.activateUser(token, widget.user['userId']);
        } else {
          await _userService.deactivateUser(token, widget.user['userId']);
        }
      }

      if (profileSuccess) {
        widget.onSuccess();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F2C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const Divider(color: Colors.white10, height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _inputLabel('FULL NAME'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('e.g. Robert Smith'),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),

                      _inputLabel('EMAIL (READ-ONLY)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        readOnly: true,
                        style: const TextStyle(color: Colors.white38),
                        decoration: _inputDecoration('').copyWith(
                          fillColor: Colors.white.withOpacity(0.01),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _inputLabel('ROLE (READ-ONLY)'),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.01),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                                  ),
                                  child: Text(_selectedRole, style: const TextStyle(color: Colors.white38)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _inputLabel('STATUS'),
                                const SizedBox(height: 8),
                                _dropdown(_selectedStatus, _statuses, (v) => setState(() => _selectedStatus = v!)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      _inputLabel('ASSIGNED SITE'),
                      const SizedBox(height: 8),
                      _siteDropdown(),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'EDIT USER',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
      filled: true,
      fillColor: Colors.white.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 1),
      ),
    );
  }

  Widget _dropdown(String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white),
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _siteDropdown() {
    if (_isLoadingSites) {
      return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSiteId,
          hint: const Text('-- No Site (Head Office) --', style: TextStyle(color: Colors.white24, fontSize: 14)),
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white),
          isExpanded: true,
          items: _sites.map((e) => DropdownMenuItem(
            value: e['siteId'].toString(), 
            child: Text(e['name'] ?? 'Unnamed Site'),
          )).toList(),
          onChanged: (v) => setState(() => _selectedSiteId = v),
        ),
      ),
    );
  }
}
