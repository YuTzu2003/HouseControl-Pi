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
      _snack('請先貼上 YouTube 影片連結。');
      return;
    }
    setState(() => _sending = true);
    final ok = await _service.play(text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (!ok) _snack('播放器目前無法使用，請稍後再試。');
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

  void _showHelp() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '怎麼播放音樂？',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '只要準備好 YouTube 影片連結，就能從家中音響播放。',
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 16),
              const _HelpStep(number: '1', text: '在 YouTube 找到想聽的音樂。'),
              const _HelpStep(number: '2', text: '點「分享」後選擇這個 App，或先複製連結。'),
              const _HelpStep(number: '3', text: '回到這裡點「貼上連結」，再點「開始播放」。'),
              const _HelpStep(number: '4', text: '播放後可隨時暫停、繼續、停止或調整音量。'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('我知道了'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _connectionLabel(YouTubeConnectionStatus value) => switch (value) {
    YouTubeConnectionStatus.connected => '播放器已就緒',
    YouTubeConnectionStatus.connecting => '正在準備播放器…',
    YouTubeConnectionStatus.failed => '播放器暫時無法使用',
    YouTubeConnectionStatus.disconnected => '播放器尚未就緒',
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
                  appBar: AppBar(
                    title: const Text('家庭音樂'),
                    actions: [
                      IconButton(
                        onPressed: _showHelp,
                        tooltip: '播放器使用說明',
                        icon: const Icon(Icons.help_outline_rounded),
                      ),
                    ],
                  ),
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
                                onTogglePause: connected ? _togglePause : null,
                                onStop: connected ? _stop : null,
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
                                      isActive ? '播放其他音樂' : '選擇要播放的音樂',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      '貼上 YouTube 影片連結，就能從家中音響播放。',
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
                                        labelText: 'YouTube 影片連結',
                                        prefixIcon:
                                            const Icon(Icons.link_rounded),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: _pasteUrl,
                                        icon: const Icon(
                                          Icons.content_paste_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('貼上連結'),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
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
                                          _sending ? '正在準備…' : '開始播放',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // --- Error ---
                            if (playback.hasError)
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
                                            '播放時發生問題，請換一個影片或稍後再試。',
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
                              '小提示：也可以在 YouTube 點「分享」，選擇這個 App 直接播放。',
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
        const Spacer(),
        TextButton(onPressed: onRetry, child: const Text('再試一次')),
      ],
    ],
  );
}

class _HelpStep extends StatelessWidget {
  const _HelpStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            number,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
      ],
    ),
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
  final VoidCallback? onTogglePause;
  final VoidCallback? onStop;
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
            Text(
              playback.isPaused ? '已暫停' : '正在播放',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              playback.title ?? '已開始播放',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),

            // --- 控制按鈕 ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onTogglePause,
                    icon: Icon(
                      playback.isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                    ),
                    label: Text(playback.isPaused ? '繼續播放' : '暫停播放'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onStop,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('停止播放'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- 音量 ---
            Row(
              children: [
                const Text(
                  '音量',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${playback.volume}%',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
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
                    semanticFormatterCallback: (value) => '音量 ${value.round()}%',
                  ),
                ),
                const Icon(Icons.volume_up_rounded, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
