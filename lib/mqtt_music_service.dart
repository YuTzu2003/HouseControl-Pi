import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'mqtt_settings.dart';

class MqttMusicService {
  MqttMusicService(this._settings);

  final MqttSettings _settings;

  Future<bool> play(String url) => _publish('house/music/play', {'url': url});
  Future<bool> stop() => _publish('house/music/stop', {});

  Future<bool> _publish(String topic, Map<String, String> value) async {
    final clientId =
        'housecontrol-music-${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttServerClient(_settings.host, clientId)
      ..port = _settings.port
      ..keepAlivePeriod = 20
      ..connectionMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean();
    try {
      await client.connect(_settings.username, _settings.password);
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        return false;
      }
      final payload = MqttClientPayloadBuilder()..addString(jsonEncode(value));
      client.publishMessage(topic, MqttQos.atLeastOnce, payload.payload!);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return true;
    } catch (_) {
      return false;
    } finally {
      client.disconnect();
    }
  }
}
