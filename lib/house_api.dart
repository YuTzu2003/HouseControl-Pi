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
    this.startTime,
    this.endTime,
    this.startAction,
    this.endAction,
    this.startMode,
    this.endMode,
    this.startBrightness,
    this.endBrightness,
    this.sceneId,
    this.lastTriggeredAt,
    this.lastResult,
  });
  final int? id;
  final String name, time, action;
  final List<int> days;
  final bool enabled;
  final String? startTime, endTime, startAction, endAction, startMode, endMode;
  final double? startBrightness, endBrightness;
  final int? sceneId;
  final String? lastTriggeredAt, lastResult;
  factory AutomationRule.fromJson(Map<String, dynamic> json) => AutomationRule(
    id: json['id'] as int?,
    name: json['name'] as String,
    time:
        (json['time'] as String?) ?? (json['start_time'] as String? ?? '00:00'),
    days: (json['days'] as List).cast<int>(),
    action:
        (json['action'] as String?) ??
        (json['start_action'] as String? ?? 'off'),
    enabled: json['enabled'] as bool,
    startTime: json['start_time'] as String?,
    endTime: json['end_time'] as String?,
    startAction: json['start_action'] as String?,
    endAction: json['end_action'] as String?,
    startMode: json['start_mode'] as String?,
    endMode: json['end_mode'] as String?,
    startBrightness: (json['start_brightness'] as num?)?.toDouble(),
    endBrightness: (json['end_brightness'] as num?)?.toDouble(),
    sceneId: json['scene_id'] as int?,
    lastTriggeredAt: json['last_triggered_at'] as String?,
    lastResult: json['last_result'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'name': name,
    'time': time,
    'days': days,
    'action': action,
    'enabled': enabled,
    'start_time': startTime ?? time,
    if (endTime != null) 'end_time': endTime,
    'start_action': startAction ?? action,
    if (endAction != null) 'end_action': endAction,
    if (startMode != null) 'start_mode': startMode,
    if (endMode != null) 'end_mode': endMode,
    if (startBrightness != null) 'start_brightness': startBrightness,
    if (endBrightness != null) 'end_brightness': endBrightness,
    if (sceneId != null) 'scene_id': sceneId,
  };
}

class SceneAction {
  const SceneAction({
    required this.device,
    this.on,
    this.mode,
    this.brightness,
    this.command = 'play',
    this.url,
  });
  final String device;
  final bool? on;
  final String? mode;
  final double? brightness;
  final String command;
  final String? url;

  factory SceneAction.fromJson(Map<String, dynamic> json) => SceneAction(
    device: json['device'] as String,
    on: json['on'] as bool?,
    mode: json['mode'] as String?,
    brightness: (json['brightness'] as num?)?.toDouble(),
    command: json['command'] as String? ?? 'play',
    url: json['url'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'device': device,
    if (on != null) 'on': on,
    if (mode != null) 'mode': mode,
    if (brightness != null) 'brightness': brightness,
    'command': command,
    if (url != null && url!.isNotEmpty) 'url': url,
  };
}

class Scene {
  const Scene({
    required this.id,
    required this.name,
    required this.actions,
    required this.enabled,
    this.lastExecutedAt,
    this.lastResult,
  });
  final int? id;
  final String name;
  final List<SceneAction> actions;
  final bool enabled;
  final String? lastExecutedAt, lastResult;

  factory Scene.fromJson(Map<String, dynamic> json) => Scene(
    id: json['id'] as int?,
    name: json['name'] as String,
    actions: (json['actions'] as List)
        .whereType<Map<String, dynamic>>()
        .map(SceneAction.fromJson)
        .toList(),
    enabled: json['enabled'] as bool? ?? true,
    lastExecutedAt: json['last_executed_at'] as String?,
    lastResult: json['last_result'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'actions': actions.map((action) => action.toJson()).toList(),
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

  Future<bool> deleteAutomation(int id) => _delete('/automations/$id');

  Future<List<Scene>> scenes() async {
    final decoded = await _requestJson('/scenes');
    return decoded is List
        ? decoded.whereType<Map<String, dynamic>>().map(Scene.fromJson).toList()
        : [];
  }

  Future<bool> saveScene(Scene scene) => _saveJson(
    scene.id == null ? 'POST' : 'PUT',
    scene.id == null ? '/scenes' : '/scenes/${scene.id}',
    scene.toJson(),
  );

  Future<bool> deleteScene(int id) => _delete('/scenes/$id');

  Future<dynamic> _requestJson(String path) async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(
        Uri.parse('http://${_settings.host}:8000$path'),
      )).close().timeout(const Duration(seconds: 4));
      if (response.statusCode != HttpStatus.ok) return null;
      return jsonDecode(await response.transform(utf8.decoder).join());
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _saveJson(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(
        method,
        Uri.parse('http://${_settings.host}:8000$path'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
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

  Future<bool> _delete(String path) async {
    final client = HttpClient();
    try {
      final response = await (await client.deleteUrl(
        Uri.parse('http://${_settings.host}:8000$path'),
      )).close().timeout(const Duration(seconds: 4));
      return response.statusCode == HttpStatus.noContent;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
