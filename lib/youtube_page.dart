import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mqtt_settings.dart';
import 'mqtt_youtube_service.dart';

/// 手機貼 YouTube 連結 → 樹莓派喇叭播放。
///
/// UI 刻意和「音樂模式」分家：音樂模式只播單首歌，YouTube 模式允許在
/// 播放過程中動態調整音量、看到目前標題。
class YouTubePage extends StatefulWidget {
  const YouTubePage({super.key, required this.settings});

  final MqttSettings settings;

  @override
  State<YouTubePage> createState() => _YouTubePageState();
}

class _YouTubePageState extends State<YouTubePage> {
  late final MqttYouTubeService _service;
  final _urlController = TextEditingController();
  bool _sending = false;
  bool _stopping = false;
  // 滑桿拖曳期間先在本地維護，放開才發 MQTT，避免每一幀都打網路。
  Timer? _volumeDebounce;
  int? _pendingVolume;

  @override
  void initState() {
    super.initState();
    _service = MqttYouTubeService(widget.settings);
    _service.connect();
  }

  @override
  void dispose() {
    _volumeDebounce?.cancel();
    _urlController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final text = _urlController.text.trim();
    if (text.isEmpty) {
      _snack('請先貼上 YouTube 影片連結或影片 ID。');
      return;
    }
    setState(() => _sending = true);
    final ok = await _service.play(text);
    if (!mounted) return;
    setState(() => _sending = false);
    _snack(ok ? '已送出播放指令，等待樹莓派回報。' : '無法連線到樹莓派，請確認 MQTT 設定。');
  }

  Future<void> _stop() async {
    setState(() => _stopping = true);
    final ok = await _service.stop();
    if (!mounted) return;
    setState(() => _stopping = false);
    _snack(ok ? '已要求樹莓派停止播放。' : '無法連線到樹莓派，請確認 MQTT 設定。');
  }

  Future<void> _pasteUrl() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text?.trim();
    if (text == null || text.isEmpty) return;
    _urlController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onVolumeChanged(double value) {
    _pendingVolume = value.round();
    _volumeDebounce?.cancel();
    _volumeDebounce = Timer(const Duration(milliseconds: 250), () {
      final target = _pendingVolume;
      if (target != null) _service.setVolume(target);
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _connectionLabel(YouTubeConnectionStatus value) {
    switch (value) {
      case YouTubeConnectionStatus.connected:
        return '樹莓派已連線';
      case YouTubeConnectionStatus.connecting:
        return '正在連線樹莓派…';
      case YouTubeConnectionStatus.failed:
        return '樹莓派連線失敗';
      case YouTubeConnectionStatus.disconnected:
        return '樹莓派未連線';
    }
  }

  String _playbackLabel(YouTubeState value) {
    if (value.hasError) return value.message ?? '播放失敗';
    if (value.isPlaying) return value.title ?? '正在播放';
    return value.message ?? '目前沒有播放';
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<YouTubeConnectionStatus>(
        valueListenable: _service.status,
        builder: (context, connection, _) =>
            ValueListenableBuilder<YouTubeState>(
              valueListenable: _service.state,
              builder: (context, playback, _) {
                final connected =
                    connection == YouTubeConnectionStatus.connected;
                return Scaffold(
                  appBar: AppBar(title: const Text('YouTube 播放')),
                  body: SafeArea(
                    top: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                          children: [
                            _StatusCard(
                              connected: connected,
                              connectionLabel: _connectionLabel(connection),
                              playback: playback,
                              playbackLabel: _playbackLabel(playback),
                            ),
                            const SizedBox(height: 16),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '貼上 YouTube 連結或影片 ID，在樹莓派喇叭播放。',
                                      style: TextStyle(height: 1.5),
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: _urlController,
                                      keyboardType: TextInputType.url,
                                      decoration: InputDecoration(
                                        labelText: 'YouTube 連結或 11 碼 ID',
                                        prefixIcon:
                                            const Icon(Icons.link_rounded),
                                        helperText:
                                            '支援 youtube.com / youtu.be / 純影片 ID',
                                        suffixIcon: IconButton(
                                          tooltip: '從剪貼簿貼上',
                                          onPressed: _pasteUrl,
                                          icon: const Icon(
                                            Icons.content_paste_rounded,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed:
                                            _sending || !connected ? null : _play,
                                        icon: const Icon(
                                          Icons.play_arrow_rounded,
                                        ),
                                        label: Text(
                                          _sending ? '正在傳送…' : '開始播放',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed:
                                            _stopping || !connected ? null : _stop,
                                        icon: const Icon(
                                          Icons.stop_circle_outlined,
                                        ),
                                        label: Text(
                                          _stopping ? '正在停止…' : '停止播放',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.volume_up_rounded),
                                        const SizedBox(width: 8),
                                        const Text(
                                          '喇叭音量',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text('${playback.volume}'),
                                      ],
                                    ),
                                    Slider(
                                      min: 0,
                                      max: 100,
                                      divisions: 100,
                                      value: playback.volume.toDouble(),
                                      onChanged: connected
                                          ? _onVolumeChanged
                                          : null,
                                    ),
                                    const Text(
                                      '音量會直接送到 mpv，不會影響系統其他輸出。',
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '樹莓派需安裝 mpv 與 yt-dlp（已包含在 pyproject 相依裡）。'
                              '首次使用請執行 uv sync 並確認喇叭是預設 ALSA/PipeWire 輸出。',
                              style: TextStyle(fontSize: 13, height: 1.45),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.connected,
    required this.connectionLabel,
    required this.playback,
    required this.playbackLabel,
  });

  final bool connected;
  final String connectionLabel;
  final YouTubeState playback;
  final String playbackLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  connected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: connected ? Colors.green : theme.disabledColor,
                ),
                const SizedBox(width: 8),
                Text(
                  connectionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  playback.isPlaying
                      ? Icons.music_note_rounded
                      : Icons.music_off_rounded,
                  color: playback.hasError
                      ? theme.colorScheme.error
                      : theme.iconTheme.color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    playbackLabel,
                    style: const TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
            if (playback.url != null && playback.isPlaying) ...[
              const SizedBox(height: 6),
              Text(
                playback.url!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
