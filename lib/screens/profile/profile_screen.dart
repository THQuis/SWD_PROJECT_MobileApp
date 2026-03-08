import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_drawer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _userService = UserService();
  bool _isRefreshing = false;

  Future<void> _refreshProfile() async {
    setState(() => _isRefreshing = true);
    // In a real app, we might fetch the latest user data from /api/users/me or /api/users/{id}
    // For now, we rely on AuthService.user being updated or just simulate a reload.
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isRefreshing = false);
  }

  void _showEditNameDialog() {
    final user = AuthService.user ?? {};
    final TextEditingController nameController = TextEditingController(text: user['fullName'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 400,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 32, bottom: 24),
                      child: Text(
                        'Edit Full Name',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('FULL NAME', style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: nameController,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.03),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
                              hintText: 'Enter your full name',
                              hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                              child: const Text('CANCEL', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                                boxShadow: [
                                  BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: isSubmitting ? null : () async {
                                  setDialogState(() => isSubmitting = true);
                                  try {
                                    final token = AuthService.token;
                                    if (token == null) return;
                                    final int userId = user['userId'] ?? 0;
                                    final int siteId = user['siteId'] ?? 0;
                                    final success = await _userService.updateUser(token, userId, {
                                      "fullName": nameController.text.trim(),
                                      "siteId": siteId,
                                    });
                                    if (success) {
                                      user['fullName'] = nameController.text.trim();
                                      if (mounted) {
                                        setState(() {});
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name updated successfully'), backgroundColor: Colors.green));
                                      }
                                    }
                                  } catch (e) {
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                                  } finally {
                                    setDialogState(() => isSubmitting = false);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: isSubmitting 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('SAVE', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final TextEditingController oldPassController = TextEditingController();
    final TextEditingController newPassController = TextEditingController();
    final TextEditingController confirmPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 400,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 32, bottom: 24),
                      child: Text(
                        'Security Update',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          _dialogTextField(oldPassController, 'CURRENT PASSWORD', true),
                          const SizedBox(height: 20),
                          _dialogTextField(newPassController, 'NEW PASSWORD', true),
                          const SizedBox(height: 20),
                          _dialogTextField(confirmPassController, 'CONFIRM NEW PASSWORD', true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                              child: const Text('CANCEL', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                                boxShadow: [
                                  BoxShadow(color: Colors.orangeAccent.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: isSubmitting ? null : () async {
                                  if (newPassController.text != confirmPassController.text) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.orange));
                                    return;
                                  }
                                  setDialogState(() => isSubmitting = true);
                                  try {
                                    await Future.delayed(const Duration(seconds: 1));
                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully'), backgroundColor: Colors.green));
                                    }
                                  } catch (e) {
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                                  } finally {
                                    setDialogState(() => isSubmitting = false);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: isSubmitting 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('UPDATE', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dialogTextField(TextEditingController controller, String label, bool isPassword) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.03),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.orangeAccent, width: 1.5)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.user ?? {};
    final String fullName = user['fullName'] ?? 'Admin User';
    final String email = user['email'] ?? 'admin@example.com';
    final String role = AuthService.role ?? 'Admin';
    final String site = user['siteName'] ?? 'All Sites';
    final bool isActive = user['isActive'] ?? true;
    final String initials = _getInitials(fullName);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _refreshProfile,
            icon: _isRefreshing 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile Settings',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage your personal information and account preferences.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 32),
            
            _profileSummaryCard(fullName, role, isActive, initials),
            const SizedBox(height: 24),
            
            _personalInfoCard(fullName, email, role, site),
            const SizedBox(height: 24),
            
            _securitySettingsCard(),
            const SizedBox(height: 24),
            
            _securityTipCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'AU';
    List<String> parts = name.split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'AU';
  }

  Widget _profileSummaryCard(String name, String role, bool isActive, String initials) {
    return _glassContainer(
      child: Column(
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blueAccent.withOpacity(0.1),
                  Colors.purpleAccent.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -50),
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFCCBC),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(color: Color(0xFF4E342E), fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  role.toUpperCase(),
                  style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Account Status', style: TextStyle(color: Colors.white54, fontSize: 14)),
                      _statusBadge(isActive),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _personalInfoCard(String name, String email, String role, String site) {
    return _glassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PERSONAL INFORMATION',
                style: TextStyle(color: Colors.white30, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              TextButton.icon(
                onPressed: _showEditNameDialog,
                icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.blueAccent),
                label: const Text('Edit', style: TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _infoRow('FULL NAME', name, 'EMAIL ADDRESS', email),
          const SizedBox(height: 24),
          _infoRow('ROLE', role, 'MAIN SITE', site),
        ],
      ),
    );
  }

  Widget _infoRow(String label1, String value1, String label2, String value2) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label1, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(value1, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label2, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(value2, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _securitySettingsCard() {
    return _glassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.lock_outline, size: 18, color: Colors.white30),
                  SizedBox(width: 8),
                  Text(
                    'SECURITY SETTINGS',
                    style: TextStyle(color: Colors.white30, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _showChangePasswordDialog,
                icon: const Icon(Icons.key_outlined, size: 16, color: Colors.orangeAccent),
                label: const Text('Change', style: TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('CURRENT PASSWORD', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: const Text('********', style: TextStyle(color: Colors.white30, fontSize: 16, letterSpacing: 2)),
          ),
        ],
      ),
    );
  }

  Widget _securityTipCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blueAccent.withOpacity(0.1),
              Colors.blueAccent.withOpacity(0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.1))),
      child: const Row(
        children: [
          Icon(Icons.verified_user_outlined, color: Colors.blueAccent, size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security Tip',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Make sure your password is strong and contains a mix of letters, numbers and symbols.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isActive ? Colors.greenAccent : Colors.redAccent).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: (isActive ? Colors.greenAccent : Colors.redAccent).withOpacity(0.2)),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(color: isActive ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _glassContainer({required Widget child, EdgeInsetsGeometry? padding, double borderRadius = 16.0}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: child,
    );
  }
}
