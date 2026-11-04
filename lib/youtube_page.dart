import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mqtt_settings.dart';
import 'mqtt_youtube_service.dart';

class YouTubePage extends StatefulWidget {
  const YouTubePage({super.key, required this.settings, this.initialUrl});

  final MqttSettings settings;
  final String? initialUrl;

  @override
  State<YouTubePage> createState() => _YouTubePageState();
}

class _YouTubePageState extends State<YouTubePage> {
  late final MqttYouTubeService _service;
  final _urlController = TextEditingController();
  bool _sending = false;
  Timer? _volumeDebounce;

  @override
  void initState() {
    super.initState();
    _service = MqttYouTubeService(widget.settings);
    _service.connect();
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _play());
    }
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
    if (!ok) _snack('無法連線到樹莓派，請確認 MQTT 設定。');
  }

  Future<void> _stop() async {
    await _service.stop();
  }

  Future<void> _togglePause() async {
    await _service.togglePause();
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
    _volumeDebounce?.cancel();
    _service.setVolume(value.round());
    _volumeDebounce = Timer(const Duration(milliseconds: 250), () {});
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _connectionLabel(YouTubeConnectionStatus value) => switch (value) {
    YouTubeConnectionStatus.connected => '樹莓派已連線',
    YouTubeConnectionStatus.connecting => '正在連線…',
    YouTubeConnectionStatus.failed => '連線失敗',
    YouTubeConnectionStatus.disconnected => '未連線',
  };

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
                final isActive = playback.isActive;
                return Scaffold(
                  appBar: AppBar(title: const Text('播放器')),
                  body: SafeArea(
                    top: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                          children: [
                            // --- 連線狀態 ---
                            _ConnectionChip(
                              connected: connected,
                              label: _connectionLabel(connection),
                              onRetry: connected ? null : _service.connect,
                            ),
                            const SizedBox(height: 16),

                            // --- Now Playing ---
                            if (isActive) ...[
                              _NowPlayingCard(
                                playback: playback,
                                onTogglePause: _togglePause,
                                onStop: _stop,
                                onVolumeChanged: connected
                                    ? _onVolumeChanged
                                    : null,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // --- 輸入區 ---
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isActive ? '換一首' : '播放音樂',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      '貼上 YouTube 連結，樹莓派喇叭直接播放。',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      controller: _urlController,
                                      keyboardType: TextInputType.url,
                                      textInputAction: TextInputAction.go,
                                      onSubmitted: (_) => _play(),
                                      decoration: InputDecoration(
                                        labelText: 'YouTube 連結或影片 ID',
                                        prefixIcon:
                                            const Icon(Icons.link_rounded),
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
                                            _sending || !connected
                                                ? null
                                                : _play,
                                        icon: _sending
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.play_arrow_rounded,
                                              ),
                                        label: Text(
                                          _sending ? '正在載入…' : '播放',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // --- Error ---
                            if (playback.hasError && playback.message != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Card(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .errorContainer,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline_rounded,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            playback.message!,
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onErrorContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 24),
                            const Text(
                              '提示：也可以在 YouTube App 分享影片到這個 App，直接播放。',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                height: 1.45,
                              ),
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

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({
    required this.connected,
    required this.label,
    this.onRetry,
  });
  final bool connected;
  final String label;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        connected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
        size: 16,
        color: connected ? Colors.green : Colors.grey,
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 13)),
      if (!connected && onRetry != null) ...[
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onRetry,
          child: const Text(
            '重試',
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    ],
  );
}

class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({
    required this.playback,
    required this.onTogglePause,
    required this.onStop,
    required this.onVolumeChanged,
  });
  final YouTubeState playback;
  final VoidCallback onTogglePause;
  final VoidCallback onStop;
  final ValueChanged<double>? onVolumeChanged;

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
                  playback.isPaused
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                  color: theme.colorScheme.primary,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playback.title ?? '正在播放',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                      if (playback.isPaused)
                        Text(
                          '已暫停',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (playback.url != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  playback.url!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 16),

            // --- 控制按鈕 ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  onPressed: onTogglePause,
                  iconSize: 32,
                  icon: Icon(
                    playback.isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                  ),
                  tooltip: playback.isPaused ? '繼續' : '暫停',
                ),
                const SizedBox(width: 16),
                IconButton.outlined(
                  onPressed: onStop,
                  iconSize: 28,
                  icon: const Icon(Icons.stop_rounded),
                  tooltip: '停止',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // --- 音量 ---
            Row(
              children: [
                const Icon(Icons.volume_down_rounded, size: 20),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 100,
                    divisions: 20,
                    value: playback.volume.toDouble(),
                    onChanged: onVolumeChanged,
                  ),
                ),
                const Icon(Icons.volume_up_rounded, size: 20),
                const SizedBox(width: 4),
                SizedBox(
                  width: 30,
                  child: Text(
                    '${playback.volume}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
