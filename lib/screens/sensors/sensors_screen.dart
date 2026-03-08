import 'package:flutter/material.dart';
import 'add_sensor_dialog.dart';
import '../../services/sensor_service.dart';
import '../../services/auth_service.dart';
import '../../services/hub_service.dart';
import '../../services/site_service.dart';
import '../../widgets/app_drawer.dart';

class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key});

  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen> {
  final SensorService _sensorService = SensorService();
  final SiteService _siteService = SiteService();

  List<dynamic> sensors = [];
  List<dynamic> sites = [];
  List<dynamic> types = [];

  bool isLoading = true;
  String? errorMessage;

  // Pagination & Filtering state
  int currentPage = 1;
  int pageSize = 7;
  int totalCount = 0;
  int totalPages = 1;
  int? selectedSiteId;
  int? selectedTypeId;

  // Stats
  int totalSensorsCount = 0;
  int onlineCount = 0;
  int offlineCount = 0;

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    await Future.wait([
      _loadFilters(),
      _loadStats(),
      _loadSensors(),
    ]);
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _loadFilters() async {
    final token = AuthService.token;
    if (token == null) return;
    try {
      final fetchedSites = await _siteService.fetchSites(token);
      final fetchedTypes = await _sensorService.fetchSensorTypes(token);
      if (mounted) {
        setState(() {
          sites = fetchedSites;
          types = fetchedTypes;
        });
      }
    } catch (e) {
      debugPrint('Error loading filters: $e');
    }
  }

  Future<void> _loadStats() async {
    final token = AuthService.token;
    if (token == null) return;
    try {
      final results = await Future.wait([
        _sensorService.fetchSensors(token, pageSize: 1),
        _sensorService.fetchSensors(token, status: 'Active', pageSize: 1),
        _sensorService.fetchSensors(token, status: 'Inactive', pageSize: 1),
      ]);

      if (mounted) {
        setState(() {
          totalSensorsCount = results[0]['totalCount'] ?? 0;
          onlineCount = results[1]['totalCount'] ?? 0;
          offlineCount = results[2]['totalCount'] ?? 0;
          
          if (totalSensorsCount > 0 && offlineCount == 0 && onlineCount < totalSensorsCount) {
             offlineCount = totalSensorsCount - onlineCount;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _loadSensors() async {
    if (!mounted) return;
    setState(() {
      errorMessage = null;
    });

    try {
      final token = AuthService.token;
      if (token == null) {
        setState(() => errorMessage = 'Chưa đăng nhập');
        return;
      }

      final result = await _sensorService.fetchSensors(
        token,
        siteId: selectedSiteId,
        typeId: selectedTypeId,
        pageNumber: currentPage,
        pageSize: pageSize,
      );

      if (mounted) {
        setState(() {
          sensors = result['data'];
          totalCount = result['totalCount'];
          totalPages = result['totalPages'] == 0 ? 1 : result['totalPages'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => errorMessage = e.toString());
      }
    }
  }

  Future<void> _deleteSensor(int id) async {
    final token = AuthService.token;
    if (token == null) return;

    try {
      final success = await _sensorService.deleteSensor(token, id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa cảm biến thành công')),
        );
        _initialLoad();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  void _openAddSensor() {
    showDialog(
      context: context,
      builder: (_) => AddSensorDialog(
        onSuccess: () => _initialLoad(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Colors
    const Color bgColor = Color(0xFF121212);
    const Color cardColor = Color(0xFF1E1E1E);
    const Color borderColor = Color(0xFF2C2C2C);

    return Scaffold(
      backgroundColor: bgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Sensors Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          currentPage = 1;
          await _initialLoad();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 24),
              _summaryCards(cardColor, borderColor),
              const SizedBox(height: 24),
              _filterSection(cardColor, borderColor),
              const SizedBox(height: 24),
              if (isLoading && sensors.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  ),
                )
              else if (errorMessage != null)
                _errorView()
              else if (sensors.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: Text('Không tìm thấy cảm biến nào',
                        style: TextStyle(color: Colors.white70)),
                  ),
                )
              else ...[
                _sensorList(cardColor, borderColor),
                const SizedBox(height: 20),
                _paginationControls(),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IoT Sensors',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Real-time environmental statistics.',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _openAddSensor,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCards(Color cardColor, Color borderColor) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            Icons.sensors,
            'TOTAL',
            totalSensorsCount.toString(),
            Colors.blueAccent,
            cardColor,
            borderColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            Icons.check_circle,
            'ONLINE',
            onlineCount.toString(),
            Colors.greenAccent,
            cardColor,
            borderColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            Icons.error,
            'OFFLINE',
            offlineCount.toString(),
            Colors.redAccent,
            cardColor,
            borderColor,
          ),
        ),
      ],
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color, Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _filterSection(Color cardColor, Color borderColor) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _filterDropdown<int>(
          hint: 'Sites',
          value: selectedSiteId,
          items: sites.map((s) => DropdownMenuItem<int>(
            value: s['siteId'],
            child: Text(s['name'] ?? 'Site ${s['siteId']}', style: const TextStyle(color: Colors.white)),
          )).toList(),
          onChanged: (val) {
            setState(() {
              selectedSiteId = val;
              currentPage = 1;
              isLoading = true;
            });
            _loadSensors().then((_) {
              if (mounted) setState(() => isLoading = false);
            });
          },
          cardColor: cardColor,
          borderColor: borderColor,
        ),
        _filterDropdown<int>(
          hint: 'Types',
          value: selectedTypeId,
          items: types.map((t) => DropdownMenuItem<int>(
            value: t['typeId'],
            child: Text(t['typeName'] ?? 'Type ${t['typeId']}', style: const TextStyle(color: Colors.white)),
          )).toList(),
          onChanged: (val) {
            setState(() {
              selectedTypeId = val;
              currentPage = 1;
              isLoading = true;
            });
            _loadSensors().then((_) {
              if (mounted) setState(() => isLoading = false);
            });
          },
          cardColor: cardColor,
          borderColor: borderColor,
        ),
        _refreshButton(borderColor),
      ],
    );
  }

  Widget _filterDropdown<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required Color cardColor,
    required Color borderColor,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          dropdownColor: cardColor,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white38),
          items: [
            DropdownMenuItem<T>(
              value: null,
              child: Text('All $hint', style: const TextStyle(color: Colors.white)),
            ),
            ...items,
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _refreshButton(Color borderColor) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () {
          currentPage = 1;
          _initialLoad();
        },
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Refresh'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _sensorList(Color cardColor, Color borderColor) {
    return Column(
      children: sensors.map((s) {
        final status = s['status'] as String?;
        final color = _statusColor(status);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.sensors, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s['sensorName'] ?? 'Unnamed',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s['typeName'] ?? 'Type'} • ${s['hubName'] ?? 'Hub'}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (status ?? 'OFFLINE').toUpperCase(),
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz, color: Colors.white38),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (val) {
                      if (val == 'delete') _showDeleteConfirm(s['sensorId']);
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                      const PopupMenuItem(value: 'delete', child: Text('Xóa', style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _paginationControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: currentPage > 1 ? () {
            setState(() {
              currentPage--;
              isLoading = true;
            });
            _loadSensors().then((_) {
              if (mounted) setState(() => isLoading = false);
            });
          } : null,
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: Colors.white,
          disabledColor: Colors.white10,
        ),
        const SizedBox(width: 16),
        Text(
          'Page $currentPage of $totalPages',
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: currentPage < totalPages ? () {
            setState(() {
              currentPage++;
              isLoading = true;
            });
            _loadSensors().then((_) {
              if (mounted) setState(() => isLoading = false);
            });
          } : null,
          icon: const Icon(Icons.arrow_forward_ios, size: 18),
          color: Colors.white,
          disabledColor: Colors.white10,
        ),
      ],
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 16),
            Text(errorMessage!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _initialLoad,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status.toLowerCase()) {
      case 'active': return Colors.greenAccent;
      case 'inactive': return Colors.redAccent;
      case 'warning': return Colors.orangeAccent;
      case 'critical': return Colors.redAccent;
      default: return Colors.greenAccent;
    }
  }

  void _showDeleteConfirm(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Confirm Delete', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this sensor?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSensor(id);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
