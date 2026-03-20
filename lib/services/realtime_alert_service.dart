import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

const String _firebaseDatabaseUrl =
    'https://iot-realtime-project-default-rtdb.asia-southeast1.firebasedatabase.app';

FirebaseDatabase _database() => FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: _firebaseDatabaseUrl,
    );

class RealtimeHubData {
  final double temperature;
  final double humidity;
  final double pressure;
  final String updatedAt;
  final Map<String, dynamic> raw;

  RealtimeHubData({
    required this.temperature,
    required this.humidity,
    required this.pressure,
    required this.updatedAt,
    required this.raw,
  });

  factory RealtimeHubData.fromMap(Map<String, dynamic> map) {
    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    return RealtimeHubData(
      temperature: toDouble(map['temperature']),
      humidity: toDouble(map['humidity']),
      pressure: toDouble(map['pressure']),
      updatedAt:
          (map['updatedAt'] ?? map['time'] ?? DateTime.now().toIso8601String())
              .toString(),
      raw: map,
    );
  }
}

class RealtimeAlertEvent {
  final String ruleName;
  final String message;
  final String time;
  final Map<String, dynamic> raw;

  RealtimeAlertEvent({
    required this.ruleName,
    required this.message,
    required this.time,
    required this.raw,
  });

  factory RealtimeAlertEvent.fromMap(Map<String, dynamic> map) {
    return RealtimeAlertEvent(
      ruleName: (map['ruleName'] ?? map['name'] ?? 'Alert').toString(),
      message:
          (map['message'] ?? map['content'] ?? 'Realtime alert').toString(),
      time:
          (map['time'] ?? map['timestamp'] ?? DateTime.now().toIso8601String())
              .toString(),
      raw: map,
    );
  }
}

class RealtimeHubSnapshot {
  final int hubId;
  final bool isOnline;
  final double temperature;
  final double humidity;
  final double pressure;
  final String lastUpdated;
  final Map<String, dynamic> raw;

  RealtimeHubSnapshot({
    required this.hubId,
    required this.isOnline,
    required this.temperature,
    required this.humidity,
    required this.pressure,
    required this.lastUpdated,
    required this.raw,
  });

  factory RealtimeHubSnapshot.fromMap(int hubId, Map<String, dynamic> map) {
    double toDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    bool toBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final normalized = value?.toString().toLowerCase().trim() ?? '';
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }

    final dataMap = (map['Data'] ?? map['data']) is Map
        ? Map<String, dynamic>.from(map['Data'] ?? map['data'])
        : <String, dynamic>{};

    return RealtimeHubSnapshot(
      hubId: hubId,
      isOnline: toBool(map['IsOnline'] ?? map['isOnline']),
      temperature: toDouble(dataMap['temperature']),
      humidity: toDouble(dataMap['humidity']),
      pressure: toDouble(dataMap['pressure']),
      lastUpdated: (map['LastUpdated'] ??
              map['lastUpdated'] ??
              DateTime.now().toIso8601String())
          .toString(),
      raw: map,
    );
  }
}

class GlobalRealtimeAlertEvent {
  final int hubId;
  final RealtimeAlertEvent alert;

  GlobalRealtimeAlertEvent({
    required this.hubId,
    required this.alert,
  });
}

class RealtimeAlertService {
  final Map<String, StreamSubscription<DatabaseEvent>> _subscriptions = {};

  void _replaceSubscription(String key, StreamSubscription<DatabaseEvent> sub) {
    _subscriptions[key]?.cancel();
    _subscriptions[key] = sub;
  }

  void _cancelByPrefix(String prefix) {
    final keys =
        _subscriptions.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      _subscriptions[key]?.cancel();
      _subscriptions.remove(key);
    }
  }

  void listenHubData({
    required int hubId,
    required void Function(RealtimeHubData event) onChanged,
    void Function(Object error)? onError,
  }) {
    _cancelByPrefix('data:');

    final paths = <String>[
      'Hubs/$hubId/Data',
      'Hubs/$hubId/data',
      'hubs/$hubId/Data',
      'hubs/$hubId/data',
    ];

    for (final path in paths) {
      final dataRef = _database().ref(path);
      final sub = dataRef.onValue.listen(
        (event) {
          final value = event.snapshot.value;
          if (value == null) return;

          try {
            final normalized = jsonDecode(jsonEncode(value));
            if (normalized is Map<String, dynamic>) {
              onChanged(RealtimeHubData.fromMap(normalized));
            }
          } catch (_) {
            // Ignore invalid shape for one path and keep listening others.
          }
        },
        onError: (error) {
          if (onError != null) onError(error);
        },
      );
      _replaceSubscription('data:$path', sub);
    }
  }

  void listenHubAlert({
    required int hubId,
    required void Function(RealtimeAlertEvent? event) onChanged,
    void Function(Object error)? onError,
  }) {
    _cancelByPrefix('alert:');

    final paths = <String>[
      'Hubs/$hubId/Alert',
      'Hubs/$hubId/alert',
      'hubs/$hubId/Alert',
      'hubs/$hubId/alert',
    ];

    for (final path in paths) {
      final alertRef = _database().ref(path);
      final sub = alertRef.onValue.listen(
        (event) {
          final value = event.snapshot.value;
          if (value == null) {
            // Ignore null from one path; another candidate path may have data.
            return;
          }

          try {
            final normalized = jsonDecode(jsonEncode(value));
            if (normalized is Map<String, dynamic>) {
              onChanged(RealtimeAlertEvent.fromMap(normalized));
            } else {
              onChanged(
                RealtimeAlertEvent(
                  ruleName: 'Alert',
                  message: normalized.toString(),
                  time: DateTime.now().toIso8601String(),
                  raw: {'value': normalized},
                ),
              );
            }
          } catch (_) {
            onChanged(
              RealtimeAlertEvent(
                ruleName: 'Alert',
                message: value.toString(),
                time: DateTime.now().toIso8601String(),
                raw: {'value': value.toString()},
              ),
            );
          }
        },
        onError: (error) {
          if (onError != null) onError(error);
        },
      );
      _replaceSubscription('alert:$path', sub);
    }
  }

  void listenAllHubsRealtime({
    required List<int> hubIds,
    required void Function(RealtimeHubSnapshot snapshot) onChanged,
    void Function(Object error)? onError,
  }) {
    _cancelByPrefix('hubroot:');

    final uniqueIds = <int>{...hubIds}.toList()..sort();
    for (final hubId in uniqueIds) {
      final hubRef = _database().ref('Hubs/$hubId');
      final sub = hubRef.onValue.listen(
        (event) {
          final value = event.snapshot.value;
          if (value == null) return;

          try {
            final normalized = jsonDecode(jsonEncode(value));
            if (normalized is Map<String, dynamic>) {
              onChanged(RealtimeHubSnapshot.fromMap(hubId, normalized));
            }
          } catch (_) {
            // Keep listener running even if one payload is malformed.
          }
        },
        onError: (error) {
          if (onError != null) onError(error);
        },
      );
      _replaceSubscription('hubroot:$hubId', sub);
    }
  }

  void listenAllHubsAlerts({
    required List<int> hubIds,
    required void Function(GlobalRealtimeAlertEvent event) onChanged,
    void Function(Object error)? onError,
  }) {
    _cancelByPrefix('hubalert:');

    final uniqueIds = <int>{...hubIds}.toList()..sort();
    for (final hubId in uniqueIds) {
      final paths = <String>[
        'Hubs/$hubId/Alert',
        'Hubs/$hubId/alert',
        'hubs/$hubId/Alert',
        'hubs/$hubId/alert',
      ];

      for (final path in paths) {
        final alertRef = _database().ref(path);
        final sub = alertRef.onValue.listen(
          (event) {
            final value = event.snapshot.value;
            if (value == null) return;

            RealtimeAlertEvent parsed;
            try {
              final normalized = jsonDecode(jsonEncode(value));
              if (normalized is Map<String, dynamic>) {
                parsed = RealtimeAlertEvent.fromMap(normalized);
              } else {
                parsed = RealtimeAlertEvent(
                  ruleName: 'Alert',
                  message: normalized.toString(),
                  time: DateTime.now().toIso8601String(),
                  raw: {'value': normalized},
                );
              }
            } catch (_) {
              parsed = RealtimeAlertEvent(
                ruleName: 'Alert',
                message: value.toString(),
                time: DateTime.now().toIso8601String(),
                raw: {'value': value.toString()},
              );
            }

            onChanged(GlobalRealtimeAlertEvent(hubId: hubId, alert: parsed));
          },
          onError: (error) {
            if (onError != null) onError(error);
          },
        );

        _replaceSubscription('hubalert:$path', sub);
      }
    }
  }

  void dispose() {
    for (final s in _subscriptions.values) {
      s.cancel();
    }
    _subscriptions.clear();
  }
}
