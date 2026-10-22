import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'family_members.dart';
import 'house_api.dart';
import 'history_page.dart';
import 'mqtt_light_service.dart';
import 'mqtt_music_service.dart';
import 'mqtt_rfid_service.dart';
import 'mqtt_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await MqttSettingsStore().load();
  runApp(HouseControlApp(initialSettings: settings));
}

class AppColors {
  static const background = Color(0xFFF2F2F7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceRaised = Color(0xFFEAEAEE);
  static const line = Color(0xFFE1E1E6);
  static const text = Color(0xFF1C1C1E);
  static const muted = Color(0xFF6E6E73);
  static const selection = Color(0xFFE7E7EC);
  static const selectionSoft = Color(0xFFF0F0F3);
  static const blue = Color(0xFF3478F6);
  static const green = Color(0xFF2E7D32);
  static const red = Color(0xFFE04F4F);
  static const amber = Color(0xFFB87916);
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
        primary: AppColors.text,
        onPrimary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        error: AppColors.red,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: ThemeData.light().textTheme.copyWith(
        displaySmall: const TextStyle(
          fontFamily: 'sans',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
          color: AppColors.text,
        ),
        headlineSmall: const TextStyle(
          fontFamily: 'sans',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: AppColors.text,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'sans',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        titleMedium: const TextStyle(
          fontFamily: 'sans',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        bodyLarge: const TextStyle(
          fontFamily: 'sans',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.text,
        ),
        bodyMedium: const TextStyle(
          fontFamily: 'sans',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.text,
        ),
        labelLarge: const TextStyle(
          fontFamily: 'sans',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: .2,
          color: AppColors.text,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        margin: EdgeInsets.zero,
        elevation: 1,
        shadowColor: const Color(0x14000000),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 78,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.selection,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: AppColors.muted),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.text,
        inactiveTrackColor: AppColors.line,
        thumbColor: AppColors.text,
        overlayColor: Color(0x3300AEEF),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: AppColors.text),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.text,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.text,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.text, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: const TextStyle(color: AppColors.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    ),
    home: _AppLaunchGate(
      child: _editingSettings || _settings == null
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
    ),
  );
}

class _AppLaunchGate extends StatefulWidget {
  const _AppLaunchGate({required this.child});
  final Widget child;

  @override
  State<_AppLaunchGate> createState() => _AppLaunchGateState();
}

class _AppLaunchGateState extends State<_AppLaunchGate> {
  bool _showLaunch = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showLaunch = false);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 260),
    switchInCurve: Curves.easeOut,
    switchOutCurve: Curves.easeIn,
    child: _showLaunch
        ? const _LaunchScreen(key: ValueKey('launch'))
        : KeyedSubtree(key: const ValueKey('app'), child: widget.child),
  );
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.text,
    body: Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: .88, end: 1),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.scale(scale: value, child: child),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.home_rounded, color: Colors.white, size: 48),
            SizedBox(height: 14),
            Text(
              'HOME CONTROL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
      ),
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
    _port = TextEditingController(
      text: '${widget.initialSettings?.port ?? 1883}',
    );
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
                          validator: (value) =>
                              (value?.isEmpty ?? true) ? '請輸入 MQTT 密碼' : null,
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
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
      HistoryPage(settings: widget.settings),
      AutomationPage(settings: widget.settings),
      FamilyMembersPage(settings: widget.settings),
      SettingsPage(host: widget.settings.host, onEdit: widget.onEditSettings),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: _pages[_page]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _page,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
          icon: Icon(Icons.groups_2_outlined),
          selectedIcon: Icon(Icons.groups_2),
          label: '家庭',
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
  late final MqttRfidService _rfidService;
  Timer? _brightnessDebounce;
  List<SensorReading>? _todayReadings;
  DemoState _state = DemoState.ready;
  String _scene = '回家';
  bool get _canControl => _state == DemoState.ready;

  @override
  void initState() {
    super.initState();
    _lightService = MqttLightService(widget.settings);
    _rfidService = MqttRfidService(widget.settings);
    _rfidService.event.addListener(_handleRfidEvent);
    _loadTodayReadings();
    if (widget.autoConnect) {
      _lightService.connect();
      _rfidService.connect();
    }
  }

  Future<void> _loadTodayReadings() async {
    final readings = await HouseApi(widget.settings).sensorHistory(limit: 48);
    final now = DateTime.now();
    final today = readings.where((reading) {
      final date = DateTime.tryParse(reading.recordedAt)?.toLocal();
      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();
    if (mounted)
      setState(
        () =>
            _todayReadings = today.isEmpty ? readings.take(1).toList() : today,
      );
  }

  void _handleRfidEvent() {
    final event = _rfidService.event.value;
    if (!mounted || event == null) return;
    if (event.type != 'access_granted' && event.type != 'access_denied') return;
    final known = event.type == 'access_granted';
    final memberName = event.memberName?.trim().isNotEmpty == true
        ? event.memberName!
        : '未知';
    final color = known ? AppColors.blue : AppColors.red;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            Icon(
              known
                  ? Icons.verified_user_outlined
                  : Icons.warning_amber_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(known ? '$memberName 刷卡進入' : '警訊：未知的人嘗試刷卡進入')),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _brightnessDebounce?.cancel();
    _rfidService.event.removeListener(_handleRfidEvent);
    _rfidService.dispose();
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
                      ? AppColors.blue
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
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My House',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '今天的家，一切都在掌握中',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.line),
              ),
              child: IconButton(
                tooltip: '切換展示狀態',
                onPressed: _chooseState,
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _LiveCameraCard(settings: widget.settings),
        const SizedBox(height: 22),
        _TodaySensorCard(
          readings: _todayReadings,
          onRefresh: _loadTodayReadings,
        ),
        const SizedBox(height: 22),
        const Text(
          '家中設備',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        const _Kicker('燈光控制'),
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
        const SizedBox(height: 22),
        const _Kicker('快捷操作'),
        const SizedBox(height: 10),
        _QuickControls(
          enabled: _canControl,
          onOpenMusic: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _MusicModePage(settings: widget.settings),
            ),
          ),
        ),
        const SizedBox(height: 22),
        const _Kicker('情境模式'),
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

class _TodaySensorCard extends StatelessWidget {
  const _TodaySensorCard({required this.readings, required this.onRefresh});
  final List<SensorReading>? readings;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final latest = readings?.isNotEmpty == true ? readings!.first : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wb_sunny_outlined,
                color: AppColors.text,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '今日環境',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                tooltip: '重新整理',
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (readings == null)
            const LinearProgressIndicator()
          else if (latest == null)
            const Text('目前沒有溫濕度資料')
          else
            Row(
              children: [
                const Icon(
                  Icons.thermostat_rounded,
                  color: AppColors.red,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Text(
                  '${latest.temperature.toStringAsFixed(1)}°',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 18),
                const Icon(
                  Icons.water_drop_outlined,
                  color: AppColors.blue,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Text(
                  '${latest.humidity.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatReadingTime(latest.recordedAt),
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String _formatReadingTime(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} 更新';
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

class _LiveCameraCard extends StatefulWidget {
  const _LiveCameraCard({required this.settings});
  final MqttSettings settings;

  @override
  State<_LiveCameraCard> createState() => _LiveCameraCardState();
}

class _LiveCameraCardState extends State<_LiveCameraCard> {
  Timer? _refresh;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted) setState(() => _frame++);
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url =
        'http://${widget.settings.host}:8000/camera/live.jpg?frame=$_frame';
    return AspectRatio(
      aspectRatio: 1.55,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFF101417),
                child: Center(
                  child: Text(
                    '等待樹莓派攝影機啟動',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            const Positioned(top: 12, left: 12, child: _LiveBadge()),
            Positioned(
              top: 6,
              right: 6,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        _CameraPlaybackPage(settings: widget.settings),
                  ),
                ),
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('回放'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .65),
      borderRadius: BorderRadius.circular(99),
    ),
    child: const Text(
      'LIVE',
      style: TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _CameraPlaybackPage extends StatefulWidget {
  const _CameraPlaybackPage({required this.settings});
  final MqttSettings settings;

  @override
  State<_CameraPlaybackPage> createState() => _CameraPlaybackPageState();
}

class _CameraPlaybackPageState extends State<_CameraPlaybackPage> {
  List<CameraRecording>? _recordings;
  VideoPlayerController? _player;
  String? _playing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final recordings = await HouseApi(widget.settings).cameraRecordings();
    if (mounted) setState(() => _recordings = recordings);
  }

  Future<void> _play(CameraRecording recording) async {
    final previous = _player;
    final player = VideoPlayerController.networkUrl(
      HouseApi(widget.settings).recordingUrl(recording.name),
    );
    setState(() {
      _player = player;
      _playing = recording.name;
    });
    await previous?.dispose();
    try {
      await player.initialize();
      await player.play();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('無法載入這段影片。')));
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final recordings = _recordings;
    final player = _player;
    return Scaffold(
      appBar: AppBar(
        title: const Text('攝影機回放'),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: recordings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (player != null && player.value.isInitialized) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: player.value.aspectRatio,
                      child: VideoPlayer(player),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: IconButton.filled(
                      onPressed: () => setState(() {
                        player.value.isPlaying ? player.pause() : player.play();
                      }),
                      icon: Icon(
                        player.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                const Text(
                  '最近片段',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (recordings.isEmpty)
                  const Card(child: ListTile(title: Text('目前沒有可回放的影片。')))
                else
                  for (final recording in recordings)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          _playing == recording.name
                              ? Icons.play_circle_filled_rounded
                              : Icons.play_circle_outline_rounded,
                        ),
                        title: Text(_recordingLabel(recording.recordedAt)),
                        subtitle: Text(_fileSize(recording.size)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _play(recording),
                      ),
                    ),
              ],
            ),
    );
  }

  String _recordingLabel(String value) {
    final match = RegExp(r'^(\d{8})T(\d{6})Z$').firstMatch(value);
    if (match == null) return value;
    final date = match.group(1)!;
    final time = match.group(2)!;
    return '${date.substring(4, 6)}/${date.substring(6, 8)} ${time.substring(0, 2)}:${time.substring(2, 4)}';
  }

  String _fileSize(int bytes) =>
      '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
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
        final statusColor = connected ? AppColors.blue : AppColors.amber;
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
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Switch(
                      value: light.on,
                      onChanged: connected
                          ? (value) => service.setLight(on: value)
                          : null,
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
                    if (!connected &&
                        status != LightConnectionStatus.unconfigured)
                      TextButton(
                        onPressed: service.connect,
                        child: const Text('重試'),
                      ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Divider(color: AppColors.line, height: 1),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.brightness_6_outlined,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: 100,
                        value: light.brightness,
                        onChanged: connected && light.on
                            ? onBrightnessChanged
                            : null,
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
                        selectedColor: AppColors.text,
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
  const _QuickControls({required this.enabled, required this.onOpenMusic});
  final bool enabled;
  final VoidCallback onOpenMusic;
  @override
  Widget build(BuildContext context) => _QuickButton(
    icon: Icons.play_circle_outline_rounded,
    label: '進入音樂模式',
    primary: true,
    enabled: enabled,
    onTap: onOpenMusic,
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
      color: primary ? AppColors.text : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: primary ? AppColors.text : AppColors.line),
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

class _MusicModePage extends StatefulWidget {
  const _MusicModePage({required this.settings});
  final MqttSettings settings;

  @override
  State<_MusicModePage> createState() => _MusicModePageState();
}

class _MusicModePageState extends State<_MusicModePage> {
  bool _openingYouTube = false;
  bool _sendingToSpeaker = false;
  final _videoUrl = TextEditingController();

  @override
  void dispose() {
    _videoUrl.dispose();
    super.dispose();
  }

  Future<void> _playOnSpeaker() async {
    final url = _videoUrl.text.trim();
    final host = Uri.tryParse(url)?.host;
    if (host == null || !(host == 'youtu.be' || host.endsWith('youtube.com'))) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請貼上完整的 YouTube 影片連結。')));
      return;
    }
    setState(() => _sendingToSpeaker = true);
    final sent = await MqttMusicService(widget.settings).play(url);
    if (!mounted) return;
    setState(() => _sendingToSpeaker = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(sent ? '已傳送給樹莓派嗇叭播放。' : '無法傳送給樹莓派，請確認 MQTT 連線。')),
    );
  }

  Future<void> _openYouTube() async {
    setState(() => _openingYouTube = true);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse('https://www.youtube.com/'),
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (!opened) {
        opened = await launchUrl(
          Uri.parse('https://www.youtube.com/'),
          mode: LaunchMode.inAppBrowserView,
          browserConfiguration: const BrowserConfiguration(showTitle: true),
        );
      }
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() => _openingYouTube = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法開啟 YouTube，請確認網路與瀏覽器後再試一次。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('音樂模式')),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.selectionSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: AppColors.text,
                  size: 30,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '想聽什麼？',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '想用手機聽可以開啟 YouTube；想由樹莓派嗇叭發聲，請貼上影片連結。',
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.play_circle_fill_rounded,
                            color: AppColors.red,
                            size: 40,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'YouTube',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '優先開啟 App，失敗時改用安全瀏覽器',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _openingYouTube ? null : _openYouTube,
                          icon: _openingYouTube
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.open_in_new_rounded),
                          label: Text(_openingYouTube ? '正在開啟…' : '開啟 YouTube'),
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
                      const Text(
                        '樹莓派嗇叭播放',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '在 YouTube 點選「共享」後複製連結，再貼到這裡。',
                        style: TextStyle(color: AppColors.muted, height: 1.45),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _videoUrl,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'YouTube 影片連結',
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _sendingToSpeaker ? null : _playOnSpeaker,
                          icon: const Icon(Icons.speaker_rounded),
                          label: Text(_sendingToSpeaker ? '正在傳送…' : '用樹莓派嗇叭播放'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '樹莓派需安裝 mpv 與 yt-dlp，且嗇叭必須是它的預設 ALSA 音訊輸出。',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
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
            selectedColor: AppColors.text,
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

class _LegacyHistoryPage extends StatefulWidget {
  const _LegacyHistoryPage({super.key, required this.settings});
  final MqttSettings settings;

  @override
  State<_LegacyHistoryPage> createState() => _LegacyHistoryPageState();
}

class _LegacyHistoryPageState extends State<_LegacyHistoryPage> {
  List<SensorReading>? _readings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final readings = await HouseApi(widget.settings).sensorHistory();
    if (mounted) setState(() => _readings = readings);
  }

  @override
  Widget build(BuildContext context) {
    final latest = _readings?.isNotEmpty == true ? _readings!.first : null;
    return _DarkPage(
      title: '活動紀錄',
      subtitle: '感測器與門禁事件  •  最近 24 小時',
      child: Column(
        children: [
          _SensorSummary(latest: latest, onRefresh: _load),
          const SizedBox(height: 14),
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
}

class _SensorSummary extends StatelessWidget {
  const _SensorSummary({required this.latest, required this.onRefresh});
  final SensorReading? latest;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: latest == null
          ? Row(
              children: [
                const Expanded(
                  child: Text('尚未收到溫濕度資料，請確認 Pi 的 DHT11 服務與 FastAPI。'),
                ),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.thermostat_rounded, color: AppColors.red),
                const SizedBox(width: 8),
                Text(
                  '${latest!.temperature.toStringAsFixed(1)}°C',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 20),
                const Icon(Icons.water_drop_outlined, color: AppColors.blue),
                const SizedBox(width: 8),
                Text(
                  '${latest!.humidity.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onRefresh,
                  tooltip: '重新整理',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
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
    final color = granted ? AppColors.blue : AppColors.red;
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

class AutomationPage extends StatefulWidget {
  const AutomationPage({super.key, required this.settings});
  final MqttSettings settings;
  @override
  State<AutomationPage> createState() => _AutomationPageState();
}

class _AutomationPageState extends State<AutomationPage> {
  List<AutomationRule>? _rules;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rules = await HouseApi(widget.settings).automations();
    if (mounted) setState(() => _rules = rules);
  }

  Future<void> _add() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選擇動作'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'off'),
            child: const Text('關燈'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'on'),
            child: const Text('開燈'),
          ),
        ],
      ),
    );
    if (action == null) return;
    final value =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final ok = await HouseApi(widget.settings).saveAutomation(
      AutomationRule(
        id: null,
        name: '$value${action == 'on' ? ' 開燈' : ' 關燈'}',
        time: value,
        days: const [0, 1, 2, 3, 4, 5, 6],
        action: action,
        enabled: true,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(ok ? '規則已儲存' : '無法連線至樹莓派')));
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) => _DarkPage(
    title: '自動化',
    subtitle: '讓家依照你的習慣自動運作',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageSectionLabel('我的規則'),
        const SizedBox(height: 10),
        if (_rules == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          for (final rule in _rules!)
            Card(
              child: ListTile(
                leading: Icon(
                  rule.action == 'on'
                      ? Icons.lightbulb_rounded
                      : Icons.lightbulb_outline_rounded,
                ),
                title: Text(rule.name),
                subtitle: Text(
                  '每天 ${rule.time} ・ ${rule.action == 'on' ? '開燈' : '關燈'}',
                ),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: const Text('新增每日定時規則'),
            ),
          ),
        ],
      ],
    ),
  );
}

class _PageSectionLabel extends StatelessWidget {
  const _PageSectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      color: AppColors.muted,
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.7,
    ),
  );
}

class _AutomationSuggestion extends StatelessWidget {
  const _AutomationSuggestion({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title, detail;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      minVerticalPadding: 12,
      leading: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: AppColors.selectionSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.text),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        detail,
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
    ),
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.host, required this.onEdit});

  final String host;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => _DarkPage(
    title: '設定',
    subtitle: '管理家庭、設備與連線',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageSectionLabel('裝置與連線'),
        const SizedBox(height: 10),
        _SettingsInfoGroup(host: host),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('修改 MQTT 連線設定'),
          ),
        ),
      ],
    ),
  );
}

class _SettingsInfoGroup extends StatelessWidget {
  const _SettingsInfoGroup({required this.host});
  final String host;
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        _SettingsInfoRow(
          icon: Icons.memory_rounded,
          title: 'Raspberry Pi',
          value: host,
        ),
        const Divider(height: 1, indent: 64),
        const _SettingsInfoRow(
          icon: Icons.wifi_rounded,
          title: 'MQTT 連線',
          value: '已設定',
        ),
        const Divider(height: 1, indent: 64),
        const _SettingsInfoRow(
          icon: Icons.info_outline_rounded,
          title: 'App 版本',
          value: '1.0.0',
        ),
      ],
    ),
  );
}

class _SettingsInfoRow extends StatelessWidget {
  const _SettingsInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title, value;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    leading: Icon(icon, color: AppColors.muted),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    trailing: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 132),
      child: Text(
        value,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
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
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 22),
      child,
    ],
  );
}
