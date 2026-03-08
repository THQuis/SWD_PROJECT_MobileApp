import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/alert_service.dart';
import '../../services/sensor_service.dart';

class AddEditAlertRuleDialog extends StatefulWidget {
  final dynamic rule; // null for Create, non-null for Edit

  const AddEditAlertRuleDialog({super.key, this.rule});

  @override
  State<AddEditAlertRuleDialog> createState() => _AddEditAlertRuleDialogState();
}

class _AddEditAlertRuleDialogState extends State<AddEditAlertRuleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _alertService = AlertService();
  final _sensorService = SensorService();

  late TextEditingController _nameController;
  late TextEditingController _minValController;
  late TextEditingController _maxValController;

  int? _selectedSensorId;
  String _selectedPriority = 'High';
  String _selectedNotifyMethod = 'Email';
  String _selectedConditionType = 'MinMax';

  List<dynamic> _sensors = [];
  bool _isLoadingSensors = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rule?['name'] ?? '');
    _minValController = TextEditingController(text: widget.rule?['minVal']?.toString() ?? '');
    _maxValController = TextEditingController(text: widget.rule?['maxVal']?.toString() ?? '');
    
    if (widget.rule != null) {
      _selectedSensorId = widget.rule['sensorId'];
      _selectedPriority = widget.rule['priority'] ?? 'High';
      _selectedNotifyMethod = widget.rule['notificationMethod'] ?? 'Email';
      _selectedConditionType = widget.rule['conditionType'] ?? 'MinMax';
    }

    _loadSensors();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minValController.dispose();
    _maxValController.dispose();
    super.dispose();
  }

  Future<void> _loadSensors() async {
    try {
      final token = AuthService.token!;
      final result = await _sensorService.fetchSensors(token, pageSize: 100);
      if (mounted) {
        setState(() {
          _sensors = result['data'] ?? [];
          _isLoadingSensors = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSensors = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sensors: $e')),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSensorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a sensor')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final token = AuthService.token!;
      final data = {
        'sensorId': _selectedSensorId,
        'name': _nameController.text.trim(),
        'conditionType': _selectedConditionType,
        'minVal': double.tryParse(_minValController.text),
        'maxVal': double.tryParse(_maxValController.text),
        'notificationMethod': _selectedNotifyMethod,
        'priority': _selectedPriority,
      };

      bool success;
      if (widget.rule == null) {
        success = await _alertService.createAlertRule(token, data);
      } else {
        success = await _alertService.updateAlertRule(token, widget.rule['ruleId'], data);
      }

      if (mounted) {
        if (success) {
          Navigator.pop(context, true);
        } else {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save rule')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.rule != null;

    return Dialog(
      backgroundColor: const Color(0xFF141414),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        isEdit ? 'EDIT ALERT RULE' : 'CREATE ALERT RULE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () => Navigator.pop(context),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 20),
                const SizedBox(height: 16),
                
                _buildLabel('RULE NAME'),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('e.g. High Temp Warning'),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildLabel('TARGET SENSOR'),
                _isLoadingSensors
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(color: Colors.blueAccent),
                      )
                    : _buildSensorDropdown(),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('MIN VALUE'),
                          TextFormField(
                            controller: _minValController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('0'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('MAX VALUE'),
                          TextFormField(
                            controller: _maxValController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('100'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('PRIORITY'),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: _boxDecoration(),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: (['Low', 'Medium', 'High'].contains(_selectedPriority)) ? _selectedPriority : 'High',
                                dropdownColor: const Color(0xFF141414),
                                isExpanded: true,
                                items: ['Low', 'Medium', 'High'].map((p) {
                                  return DropdownMenuItem(
                                    value: p,
                                    child: Text(p, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedPriority = val!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('NOTIFY VIA'),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: _boxDecoration(),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: (['Email', 'SMS', 'All Channels'].contains(_selectedNotifyMethod)) ? _selectedNotifyMethod : 'Email',
                                dropdownColor: const Color(0xFF141414),
                                itemHeight: 50,
                                isExpanded: true,
                                items: ['Email', 'SMS', 'All Channels'].map((n) {
                                  return DropdownMenuItem(
                                    value: n,
                                    child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedNotifyMethod = val!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white12),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1F2C),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent))
                            : Text(isEdit ? 'UPDATE RULE' : 'CREATE RULE', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSensorDropdown() {
    final List<dynamic> uniqueSensors = [];
    final Set<int> seenSensorIds = {};
    for (var s in _sensors) {
      final idValue = s['id'];
      if (idValue == null) continue;
      final intId = idValue is int ? idValue : int.tryParse(idValue.toString());
      if (intId != null && !seenSensorIds.contains(intId)) {
        uniqueSensors.add(s);
        seenSensorIds.add(intId);
      }
    }

    final bool sensorExists = _selectedSensorId != null && seenSensorIds.contains(_selectedSensorId);
    final int? currentValue = sensorExists ? _selectedSensorId : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _boxDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: currentValue,
          dropdownColor: const Color(0xFF141414),
          hint: Text(
            uniqueSensors.isEmpty ? 'No Sensors Found - Tap to Retry' : '-- Select Sensor --', 
            style: const TextStyle(color: Colors.white38, fontSize: 13)
          ),
          isExpanded: true,
          onTap: uniqueSensors.isEmpty ? _loadSensors : null,
          items: uniqueSensors.map((s) {
            final idValue = s['id'];
            final intId = idValue is int ? idValue : int.tryParse(idValue.toString());
            return DropdownMenuItem<int>(
              value: intId,
              child: Text(
                '${s['name']} (Hub ${s['hubName'] ?? '?'})',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedSensorId = val),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      filled: true,
      fillColor: Colors.black26,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 1),
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.black26,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white10),
    );
  }
}
