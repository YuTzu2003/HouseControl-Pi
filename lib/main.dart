import 'package:flutter/material.dart';

void main() => runApp(const HouseControlApp());

class AppColors {
  static const background = Color(0xFF080808);
  static const surface = Color(0xFF151515);
  static const surfaceRaised = Color(0xFF202020);
  static const line = Color(0xFF333333);
  static const text = Color(0xFFF5F5F5);
  static const muted = Color(0xFFA7A7A7);
  static const blue = Color(0xFF00AEEF);
  static const green = Color(0xFF27D17F);
  static const red = Color(0xFFFF5D5D);
  static const amber = Color(0xFFFFC857);
}

class HouseControlApp extends StatelessWidget {
  const HouseControlApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '我的居家',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.blue,
        onPrimary: Colors.black,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        error: AppColors.red,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: ThemeData.dark().textTheme.apply(
        fontFamily: 'sans',
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        margin: EdgeInsets.zero,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 74,
        backgroundColor: Color(0xFF101010),
        indicatorColor: Color(0xFF173441),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: AppColors.muted),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.blue,
        inactiveTrackColor: AppColors.line,
        thumbColor: AppColors.text,
        overlayColor: Color(0x3300AEEF),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: const TextStyle(color: AppColors.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    ),
    home: const MainShell(),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _page = 0;
  final _pages = const [
    HomePage(),
    HistoryPage(),
    AutomationPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: _pages[_page]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _page,
      onDestinationSelected: (index) => setState(() => _page = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: '控制',
        ),
        NavigationDestination(
          icon: Icon(Icons.query_stats_outlined),
          selectedIcon: Icon(Icons.query_stats),
          label: '活動',
        ),
        NavigationDestination(
          icon: Icon(Icons.bolt_outlined),
          selectedIcon: Icon(Icons.bolt),
          label: '自動化',
        ),
        NavigationDestination(
          icon: Icon(Icons.tune_outlined),
          selectedIcon: Icon(Icons.tune),
          label: '設定',
        ),
      ],
    ),
  );
}

enum DemoState { ready, loading, offline, failure, empty }

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DemoState _state = DemoState.ready;
  bool _lightOn = true;
  bool _musicPlaying = false;
  double _brightness = 72;
  String _lightMode = '暖白';
  String _scene = '回家';
  bool get _canControl => _state == DemoState.ready;

  Future<void> _action(VoidCallback action, String message) async {
    if (!_canControl) return;
    setState(() => _state = DemoState.loading);
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    setState(() {
      _state = DemoState.ready;
      action();
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _chooseState() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceRaised,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '展示連線狀態',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            for (final state in const [
              (DemoState.ready, '已連線', Icons.wifi_rounded),
              (DemoState.loading, '同步中', Icons.sync_rounded),
              (DemoState.offline, '樹莓派離線', Icons.wifi_off_rounded),
              (DemoState.failure, '操作失敗', Icons.error_outline_rounded),
              (DemoState.empty, '未設定設備', Icons.add_to_queue_outlined),
            ])
              ListTile(
                minVerticalPadding: 12,
                leading: Icon(
                  state.$3,
                  color: state.$1 == DemoState.ready
                      ? AppColors.green
                      : AppColors.text,
                ),
                title: Text(state.$2),
                onTap: () {
                  setState(() => _state = state.$1);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final gutter = MediaQuery.sizeOf(context).width >= 700 ? 32.0 : 20.0;
    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 32),
      children: [
        Row(
          children: [
            const _BrandMark(),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOME CONTROL',
                    style: TextStyle(
                      fontSize: 17,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '客廳基地',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '切換展示狀態',
              onPressed: _chooseState,
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _LiveView(state: _state),
        const SizedBox(height: 14),
        _TelemetryStrip(state: _state),
        const SizedBox(height: 30),
        const _Kicker('ACCESS EVENT'),
        const SizedBox(height: 10),
        _RfidEventCard(
          onTap: () => ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('刷卡紀錄已顯示於「活動」頁面。'))),
        ),
        const SizedBox(height: 30),
        const _Kicker('LIGHTING'),
        const SizedBox(height: 10),
        _LightingConsole(
          enabled: _canControl,
          lightOn: _lightOn,
          brightness: _brightness,
          lightMode: _lightMode,
          onSwitch: (value) =>
              _action(() => _lightOn = value, value ? '客廳主燈已開啟' : '客廳主燈已關閉'),
          onBrightness: (value) => setState(() => _brightness = value),
          onMode: (mode) => _action(() => _lightMode = mode, '已切換為 $mode'),
        ),
        const SizedBox(height: 30),
        const _Kicker('QUICK CAPTURE'),
        const SizedBox(height: 10),
        _QuickControls(
          playing: _musicPlaying,
          enabled: _canControl,
          onMusic: () => _action(
            () => _musicPlaying = !_musicPlaying,
            _musicPlaying ? '音樂已播放' : '音樂已暫停',
          ),
          onPick: () => ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('手機音樂選擇會在連接播放端後啟用。'))),
        ),
        const SizedBox(height: 30),
        const _Kicker('PRESETS'),
        const SizedBox(height: 10),
        _PresetRow(
          selected: _scene,
          enabled: _canControl,
          onSelect: (scene) => _action(() => _scene = scene, '已套用「$scene」情境'),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: AppColors.blue,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.home_rounded, color: Colors.black, size: 22),
  );
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Text(
    value,
    style: const TextStyle(
      color: AppColors.muted,
      fontWeight: FontWeight.w800,
      fontSize: 12,
      letterSpacing: 1.6,
    ),
  );
}

class _LiveView extends StatelessWidget {
  const _LiveView({required this.state});
  final DemoState state;
  @override
  Widget build(BuildContext context) {
    final connected = state == DemoState.ready || state == DemoState.loading;
    final status = switch (state) {
      DemoState.ready => ('LIVE', '客廳即時狀態', AppColors.green),
      DemoState.loading => ('SYNC', '正在讀取設備資訊', AppColors.blue),
      DemoState.offline => ('OFFLINE', '樹莓派尚未連線', AppColors.red),
      DemoState.failure => ('RETRY', '上一個指令未完成', AppColors.red),
      DemoState.empty => ('SETUP', '尚未設定設備', AppColors.amber),
    };
    return AspectRatio(
      aspectRatio: 1.55,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF101417),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: connected ? const Color(0xFF31505D) : AppColors.line,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _GridPainter())),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .82),
                    ],
                  ),
                ),
              ),
            ),
            const Center(
              child: Icon(
                Icons.videocam_outlined,
                size: 58,
                color: Color(0xFF4B656E),
              ),
            ),
            Positioned(
              top: 14,
              left: 14,
              child: _LiveBadge(label: status.$1, color: status.$3),
            ),
            const Positioned(
              top: 17,
              right: 14,
              child: Text(
                '4K  •  DEMO',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 15,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.$2,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          connected
                              ? 'Raspberry Pi 4  •  最後更新：剛剛'
                              : '開啟設定以建立設備連線',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    color: status.$3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .6),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: .8)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 7, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2A3A41)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += size.width / 5) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += size.height / 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _TelemetryStrip extends StatelessWidget {
  const _TelemetryStrip({required this.state});
  final DemoState state;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _Telemetry(
          icon: Icons.thermostat_rounded,
          value: '25.2°',
          label: '溫度',
          color: AppColors.red,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _Telemetry(
          icon: Icons.water_drop_outlined,
          value: '61%',
          label: '濕度',
          color: AppColors.blue,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _Telemetry(
          icon: Icons.bolt_rounded,
          value: state == DemoState.ready ? 'ON' : '--',
          label: '系統',
          color: AppColors.green,
        ),
      ),
    ],
  );
}

class _Telemetry extends StatelessWidget {
  const _Telemetry({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class _RfidEventCard extends StatelessWidget {
  const _RfidEventCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '最新刷卡紀錄：小明，刷卡通過，剛剛',
    child: Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF236346)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0x1F27D17F),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.contactless_rounded,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '刷卡通過',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 8),
                        _AccessPill('已授權', AppColors.green),
                      ],
                    ),
                    SizedBox(height: 5),
                    Text(
                      '小明的卡片  •  前門讀卡機  •  剛剛',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AccessPill extends StatelessWidget {
  const _AccessPill(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );
}

class _LightingConsole extends StatelessWidget {
  const _LightingConsole({
    required this.enabled,
    required this.lightOn,
    required this.brightness,
    required this.lightMode,
    required this.onSwitch,
    required this.onBrightness,
    required this.onMode,
  });
  final bool enabled, lightOn;
  final double brightness;
  final String lightMode;
  final ValueChanged<bool> onSwitch;
  final ValueChanged<double> onBrightness;
  final ValueChanged<String> onMode;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0x1A00AEEF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '客廳主燈',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      lightOn ? '開啟中  •  $lightMode' : '目前已關閉',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: lightOn, onChanged: enabled ? onSwitch : null),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(color: AppColors.line, height: 1),
          ),
          Row(
            children: [
              const Icon(Icons.brightness_6_outlined, color: AppColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Slider(
                  min: 0,
                  max: 100,
                  value: brightness,
                  onChanged: enabled && lightOn ? onBrightness : null,
                ),
              ),
              SizedBox(
                width: 42,
                child: Text(
                  '${brightness.round()}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in ['暖白', '日光', '閱讀'])
                  ChoiceChip(
                    label: Text(mode),
                    selected: mode == lightMode,
                    onSelected: enabled ? (_) => onMode(mode) : null,
                    selectedColor: AppColors.blue,
                    labelStyle: TextStyle(
                      color: mode == lightMode ? Colors.black : AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                    backgroundColor: AppColors.surfaceRaised,
                    side: const BorderSide(color: AppColors.line),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _QuickControls extends StatelessWidget {
  const _QuickControls({
    required this.playing,
    required this.enabled,
    required this.onMusic,
    required this.onPick,
  });
  final bool playing, enabled;
  final VoidCallback onMusic, onPick;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _QuickButton(
          icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          label: playing ? '暫停音樂' : '播放音樂',
          primary: true,
          enabled: enabled,
          onTap: onMusic,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _QuickButton(
          icon: Icons.library_music_outlined,
          label: '選擇音樂',
          enabled: enabled,
          onTap: onPick,
        ),
      ),
    ],
  );
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.icon,
    required this.label,
    this.primary = false,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool primary, enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 74,
    child: Material(
      color: primary ? AppColors.blue : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: primary ? AppColors.blue : AppColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primary ? Colors.black : AppColors.text),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: primary ? Colors.black : AppColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });
  final String selected;
  final bool enabled;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) {
    const presets = [
      ('回家', Icons.home_outlined),
      ('專注', Icons.light_mode_outlined),
      ('電影', Icons.movie_outlined),
      ('晚安', Icons.nightlight_round),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final preset in presets)
          ChoiceChip(
            avatar: Icon(
              preset.$2,
              size: 17,
              color: selected == preset.$1 ? Colors.black : AppColors.muted,
            ),
            label: Text(preset.$1),
            selected: selected == preset.$1,
            onSelected: enabled ? (_) => onSelect(preset.$1) : null,
            selectedColor: AppColors.blue,
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.line),
            labelStyle: TextStyle(
              color: selected == preset.$1 ? Colors.black : AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) => _DarkPage(
    title: '活動紀錄',
    subtitle: '感測器與門禁事件  •  最近 24 小時',
    child: Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '環境變化',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  '溫度與濕度的展示歷史資料',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: CustomPaint(painter: _ChartPainter()),
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '00:00',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                    Text(
                      '06:00',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                    Text(
                      '12:00',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                    Text(
                      '現在',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _ActivityRow(
          icon: Icons.thermostat_rounded,
          color: AppColors.red,
          title: '最高溫度',
          value: '26.1°C',
        ),
        const SizedBox(height: 10),
        const _ActivityRow(
          icon: Icons.water_drop_outlined,
          color: AppColors.blue,
          title: '平均濕度',
          value: '59%',
        ),
        const SizedBox(height: 28),
        const Align(
          alignment: Alignment.centerLeft,
          child: _Kicker('RFID ACCESS LOG'),
        ),
        const SizedBox(height: 10),
        const _RfidLogItem(
          name: '小明的卡片',
          detail: '前門讀卡機',
          time: '剛剛',
          granted: true,
        ),
        const _RfidLogItem(
          name: '訪客卡',
          detail: '前門讀卡機',
          time: '今天 09:42',
          granted: true,
        ),
        const _RfidLogItem(
          name: '未知卡片  •  UID 4A:82:XX',
          detail: '前門讀卡機',
          time: '昨天 21:17',
          granted: false,
        ),
      ],
    ),
  );
}

class _RfidLogItem extends StatelessWidget {
  const _RfidLogItem({
    required this.name,
    required this.detail,
    required this.time,
    required this.granted,
  });
  final String name, detail, time;
  final bool granted;
  @override
  Widget build(BuildContext context) {
    final color = granted ? AppColors.green : AppColors.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: granted ? AppColors.line : const Color(0xFF753B3B),
        ),
      ),
      child: Row(
        children: [
          Icon(
            granted ? Icons.verified_user_outlined : Icons.block_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  '$detail  •  $time',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          _AccessPill(granted ? '通過' : '拒絕', color),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 3),
        Offset(size.width, size.height * i / 3),
        grid,
      );
    }
    const values = [.70, .59, .62, .48, .55, .42, .47, .30, .38, .24, .32, .29];
    final line = Path();
    for (var i = 0; i < values.length; i++) {
      final p = Offset(
        size.width * i / (values.length - 1),
        size.height * values[i],
      );
      i == 0 ? line.moveTo(p.dx, p.dy) : line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String title, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );
}

class AutomationPage extends StatelessWidget {
  const AutomationPage({super.key});
  @override
  Widget build(BuildContext context) => _DarkPage(
    title: '自動化',
    subtitle: '依照即時感測數據建立動作',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.bolt_rounded, size: 42, color: AppColors.blue),
            const SizedBox(height: 14),
            const Text(
              '尚未建立自動化',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            const Text(
              '完成樹莓派連線後，可設定溫溼度與情境觸發條件。',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.black,
              ),
              child: const Text('建立第一個規則'),
            ),
          ],
        ),
      ),
    ),
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => _DarkPage(
    title: '連線設定',
    subtitle: '樹莓派與設備來源',
    child: Column(
      children: [
        const _ActivityRow(
          icon: Icons.memory_rounded,
          color: AppColors.green,
          title: 'Raspberry Pi 4',
          value: '展示模式',
        ),
        const SizedBox(height: 10),
        const _ActivityRow(
          icon: Icons.wifi_outlined,
          color: AppColors.blue,
          title: '網路連線',
          value: '尚未設定',
        ),
        const SizedBox(height: 10),
        const _ActivityRow(
          icon: Icons.info_outline_rounded,
          color: AppColors.muted,
          title: 'App 版本',
          value: '1.0.0',
        ),
      ],
    ),
  );
}

class _DarkPage extends StatelessWidget {
  const _DarkPage({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 26),
      child,
    ],
  );
}
