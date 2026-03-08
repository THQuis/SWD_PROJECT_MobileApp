import 'package:flutter/material.dart';
import '../../services/sensor_service.dart';
import '../../services/hub_service.dart';
import '../../services/auth_service.dart';

class AddSensorDialog extends StatefulWidget {
  final VoidCallback onSuccess;

  const AddSensorDialog({super.key, required this.onSuccess});

  @override
  State<AddSensorDialog> createState() => _AddSensorDialogState();
}

class _AddSensorDialogState extends State<AddSensorDialog> {
  final SensorService _sensorService = SensorService();
  final HubService _hubService = HubService();
  final TextEditingController nameCtrl = TextEditingController();

  List<dynamic> hubs = [];
  List<dynamic> types = [];
  int? selectedHubId;
  int? selectedTypeId;
  bool isLoadingData = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final token = AuthService.token;
      if (token == null) return;

      final fetchedHubs = await _hubService.fetchHubs(token);
      final fetchedTypes = await _sensorService.fetchSensorTypes(token);

      setState(() {
        hubs = fetchedHubs;
        types = fetchedTypes;
        if (hubs.isNotEmpty) selectedHubId = hubs[0]['hubId'];
        if (types.isNotEmpty) selectedTypeId = types[0]['typeId'];
        isLoadingData = false;
      });
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      setState(() => isLoadingData = false);
    }
  }

  Future<void> _handleRegister() async {
    if (nameCtrl.text.trim().isEmpty ||
        selectedHubId == null ||
        selectedTypeId == null) return;

    setState(() => isSubmitting = true);

    try {
      final token = AuthService.token;
      if (token == null) return;

      final success = await _sensorService.addSensor(token, {
        'name': nameCtrl.text.trim(),
        'hubId': selectedHubId,
        'typeId': selectedTypeId,
      });

      if (success) {
        widget.onSuccess();
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: isLoadingData
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()))
            : LayoutBuilder(
                builder: (context, constraints) {
                  final bool isMobile = constraints.maxWidth < 500;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// ===== HEADER =====
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ĐĂNG KÝ CẢM BIẾN',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.8,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      /// ===== SENSOR NAME =====
                      const Text(
                        'TÊN CẢM BIẾN',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameCtrl,
                        onChanged: (v) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'VD: TEMP-OUTDOOR-01',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),

                      const SizedBox(height: 16),

                      /// ===== HUB + TYPE =====
                      isMobile
                          ? Column(
                              children: [
                                _hubField(),
                                const SizedBox(height: 12),
                                _typeField(),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: _hubField()),
                                const SizedBox(width: 12),
                                Expanded(child: _typeField()),
                              ],
                            ),

                      const SizedBox(height: 24),

                      /// ===== ACTIONS =====
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('HỦY'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (nameCtrl.text.trim().isEmpty ||
                                      isSubmitting)
                                  ? null
                                  : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Text(
                                      'ĐĂNG KÝ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  /// ===== HUB FIELD =====
  Widget _hubField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HUB',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          value: selectedHubId,
          isExpanded: true,
          items: hubs.map((h) {
            return DropdownMenuItem<int>(
              value: h['hubId'],
              child: Text(h['name'] ?? h['hubId'].toString()),
            );
          }).toList(),
          onChanged: (v) => setState(() => selectedHubId = v),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  /// ===== TYPE FIELD =====
  Widget _typeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LOẠI',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          value: selectedTypeId,
          isExpanded: true,
          items: types.map((t) {
            return DropdownMenuItem<int>(
              value: t['typeId'],
              child: Text(t['typeName'] ?? t['typeId'].toString()),
            );
          }).toList(),
          onChanged: (v) => setState(() => selectedTypeId = v),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
