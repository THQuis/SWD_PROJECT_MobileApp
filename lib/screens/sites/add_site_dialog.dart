import 'package:flutter/material.dart';
import '../../services/site_service.dart';
import '../../services/auth_service.dart';

class AddSiteDialog extends StatefulWidget {
  final VoidCallback onSuccess;

  const AddSiteDialog({super.key, required this.onSuccess});

  @override
  State<AddSiteDialog> createState() => _AddSiteDialogState();
}

class _AddSiteDialogState extends State<AddSiteDialog> {
  final SiteService _siteService = SiteService();
  
  final orgController = TextEditingController(text: "Co.opmart");
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final geoController = TextEditingController();

  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (nameController.text.isEmpty || addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in Name and Address")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = AuthService.token;
      if (token == null) return;

      // Parse geo location if provided
      double? lat, long;
      if (geoController.text.contains(',')) {
        final parts = geoController.text.split(',');
        lat = double.tryParse(parts[0].trim());
        long = double.tryParse(parts[1].trim());
      }

      final success = await _siteService.addSite(token, {
        "name": nameController.text,
        "address": addressController.text,
        "latitude": lat ?? 0.0,
        "longitude": long ?? 0.0,
        "orgId": 1, // Default for now
      });

      if (success) {
        widget.onSuccess();
        if (mounted) Navigator.pop(context);
      } else {
        throw Exception("Failed to add site");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFF1A1F2C).withOpacity(0.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 1),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D0D0D),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ADD NEW SITE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const Divider(color: Colors.white12, height: 32),
              
              _label('Organization'),
              TextField(
                controller: orgController,
                readOnly: true,
                style: const TextStyle(color: Colors.white70),
                decoration: _inputDecoration(''),
              ),

              _label('Site Name'),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('e.g., WinMart Cầu Giấy'),
              ),

              _label('Address'),
              TextField(
                controller: addressController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('e.g., 123 Cau Giay, Hanoi'),
              ),

              _label('Geo Location'),
              TextField(
                controller: geoController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Lat, Long (e.g. 21.0285, 105.8542)'),
              ),

              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
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
                        backgroundColor: const Color(0xFF1A1F2C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('ADD SITE', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
