import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'mqtt_settings.dart';

const _playTopic = 'house/music/play';
const _stopTopic = 'house/music/stop';
const _stateTopic = 'house/music/state';

enum MusicConnectionStatus { disconnected, connecting, connected, failed }

class MusicState {
  const MusicState({required this.state, this.url, this.message});

  final String state;
  final String? url;
  final String? message;

  bool get isPlaying => state == 'playing';

  factory MusicState.fromJson(Map<String, dynamic> json) => MusicState(
    state: json['state'] as String? ?? 'unknown',
    url: json['url'] as String?,
    message: json['message'] as String?,
  );
}

class MqttMusicService {
  MqttMusicService(this._settings);

  final MqttSettings _settings;
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updates;
  bool _disposed = false;

  final status = ValueNotifier(MusicConnectionStatus.disconnected);
  final state = ValueNotifier(
    const MusicState(state: 'stopped', message: '尚未播放音樂'),
  );

  bool get isConfigured => _settings.host.isNotEmpty;

  Future<bool> connect() async {
    if (_disposed) return false;
    if (!isConfigured) {
      status.value = MusicConnectionStatus.failed;
      return false;
    }
    if (status.value == MusicConnectionStatus.connecting ||
        status.value == MusicConnectionStatus.connected) {
      return status.value == MusicConnectionStatus.connected;
    }

    status.value = MusicConnectionStatus.connecting;
    await _updates?.cancel();
    _updates = null;
    final clientId =
        'housecontrol-music-${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttServerClient(_settings.host, clientId)
      ..port = _settings.port
      ..keepAlivePeriod = 30
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..onConnected = _onConnected
      ..onDisconnected = _onDisconnected
      ..connectionMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean();
    _client = client;
    try {
      await connectMqttClient(client, _settings);
      if (_disposed) {
        client.disconnect();
        return false;
      }
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        status.value = MusicConnectionStatus.failed;
        client.disconnect();
        return false;
      }
      _onConnected();
      return true;
    } catch (_) {
      status.value = MusicConnectionStatus.failed;
      client.disconnect();
      return false;
    }
  }

  void _onConnected() {
    if (_disposed) return;
    status.value = MusicConnectionStatus.connected;
    _client?.subscribe(_stateTopic, MqttQos.atLeastOnce);
    _updates ??= _client?.updates?.listen((messages) {
      for (final received in messages) {
        if (_disposed) return;
        if (received.topic != _stateTopic) continue;
        try {
          final message = received.payload as MqttPublishMessage;
          final decoded = jsonDecode(
            MqttPublishPayload.bytesToStringAsString(message.payload.message),
          );
          if (decoded is Map<String, dynamic>) {
            state.value = MusicState.fromJson(decoded);
          }
        } catch (_) {
          // Ignore malformed retained state messages.
        }
      }
    });
  }

  void _onDisconnected() {
    if (_disposed) return;
    if (status.value != MusicConnectionStatus.failed) {
      status.value = MusicConnectionStatus.disconnected;
    }
  }

  Future<bool> play(String url) => _publish(_playTopic, {'url': url});

  Future<bool> stop() => _publish(_stopTopic, {});

  Future<bool> _publish(String topic, Map<String, String> value) async {
    if (!await connect()) return false;
    final client = _client;
    if (client?.connectionStatus?.state != MqttConnectionState.connected) {
      return false;
    }
    final payload = MqttClientPayloadBuilder()..addString(jsonEncode(value));
    client!.publishMessage(topic, MqttQos.atLeastOnce, payload.payload!);
    return true;
  }

  void dispose() {
    _disposed = true;
    _updates?.cancel();
    _client?.disconnect();
    status.dispose();
    state.dispose();
  }
}
