import 'dart:convert';
import 'dart:io';

import 'mqtt_settings.dart';

class SensorReading {
  const SensorReading({
    required this.temperature,
    required this.humidity,
    required this.recordedAt,
  });
  final double temperature, humidity;
  final String recordedAt;

  factory SensorReading.fromJson(Map<String, dynamic> json) => SensorReading(
    temperature: (json['temperature'] as num).toDouble(),
    humidity: (json['humidity'] as num).toDouble(),
    recordedAt: json['recorded_at'] as String,
  );
}

class CameraRecording {
  const CameraRecording({
    required this.name,
    required this.recordedAt,
    required this.size,
  });

  final String name;
  final String recordedAt;
  final int size;

  factory CameraRecording.fromJson(Map<String, dynamic> json) =>
      CameraRecording(
        name: json['name'] as String,
        recordedAt: json['recorded_at'] as String,
        size: (json['size'] as num).toInt(),
      );
}

class AutomationRule {
  const AutomationRule({
    required this.id,
    required this.name,
    required this.time,
    required this.days,
    required this.action,
    required this.enabled,
  });
  final int? id;
  final String name, time, action;
  final List<int> days;
  final bool enabled;
  factory AutomationRule.fromJson(Map<String, dynamic> json) => AutomationRule(
    id: json['id'] as int?,
    name: json['name'] as String,
    time: json['time'] as String,
    days: (json['days'] as List).cast<int>(),
    action: json['action'] as String,
    enabled: json['enabled'] as bool,
  );
  Map<String, dynamic> toJson() => {
    'name': name,
    'time': time,
    'days': days,
    'action': action,
    'enabled': enabled,
  };
}

class HouseApi {
  const HouseApi(this._settings);
  final MqttSettings _settings;

  Future<List<SensorReading>> sensorHistory({int limit = 48}) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('http://${_settings.host}:8000/dht11/readings?limit=$limit'),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 4),
      );
      if (response.statusCode != HttpStatus.ok) return [];
      final decoded = jsonDecode(await response.transform(utf8.decoder).join());
      return decoded is List
          ? decoded
                .whereType<Map<String, dynamic>>()
                .map(SensorReading.fromJson)
                .toList()
          : [];
    } catch (_) {
      return [];
    } finally {
      client.close(force: true);
    }
  }

  Future<List<CameraRecording>> cameraRecordings() async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(
        Uri.parse('http://${_settings.host}:8000/camera/recordings'),
      )).close().timeout(const Duration(seconds: 4));
      if (response.statusCode != HttpStatus.ok) return [];
      final decoded = jsonDecode(await response.transform(utf8.decoder).join());
      return (decoded as List)
          .whereType<Map<String, dynamic>>()
          .map(CameraRecording.fromJson)
          .toList();
    } catch (_) {
      return [];
    } finally {
      client.close(force: true);
    }
  }

  Uri recordingUrl(String name) =>
      Uri.parse('http://${_settings.host}:8000/camera/recordings/$name');

  Future<List<AutomationRule>> automations() async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(
        Uri.parse('http://${_settings.host}:8000/automations'),
      )).close().timeout(const Duration(seconds: 4));
      if (response.statusCode != HttpStatus.ok) return [];
      final decoded = jsonDecode(await response.transform(utf8.decoder).join());
      return (decoded as List)
          .whereType<Map<String, dynamic>>()
          .map(AutomationRule.fromJson)
          .toList();
    } catch (_) {
      return [];
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> saveAutomation(AutomationRule rule) async {
    final client = HttpClient();
    try {
      final path = rule.id == null ? '/automations' : '/automations/${rule.id}';
      final request = await client.openUrl(
        rule.id == null ? 'POST' : 'PUT',
        Uri.parse('http://${_settings.host}:8000$path'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(rule.toJson()));
      final response = await request.close().timeout(
        const Duration(seconds: 4),
      );
      return response.statusCode == HttpStatus.ok;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
