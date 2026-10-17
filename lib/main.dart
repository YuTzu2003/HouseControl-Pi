import 'dart:async';

import 'package:flutter/material.dart';

import 'mqtt_light_service.dart';
import 'mqtt_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await MqttSettingsStore().load();
  runApp(HouseControlApp(initialSettings: settings));
}

class AppColors {
  static const background = Color(0xFFF7F9FC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceRaised = Color(0xFFF0F4F8);
  static const line = Color(0xFFD8E0E8);
  static const text = Color(0xFF15212B);
  static const muted = Color(0xFF5F6F7D);
  static const blue = Color(0xFF0077B6);
  static const green = Color(0xFF168A55);
  static const red = Color(0xFFC62828);
  static const amber = Color(0xFF966500);
}

class HouseControlApp extends StatefulWidget {
  const HouseControlApp({
    super.key,
    required this.initialSettings,
    this.autoConnect = true,
  });

  final MqttSettings? initialSettings;
  final bool autoConnect;

  @override
  State<HouseControlApp> createState() => _HouseControlAppState();
}

class _HouseControlAppState extends State<HouseControlApp> {
  MqttSettings? _settings;
  bool _editingSettings = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '我的居家',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.blue,
        onPrimary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        error: AppColors.red,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: ThemeData.light().textTheme.apply(
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
        backgroundColor: AppColors.surface,
        indicatorColor: Color(0xFFDCEFFD),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: AppColors.muted)),
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
    home: _editingSettings || _settings == null
        ? MqttSetupPage(
            initialSettings: _settings,
            onSaved: (settings) async {
              await MqttSettingsStore().save(settings);
              if (!mounted) return;
              setState(() {
                _settings = settings;
                _editingSettings = false;
              });
            },
          )
        : MainShell(
            settings: _settings!,
            autoConnect: widget.autoConnect,
            onEditSettings: () => setState(() => _editingSettings = true),
          ),
  );
}

class MqttSetupPage extends StatefulWidget {
  const MqttSetupPage({
    super.key,
    required this.initialSettings,
    required this.onSaved,
  });

  final MqttSettings? initialSettings;
  final Future<void> Function(MqttSettings settings) onSaved;

  @override
  State<MqttSetupPage> createState() => _MqttSetupPageState();
}

class _MqttSetupPageState extends State<MqttSetupPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _host = TextEditingController(text: widget.initialSettings?.host);
    _port = TextEditingController(text: '${widget.initialSettings?.port ?? 1883}');
    _username = TextEditingController(text: widget.initialSettings?.username);
    _password = TextEditingController(text: widget.initialSettings?.password);
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    await widget.onSaved(
      MqttSettings(
        host: _host.text.trim(),
        port: int.parse(_port.text),
        username: _username.text.trim(),
        password: _password.text,
      ),
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
            children: [
              const Icon(Icons.home_rounded, size: 48, color: AppColors.blue),
              const SizedBox(height: 24),
              const Text(
                '連接你的樹莓派',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                '請輸入 MQTT broker 設定。若 broker 在樹莓派上，位址通常是它的區網 IP，例如 192.168.1.50。',
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _host,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Broker 位址',
                            hintText: '192.168.1.50',
                            prefixIcon: Icon(Icons.dns_outlined),
                          ),
                          validator: (value) {
                            final host = value?.trim() ?? '';
                            if (host.isEmpty) return '請輸入樹莓派或 broker 位址';
                            if (host.contains('://') || host.contains('/')) {
                              return '請只輸入 IP 或網域名稱，不要包含 http://';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _port,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'MQTT 埠號',
                            prefixIcon: Icon(Icons.settings_ethernet_rounded),
                          ),
                          validator: (value) {
                            final port = int.tryParse(value ?? '');
                            return port == null || port < 1 || port > 65535
                                ? '請輸入 1 到 65535 的埠號'
                                : null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _username,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'MQTT 使用者名稱',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? '請輸入使用者名稱'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'MQTT 密碼',
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                          validator: (value) => (value?.isEmpty ?? true)
                              ? '請輸入 MQTT 密碼'
                              : null,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('儲存並連線'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '帳號與密碼會使用裝置的安全儲存空間保存，不會寫入原始碼。',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.settings,
    required this.autoConnect,
    required this.onEditSettings,
  });

  final MqttSettings settings;
  final bool autoConnect;
  final VoidCallback onEditSettings;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _page = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(settings: widget.settings, autoConnect: widget.autoConnect),
      const HistoryPage(),
      const AutomationPage(),
      SettingsPage(
        host: widget.settings.host,
        onEdit: widget.onEditSettings,
      ),
    ];
  }

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
  const HomePage({super.key, required this.settings, this.autoConnect = true});

  final MqttSettings settings;
  final bool autoConnect;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final MqttLightService _lightService;
  Timer? _brightnessDebounce;
  DemoState _state = DemoState.ready;
  bool _musicPlaying = false;
  String _scene = '回家';
  bool get _canControl => _state == DemoState.ready;

  @override
  void initState() {
    super.initState();
    _lightService = MqttLightService(widget.settings);
    if (widget.autoConnect) _lightService.connect();
  }

  @override
  void dispose() {
    _brightnessDebounce?.cancel();
    _lightService.dispose();
    super.dispose();
  }

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
        _MqttLightingConsole(
          service: _lightService,
          onBrightnessChanged: (value) {
            _lightService.previewBrightness(value);
            _brightnessDebounce?.cancel();
            _brightnessDebounce = Timer(
              const Duration(milliseconds: 180),
              () => _lightService.setLight(brightness: value),
            );
          },
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
    child: const Icon(Icons.home_rounded, color: Colors.white, size: 22),
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

class _MqttLightingConsole extends StatelessWidget {
  const _MqttLightingConsole({
    required this.service,
    required this.onBrightnessChanged,
  });

  final MqttLightService service;
  final ValueChanged<double> onBrightnessChanged;

  static const _modes = [
    ('warm_yellow', '暖黃'),
    ('warm_white', '暖白'),
    ('natural_white', '自然白'),
    ('cool_white', '冷白'),
  ];

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: service.status,
    builder: (context, status, _) => ValueListenableBuilder(
      valueListenable: service.lightState,
      builder: (context, light, _) {
        final connected = status == LightConnectionStatus.connected;
        final statusText = switch (status) {
          LightConnectionStatus.connected => '已連線，狀態來自樹莓派',
          LightConnectionStatus.connecting => '正在連線至 MQTT…',
          LightConnectionStatus.unconfigured => '尚未設定 MQTT 連線資訊',
          LightConnectionStatus.failed => '連線失敗，請確認 Wi-Fi 與 broker',
          LightConnectionStatus.disconnected => '已離線',
        };
        final statusColor = connected ? AppColors.green : AppColors.amber;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_rounded, color: AppColors.blue),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '客廳主燈',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Switch(
                      value: light.on,
                      onChanged: connected ? (value) => service.setLight(on: value) : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 12),
                      ),
                    ),
                    if (!connected && status != LightConnectionStatus.unconfigured)
                      TextButton(onPressed: service.connect, child: const Text('重試')),
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
                        value: light.brightness,
                        onChanged: connected && light.on ? onBrightnessChanged : null,
                      ),
                    ),
                    SizedBox(
                      width: 42,
                      child: Text(
                        '${light.brightness.round()}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mode in _modes)
                      ChoiceChip(
                        label: Text(mode.$2),
                        selected: light.mode == mode.$1,
                        onSelected: connected
                            ? (_) => service.setLight(mode: mode.$1)
                            : null,
                        selectedColor: AppColors.blue,
                        labelStyle: TextStyle(
                          color: light.mode == mode.$1
                              ? Colors.white
                              : AppColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                        backgroundColor: AppColors.surfaceRaised,
                        side: const BorderSide(color: AppColors.line),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
            Icon(icon, color: primary ? Colors.white : AppColors.text),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: primary ? Colors.white : AppColors.text,
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
              color: selected == preset.$1 ? Colors.white : AppColors.muted,
            ),
            label: Text(preset.$1),
            selected: selected == preset.$1,
            onSelected: enabled ? (_) => onSelect(preset.$1) : null,
            selectedColor: AppColors.blue,
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.line),
            labelStyle: TextStyle(
              color: selected == preset.$1 ? Colors.white : AppColors.text,
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
                foregroundColor: Colors.white,
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
  const SettingsPage({super.key, required this.host, required this.onEdit});

  final String host;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => _DarkPage(
    title: '連線設定',
    subtitle: '樹莓派與設備來源',
    child: Column(
      children: [
        _ActivityRow(
          icon: Icons.memory_rounded,
          color: AppColors.green,
          title: 'Raspberry Pi 4',
          value: host,
        ),
        const SizedBox(height: 10),
        const _ActivityRow(
          icon: Icons.wifi_outlined,
          color: AppColors.blue,
          title: '網路連線',
          value: 'MQTT 已設定',
        ),
        const SizedBox(height: 10),
        const _ActivityRow(
          icon: Icons.info_outline_rounded,
          color: AppColors.muted,
          title: 'App 版本',
          value: '1.0.0',
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('修改 MQTT 連線設定'),
          ),
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
