import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/dashboard_service.dart';
import '../services/auth_service.dart';
import '../services/hub_service.dart';
import '../services/realtime_alert_service.dart';

class _ReadingPoint {
  final DateTime time;
  final double value;

  _ReadingPoint({required this.time, required this.value});
}

class HistoryChartWidget extends StatefulWidget {
  final int? fixedHubId;
  final bool allowHubSelection;
  final int realtimeRefreshTick;

  const HistoryChartWidget({
    super.key,
    this.fixedHubId,
    this.allowHubSelection = true,
    this.realtimeRefreshTick = 0,
  });

  @override
  State<HistoryChartWidget> createState() => _HistoryChartWidgetState();
}

class _HistoryChartWidgetState extends State<HistoryChartWidget> {
  final DashboardService _service = DashboardService();
  final HubService _hubService = HubService();
  final RealtimeAlertService _realtimeService = RealtimeAlertService();

  List<dynamic> hubs = [];
  int? selectedHubId;
  List<dynamic> historySensors = [];
  int? selectedSensorId;

  DateTime fromDate = DateTime.now().subtract(const Duration(days: 1));
  DateTime toDate = DateTime.now();
  List<FlSpot> spots = [];
  List<_ReadingPoint> _selectedReadings = [];
  String? _selectedMetric;
  bool isLoading = false;
  bool hubsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHubs();
  }

  @override
  void dispose() {
    _realtimeService.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HistoryChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fixedHubId != null && widget.fixedHubId != selectedHubId) {
      setState(() {
        selectedHubId = widget.fixedHubId;
        historySensors = [];
        spots = [];
        _selectedReadings = [];
        _selectedMetric = null;
      });
      _startRealtimeForHub(selectedHubId);
      loadChart();
      return;
    }

    if (widget.realtimeRefreshTick != oldWidget.realtimeRefreshTick &&
        selectedHubId != null &&
        !isLoading) {
      loadChart();
    }
  }

  Future<void> _loadHubs() async {
    if (AuthService.token == null) return;
    try {
      final data = await _hubService.fetchHubs(AuthService.token!);

      int? nextHubId = widget.fixedHubId;
      if (nextHubId == null && data.isNotEmpty) {
        final firstHub = data[0];
        nextHubId = (firstHub['hubId'] ??
            firstHub['id'] ??
            firstHub['Id'] ??
            firstHub['ID'] ??
            firstHub['hub_id']);
      }

      setState(() {
        hubs = data;
        selectedHubId = nextHubId is int
            ? nextHubId
            : int.tryParse(nextHubId?.toString() ?? '');
        hubsLoading = false;
      });
      _startRealtimeForHub(selectedHubId);
      if (selectedHubId != null) loadChart();
    } catch (e) {
      debugPrint("Hubs load error: $e");
      setState(() => hubsLoading = false);
    }
  }

  void _startRealtimeForHub(int? hubId) {
    if (hubId == null) {
      _realtimeService.dispose();
      return;
    }

    _realtimeService.listenHubData(
      hubId: hubId,
      onChanged: (event) {
        if (!mounted || _selectedMetric == null) return;

        double nextValue;
        switch (_selectedMetric) {
          case 'temperature':
            nextValue = event.temperature;
            break;
          case 'humidity':
            nextValue = event.humidity;
            break;
          case 'pressure':
            nextValue = event.pressure;
            break;
          default:
            return;
        }

        final nextTime = DateTime.tryParse(event.updatedAt) ?? DateTime.now();

        if (_selectedReadings.isNotEmpty) {
          final last = _selectedReadings.last;
          if (last.time.isAtSameMomentAs(nextTime) &&
              (last.value - nextValue).abs() < 0.0001) {
            return;
          }
        }

        setState(() {
          _selectedReadings
              .add(_ReadingPoint(time: nextTime, value: nextValue));
          if (_selectedReadings.length > 100) {
            _selectedReadings.removeAt(0);
          }
          _rebuildSpots();
        });
      },
      onError: (error) {
        debugPrint('History realtime error: $error');
      },
    );
  }

  DateTime? _parseReadingTime(dynamic reading) {
    final timeStr = reading["recordedAt"] ??
        reading["time"] ??
        reading["timestamp"] ??
        reading["updatedAt"];
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr.toString());
  }

  double? _extractReadingValue(dynamic reading) {
    dynamic raw =
        reading['value'] ?? reading['v1'] ?? reading['v2'] ?? reading['v3'];
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString());
  }

  String _resolveMetricFromSensor(dynamic sensor) {
    final typeName =
        (sensor['typeName'] ?? sensor['name'] ?? sensor['sensorName'] ?? '')
            .toString()
            .toLowerCase();

    if (typeName.contains('temp') ||
        typeName.contains('nhiệt') ||
        typeName.contains('nhiet')) {
      return 'temperature';
    }
    if (typeName.contains('humid') ||
        typeName.contains('độ ẩm') ||
        typeName.contains('do am')) {
      return 'humidity';
    }
    if (typeName.contains('press') ||
        typeName.contains('áp suất') ||
        typeName.contains('ap suat')) {
      return 'pressure';
    }

    // Fallback for unknown sensor naming.
    return 'temperature';
  }

  void _rebuildSpots() {
    if (_selectedReadings.isEmpty) {
      spots = [];
      return;
    }

    final sorted = List<_ReadingPoint>.from(_selectedReadings)
      ..sort((a, b) => a.time.compareTo(b.time));

    final deduped = <_ReadingPoint>[];
    for (final p in sorted) {
      if (deduped.isEmpty) {
        deduped.add(p);
        continue;
      }

      final last = deduped.last;
      final diffMs = p.time.difference(last.time).inMilliseconds.abs();

      // Keep only one point for very close timestamps to avoid vertical spikes.
      if (diffMs < 1000) {
        deduped[deduped.length - 1] = p;
      } else {
        deduped.add(p);
      }
    }

    final minTime = deduped.first.time;
    spots = deduped
        .map(
          (p) => FlSpot(
            p.time.difference(minTime).inMilliseconds / 60000,
            p.value,
          ),
        )
        .toList();
  }

  Future<void> loadChart() async {
    if (AuthService.token == null || selectedHubId == null) return;
    setState(() => isLoading = true);

    try {
      final token = AuthService.token!;
      final String from =
          "${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')} 00:00:00";
      final String to =
          "${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')} 23:59:59";

      final dynamic responseData =
          await _service.getHistory(token, selectedHubId!, from, to);

      final List<dynamic> sensorData = (responseData is List)
          ? responseData
          : (responseData is Map && responseData['sensors'] is List
              ? responseData['sensors']
              : (responseData is Map && responseData['data'] is List
                  ? responseData['data']
                  : []));

      setState(() {
        historySensors = sensorData;
      });

      if (sensorData.isNotEmpty) {
        // Auto select first sensor if none selected or not in new data
        if (selectedSensorId == null ||
            !sensorData
                .any((s) => (s['sensorId'] ?? s['id']) == selectedSensorId)) {
          _processSensorData(sensorData[0]);
        } else {
          final s = sensorData.firstWhere(
              (s) => (s['sensorId'] ?? s['id']) == selectedSensorId);
          _processSensorData(s);
        }
      } else {
        setState(() => spots = []);
      }
    } catch (e) {
      debugPrint("Chart error: $e");
    }

    setState(() => isLoading = false);
  }

  void _processSensorData(dynamic sensor) {
    final readingsRaw = sensor["readings"] ??
        sensor["reading_history"] ??
        sensor["history"] ??
        [];

    if ((readingsRaw as List).isEmpty) {
      setState(() {
        spots = [];
        selectedSensorId = sensor['sensorId'] ?? sensor['id'];
      });
      return;
    }

    final readings = readingsRaw
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);

    final apiPoints = <_ReadingPoint>[];
    for (final reading in readings) {
      final time = _parseReadingTime(reading);
      final value = _extractReadingValue(reading);
      if (time == null || value == null) continue;
      apiPoints.add(_ReadingPoint(time: time, value: value));
    }

    apiPoints.sort((a, b) => a.time.compareTo(b.time));

    final metric = _resolveMetricFromSensor(sensor);

    setState(() {
      _selectedMetric = metric;
      _selectedReadings = apiPoints;
      _rebuildSpots();
      selectedSensorId = sensor['sensorId'] ?? sensor['id'];
      isLoading = false;
    });
  }

  Widget _buildChart() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (spots.isEmpty)
      return Center(
          child: Text(
              selectedHubId == null
                  ? "No Hub Selected"
                  : "No data found for this range",
              style: const TextStyle(color: Colors.white38, fontSize: 13)));

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withOpacity(0.05),
            strokeWidth: 1,
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false, // Web looks angular/pointy
            color: const Color(0xFF1791cf),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1791cf).withOpacity(0.3),
                  const Color(0xFF1791cf).withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.blueGrey.withOpacity(0.8),
          ),
        ),
      ),
    );
  }

  Future<void> pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate : toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
          // Ensure toDate is at least fromDate
          if (toDate.isBefore(fromDate)) {
            toDate = fromDate;
          }
        } else {
          toDate = picked;
          // Ensure fromDate is at most toDate
          if (fromDate.isAfter(toDate)) {
            fromDate = toDate;
          }
        }
      });
      loadChart();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (hubsLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Historical Readings",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            if (widget.allowHubSelection &&
                widget.fixedHubId == null &&
                hubs.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<int>(
                  value: selectedHubId,
                  dropdownColor: const Color(0xFF1A1A1A),
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  items: hubs.map((h) {
                    final id = (h['hubId'] ??
                        h['id'] ??
                        h['Id'] ??
                        h['ID'] ??
                        h['hub_id']);
                    return DropdownMenuItem<int>(
                      value: id is int ? id : int.parse(id.toString()),
                      child: Text(h['name'] ?? 'Hub $id'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedHubId = val;
                      historySensors = [];
                      spots = [];
                      _selectedReadings = [];
                      _selectedMetric = null;
                    });
                    _startRealtimeForHub(val);
                    loadChart();
                  },
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        /// DATE PICKER
        Row(
          children: [
            Expanded(
              child: _dateTile(
                label: "From",
                date: fromDate,
                onTap: () => pickDate(true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _dateTile(
                label: "To",
                date: toDate,
                onTap: () => pickDate(false),
              ),
            ),
            const SizedBox(width: 12),
            _loadButton(),
          ],
        ),

        const SizedBox(height: 16),

        /// SENSOR LIST (returned from API)
        if (historySensors.isNotEmpty)
          Container(
            height: 45,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: historySensors.length,
              itemBuilder: (context, index) {
                final s = historySensors[index];
                final id = s['sensorId'] ?? s['id'];
                final isSelected = selectedSensorId == id;
                return GestureDetector(
                  onTap: () {
                    setState(() => selectedSensorId = id);
                    _processSensorData(s);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blueAccent
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              isSelected ? Colors.blueAccent : Colors.white10),
                    ),
                    child: Center(
                      child: Text(
                        (s['typeName'] ?? s['name'] ?? 'Sensor')
                            .toString()
                            .toUpperCase(),
                        style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        /// CHART
        Container(
          height: 250,
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : (spots.isEmpty
                  ? Center(
                      child: Text(
                        selectedHubId == null
                            ? "No Hub Selected"
                            : "No data found for this range",
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 13),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: Colors.blueAccent,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.blueAccent.withOpacity(0.3),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    )),
        )
      ],
    );
  }

  Widget _dateTile(
      {required String label,
      required DateTime date,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadButton() {
    return ElevatedButton(
      onPressed: loadChart,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: const Icon(Icons.refresh, size: 20),
    );
  }
}
