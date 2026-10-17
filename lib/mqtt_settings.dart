import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MqttSettings {
  const MqttSettings({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  final String host;
  final int port;
  final String username;
  final String password;
}

class MqttSettingsStore {
  static const _hostKey = 'mqtt_host';
  static const _portKey = 'mqtt_port';
  static const _usernameKey = 'mqtt_username';
  static const _passwordKey = 'mqtt_password';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<MqttSettings?> load() async {
    final values = await Future.wait([
      _storage.read(key: _hostKey),
      _storage.read(key: _portKey),
      _storage.read(key: _usernameKey),
      _storage.read(key: _passwordKey),
    ]);
    final port = int.tryParse(values[1] ?? '');
    if (values.any((value) => value == null || value.isEmpty) ||
        port == null ||
        port < 1 ||
        port > 65535) {
      return null;
    }
    return MqttSettings(
      host: values[0]!,
      port: port,
      username: values[2]!,
      password: values[3]!,
    );
  }

  Future<void> save(MqttSettings settings) => Future.wait([
    _storage.write(key: _hostKey, value: settings.host.trim()),
    _storage.write(key: _portKey, value: settings.port.toString()),
    _storage.write(key: _usernameKey, value: settings.username.trim()),
    _storage.write(key: _passwordKey, value: settings.password),
  ]);
}
