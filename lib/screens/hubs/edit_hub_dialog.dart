import 'package:flutter/material.dart';
import '../../services/hub_service.dart';
import '../../services/site_service.dart';
import '../../services/auth_service.dart';

class EditHubDialog extends StatefulWidget {
  final dynamic hub;
  final VoidCallback onSuccess;

  const EditHubDialog({super.key, required this.hub, required this.onSuccess});

  @override
  State<EditHubDialog> createState() => _EditHubDialogState();
}

class _EditHubDialogState extends State<EditHubDialog> {
  final HubService _hubService = HubService();
  final SiteService _siteService = SiteService();
  
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController macController;
  
  int? selectedSiteId;
  List<dynamic> sites = [];
  bool _isLoadingSites = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.hub['name'] ?? "");
    macController = TextEditingController(text: widget.hub['macAddress'] ?? "");
    selectedSiteId = widget.hub['siteId'];
    _loadSites();
  }

  Future<void> _loadSites() async {
    try {
      final token = AuthService.token;
      if (token == null) return;
      
      final data = await _siteService.fetchSites(token);
      if (mounted) {
        setState(() {
          sites = data;
          _isLoadingSites = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSites = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading sites: $e")),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedSiteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a site")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = AuthService.token;
      if (token == null) return;

      final success = await _hubService.updateHub(token, widget.hub['hubId'], {
        "name": nameController.text.trim(),
        "macAddress": macController.text.trim(),
        "siteId": selectedSiteId,
      });

      if (success) {
        widget.onSuccess();
        if (mounted) Navigator.pop(context);
      } else {
        throw Exception("Failed to update hub.");
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
      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
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
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'EDIT HUB',
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
                
                _label('Site'),
                _isLoadingSites
                    ? const Center(child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ))
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F2C).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedSiteId,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1A1F2C),
                            style: const TextStyle(color: Colors.white),
                            hint: const Text("Select a Site", style: TextStyle(color: Colors.white24)),
                            items: sites.map((s) {
                              return DropdownMenuItem<int>(
                                value: s['siteId'],
                                child: Text(s['name'] ?? 'Unknown'),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => selectedSiteId = val),
                          ),
                        ),
                      ),

                _label('Hub Name'),
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('e.g., Gateway 01'),
                  validator: (v) => v == null || v.isEmpty ? "Required" : null,
                ),

                _label('MAC Address'),
                TextFormField(
                  controller: macController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('00:00:00:00:00:00'),
                  validator: (v) => v == null || v.isEmpty ? "Required" : null,
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
                            : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
