import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'mqtt_settings.dart';

const _topicSet = 'house/room/light/set';
const _topicState = 'house/room/light/state';

enum LightConnectionStatus {
  unconfigured,
  connecting,
  connected,
  disconnected,
  failed,
}

class LightState {
  const LightState({
    required this.on,
    required this.mode,
    required this.brightness,
  });

  final bool on;
  final String mode;
  final double brightness;

  factory LightState.fromJson(Map<String, dynamic> json) {
    final brightness = json['brightness'];
    return LightState(
      on: json['on'] is bool ? json['on'] as bool : false,
      mode: json['mode'] is String ? json['mode'] as String : 'warm_white',
      brightness: brightness is num
          ? brightness.toDouble().clamp(0, 100).toDouble()
          : 100,
    );
  }
}

class MqttLightService {
  MqttLightService(this._settings);

  final MqttSettings _settings;
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updatesSubscription;

  final status = ValueNotifier(LightConnectionStatus.disconnected);
  final lightState = ValueNotifier(
    const LightState(on: false, mode: 'warm_white', brightness: 100),
  );

  bool get isConfigured =>
      _settings.host.isNotEmpty &&
      _settings.username.isNotEmpty &&
      _settings.password.isNotEmpty;

  Future<void> connect() async {
    if (!isConfigured) {
      status.value = LightConnectionStatus.unconfigured;
      return;
    }
    if (status.value == LightConnectionStatus.connecting ||
        status.value == LightConnectionStatus.connected) {
      return;
    }

    status.value = LightConnectionStatus.connecting;
    await _updatesSubscription?.cancel();
    _updatesSubscription = null;
    final clientId = 'housecontrol-${DateTime.now().millisecondsSinceEpoch}';
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
      await client.connect(_settings.username, _settings.password);
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        status.value = LightConnectionStatus.failed;
        client.disconnect();
      }
    } catch (_) {
      status.value = LightConnectionStatus.failed;
      client.disconnect();
    }
  }

  void _onConnected() {
    status.value = LightConnectionStatus.connected;
    _client?.subscribe(_topicState, MqttQos.atLeastOnce);
    _updatesSubscription ??= _client?.updates?.listen((events) {
      if (events.isEmpty || events.first.topic != _topicState) return;
      final message = events.first.payload as MqttPublishMessage;
      try {
        final decoded = jsonDecode(
          MqttPublishPayload.bytesToStringAsString(message.payload.message),
        );
        if (decoded is Map<String, dynamic>) {
          lightState.value = LightState.fromJson(decoded);
        }
      } catch (_) {
        // Ignore malformed messages from other MQTT publishers.
      }
    });
  }

  void _onDisconnected() {
    if (status.value != LightConnectionStatus.failed) {
      status.value = LightConnectionStatus.disconnected;
    }
  }

  void setLight({bool? on, String? mode, double? brightness}) {
    final client = _client;
    if (client?.connectionStatus?.state != MqttConnectionState.connected) return;
    final current = lightState.value;
    lightState.value = LightState(
      on: on ?? current.on,
      mode: mode ?? current.mode,
      brightness: brightness ?? current.brightness,
    );
    final command = <String, dynamic>{
      if (on != null) 'on': on,
      if (mode != null) 'mode': mode,
      if (brightness != null) 'brightness': brightness.round(),
    };
    if (command.isEmpty) return;
    final builder = MqttClientPayloadBuilder()..addString(jsonEncode(command));
    client!.publishMessage(_topicSet, MqttQos.atLeastOnce, builder.payload!);
  }

  void previewBrightness(double brightness) {
    final current = lightState.value;
    lightState.value = LightState(
      on: current.on,
      mode: current.mode,
      brightness: brightness.clamp(0, 100).toDouble(),
    );
  }

  void dispose() {
    _updatesSubscription?.cancel();
    _client?.disconnect();
    status.dispose();
    lightState.dispose();
  }
}
