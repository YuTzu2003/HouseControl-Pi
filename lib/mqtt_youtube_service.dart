import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'mqtt_settings.dart';

// 對應 pi/house_control/youtube_player.py 的 TOPIC_*。改名要兩邊同步。
const _playTopic = 'house/youtube/play';
const _stopTopic = 'house/youtube/stop';
const _volumeTopic = 'house/youtube/volume';
const _statusTopic = 'house/youtube/status';

enum YouTubeConnectionStatus { disconnected, connecting, connected, failed }

/// 由 ``house/youtube/status`` 解析出來的播放狀態。``volume`` 一律 0～100，
/// ``title`` 是 yt-dlp 抓到的影片標題（抓失敗時為 null）。
class YouTubeState {
  const YouTubeState({
    required this.state,
    required this.volume,
    this.url,
    this.title,
    this.message,
  });

  final String state;
  final int volume;
  final String? url;
  final String? title;
  final String? message;

  bool get isPlaying => state == 'playing';
  bool get hasError => state == 'error';

  factory YouTubeState.fromJson(Map<String, dynamic> json) {
    final rawVolume = json['volume'];
    final volume = rawVolume is num ? rawVolume.toInt().clamp(0, 100) : 80;
    return YouTubeState(
      state: json['state'] as String? ?? 'unknown',
      volume: volume,
      url: json['url'] as String?,
      title: json['title'] as String?,
      message: json['message'] as String?,
    );
  }

  YouTubeState copyWith({int? volume}) => YouTubeState(
    state: state,
    volume: volume ?? this.volume,
    url: url,
    title: title,
    message: message,
  );
}

/// MQTT 版 YouTube 控制器。寫法沿用 `MqttMusicService`：
///
/// * `status` 是 MQTT 連線狀態
/// * `state` 是樹莓派回報的播放狀態
///
/// UI 直接 `ValueListenableBuilder` 訂閱兩者即可。
class MqttYouTubeService {
  MqttYouTubeService(this._settings);

  final MqttSettings _settings;
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updates;
  bool _disposed = false;

  final status = ValueNotifier(YouTubeConnectionStatus.disconnected);
  final state = ValueNotifier(
    const YouTubeState(state: 'stopped', volume: 80, message: '尚未播放'),
  );

  bool get isConfigured => _settings.host.isNotEmpty;

  Future<bool> connect() async {
    if (_disposed) return false;
    if (!isConfigured) {
      status.value = YouTubeConnectionStatus.failed;
      return false;
    }
    if (status.value == YouTubeConnectionStatus.connecting ||
        status.value == YouTubeConnectionStatus.connected) {
      return status.value == YouTubeConnectionStatus.connected;
    }

    status.value = YouTubeConnectionStatus.connecting;
    await _updates?.cancel();
    _updates = null;
    final clientId =
        'housecontrol-youtube-${DateTime.now().millisecondsSinceEpoch}';
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
        status.value = YouTubeConnectionStatus.failed;
        client.disconnect();
        return false;
      }
      _onConnected();
      return true;
    } catch (_) {
      status.value = YouTubeConnectionStatus.failed;
      client.disconnect();
      return false;
    }
  }

  void _onConnected() {
    if (_disposed) return;
    status.value = YouTubeConnectionStatus.connected;
    _client?.subscribe(_statusTopic, MqttQos.atLeastOnce);
    _updates ??= _client?.updates?.listen((messages) {
      for (final received in messages) {
        if (_disposed) return;
        if (received.topic != _statusTopic) continue;
        try {
          final message = received.payload as MqttPublishMessage;
          final decoded = jsonDecode(
            MqttPublishPayload.bytesToStringAsString(message.payload.message),
          );
          if (decoded is Map<String, dynamic>) {
            state.value = YouTubeState.fromJson(decoded);
          }
        } catch (_) {
          // 樹莓派偶爾會留下損壞的 retained 訊息，忽略即可。
        }
      }
    });
  }

  void _onDisconnected() {
    if (_disposed) return;
    if (status.value != YouTubeConnectionStatus.failed) {
      status.value = YouTubeConnectionStatus.disconnected;
    }
  }

  Future<bool> play(String urlOrVideoId) =>
      _publish(_playTopic, {'url': urlOrVideoId});

  Future<bool> stop() => _publish(_stopTopic, <String, Object?>{});

  /// 樂觀更新：先把滑桿值寫進 state，再送 MQTT；若送出失敗則狀態訊息重新
  /// 由 retained 回報修正。
  Future<bool> setVolume(int volume) {
    final clamped = volume.clamp(0, 100);
    state.value = state.value.copyWith(volume: clamped);
    return _publish(_volumeTopic, {'volume': clamped});
  }

  Future<bool> _publish(String topic, Map<String, Object?> value) async {
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
    if (_disposed) return;
    _disposed = true;
    _updates?.cancel();
    _client?.disconnect();
    status.dispose();
    state.dispose();
  }
}
