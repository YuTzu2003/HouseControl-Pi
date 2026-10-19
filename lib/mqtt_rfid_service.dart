import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'mqtt_settings.dart';

const _bindTopic = 'house/rfid/bind';
const _eventTopic = 'house/rfid/event';

class RfidEvent {
  const RfidEvent({required this.type, this.memberId, this.memberName, this.uid});
  final String type;
  final String? memberId, memberName, uid;

  factory RfidEvent.fromJson(Map<String, dynamic> json) => RfidEvent(
    type: json['type'] as String? ?? 'error',
    memberId: json['member_id'] as String?,
    memberName: json['member_name'] as String?,
    uid: json['uid'] as String?,
  );
}

class MqttRfidService {
  MqttRfidService(this._settings);
  final MqttSettings _settings;
  final event = ValueNotifier<RfidEvent?>(null);
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updates;

  Future<bool> connect() async {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) return true;
    final clientId = 'housecontrol-rfid-${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttServerClient(_settings.host, clientId);
    client
      ..port = _settings.port
      ..keepAlivePeriod = 30
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..onConnected = _onConnected
      ..connectionMessage = MqttConnectMessage().withClientIdentifier(clientId).startClean();
    _client = client;
    try {
      await client.connect(_settings.username, _settings.password);
      if (client.connectionStatus?.state != MqttConnectionState.connected) return false;
      _updates ??= client.updates?.listen((messages) {
        for (final received in messages) {
          if (received.topic != _eventTopic) continue;
          try {
            final message = received.payload as MqttPublishMessage;
            final data = jsonDecode(MqttPublishPayload.bytesToStringAsString(message.payload.message));
            if (data is Map<String, dynamic>) event.value = RfidEvent.fromJson(data);
          } catch (_) {}
        }
      });
      return true;
    } catch (_) {
      client.disconnect();
      return false;
    }
  }

  void _onConnected() {
    _client?.subscribe(_eventTopic, MqttQos.atLeastOnce);
  }

  Future<bool> startBinding({required String memberId, required String memberName}) async {
    if (!await connect()) return false;
    final builder = MqttClientPayloadBuilder()
      ..addString(jsonEncode({'member_id': memberId, 'member_name': memberName}));
    _client!.publishMessage(_bindTopic, MqttQos.atLeastOnce, builder.payload!);
    return true;
  }

  void dispose() {
    _updates?.cancel();
    _client?.disconnect();
    event.dispose();
  }
}
