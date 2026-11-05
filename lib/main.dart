import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:video_player/video_player.dart';

import 'family_members.dart';
import 'house_api.dart';
import 'history_page.dart';
import 'mqtt_light_service.dart';
import 'mqtt_rfid_service.dart';
import 'mqtt_scene_service.dart';
import 'mqtt_settings.dart';
import 'youtube_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await MqttSettingsStore().load();
  runApp(HouseControlApp(initialSettings: settings));
}

class AppColors {
  static const background = Color(0xFFF4F4F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceRaised = Color(0xFFECECED);
  static const line = Color(0xFFE0E0E2);
  static const text = Color(0xFF1A1A1A);
  static const muted = Color(0xFF7A7A80);
  static const selection = Color(0xFFE6E6E8);
  static const selectionSoft = Color(0xFFF0F0F2);
  static const accent = Color(0xFF1A1A1A);
  static const accentSoft = Color(0xFFF0F0F2);
  static const blue = Color(0xFF5B8FA8);
  static const green = Color(0xFF5A8F6B);
  static const red = Color(0xFFCC5F52);
  static const amber = Color(0xFFC09236);
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
  MqttLightService? _machineService;
  bool _editingSettings = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _machineService = _createMachineService(_settings);
  }

  MqttLightService? _createMachineService(MqttSettings? settings) {
    if (settings == null) return null;
    final service = MqttLightService(settings);
    if (widget.autoConnect) service.connect();
    return service;
  }

  Future<void> _saveSettings(MqttSettings settings) async {
    await MqttSettingsStore().save(settings);
    if (!mounted) return;
    final previousService = _machineService;
    setState(() {
      _settings = settings;
      _machineService = _createMachineService(settings);
      _editingSettings = false;
    });
    previousService?.dispose();
  }

  @override
  void dispose() {
    _machineService?.dispose();
    super.dispose();
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
          ? MqttSetupPage(initialSettings: _settings, onSaved: _saveSettings)
          : MainShell(
              settings: _settings!,
              machineService: _machineService!,
              autoConnect: widget.autoConnect,
              onEditSettings: () => setState(() => _editingSettings = true),
            ),
    ),
  );
}

class _MachineConnectionStatus extends StatelessWidget {
  const _MachineConnectionStatus({required this.status, required this.onRetry});

  final LightConnectionStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final canRetry =
        status == LightConnectionStatus.disconnected ||
        status == LightConnectionStatus.failed;
    final label = switch (status) {
      LightConnectionStatus.connected => '樹莓派連線正常',
      LightConnectionStatus.connecting => '樹莓派連線中',
      LightConnectionStatus.unconfigured => '樹莓派尚未設定',
      LightConnectionStatus.failed => '樹莓派已離線',
      LightConnectionStatus.disconnected => '樹莓派已離線',
    };
    final color = switch (status) {
      LightConnectionStatus.connected => AppColors.green,
      LightConnectionStatus.connecting => AppColors.accent,
      LightConnectionStatus.unconfigured => AppColors.amber,
      LightConnectionStatus.failed => AppColors.red,
      LightConnectionStatus.disconnected => AppColors.red,
    };
    return Semantics(
      liveRegion: true,
      button: canRetry,
      label: 'Raspberry Pi 機台：$label${canRetry ? '，點此重新連線' : ''}',
      child: Tooltip(
        message: canRetry ? '點此重新連線' : 'Raspberry Pi 機台 $label',
        child: InkWell(
          onTap: canRetry ? onRetry : null,
          borderRadius: BorderRadius.circular(99),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == LightConnectionStatus.connecting)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                else
                  Icon(
                    status == LightConnectionStatus.connected
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    color: color,
                    size: 18,
                  ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
                '連接你的家',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                '請輸入安裝服務人員提供的家庭連線資料。完成後，就可以開始控制家中設備。',
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
                            labelText: '家庭連線位址',
                            hintText: '由安裝服務人員提供',
                            prefixIcon: Icon(Icons.home_work_outlined),
                          ),
                          validator: (value) {
                            final host = value?.trim() ?? '';
                            if (host.isEmpty) return '請輸入家庭連線位址';
                            if (host.contains('://') || host.contains('/')) {
                              return '這個位址格式不正確，請重新確認';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 8),
                          title: const Text(
                            '更多連線選項',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text('只有安裝服務人員要求時才需要調整'),
                          children: [
                            TextFormField(
                              controller: _port,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '連線通道',
                                prefixIcon: Icon(
                                  Icons.settings_ethernet_rounded,
                                ),
                              ),
                              validator: (value) {
                                final port = int.tryParse(value ?? '');
                                return port == null || port < 1 || port > 65535
                                    ? '請確認連線通道是否正確'
                                    : null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _username,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: '家庭帳號（選填）',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (value) {
                                if ((value?.trim().isEmpty ?? true) &&
                                    _password.text.isNotEmpty) {
                                  return '輸入密碼時，也請輸入家庭帳號';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _password,
                              obscureText: true,
                              enableSuggestions: false,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: '家庭密碼（選填）',
                                prefixIcon: Icon(Icons.lock_outline_rounded),
                              ),
                              validator: (value) {
                                if ((value?.isEmpty ?? true) &&
                                    _username.text.trim().isNotEmpty) {
                                  return '輸入家庭帳號時，也請輸入密碼';
                                }
                                return null;
                              },
                            ),
                          ],
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
                                : const Text('完成設定'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '你的連線資料會安全保存在這台裝置上。',
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
    required this.machineService,
    required this.autoConnect,
    required this.onEditSettings,
  });

  final MqttSettings settings;
  final MqttLightService machineService;
  final bool autoConnect;
  final VoidCallback onEditSettings;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _page = 0;
  late final List<Widget> _pages;
  StreamSubscription? _shareIntentSub;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(
        settings: widget.settings,
        lightService: widget.machineService,
        autoConnect: widget.autoConnect,
      ),
      HistoryPage(settings: widget.settings),
      AutomationPage(settings: widget.settings),
      FamilyMembersPage(settings: widget.settings),
      SettingsPage(onEdit: widget.onEditSettings),
    ];
    _handleInitialShareIntent();
    _shareIntentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _onSharedMedia,
    );
  }

  @override
  void dispose() {
    _shareIntentSub?.cancel();
    super.dispose();
  }

  Future<void> _handleInitialShareIntent() async {
    final media = await ReceiveSharingIntent.instance.getInitialMedia();
    if (media.isNotEmpty) _onSharedMedia(media);
  }

  void _onSharedMedia(List<SharedMediaFile> media) {
    for (final item in media) {
      final text = item.path;
      final url = _extractYouTubeUrl(text);
      if (url != null) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                YouTubePage(settings: widget.settings, initialUrl: url),
          ),
        );
        return;
      }
    }
  }

  String? _extractYouTubeUrl(String text) {
    final pattern = RegExp(
      r'https?://(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/)[^\s]+',
    );
    final match = pattern.firstMatch(text);
    return match?.group(0);
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
          icon: Icon(Icons.thermostat_outlined),
          selectedIcon: Icon(Icons.thermostat),
          label: '環境溫度',
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

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.settings,
    this.lightService,
    this.autoConnect = true,
  });

  final MqttSettings settings;
  final MqttLightService? lightService;
  final bool autoConnect;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final MqttLightService _lightService;
  late final bool _ownsLightService;
  late final MqttRfidService _rfidService;
  Timer? _brightnessDebounce;
  List<SensorReading>? _todayReadings;

  @override
  void initState() {
    super.initState();
    _ownsLightService = widget.lightService == null;
    _lightService = widget.lightService ?? MqttLightService(widget.settings);
    _lightService.lightState.addListener(_onLightStateChanged);
    _rfidService = MqttRfidService(widget.settings);
    _rfidService.event.addListener(_handleRfidEvent);
    _loadTodayReadings();
    if (widget.autoConnect) {
      if (_ownsLightService) _lightService.connect();
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
    if (mounted) {
      setState(
        () =>
            _todayReadings = today.isEmpty ? readings.take(1).toList() : today,
      );
    }
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
            Expanded(
              child: Text(
                known
                    ? '$memberName 刷卡進入'
                    : '警訊：陌生卡片嘗試刷卡${event.uid == null ? '' : '（${event.uid}）'}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _brightnessDebounce?.cancel();
    _lightService.lightState.removeListener(_onLightStateChanged);
    _rfidService.event.removeListener(_handleRfidEvent);
    _rfidService.dispose();
    if (_ownsLightService) _lightService.dispose();
    super.dispose();
  }

  void _onLightStateChanged() {
    if (mounted) setState(() {});
  }

  String _sceneForLight(LightState light) {
    if (!light.on) return '晚安';
    if (light.mode == 'warm_white' && light.brightness == 100) return '回家';
    if (light.mode == 'cool_white' && light.brightness == 100) return '專注';
    if (light.mode == 'warm_yellow' && light.brightness == 20) return '電影';
    return '';
  }

  void _applyScene(String scene) {
    if (_lightService.status.value != LightConnectionStatus.connected) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('燈光目前無法控制，請稍後再試')));
      return;
    }
    _brightnessDebounce?.cancel();
    switch (scene) {
      case '回家':
        _lightService.setLight(on: true, mode: 'warm_white', brightness: 100);
        break;
      case '專注':
        _lightService.setLight(on: true, mode: 'cool_white', brightness: 100);
        break;
      case '電影':
        _lightService.setLight(on: true, mode: 'warm_yellow', brightness: 20);
        break;
      case '晚安':
        _lightService.setLight(on: false);
        break;
      default:
        return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已送出「$scene」燈光指令')));
  }

  @override
  Widget build(BuildContext context) {
    final gutter = MediaQuery.sizeOf(context).width >= 700 ? 32.0 : 20.0;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My House',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '一切都在掌握中',
                      style: TextStyle(color: AppColors.muted, fontSize: 14),
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder<LightConnectionStatus>(
                valueListenable: _lightService.status,
                builder: (context, status, _) => _MachineConnectionStatus(
                  status: status,
                  onRetry: _lightService.connect,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 32),
            children: [
              // -- Camera feed --
              _LiveCameraCard(settings: widget.settings),
              const SizedBox(height: 16),

              // -- Inline environment reading --
              _TodaySensorCard(
                readings: _todayReadings,
                onRefresh: _loadTodayReadings,
              ),
              const SizedBox(height: 20),

              // -- Scene presets --
              const _Kicker('情境模式'),
              const SizedBox(height: 10),
              _PresetRow(
                selected: _sceneForLight(_lightService.lightState.value),
                enabled: true,
                onSelect: _applyScene,
              ),
              const SizedBox(height: 24),

              // -- Light + Music side by side --
              const _Kicker('控制中心'),
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
              const SizedBox(height: 12),
              _QuickControls(
                enabled: true,
                onOpenPlayer: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => YouTubePage(settings: widget.settings),
                  ),
                ),
              ),
            ],
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFDE8D8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.thermostat_rounded,
              color: AppColors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '溫度',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                readings == null
                    ? '--'
                    : latest != null
                    ? '${latest.temperature.toStringAsFixed(1)}°C'
                    : '--',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(width: 1, height: 28, color: AppColors.line),
          const Spacer(),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFDCEEF3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.water_drop_outlined,
              color: AppColors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '濕度',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                readings == null
                    ? '--'
                    : latest != null
                    ? '${latest.humidity.toStringAsFixed(0)}%'
                    : '--',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: onRefresh,
            child: const Icon(
              Icons.refresh_rounded,
              size: 18,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
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
    _refresh = Timer.periodic(const Duration(milliseconds: 800), (_) {
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
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFF101417),
                child: Center(
                  child: Text(
                    '攝影機畫面準備中',
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
  String? _playerError;

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
      _playerError = null;
    });
    await previous?.dispose();
    try {
      await player.initialize();
      await player.play();
    } catch (error) {
      if (mounted) {
        setState(() {
          _playerError = error.toString();
          _playing = null;
        });
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
                if (_playerError != null) ...[
                  Card(
                    color: AppColors.surfaceRaised,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: const Text(
                        '影片暫時無法播放，請稍後再試。',
                        style: TextStyle(color: AppColors.red),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
    final utc = DateTime.utc(
      int.parse(date.substring(0, 4)),
      int.parse(date.substring(4, 6)),
      int.parse(date.substring(6, 8)),
      int.parse(time.substring(0, 2)),
      int.parse(time.substring(2, 4)),
      int.parse(time.substring(4, 6)),
    );
    final localTime = utc.add(const Duration(hours: 8));
    return '${localTime.month.toString().padLeft(2, '0')}/${localTime.day.toString().padLeft(2, '0')} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
  }

  String _fileSize(int bytes) =>
      '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      value,
      style: const TextStyle(
        color: AppColors.muted,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        letterSpacing: 0.2,
      ),
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
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: light.on
                            ? AppColors.accentSoft
                            : AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.lightbulb_rounded,
                        color: light.on ? AppColors.accent : AppColors.muted,
                        size: 22,
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
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            light.on ? '已開啟' : '已關閉',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: light.on,
                      activeTrackColor: AppColors.accent,
                      activeThumbColor: Colors.white,
                      onChanged: connected
                          ? (value) => service.setLight(on: value)
                          : null,
                    ),
                  ],
                ),
                if (light.on) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.brightness_6_outlined,
                        color: AppColors.muted,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppColors.accent,
                            thumbColor: AppColors.accent,
                            inactiveTrackColor: AppColors.line,
                            overlayColor: AppColors.accent.withValues(
                              alpha: .12,
                            ),
                          ),
                          child: Slider(
                            min: 0,
                            max: 100,
                            value: light.brightness,
                            onChanged: connected ? onBrightnessChanged : null,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 42,
                        child: Text(
                          '${light.brightness.round()}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                          selectedColor: AppColors.accent,
                          labelStyle: TextStyle(
                            color: light.mode == mode.$1
                                ? Colors.white
                                : AppColors.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          backgroundColor: AppColors.surfaceRaised,
                          side: BorderSide(
                            color: light.mode == mode.$1
                                ? AppColors.accent
                                : AppColors.line,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _QuickControls extends StatelessWidget {
  const _QuickControls({required this.enabled, required this.onOpenPlayer});
  final bool enabled;
  final VoidCallback onOpenPlayer;
  @override
  Widget build(BuildContext context) => _QuickButton(
    icon: Icons.music_note_rounded,
    label: '音樂播放',
    subtitle: '開啟播放器',
    enabled: enabled,
    onTap: onOpenPlayer,
  );
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.line),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );
}

// _MusicModePage removed — merged into YouTubePage (lib/youtube_page.dart).

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
      ('回家', Icons.home_rounded, Color(0xFFC08B5C)),
      ('專注', Icons.light_mode_rounded, Color(0xFF6A9A5B)),
      ('電影', Icons.movie_rounded, Color(0xFF8678B0)),
      ('晚安', Icons.bedtime_rounded, Color(0xFF5B86A8)),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (int i = 0; i < presets.length; i++) ...[
            if (i > 0) Container(width: 1, height: 40, color: AppColors.line),
            Expanded(
              child: GestureDetector(
                onTap: enabled ? () => onSelect(presets[i].$1) : null,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected == presets[i].$1
                        ? presets[i].$3.withValues(alpha: .12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      i == 0
                          ? 15
                          : i == presets.length - 1
                          ? 15
                          : 0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        presets[i].$2,
                        color: selected == presets[i].$1
                            ? presets[i].$3
                            : AppColors.muted,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        presets[i].$1,
                        style: TextStyle(
                          color: selected == presets[i].$1
                              ? presets[i].$3
                              : AppColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AutomationPage extends StatefulWidget {
  const AutomationPage({super.key, required this.settings});
  final MqttSettings settings;
  @override
  State<AutomationPage> createState() => _AutomationPageState();
}

class _AutomationPageState extends State<AutomationPage> {
  List<AutomationRule>? _rules;
  List<Scene>? _scenes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = HouseApi(widget.settings);
    final values = await Future.wait([api.automations(), api.scenes()]);
    if (mounted) {
      setState(() {
        _rules = values[0] as List<AutomationRule>;
        _scenes = values[1] as List<Scene>;
      });
    }
  }

  Future<void> _editRule([AutomationRule? rule]) async {
    final edited = await showModalBottomSheet<AutomationRule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (_) =>
          _AutomationEditor(rule: rule, scenes: _scenes ?? const []),
    );
    if (edited == null) return;
    final ok = await HouseApi(widget.settings).saveAutomation(edited);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(ok ? '排程已儲存' : '目前無法儲存排程，請稍後再試')));
    if (ok) _load();
  }

  Future<void> _deleteRule(AutomationRule rule) async {
    if (rule.id == null) return;
    final confirmed = await _confirm('刪除排程？', '確定要刪除「${rule.name}」嗎？');
    if (confirmed != true) return;
    final ok = await HouseApi(widget.settings).deleteAutomation(rule.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(ok ? '排程已刪除' : '排程刪除失敗')));
    if (ok) _load();
  }

  Future<void> _toggleRule(AutomationRule rule, bool enabled) async {
    final ok = await HouseApi(widget.settings)
        .saveAutomation(_copyRule(rule, enabled: enabled));
    if (ok) _load();
  }

  Future<void> _editScene([Scene? scene]) async {
    final edited = await showModalBottomSheet<Scene>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (_) => _SceneEditor(scene: scene),
    );
    if (edited == null) return;
    final ok = await HouseApi(widget.settings).saveScene(edited);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(ok ? '情境已儲存' : '目前無法儲存情境，請稍後再試')));
    if (ok) _load();
  }

  Future<void> _deleteScene(Scene scene) async {
    if (scene.id == null) return;
    final confirmed = await _confirm('刪除情境？', '確定要刪除「${scene.name}」嗎？');
    if (confirmed != true) return;
    final ok = await HouseApi(widget.settings).deleteScene(scene.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(ok ? '情境已刪除' : '情境刪除失敗')));
    if (ok) _load();
  }

  Future<void> _toggleScene(Scene scene, bool enabled) async {
    final ok = await HouseApi(widget.settings).saveScene(
      Scene(
        id: scene.id,
        name: scene.name,
        actions: scene.actions,
        enabled: enabled,
      ),
    );
    if (ok) _load();
  }

  Future<void> _runScene(Scene scene) async {
    if (scene.id == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('正在執行情境「${scene.name}」…')));
    final result = await MqttSceneService(widget.settings).execute(scene.id!);
    if (!mounted) return;
    final message = result == null
        ? '情境執行逾時，請再試一次'
        : result.ok
        ? '情境「${scene.name}」已完成'
        : '情境暫時無法執行，請稍後再試';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    if (result != null) _load();
  }

  Future<bool?> _confirm(String title, String message) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('確認'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => _DarkPage(
    title: '自動化',
    subtitle: '排程、星期、燈光設定與情境模式',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _PageSectionLabel('燈光排程')),
            IconButton(
              onPressed: () => _editRule(),
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_rules == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          if (_rules!.isEmpty)
            const Card(child: ListTile(title: Text('尚未建立排程')))
          else
            for (final rule in _rules!)
              Card(
                child: ListTile(
                  leading: Icon(
                    (rule.startAction ?? rule.action) == 'on'
                        ? Icons.lightbulb_rounded
                        : Icons.lightbulb_outline_rounded,
                  ),
                  title: Text(rule.name),
                  subtitle: Text(_ruleSummary(rule)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: rule.enabled,
                        onChanged: (value) => _toggleRule(rule, value),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _editRule(rule);
                          if (value == 'delete') _deleteRule(rule);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('編輯')),
                          PopupMenuItem(value: 'delete', child: Text('刪除')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(child: _PageSectionLabel('情境模式')),
              IconButton(
                onPressed: () => _editScene(),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_scenes == null)
            const Center(child: CircularProgressIndicator())
          else if (_scenes!.isEmpty)
            const Card(child: ListTile(title: Text('尚未建立情境')))
          else
            for (final scene in _scenes!)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.movie_filter_outlined),
                  title: Text(scene.name),
                  subtitle: Text(_sceneSummary(scene)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '立即執行',
                        onPressed: scene.enabled
                            ? () => _runScene(scene)
                            : null,
                        icon: const Icon(Icons.play_arrow_rounded),
                      ),
                      Switch(
                        value: scene.enabled,
                        onChanged: (value) => _toggleScene(scene, value),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _editScene(scene);
                          if (value == 'delete') _deleteScene(scene);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('編輯')),
                          PopupMenuItem(value: 'delete', child: Text('刪除')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 14),
          const Text(
            '排程會依家中設定的時間自動執行。',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
          ),
        ],
      ],
    ),
  );
}

AutomationRule _copyRule(AutomationRule rule, {bool? enabled}) =>
    AutomationRule(
      id: rule.id,
      name: rule.name,
      time: rule.time,
      days: rule.days,
      action: rule.action,
      enabled: enabled ?? rule.enabled,
      startTime: rule.startTime,
      endTime: rule.endTime,
      startAction: rule.startAction,
      endAction: rule.endAction,
      startMode: rule.startMode,
      endMode: rule.endMode,
      startBrightness: rule.startBrightness,
      endBrightness: rule.endBrightness,
      sceneId: rule.sceneId,
    );

String _ruleSummary(AutomationRule rule) {
  final days = _daysLabel(rule.days);
  final start = rule.startTime ?? rule.time;
  final end = rule.endTime == null ? '' : ' → ${rule.endTime}';
  return '$days  $start$end  ${_actionLabel(rule.startAction ?? rule.action)}';
}

String _daysLabel(List<int> days) {
  if (days.length == 7) return '每天';
  const labels = ['一', '二', '三', '四', '五', '六', '日'];
  return days
      .map((day) => day >= 0 && day < 7 ? '週${labels[day]}' : '?')
      .join('、');
}

String _actionLabel(String action) => switch (action) {
  'on' => '開燈',
  'off' => '關燈',
  'scene' => '執行情境',
  _ => action,
};

String _sceneSummary(Scene scene) {
  final lightCount = scene.actions
      .where((action) => action.device == 'light')
      .length;
  final hasMusic = scene.actions.any((action) => action.device == 'music');
  final parts = <String>[];
  if (lightCount > 0) parts.add('$lightCount 組燈光');
  if (hasMusic) parts.add('音樂');
  return parts.isEmpty ? '${scene.actions.length} 個設備動作' : parts.join(' + ');
}

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts.first) ?? 18,
    minute: int.tryParse(parts.last) ?? 0,
  );
}

String _formatTime(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class _AutomationEditor extends StatefulWidget {
  const _AutomationEditor({this.rule, required this.scenes});
  final AutomationRule? rule;
  final List<Scene> scenes;

  @override
  State<_AutomationEditor> createState() => _AutomationEditorState();
}

class _AutomationEditorState extends State<_AutomationEditor> {
  late final TextEditingController _name;
  late TimeOfDay _startTime;
  TimeOfDay? _endTime;
  late String _startAction, _endAction, _startMode, _endMode;
  late double _startBrightness, _endBrightness;
  late Set<int> _days;
  int? _sceneId;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _name = TextEditingController(text: rule?.name ?? '晚上客廳燈');
    _startTime = _parseTime(rule?.startTime ?? rule?.time ?? '18:00');
    _endTime = rule?.endTime == null ? null : _parseTime(rule!.endTime!);
    _startAction = rule?.startAction ?? rule?.action ?? 'on';
    _endAction = rule?.endAction ?? 'off';
    _startMode = rule?.startMode ?? 'warm_white';
    _endMode = rule?.endMode ?? 'warm_yellow';
    _startBrightness = rule?.startBrightness ?? 70;
    _endBrightness = rule?.endBrightness ?? 30;
    _days = {
      ...(rule?.days ?? const [0, 1, 2, 3, 4, 5, 6]),
    };
    _sceneId = rule?.sceneId;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _startTime,
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請輸入排程名稱')));
      return;
    }
    if (_days.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('至少選擇一個執行星期')));
      return;
    }
    if ((_startAction == 'scene' || _endAction == 'scene') &&
        _sceneId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請先選擇要執行的情境')));
      return;
    }
    final start = _formatTime(_startTime);
    Navigator.pop(
      context,
      AutomationRule(
        id: widget.rule?.id,
        name: name,
        time: start,
        days: _days.toList()..sort(),
        action: _startAction,
        enabled: widget.rule?.enabled ?? true,
        startTime: start,
        endTime: _endTime == null ? null : _formatTime(_endTime!),
        startAction: _startAction,
        endAction: _endTime == null ? null : _endAction,
        startMode: _startAction == 'on' ? _startMode : null,
        endMode: _endTime != null && _endAction == 'on' ? _endMode : null,
        startBrightness: _startAction == 'on' ? _startBrightness : null,
        endBrightness: _endTime != null && _endAction == 'on'
            ? _endBrightness
            : null,
        sceneId: _sceneId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.rule == null ? '新增燈光排程' : '編輯燈光排程',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '排程名稱',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            const Text('執行星期', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (var day = 0; day < 7; day++)
                  FilterChip(
                    label: Text('週${['一', '二', '三', '四', '五', '六', '日'][day]}'),
                    selected: _days.contains(day),
                    onSelected: (selected) => setState(
                      () => selected ? _days.add(day) : _days.remove(day),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('開始時間'),
              trailing: TextButton(
                onPressed: _pickStart,
                child: Text(_formatTime(_startTime)),
              ),
            ),
            _ActionEditor(
              title: '開始動作',
              action: _startAction,
              mode: _startMode,
              brightness: _startBrightness,
              scenes: widget.scenes,
              sceneId: _sceneId,
              onAction: (value) => setState(() => _startAction = value),
              onMode: (value) => setState(() => _startMode = value),
              onBrightness: (value) => setState(() => _startBrightness = value),
              onScene: (value) => setState(() => _sceneId = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('設定結束時間'),
              value: _endTime != null,
              onChanged: (value) => setState(
                () => _endTime = value ? (_endTime ?? _startTime) : null,
              ),
            ),
            if (_endTime != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timer_off_outlined),
                title: const Text('結束時間'),
                trailing: TextButton(
                  onPressed: _pickEnd,
                  child: Text(_formatTime(_endTime!)),
                ),
              ),
              _ActionEditor(
                title: '結束動作',
                action: _endAction,
                mode: _endMode,
                brightness: _endBrightness,
                scenes: widget.scenes,
                sceneId: _sceneId,
                onAction: (value) => setState(() => _endAction = value),
                onMode: (value) => setState(() => _endMode = value),
                onBrightness: (value) => setState(() => _endBrightness = value),
                onScene: (value) => setState(() => _sceneId = value),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('儲存排程'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActionEditor extends StatelessWidget {
  const _ActionEditor({
    required this.title,
    required this.action,
    required this.mode,
    required this.brightness,
    required this.scenes,
    required this.sceneId,
    required this.onAction,
    required this.onMode,
    required this.onBrightness,
    required this.onScene,
  });
  final String title, action, mode;
  final double brightness;
  final List<Scene> scenes;
  final int? sceneId;
  final ValueChanged<String> onAction, onMode;
  final ValueChanged<double> onBrightness;
  final ValueChanged<int?> onScene;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surfaceRaised,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: action,
            decoration: const InputDecoration(labelText: '動作'),
            items: const [
              DropdownMenuItem(value: 'on', child: Text('開燈')),
              DropdownMenuItem(value: 'off', child: Text('關燈')),
              DropdownMenuItem(value: 'scene', child: Text('執行情境')),
            ],
            onChanged: (value) {
              if (value != null) onAction(value);
            },
          ),
          if (action == 'on') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: mode,
              decoration: const InputDecoration(labelText: '燈光模式'),
              items: const [
                DropdownMenuItem(value: 'warm_yellow', child: Text('暖黃光')),
                DropdownMenuItem(value: 'warm_white', child: Text('暖白光')),
                DropdownMenuItem(value: 'natural_white', child: Text('自然白')),
                DropdownMenuItem(value: 'cool_white', child: Text('冷白光')),
              ],
              onChanged: (value) {
                if (value != null) onMode(value);
              },
            ),
            Row(
              children: [
                const Icon(Icons.brightness_6_outlined),
                Expanded(
                  child: Slider(
                    value: brightness,
                    min: 0,
                    max: 100,
                    onChanged: onBrightness,
                  ),
                ),
                Text('${brightness.round()}%'),
              ],
            ),
          ],
          if (action == 'scene')
            DropdownButtonFormField<int>(
              initialValue: scenes.any((scene) => scene.id == sceneId)
                  ? sceneId
                  : null,
              decoration: const InputDecoration(labelText: '選擇情境'),
              items: [
                for (final scene in scenes)
                  DropdownMenuItem(value: scene.id, child: Text(scene.name)),
              ],
              onChanged: onScene,
            ),
        ],
      ),
    ),
  );
}

class _SceneEditor extends StatefulWidget {
  const _SceneEditor({this.scene});
  final Scene? scene;

  @override
  State<_SceneEditor> createState() => _SceneEditorState();
}

class _SceneLightDraft {
  _SceneLightDraft({
    this.on = true,
    this.mode = 'warm_yellow',
    this.brightness = 20,
  });

  factory _SceneLightDraft.fromAction(SceneAction action) => _SceneLightDraft(
    on: action.on ?? true,
    mode: action.mode ?? 'warm_yellow',
    brightness: action.brightness ?? 20,
  );

  bool on;
  String mode;
  double brightness;
}

class _SceneEditorState extends State<_SceneEditor> {
  late final TextEditingController _name, _url;
  late final List<_SceneLightDraft> _lights;
  bool _includeMusic = false;
  String _musicCommand = 'play';

  @override
  void initState() {
    super.initState();
    final scene = widget.scene;
    final lightActions =
        scene?.actions.where((action) => action.device == 'light').toList() ??
        const <SceneAction>[];
    final musicActions =
        scene?.actions.where((action) => action.device == 'music').toList() ??
        const <SceneAction>[];
    final music = musicActions.isEmpty ? null : musicActions.first;
    _name = TextEditingController(text: scene?.name ?? '電影模式');
    _url = TextEditingController(text: music?.url ?? '');
    _lights = lightActions.map(_SceneLightDraft.fromAction).toList();
    if (scene == null && _lights.isEmpty) _lights.add(_SceneLightDraft());
    _includeMusic = music != null;
    _musicCommand = music?.command ?? 'play';
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  void _addLight() {
    if (_lights.length + (_includeMusic ? 1 : 0) >= 20) return;
    setState(() => _lights.add(_SceneLightDraft()));
  }

  void _removeLight(int index) {
    setState(() => _lights.removeAt(index));
  }

  Future<void> _pasteMusicUrl() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text?.trim();
    if (text == null || text.isEmpty) return;
    _url.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  bool _isYouTubeUrl(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        {
          'youtu.be',
          'youtube.com',
          'www.youtube.com',
          'm.youtube.com',
        }.contains(host);
  }

  Widget _buildLightEditor(int index) {
    final light = _lights[index];
    return Container(
      margin: EdgeInsets.only(top: index == 0 ? 14 : 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      decoration: BoxDecoration(
        color: AppColors.selectionSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '燈光 ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => _removeLight(index),
                tooltip: '移除這組燈光',
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          DropdownButtonFormField<bool>(
            initialValue: light.on,
            decoration: const InputDecoration(labelText: '燈光狀態'),
            items: const [
              DropdownMenuItem(value: true, child: Text('開燈')),
              DropdownMenuItem(value: false, child: Text('關燈')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => light.on = value);
            },
          ),
          if (light.on) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: light.mode,
              decoration: const InputDecoration(labelText: '燈光模式'),
              items: const [
                DropdownMenuItem(value: 'warm_yellow', child: Text('暖黃光')),
                DropdownMenuItem(value: 'warm_white', child: Text('暖白光')),
                DropdownMenuItem(value: 'natural_white', child: Text('自然白')),
                DropdownMenuItem(value: 'cool_white', child: Text('冷白光')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => light.mode = value);
              },
            ),
            Row(
              children: [
                const Icon(Icons.brightness_6_outlined),
                Expanded(
                  child: Slider(
                    value: light.brightness,
                    min: 0,
                    max: 100,
                    onChanged: (value) =>
                        setState(() => light.brightness = value),
                  ),
                ),
                Text('${light.brightness.round()}%'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _submit() {
    final name = _name.text.trim();
    final actions = <SceneAction>[];
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請輸入情境名稱')));
      return;
    }
    for (final light in _lights) {
      actions.add(
        SceneAction(
          device: 'light',
          on: light.on,
          mode: light.mode,
          brightness: light.brightness,
        ),
      );
    }
    if (_includeMusic) {
      final url = _url.text.trim();
      if (_musicCommand == 'play' && !_isYouTubeUrl(url)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('請貼上完整的 YouTube 影片連結')));
        return;
      }
      actions.add(
        SceneAction(device: 'music', command: _musicCommand, url: url),
      );
    }
    if (actions.length > 20) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('一個情境最多只能有 20 個設備動作')));
      return;
    }
    if (actions.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('至少選擇一個設備動作')));
      return;
    }
    Navigator.pop(
      context,
      Scene(
        id: widget.scene?.id,
        name: name,
        actions: actions,
        enabled: widget.scene?.enabled ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.scene == null ? '新增情境' : '編輯情境',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '情境名稱',
                prefixIcon: Icon(Icons.movie_filter_outlined),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '燈光動作',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              SizedBox(height: 3),
                              Text(
                                '同一情境可加入多組燈光設定，會依序套用。',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _lights.length + (_includeMusic ? 1 : 0) >= 20
                              ? null
                              : _addLight,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('新增燈光'),
                        ),
                      ],
                    ),
                    if (_lights.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          '目前沒有燈光動作；如果只想播放音樂，可以保持空白。',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    else
                      for (var index = 0; index < _lights.length; index++)
                        _buildLightEditor(index),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.music_note_rounded),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '音樂動作',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              SizedBox(height: 3),
                              Text(
                                '可讓情境同時播放或停止家中音響。',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _includeMusic,
                          onChanged: (value) =>
                              setState(() => _includeMusic = value),
                        ),
                      ],
                    ),
                    if (_includeMusic) ...[
                      const Divider(height: 24),
                      DropdownButtonFormField<String>(
                        initialValue: _musicCommand,
                        decoration: const InputDecoration(labelText: '音樂動作'),
                        items: const [
                          DropdownMenuItem(value: 'play', child: Text('播放音樂')),
                          DropdownMenuItem(value: 'stop', child: Text('停止播放')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _musicCommand = value);
                          }
                        },
                      ),
                      if (_musicCommand == 'play') ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _url,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            labelText: 'YouTube 影片連結',
                            helperText: '支援 youtube.com 與 youtu.be',
                            prefixIcon: const Icon(Icons.link_rounded),
                            suffixIcon: IconButton(
                              onPressed: _pasteMusicUrl,
                              tooltip: '從剪貼簿貼上',
                              icon: const Icon(Icons.content_paste_rounded),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('儲存情境'),
              ),
            ),
          ],
        ),
      ),
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

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => _DarkPage(
    title: '設定',
    subtitle: '管理家庭與使用設定',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageSectionLabel('家庭連線'),
        const SizedBox(height: 10),
        const _SettingsInfoGroup(),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('管理家庭連線'),
          ),
        ),
      ],
    ),
  );
}

class _SettingsInfoGroup extends StatelessWidget {
  const _SettingsInfoGroup();
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        _SettingsInfoRow(
          icon: Icons.memory_rounded,
          title: '家庭控制中心',
          value: '已設定',
        ),
        const Divider(height: 1, indent: 64),
        const _SettingsInfoRow(
          icon: Icons.info_outline_rounded,
          title: '應用程式版本',
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
