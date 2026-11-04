import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'mqtt_settings.dart';

const _executeTopic = 'house/scene/execute';
const _resultTopic = 'house/scene/result';

class SceneExecutionResult {
  const SceneExecutionResult({
    required this.ok,
    this.error,
    this.results = const [],
  });

  final bool ok;
  final String? error;
  final List<Map<String, dynamic>> results;

  factory SceneExecutionResult.fromJson(Map<String, dynamic> json) =>
      SceneExecutionResult(
        ok: json['ok'] == true,
        error: json['error'] as String?,
        results: (json['results'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList(),
      );
}

class MqttSceneService {
  MqttSceneService(this._settings);
  final MqttSettings _settings;

  Future<SceneExecutionResult?> execute(int sceneId) async {
    final requestId = 'app-${DateTime.now().microsecondsSinceEpoch}';
    final client =
        MqttServerClient(
            _settings.host,
            'housecontrol-scene-${DateTime.now().millisecondsSinceEpoch}',
          )
          ..port = _settings.port
          ..keepAlivePeriod = 20
          ..connectionMessage = MqttConnectMessage().startClean();
    final completer = Completer<SceneExecutionResult?>();
    StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? updates;
    try {
      await connectMqttClient(client, _settings);
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        return null;
      }
      client.subscribe(_resultTopic, MqttQos.atLeastOnce);
      updates = client.updates?.listen((messages) {
        for (final received in messages) {
          if (received.topic != _resultTopic) continue;
          try {
            final message = received.payload as MqttPublishMessage;
            final decoded = jsonDecode(
              MqttPublishPayload.bytesToStringAsString(message.payload.message),
            );
            if (decoded is Map<String, dynamic> &&
                decoded['request_id'] == requestId &&
                !completer.isCompleted) {
              completer.complete(SceneExecutionResult.fromJson(decoded));
            }
          } catch (_) {
            // Ignore malformed results from other publishers.
          }
        }
      });
      final payload = MqttClientPayloadBuilder()
        ..addString(jsonEncode({'scene_id': sceneId, 'request_id': requestId}));
      client.publishMessage(
        _executeTopic,
        MqttQos.atLeastOnce,
        payload.payload!,
      );
      return await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => null,
      );
    } catch (_) {
      return null;
    } finally {
      await updates?.cancel();
      client.disconnect();
    }
  }
}
